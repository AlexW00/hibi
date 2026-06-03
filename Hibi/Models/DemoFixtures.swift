import Foundation
import SwiftUI

/// Curated demo data for DEBUG demo mode and App Store screenshots.
///
/// **Everything is anchored to *today*** (`SampleData.today*`), not fixed
/// calendar dates — the app always opens on the real current day, so a floating
/// "today" over fixed fixtures was what made the Day/Week/widget content look
/// random. Anchoring means the curated distribution always lands where it's
/// seen.
///
/// One source of truth, three layers:
///  - **Highlight window** (`highlightEvents`, today ± a few days): a hand-tuned
///    schedule with a deliberate per-day count (today = 3, then 2 / 2 / 1 / 0 on
///    nearby days) — this is what the Day and Week screenshots show.
///  - **Ambient filler**: one event every other day across ± ~10 weeks so the
///    Month grid has dots and far Week scrolling isn't empty. Titles are reused
///    from the same pool.
///  - **Reminders** (`reminderSlots`): today-anchored, mixed (timed / overdue /
///    completed / recurring).
///
/// All user-visible words live in `DemoStrings`; weather in `DemoFixtures+Weather`;
/// widget entry adapters in `DemoFixtures+WidgetSnapshots`.
enum DemoFixtures {
    typealias EventMap = [MonthKey: [Int: [CalendarEvent]]]
    typealias ReminderMap = [MonthKey: [Int: [CalendarReminder]]]

    /// The language the curated content renders in. Resolved from
    /// `Locale.preferredLanguages` (what the app actually renders in), not
    /// `Locale.current`, whose region is pinned to de_DE for calendar math.
    enum Language {
        case english, german, japanese, korean, chineseSimplified, chineseTraditional
    }

    static let resolvedLanguage: Language = {
        let language = Locale(identifier: Locale.preferredLanguages.first ?? "en").language
        switch language.languageCode?.identifier {
        case "ja": return .japanese
        case "ko": return .korean
        case "de": return .german
        case "zh":
            return language.script?.identifier == "Hant" ? .chineseTraditional : .chineseSimplified
        default:   return .english
        }
    }()

    static let events: EventMap = buildEvents()
    static let reminders: ReminderMap = buildReminders()

    // MARK: - Shared helpers

    static func date(_ y: Int, _ m: Int, _ day: Int, h: Int = 0, min: Int = 0) -> Date {
        var comps = DateComponents(year: y, month: m, day: day, hour: h, minute: min)
        comps.calendar = Calendar(identifier: .gregorian)
        return comps.date!
    }

    /// (year, month, day) for `today + delta`, in the user's calendar.
    static func dayInfo(offsetDays delta: Int) -> (y: Int, m: Int, d: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let base = cal.date(from: DateComponents(
            year: SampleData.todayYear, month: SampleData.todayMonth, day: SampleData.todayDay
        )) ?? Date()
        let shifted = cal.date(byAdding: .day, value: delta, to: base) ?? base
        let c = cal.dateComponents([.year, .month, .day], from: shifted)
        return (c.year ?? SampleData.todayYear, c.month ?? SampleData.todayMonth, c.day ?? SampleData.todayDay)
    }

    // MARK: - Palette

    static let rose   = Color(.displayP3, red: 0.96, green: 0.72, blue: 0.78)
    static let peach  = Color(.displayP3, red: 0.99, green: 0.82, blue: 0.70)
    static let mint   = Color(.displayP3, red: 0.72, green: 0.90, blue: 0.82)
    static let sky    = Color(.displayP3, red: 0.72, green: 0.84, blue: 0.98)
    static let lilac  = Color(.displayP3, red: 0.82, green: 0.76, blue: 0.96)
    static let butter = Color(.displayP3, red: 0.98, green: 0.93, blue: 0.65)
    static let sea    = Color(.displayP3, red: 0.65, green: 0.88, blue: 0.90)
    static let coral  = Color(.displayP3, red: 0.98, green: 0.70, blue: 0.68)

    // MARK: - Event schedule

    /// One curated event, relative to today.
    private struct EventSpec {
        let offset: Int
        /// nil start = all-day.
        let start: (h: Int, m: Int)?
        let end: (h: Int, m: Int)?
        let titleKey: String
        let tint: Color
        let locationKey: String?
        let recurring: Bool
    }

    private static func timed(_ offset: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int,
                              _ titleKey: String, _ tint: Color,
                              loc: String? = nil, recurring: Bool = false) -> EventSpec {
        EventSpec(offset: offset, start: (sh, sm), end: (eh, em),
                  titleKey: titleKey, tint: tint, locationKey: loc, recurring: recurring)
    }

    private static func allDay(_ offset: Int, _ titleKey: String, _ tint: Color) -> EventSpec {
        EventSpec(offset: offset, start: nil, end: nil,
                  titleKey: titleKey, tint: tint, locationKey: nil, recurring: false)
    }

    /// Deliberate per-day counts: today = 3, +1 = 2, −1 = 2, +2 = 1, +3 = 0, …
    private static let highlightEvents: [EventSpec] = [
        // Today — a light, legible day that tells a done / in-progress / upcoming
        // story against the frozen 09:41 screenshot clock (see
        // `DemoEnvironment.screenshotNow`): the morning run reads as finished,
        // the design review (09:00–10:30) is mid-progress (~half filled at 09:41),
        // and dinner is still ahead (empty).
        timed(0, 7, 30, 8, 15, "run", mint),
        timed(0, 9, 0, 10, 30, "review", lilac, loc: "studio"),
        timed(0, 19, 30, 21, 30, "dinner", rose, loc: "saffron"),
        // +1 — two.
        timed(1, 12, 30, 13, 30, "lunch", peach, loc: "lumi"),
        timed(1, 16, 0, 16, 30, "coffee", sea, loc: "bluebottle"),
        // −1 — two.
        timed(-1, 11, 0, 11, 45, "haircut", sea, loc: "salon"),
        timed(-1, 17, 30, 18, 15, "grocery", butter, loc: "market"),
        // +2 — one. (+3 deliberately empty.)
        timed(2, 19, 0, 20, 30, "bookclub", sky),
        // −2 — two.
        timed(-2, 9, 30, 10, 0, "standup", sky, loc: "zoom"),
        timed(-2, 15, 0, 15, 30, "coffee", sea, loc: "bluebottle"),
        // −3 — one (recurring).
        timed(-3, 8, 0, 9, 0, "yoga", mint, loc: "studionorth", recurring: true),
        // +4 — one.
        timed(4, 18, 0, 22, 0, "birthday", rose),
        // −4 — one all-day.
        allDay(-4, "deadline", peach),
    ]

    /// Days the highlight window owns — filler skips these.
    private static let highlightRange = -4...4

    private static let fillerKeys = ["yoga", "coffee", "bookclub", "grocery", "review"]
    private static let fillerTints = [mint, sea, sky, butter, lilac]

    private static func buildEvents() -> EventMap {
        var out: EventMap = [:]

        func insert(_ event: CalendarEvent, _ info: (y: Int, m: Int, d: Int)) {
            out[MonthKey(year: info.y, month: info.m), default: [:]][info.d, default: []].append(event)
        }

        func make(_ spec: EventSpec, id: String) {
            let info = dayInfo(offsetDays: spec.offset)
            let title = DemoStrings.eventTitle(spec.titleKey, resolvedLanguage)
            let location = spec.locationKey.map { DemoStrings.location($0) }
            if let start = spec.start, let end = spec.end {
                insert(CalendarEvent(
                    id: id, day: info.d,
                    startDate: date(info.y, info.m, info.d, h: start.h, min: start.m),
                    endDate: date(info.y, info.m, info.d, h: end.h, min: end.m),
                    title: title, tint: spec.tint, location: location,
                    allDay: false, isRecurring: spec.recurring
                ), info)
            } else {
                insert(CalendarEvent(
                    id: id, day: info.d, title: title, tint: spec.tint, allDay: true
                ), info)
            }
        }

        for (i, spec) in highlightEvents.enumerated() {
            make(spec, id: "demo-ev-\(spec.offset)-\(i)")
        }

        // Ambient filler so the Month grid and far Week scrolling aren't empty.
        for offset in -75...75 where !highlightRange.contains(offset) && offset % 2 == 0 {
            let idx = abs(offset / 2)
            make(
                timed(offset, 17, 30, 18, 30, fillerKeys[idx % fillerKeys.count],
                      fillerTints[idx % fillerTints.count]),
                id: "demo-fill-\(offset)"
            )
        }

        // Sort each day: all-day first, then by start time.
        for key in Array(out.keys) {
            guard var days = out[key] else { continue }
            for d in Array(days.keys) {
                days[d]?.sort { lhs, rhs in
                    if lhs.allDay != rhs.allDay { return lhs.allDay && !rhs.allDay }
                    return (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
                }
            }
            out[key] = days
        }
        return out
    }

    // MARK: - Reminder schedule

    private struct ReminderSlot {
        let id: String
        let offset: Int
        let hour: Int?
        let minute: Int
        let tint: Color
        let isCompleted: Bool
        let isOverdue: Bool
        let isRecurring: Bool
        let dueOffset: Int?
        let titleKey: String

        init(_ id: String, offset: Int, hour: Int? = nil, minute: Int = 0,
             tint: Color, completed: Bool = false, overdue: Bool = false,
             recurring: Bool = false, dueOffset: Int? = nil, _ titleKey: String) {
            self.id = id; self.offset = offset; self.hour = hour; self.minute = minute
            self.tint = tint; self.isCompleted = completed; self.isOverdue = overdue
            self.isRecurring = recurring; self.dueOffset = dueOffset; self.titleKey = titleKey
        }
    }

    private static let reminderSlots: [ReminderSlot] = [
        // Today — two reminders: one pleasant incomplete (also what the medium
        // widget's `pleasantOnly` filter surfaces) and one completed.
        ReminderSlot("demo-rem-401", offset: 0, tint: mint, recurring: true, "water_plants"),
        ReminderSlot("demo-rem-404", offset: 0, tint: butter, completed: true, "pick_up_parcel"),
        ReminderSlot("demo-rem-405", offset: -1, hour: 17, minute: 30, tint: lilac, "dry_cleaning"),
        ReminderSlot("demo-rem-406", offset: 2, tint: rose, "birthday_gift"),
        ReminderSlot("demo-rem-407", offset: 4, hour: 9, minute: 0, tint: sea, recurring: true, "library_books"),
    ]

    private static func buildReminders() -> ReminderMap {
        var out: ReminderMap = [:]

        for slot in reminderSlots {
            let surface = dayInfo(offsetDays: slot.offset)
            let dueDayInfo = dayInfo(offsetDays: slot.dueOffset ?? slot.offset)
            let hasTime = slot.hour != nil
            let due = date(dueDayInfo.y, dueDayInfo.m, dueDayInfo.d, h: slot.hour ?? 0, min: slot.minute)
            let reminder = CalendarReminder(
                id: slot.id,
                reminderIdentifier: slot.id,
                day: surface.d,
                dueDate: due,
                hasTime: hasTime,
                title: DemoStrings.reminderTitle(slot.titleKey, resolvedLanguage),
                tint: slot.tint,
                isCompleted: slot.isCompleted,
                isOverdue: slot.isOverdue,
                isRecurring: slot.isRecurring
            )
            out[MonthKey(year: surface.y, month: surface.m), default: [:]][surface.d, default: []].append(reminder)
        }

        // Incomplete first, then by due date — mirrors EventStore's ordering.
        for key in Array(out.keys) {
            guard var days = out[key] else { continue }
            for d in Array(days.keys) {
                days[d]?.sort { lhs, rhs in
                    if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                    return (lhs.dueDate ?? .distantPast) < (rhs.dueDate ?? .distantPast)
                }
            }
            out[key] = days
        }
        return out
    }
}
