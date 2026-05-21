import Foundation
import WidgetKit

struct TodaysPageTimelineProvider: TimelineProvider {
    typealias Entry = TodaysPageEntry

    /// Calendar used to compute day/month/year. Locale-independent for the
    /// math; user-visible weekday names are still pulled from `DayNames`.
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .autoupdatingCurrent
        return c
    }()

    func placeholder(in context: Context) -> TodaysPageEntry {
        Self.entry(for: Date(), snapshot: nil, calendar: calendar)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysPageEntry) -> Void) {
        let snapshot = Self.loadSnapshot()
        completion(Self.entry(for: Date(), snapshot: snapshot, calendar: calendar))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysPageEntry>) -> Void) {
        let snapshot = Self.loadSnapshot()
        let now = Date()

        // Build entries: now, tomorrow 00:00:01, day-after 00:00:01.
        // Each entry's `date` is when WidgetKit switches to it, and the
        // entry's calendar (year, month, day) is computed from that date —
        // so each entry represents "today" at its own moment.
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))!
        let oneSecond: TimeInterval = 1
        let dates: [Date] = [
            now,
            startOfTomorrow.addingTimeInterval(oneSecond),
            startOfDayAfter.addingTimeInterval(oneSecond),
        ]

        let entries = dates.map { date in
            Self.entry(for: date, snapshot: snapshot, calendar: calendar)
        }

        // Reload after the last entry's date so a 3-day app dormancy still
        // bottoms out at a fresh timeline rather than freezing on day 3's
        // content forever.
        let reloadAt = startOfDayAfter.addingTimeInterval(60)
        completion(Timeline(entries: entries, policy: .after(reloadAt)))
    }

    // MARK: - Helpers

    private static func loadSnapshot() -> WidgetWeatherSnapshot? {
        guard let data = AppGroup.defaults?.data(forKey: AppGroup.Key.snapshot) else { return nil }
        return try? JSONDecoder().decode(WidgetWeatherSnapshot.self, from: data)
    }

    /// Builds an entry for a given wall-clock date. The `snapshot` is
    /// attached only if its `(year, month, day)` matches the entry's date —
    /// stale or wrong-day snapshots are surfaced as `nil` so the view can
    /// hide the weather elements.
    private static func entry(
        for date: Date,
        snapshot: WidgetWeatherSnapshot?,
        calendar: Calendar
    ) -> TodaysPageEntry {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1

        let matching: WidgetWeatherSnapshot? = {
            guard let s = snapshot, s.year == y, s.month == m, s.day == d else { return nil }
            return s
        }()

        let daysSinceCapture: Int? = snapshot.flatMap { s in
            let dc = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: s.capturedAt),
                to: calendar.startOfDay(for: date)
            )
            return dc.day
        }

        return TodaysPageEntry(
            date: date,
            day: d, month: m, year: y,
            snapshot: matching,
            daysSinceCapture: daysSinceCapture
        )
    }
}
