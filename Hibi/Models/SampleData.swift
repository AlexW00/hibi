import CoreText
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

nonisolated enum AppFont {
    static let serifRegular = "InstrumentSerif-Regular"
    static let serifItalic  = "InstrumentSerif-Italic"
    /// Noto Serif JP Regular. Used for the entire display face when the user's
    /// preferred language needs CJK glyphs — Instrument Serif is Latin-only and
    /// would otherwise fall back to the system default for kana/kanji/hanja/hanzi.
    /// Noto CJK ships no italic; callers that want italic in a CJK locale get
    /// synthesized skew via `Font.italic()`.
    static let serifJP = "NotoSerifJP-Regular"
    static let serifJPBlack = "NotoSerifJP-Black"

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

    /// Idempotent: registers Instrument Serif (Regular/Italic) and Noto
    /// Serif JP with the process-wide CoreText font manager. Called from
    /// `HibiApp.init` in the main app and from `HibiWidgetsBundle.init` in
    /// the widget extension. Each process has its own font namespace so the
    /// widget MUST call this; fonts registered by the app are not visible
    /// to the widget extension.
    static func registerFonts() {
        let fonts: [(name: String, ext: String)] = [
            ("InstrumentSerif-Regular", "ttf"),
            ("InstrumentSerif-Italic", "ttf"),
            ("NotoSerifJP-Regular", "otf"),
            ("NotoSerifJP-Black", "otf"),
        ]
        for font in fonts {
            guard let url = Bundle.main.url(forResource: font.name, withExtension: font.ext) else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
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

extension AppFont {
    /// How far (in points) the Today's-Page **small widget** numeral must be
    /// lifted so the day number — and the today-underline pinned to its bottom
    /// — land where they do in Latin locales.
    ///
    /// The small widget anchors its content from the top. In a CJK locale the
    /// numeral renders in Noto Serif JP, whose line box has a much deeper
    /// ascent than Instrument Serif (≈1.15em vs ≈0.99em) and is taller overall.
    /// Digits sit on the baseline, so that extra ascent is empty space *above*
    /// the glyph: the top-anchored numeral, and the underline bottom-pinned to
    /// it, get shoved down toward the perforation. Subtracting this difference
    /// (as a negative top padding) re-seats the block at the Latin position.
    ///
    /// Metrics are read live from the registered faces via CoreText, so the
    /// value tracks the actual fonts rather than hard-coded ratios. Returns 0
    /// for Latin / system (`simple`) faces, leaving non-CJK locales untouched.
    ///
    /// - Parameters:
    ///   - numeralSize: point size of the day numeral.
    ///   - weekdaySize: point size of the weekday line above it — its taller
    ///     CJK line box also pushes the numeral down, so it's folded in here.
    static func cjkNumeralTopCompensation(numeralSize: CGFloat, weekdaySize: CGFloat, simple: Bool) -> CGFloat {
        guard !simple, usesCJKSerif else { return 0 }
        func ascent(_ name: String, _ size: CGFloat) -> CGFloat {
            CTFontGetAscent(CTFontCreateWithName(name as CFString, size, nil))
        }
        func lineHeight(_ name: String, _ size: CGFloat) -> CGFloat {
            let f = CTFontCreateWithName(name as CFString, size, nil)
            return CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
        }
        let numeralAscentGap = ascent(serifJP, numeralSize) - ascent(serifRegular, numeralSize)
        let weekdayLineGap = lineHeight(serifJP, weekdaySize) - lineHeight(serifRegular, weekdaySize)
        return max(0, numeralAscentGap + weekdayLineGap)
    }
}
