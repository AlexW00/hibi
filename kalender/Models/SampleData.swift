import Foundation
import SwiftUI

enum SampleData {
    static let todayYear = 2026
    static let todayMonth = 4
    static let todayDay = 18

    static let events: [CalendarEvent] = [
        .init(day: 2,  start: "09:00", end: "10:00", title: "All-hands",            category: .work),
        .init(day: 4,  start: "20:00", end: "22:00", title: "Concert · Tivoli",     category: .social),
        .init(day: 6,  start: "11:00", end: "12:00", title: "Doctor",               category: .focus),
        .init(day: 7,  start: "18:00", end: "19:00", title: "Run",                  category: .health),
        .init(day: 9,  start: "13:00", end: "14:00", title: "Budget review",        category: .work),
        .init(day: 10, start: "19:30", end: "21:00", title: "Movie night",          category: .life),
        .init(day: 11, title: "Mom visiting", category: .life, allDay: true),
        .init(day: 12, start: "11:00", end: "13:00", title: "Brunch with mom",      category: .life),

        .init(day: 13, start: "09:30", end: "10:00", title: "Weekly planning",      category: .work,   location: "HQ · Room 4"),
        .init(day: 13, start: "13:00", end: "14:00", title: "Lunch — Mira",         category: .life,   location: "Torno"),
        .init(day: 13, start: "18:00", end: "19:30", title: "Run · Kanalvej loop",  category: .health),

        .init(day: 14, start: "11:00", end: "12:00", title: "Design crit",          category: .work),
        .init(day: 14, start: "19:00", end: "22:00", title: "Dinner at Stedsans",   category: .social),

        .init(day: 15, start: "08:00", end: "09:00", title: "Strength",             category: .health, location: "Studio 3"),
        .init(day: 15, start: "14:00", end: "15:00", title: "Project review",       category: .work),
        .init(day: 15, title: "Tax filing due", category: .focus, allDay: true),

        .init(day: 16, start: "09:00", end: "09:45", title: "1:1 · Jonas",          category: .work),
        .init(day: 16, start: "16:00", end: "17:00", title: "Therapy",              category: .focus),

        .init(day: 17, start: "12:00", end: "13:00", title: "Team lunch",           category: .social, location: "Pluto"),
        .init(day: 17, start: "20:00", end: "23:30", title: "Elin & Kasper · drinks", category: .social, location: "Lidkoeb"),

        .init(day: 18, start: "10:30", end: "11:00", title: "Coffee with Anna",     category: .life,   location: "Democratic"),
        .init(day: 18, start: "14:00", end: "15:30", title: "Museum: Arctic Light", category: .focus,  location: "SMK"),
        .init(day: 18, start: "19:00", end: "20:30", title: "Sunset swim",          category: .health, location: "Amager Strand"),

        .init(day: 19, title: "No plans — recover", category: .life, allDay: true),
        .init(day: 19, start: "11:00", end: "12:30", title: "Farmers market",       category: .life,   location: "Torvehallerne"),

        .init(day: 20, start: "09:00", end: "09:30", title: "Standup",              category: .work),
        .init(day: 20, start: "10:00", end: "11:00", title: "Concept review",       category: .work),
        .init(day: 20, start: "17:30", end: "18:30", title: "Yoga",                 category: .health),

        .init(day: 21, start: "10:00", end: "11:30", title: "Client workshop",      category: .work,   location: "Remote"),
        .init(day: 21, start: "18:00", end: "19:00", title: "Book club",            category: .focus),

        .init(day: 22, start: "13:00", end: "17:00", title: "Offsite planning",     category: .work),
        .init(day: 23, start: "20:00", end: "23:00", title: "Birthday · Soren",     category: .social, location: "Vesterbro"),
        .init(day: 24, title: "Flight to Lisbon", category: .life, allDay: true),
        .init(day: 24, start: "07:10", end: "11:40", title: "CPH → LIS",            category: .life),
        .init(day: 25, start: "10:00", end: "12:00", title: "LX Factory walk",      category: .focus),
        .init(day: 26, start: "19:00", end: "22:00", title: "Dinner at Belcanto",   category: .social),
        .init(day: 27, start: "12:00", end: "13:00", title: "Museum MAAT",          category: .focus),
        .init(day: 28, start: "16:00", end: "19:00", title: "LIS → CPH",            category: .life),
        .init(day: 29, start: "09:00", end: "09:30", title: "Standup",              category: .work),
        .init(day: 30, start: "15:00", end: "16:00", title: "Q2 kickoff",           category: .work),
    ]

    static let weather: [Int: DayWeather] = [
        1:  .init(high: 11, low: 4,  code: .pcloud),
        2:  .init(high: 12, low: 5,  code: .sun),
        3:  .init(high: 10, low: 6,  code: .rain),
        4:  .init(high: 9,  low: 4,  code: .wind),
        5:  .init(high: 13, low: 5,  code: .sun),
        6:  .init(high: 14, low: 7,  code: .sun),
        7:  .init(high: 12, low: 8,  code: .pcloud),
        8:  .init(high: 10, low: 6,  code: .rain),
        9:  .init(high: 11, low: 5,  code: .cloud),
        10: .init(high: 13, low: 6,  code: .pcloud),
        11: .init(high: 15, low: 7,  code: .sun),
        12: .init(high: 16, low: 8,  code: .sun),
        13: .init(high: 14, low: 9,  code: .pcloud),
        14: .init(high: 12, low: 7,  code: .rain),
        15: .init(high: 11, low: 6,  code: .rain),
        16: .init(high: 13, low: 5,  code: .wind),
        17: .init(high: 15, low: 7,  code: .sun),
        18: .init(high: 17, low: 9,  code: .sun),
        19: .init(high: 16, low: 8,  code: .pcloud),
        20: .init(high: 14, low: 7,  code: .pcloud),
        21: .init(high: 13, low: 6,  code: .cloud),
        22: .init(high: 12, low: 6,  code: .rain),
        23: .init(high: 14, low: 7,  code: .pcloud),
        24: .init(high: 16, low: 8,  code: .sun),
        25: .init(high: 18, low: 9,  code: .sun),
        26: .init(high: 19, low: 10, code: .sun),
        27: .init(high: 17, low: 9,  code: .pcloud),
        28: .init(high: 15, low: 8,  code: .pcloud),
        29: .init(high: 14, low: 7,  code: .rain),
        30: .init(high: 13, low: 6,  code: .cloud),
    ]

    static func events(forDay day: Int) -> [CalendarEvent] {
        events.filter { $0.day == day }.sorted { a, b in
            if a.allDay && !b.allDay { return true }
            if !a.allDay && b.allDay { return false }
            return (a.start ?? "") < (b.start ?? "")
        }
    }

    static func weather(forDay day: Int) -> DayWeather? {
        weather[day]
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
