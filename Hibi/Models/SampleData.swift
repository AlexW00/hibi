import Foundation
import SwiftUI

enum SampleData {
    static let todayYear = 2026
    static let todayMonth = 4
    static let todayDay = 18

    static func firstWeekday(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return 0 }
        return cal.component(.weekday, from: date) - 1
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
        year == todayYear && month == todayMonth && day == todayDay
    }
}

enum MonthNames {
    static let full = ["January","February","March","April","May","June",
                       "July","August","September","October","November","December"]
    static let short = ["Jan","Feb","Mar","Apr","May","Jun",
                        "Jul","Aug","Sep","Oct","Nov","Dec"]
}

enum DayNames {
    static let upper = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
    static let full  = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    static let short = ["S","M","T","W","T","F","S"]
}

enum AppColor {
    /// Monochrome highlight — the primary ink color.
    /// Used for the today-indicator outline and other minimal editorial accents.
    static let accent: Color = .primary
}

enum AppFont {
    static let serifRegular = "InstrumentSerif-Regular"
    static let serifItalic  = "InstrumentSerif-Italic"
}
