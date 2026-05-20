import Foundation
import Observation

/// Observable "what day is it right now" source. Views that highlight today
/// read `clock.isToday(...)` so a redraw is triggered when the wall clock
/// crosses midnight (or the user changes time zone / system date).
/// `ContentView` owns the single instance, calls `refresh()` from
/// `NSCalendarDayChanged` and scene-foreground transitions, and injects it
/// via `.environment(_:)`.
@MainActor
@Observable
final class Clock {
    private(set) var year: Int
    private(set) var month: Int
    private(set) var day: Int

    init() {
        let c = Self.currentComponents()
        self.year = c.year
        self.month = c.month
        self.day = c.day
    }

    /// Re-read the current date. Returns the previous (y, m, d) if the day
    /// rolled over so the caller can decide whether to follow the user along
    /// (e.g. advance a "viewing today" selection to the new today). Returns
    /// nil when nothing changed.
    @discardableResult
    func refresh() -> (year: Int, month: Int, day: Int)? {
        let c = Self.currentComponents()
        guard c.year != year || c.month != month || c.day != day else { return nil }
        let previous = (year: year, month: month, day: day)
        year = c.year
        month = c.month
        day = c.day
        return previous
    }

    func isToday(year: Int, month: Int, day: Int) -> Bool {
        year == self.year && month == self.month && day == self.day
    }

    private static func currentComponents() -> (year: Int, month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return (
            c.year ?? SampleData.demoAnchorYear,
            c.month ?? SampleData.demoAnchorMonth,
            c.day ?? SampleData.demoAnchorDay
        )
    }
}
