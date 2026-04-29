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

    /// Column offset (0..6) for the first day of the given month in the user's
    /// current calendar. Respects `Calendar.firstWeekday` so German users get a
    /// Monday-first grid and Japanese/English users get a Sunday-first grid.
    static func firstWeekday(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = Calendar.autoupdatingCurrent
        guard let date = cal.date(from: comps) else { return 0 }
        let weekday = cal.component(.weekday, from: date)  // 1=Sun..7=Sat
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

    /// True when the given (y, m, d) matches the fixed demo anchor date.
    /// Used only by the demo-time-of-day branch in `CalendarEvent.progress`.
    static func isDemoAnchor(year: Int, month: Int, day: Int) -> Bool {
        year == demoAnchorYear && month == demoAnchorMonth && day == demoAnchorDay
    }
}

/// Locale-aware month name accessors. Backed by `Calendar.autoupdatingCurrent`
/// so German shows "Januar", Japanese "1月", English "January" — no catalog
/// entries needed for these since the system already provides them.
enum MonthNames {
    static var full: [String]  { Calendar.autoupdatingCurrent.standaloneMonthSymbols }
    static var short: [String] { Calendar.autoupdatingCurrent.shortStandaloneMonthSymbols }
}

/// Locale-aware weekday name accessors, always Sunday-indexed (0=Sun..6=Sat)
/// regardless of locale week-start — callers that need to account for
/// `firstWeekday` do so at the view layer (see `MonthView.weekdayHeader`).
enum DayNames {
    static var full: [String]  { Calendar.autoupdatingCurrent.standaloneWeekdaySymbols }
    static var short: [String] { Calendar.autoupdatingCurrent.veryShortStandaloneWeekdaySymbols }
}

enum AppColor {
    /// Monochrome highlight — the primary ink color.
    /// Used for the today-indicator outline and other minimal editorial accents.
    static let accent: Color = .primary
}

enum AppFont {
    static let serifRegular = "InstrumentSerif-Regular"
    static let serifItalic  = "InstrumentSerif-Italic"
    /// Noto Serif JP Regular. Used for the entire display face when the user's
    /// preferred language needs CJK glyphs — Instrument Serif is Latin-only and
    /// would otherwise fall back to the system default for kana/kanji/hanja/hanzi.
    /// Noto CJK ships no italic; callers that want italic in a CJK locale get
    /// synthesized skew via `Font.italic()`.
    static let serifJP = "NotoSerifJP-Regular"

    /// True when the user's preferred UI language resolves to a CJK language.
    /// Read from `Locale.preferredLanguages` (what the app actually renders
    /// in) rather than `Locale.current`, which on this project is pinned to
    /// `de_DE` for calendar math.
    static var usesCJKSerif: Bool {
        guard let first = Locale.preferredLanguages.first else { return false }
        switch Locale(identifier: first).language.languageCode?.identifier {
        case "ja", "zh", "ko":
            return true
        default:
            return false
        }
    }
}

extension Font {
    /// App display font. `simple` swaps Instrument Serif for the system
    /// sans-serif face (driven by the "useSimpleFont" AppStorage toggle).
    /// In a CJK locale the serif face is Noto Serif JP (Latin-only
    /// Instrument Serif can't render CJK scripts); italic is synthesized since
    /// Noto CJK has no italic cut.
    static func appSerif(size: CGFloat, italic: Bool = false, simple: Bool) -> Font {
        if simple {
            let base = Font.system(size: size)
            return italic ? base.italic() : base
        }
        if AppFont.usesCJKSerif {
            let base = Font.custom(AppFont.serifJP, size: size)
            return italic ? base.italic() : base
        }
        return .custom(italic ? AppFont.serifItalic : AppFont.serifRegular, size: size)
    }
}
