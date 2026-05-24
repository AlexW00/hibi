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
            upcomingOnly: false,
            showReminders: true
        )
    }

    func snapshot(for config: Intent, in context: Context) async -> EventsEntry {
        let snapshot = Self.loadSnapshot()
        return Self.entry(
            for: Date(),
            snapshot: snapshot,
            calendar: calendar,
            includeAllDay: config.showAllDay,
            upcomingOnly: config.upcomingOnly,
            showReminders: config.showReminders
        )
    }

    func timeline(
        for config: Intent,
        in context: Context
    ) async -> Timeline<EventsEntry> {
        let snapshot = Self.loadSnapshot()
        let now = Date()

        // Build entries: now, plus each remaining event start/end boundary
        // and each remaining reminder due-time boundary, plus the start of
        // tomorrow (so the widget rolls over to the empty state if the app
        // hasn't been opened to refresh the snapshot). Boundaries make the
        // active row's progress fill advance, drop reminders out of the
        // upcoming-only filter when their due time passes, AND, if the user
        // opted into `upcomingOnly`, drop events from the list at the moment
        // they end.
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
            for rem in snap.reminders {
                if let due = rem.dueDate, due > now {
                    dates.insert(due.addingTimeInterval(1))
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
                upcomingOnly: config.upcomingOnly,
                showReminders: config.showReminders
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

    /// Build an entry for `date`. Defaults show every event and every
    /// reminder on the day; the user's per-widget toggles can drop all-day
    /// rows, drop reminders entirely, and/or hide items that have already
    /// finished (events past their end, reminders marked complete).
    private static func entry(
        for date: Date,
        snapshot: WidgetEventsSnapshot?,
        calendar: Calendar,
        includeAllDay: Bool,
        upcomingOnly: Bool,
        showReminders: Bool
    ) -> EventsEntry {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1

        let snapshotIsForToday = snapshot?.year == y && snapshot?.month == m && snapshot?.day == d

        let events: [WidgetEventsSnapshot.Event] = {
            guard let s = snapshot, snapshotIsForToday else { return [] }
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

        let reminders: [WidgetEventsSnapshot.Reminder] = {
            guard showReminders else { return [] }
            guard let s = snapshot, snapshotIsForToday else { return [] }
            return s.reminders.filter { rem in
                // Completed reminders are the reminders equivalent of a
                // finished event — hide them in upcoming-only mode.
                if upcomingOnly && rem.isCompleted { return false }
                return true
            }
        }()

        return EventsEntry(
            date: date,
            day: d, month: m, year: y,
            events: events,
            reminders: reminders
        )
    }
}
