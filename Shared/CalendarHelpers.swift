import Foundation

enum CalendarHelpers {
    static var todayYear: Int { todayComponents.year }
    static var todayMonth: Int { todayComponents.month }
    static var todayDay: Int { todayComponents.day }

    private static var todayComponents: (year: Int, month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    static func firstWeekday(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = Calendar.autoupdatingCurrent
        guard let date = cal.date(from: comps) else { return 0 }
        let weekday = cal.component(.weekday, from: date)
        return (weekday - cal.firstWeekday + 7) % 7
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    static func weekday(year: Int, month: Int, day: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return 0 }
        return cal.component(.weekday, from: date) - 1
    }

    static func isToday(year: Int, month: Int, day: Int) -> Bool {
        let t = todayComponents
        return year == t.year && month == t.month && day == t.day
    }
}

enum MonthNames {
    static var full: [String]  { Calendar.autoupdatingCurrent.standaloneMonthSymbols }
    static var short: [String] { Calendar.autoupdatingCurrent.shortStandaloneMonthSymbols }
}

enum DayNames {
    static var full: [String]  { Calendar.autoupdatingCurrent.standaloneWeekdaySymbols }
    static var short: [String] { Calendar.autoupdatingCurrent.veryShortStandaloneWeekdaySymbols }
}
