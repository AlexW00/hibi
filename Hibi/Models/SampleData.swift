import Foundation
import SwiftUI

enum SampleData {
    /// The device's current date, split into gregorian components in the user's
    /// current time zone. Recomputed on each access so crossing midnight is
    /// reflected the next time a view reads these.
    static var todayYear: Int { todayComponents.year }
    static var todayMonth: Int { todayComponents.month }
    static var todayDay: Int { todayComponents.day }

    /// Fixed anchor for DEBUG demo mode: the date the curated `DemoFixtures`
    /// events and the demo-time-of-day branch in `CalendarEvent.progress` treat
    /// as "today" for screenshots.
    static let demoAnchorYear = 2026
    static let demoAnchorMonth = 4
    static let demoAnchorDay = 18

    private static var todayComponents: (year: Int, month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? demoAnchorYear, c.month ?? demoAnchorMonth, c.day ?? demoAnchorDay)
    }

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
        let t = todayComponents
        return year == t.year && month == t.month && day == t.day
    }

    /// True when the given (y, m, d) matches the fixed demo anchor date.
    /// Used only by the demo-time-of-day branch in `CalendarEvent.progress`.
    static func isDemoAnchor(year: Int, month: Int, day: Int) -> Bool {
        year == demoAnchorYear && month == demoAnchorMonth && day == demoAnchorDay
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

extension Font {
    /// App display font. `simple` swaps Instrument Serif for the system
    /// sans-serif face (driven by the "useSimpleFont" AppStorage toggle).
    static func appSerif(size: CGFloat, italic: Bool = false, simple: Bool) -> Font {
        if simple {
            let base = Font.system(size: size)
            return italic ? base.italic() : base
        }
        return .custom(italic ? AppFont.serifItalic : AppFont.serifRegular, size: size)
    }
}
