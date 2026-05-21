import Foundation
import WidgetKit

struct EventsTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = EventsEntry
    typealias Intent = EventsWidgetConfigurationIntent

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .autoupdatingCurrent
        return c
    }()

    func placeholder(in context: Context) -> EventsEntry {
        Self.entry(
            for: Date(),
            snapshot: nil,
            calendar: calendar,
            includeAllDay: true,
            upcomingOnly: false
        )
    }

    func snapshot(for config: Intent, in context: Context) async -> EventsEntry {
        let snapshot = Self.loadSnapshot()
        return Self.entry(
            for: Date(),
            snapshot: snapshot,
            calendar: calendar,
            includeAllDay: config.showAllDay,
            upcomingOnly: config.upcomingOnly
        )
    }

    func timeline(
        for config: Intent,
        in context: Context
    ) async -> Timeline<EventsEntry> {
        let snapshot = Self.loadSnapshot()
        let now = Date()

        // Build entries: now, plus each remaining event start/end boundary,
        // plus the start of tomorrow (so the widget rolls over to the empty
        // state if the app hasn't been opened to refresh the snapshot).
        // Boundaries make the active row's progress fill advance — AND, if
        // the user opted into `upcomingOnly`, drop events from the list at
        // the moment they end.
        var dates: Set<Date> = [now]

        if let snap = snapshot {
            for ev in snap.events {
                if let s = ev.startDate, s > now {
                    dates.insert(s.addingTimeInterval(1))
                }
                if let e = ev.endDate, e > now {
                    dates.insert(e.addingTimeInterval(1))
                }
            }
        }

        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: now)
        )!
        dates.insert(startOfTomorrow.addingTimeInterval(1))

        // Budget guard — pathological calendars shouldn't burn all 40-70
        // daily refreshes on one widget.
        let sortedDates = Array(dates).sorted().prefix(50)

        let entries = sortedDates.map { date in
            Self.entry(
                for: date,
                snapshot: snapshot,
                calendar: calendar,
                includeAllDay: config.showAllDay,
                upcomingOnly: config.upcomingOnly
            )
        }

        let reloadAt = startOfTomorrow.addingTimeInterval(60)
        return Timeline(entries: entries, policy: .after(reloadAt))
    }

    // MARK: - Helpers

    private static func loadSnapshot() -> WidgetEventsSnapshot? {
        guard let data = AppGroup.defaults?.data(forKey: AppGroup.Key.eventsSnapshot) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetEventsSnapshot.self, from: data)
    }

    /// Build an entry for `date`. Defaults show every event on the day;
    /// the user's per-widget toggles can drop all-day rows and/or hide
    /// events whose end has already passed.
    private static func entry(
        for date: Date,
        snapshot: WidgetEventsSnapshot?,
        calendar: Calendar,
        includeAllDay: Bool,
        upcomingOnly: Bool
    ) -> EventsEntry {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1

        let events: [WidgetEventsSnapshot.Event] = {
            guard let s = snapshot, s.year == y, s.month == m, s.day == d else { return [] }
            return s.events.filter { ev in
                if !includeAllDay && ev.allDay { return false }
                if upcomingOnly {
                    // Drop events whose end has already passed. Missing
                    // endDate is treated as still-pending (we can't say
                    // otherwise).
                    guard let end = ev.endDate else { return true }
                    return end > date
                }
                return true
            }
        }()

        return EventsEntry(date: date, day: d, month: m, year: y, events: events)
    }
}
