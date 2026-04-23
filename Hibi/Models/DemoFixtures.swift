import Foundation
import SwiftUI

/// Curated static events for debug demo mode (screenshots / App Store), Feb–Jun 2026.
///
/// Events are locale-aware: English, German, and Japanese each get culturally
/// appropriate fixtures so screenshots feel native in every language.
///
/// **Sparse days (~1 in 6):** for each month, days where `day % 6 == 0` have no events,
/// except **April 18** (SampleData "today") stays full for screenshots.
enum DemoFixtures {
    typealias EventMap = [MonthKey: [Int: [CalendarEvent]]]

    static let events: EventMap = {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "ja": return makeJapaneseEvents()
        case "de": return makeGermanEvents()
        default:   return makeEnglishEvents()
        }
    }()

    // MARK: - Shared helpers

    static func date(_ y: Int, _ m: Int, _ day: Int, h: Int = 0, min: Int = 0) -> Date {
        var comps = DateComponents(year: y, month: m, day: day, hour: h, minute: min)
        comps.calendar = Calendar(identifier: .gregorian)
        return comps.date!
    }

    static func sortedMap(_ map: inout EventMap) {
        for (key, days) in map {
            var sortedDays = days
            for dayKey in sortedDays.keys {
                sortedDays[dayKey]?.sort { lhs, rhs in
                    if lhs.allDay != rhs.allDay { return lhs.allDay && !rhs.allDay }
                    return (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
                }
            }
            map[key] = sortedDays
        }
    }

    // MARK: - Shared palette

    static let rose   = Color(.displayP3, red: 0.96, green: 0.72, blue: 0.78)
    static let peach  = Color(.displayP3, red: 0.99, green: 0.82, blue: 0.70)
    static let mint   = Color(.displayP3, red: 0.72, green: 0.90, blue: 0.82)
    static let sky    = Color(.displayP3, red: 0.72, green: 0.84, blue: 0.98)
    static let lilac  = Color(.displayP3, red: 0.82, green: 0.76, blue: 0.96)
    static let butter = Color(.displayP3, red: 0.98, green: 0.93, blue: 0.65)
    static let sea    = Color(.displayP3, red: 0.65, green: 0.88, blue: 0.90)
    static let coral  = Color(.displayP3, red: 0.98, green: 0.70, blue: 0.68)
}
