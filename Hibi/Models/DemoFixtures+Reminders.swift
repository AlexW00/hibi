import Foundation
import SwiftUI

/// Curated reminders for demo mode (screenshots). The *schedule* (which days,
/// times, completed/overdue/recurring flags, tints) is shared across locales;
/// only the titles are translated, so the Day-view schedule shows a natural mix
/// of reminders above the events in every language.
///
/// Concentrated in April 2026 around the demo anchor (April 18 = SampleData
/// "today"), which is the hero Day screenshot.
extension DemoFixtures {
    typealias ReminderMap = [MonthKey: [Int: [CalendarReminder]]]

    static let reminders: ReminderMap = makeReminders()

    /// One reminder in the curated schedule. `titleKey` indexes the per-language
    /// title table; `dueDay` is the day it surfaces on (for overdue items this
    /// is "today", later than the actual `dueMonth`/`dueDayActual`).
    private struct ReminderSlot {
        let id: String
        let dueDay: Int
        /// Hour of day, or nil for an all-day (timeless) reminder.
        let hour: Int?
        let minute: Int
        let tint: Color
        let isCompleted: Bool
        let isOverdue: Bool
        let isRecurring: Bool
        let titleKey: String
        /// Actual due date used for the timestamp (defaults to `dueDay` in April).
        let dueDayActual: Int

        init(_ id: String, day dueDay: Int, hour: Int? = nil, minute: Int = 0,
             tint: Color, completed: Bool = false, overdue: Bool = false,
             recurring: Bool = false, dueDayActual: Int? = nil, _ titleKey: String) {
            self.id = id
            self.dueDay = dueDay
            self.hour = hour
            self.minute = minute
            self.tint = tint
            self.isCompleted = completed
            self.isOverdue = overdue
            self.isRecurring = recurring
            self.titleKey = titleKey
            self.dueDayActual = dueDayActual ?? dueDay
        }
    }

    // All in April 2026.
    private static let reminderSlots: [ReminderSlot] = [
        // Anchor day (April 18) — a varied stack above the day's events.
        ReminderSlot("demo-rem-401", day: 18, tint: mint, recurring: true, "water_plants"),
        ReminderSlot("demo-rem-402", day: 18, hour: 11, minute: 0, tint: sky, "call_dentist"),
        ReminderSlot("demo-rem-403", day: 18, tint: coral, overdue: true, dueDayActual: 15, "tax_documents"),
        ReminderSlot("demo-rem-404", day: 18, tint: butter, completed: true, "pick_up_parcel"),
        // Surrounding days — populate the Week view.
        ReminderSlot("demo-rem-405", day: 15, hour: 17, minute: 30, tint: lilac, "dry_cleaning"),
        ReminderSlot("demo-rem-406", day: 20, tint: rose, "birthday_gift"),
        ReminderSlot("demo-rem-407", day: 22, hour: 9, minute: 0, tint: sea, recurring: true, "library_books"),
    ]

    private static func makeReminders() -> ReminderMap {
        let titles = reminderTitles(for: resolvedLanguage)
        let key = MonthKey(year: 2026, month: 4)
        var byDay: [Int: [CalendarReminder]] = [:]

        for slot in reminderSlots {
            let hasTime = slot.hour != nil
            let due = date(2026, 4, slot.dueDayActual, h: slot.hour ?? 0, min: slot.minute)
            let reminder = CalendarReminder(
                id: slot.id,
                reminderIdentifier: slot.id,
                day: slot.dueDay,
                dueDate: due,
                hasTime: hasTime,
                title: titles[slot.titleKey] ?? slot.titleKey,
                tint: slot.tint,
                isCompleted: slot.isCompleted,
                isOverdue: slot.isOverdue,
                isRecurring: slot.isRecurring
            )
            byDay[slot.dueDay, default: []].append(reminder)
        }

        // Incomplete first, then by due date — mirrors EventStore's ordering.
        for d in byDay.keys {
            byDay[d]?.sort { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return (lhs.dueDate ?? .distantPast) < (rhs.dueDate ?? .distantPast)
            }
        }

        return [key: byDay]
    }

    /// Naturally-written titles per language (not literal calques — see the
    /// "translate naturally" rule in AGENTS.md).
    private static func reminderTitles(for language: Language) -> [String: String] {
        switch language {
        case .english:
            return [
                "water_plants": "Water the plants",
                "call_dentist": "Call the dentist",
                "tax_documents": "Send tax documents",
                "pick_up_parcel": "Pick up parcel",
                "dry_cleaning": "Collect dry cleaning",
                "birthday_gift": "Buy birthday gift",
                "library_books": "Renew library books",
            ]
        case .german:
            return [
                "water_plants": "Pflanzen gießen",
                "call_dentist": "Beim Zahnarzt anrufen",
                "tax_documents": "Steuerunterlagen abschicken",
                "pick_up_parcel": "Paket abholen",
                "dry_cleaning": "Wäsche aus der Reinigung holen",
                "birthday_gift": "Geburtstagsgeschenk kaufen",
                "library_books": "Bücher verlängern",
            ]
        case .japanese:
            return [
                "water_plants": "植物に水やり",
                "call_dentist": "歯医者に電話",
                "tax_documents": "確定申告の書類を送る",
                "pick_up_parcel": "荷物を受け取る",
                "dry_cleaning": "クリーニングを取りに行く",
                "birthday_gift": "誕生日プレゼントを買う",
                "library_books": "図書館の本を延長",
            ]
        case .korean:
            return [
                "water_plants": "화분에 물 주기",
                "call_dentist": "치과 예약 전화하기",
                "tax_documents": "세금 서류 보내기",
                "pick_up_parcel": "택배 찾기",
                "dry_cleaning": "세탁물 찾아오기",
                "birthday_gift": "생일 선물 사기",
                "library_books": "도서관 책 연장하기",
            ]
        case .chineseSimplified:
            return [
                "water_plants": "给植物浇水",
                "call_dentist": "打电话给牙医",
                "tax_documents": "寄送报税材料",
                "pick_up_parcel": "取快递",
                "dry_cleaning": "取干洗的衣服",
                "birthday_gift": "买生日礼物",
                "library_books": "续借图书馆的书",
            ]
        case .chineseTraditional:
            return [
                "water_plants": "幫植物澆水",
                "call_dentist": "打電話給牙醫",
                "tax_documents": "寄送報稅文件",
                "pick_up_parcel": "領取包裹",
                "dry_cleaning": "拿乾洗的衣服",
                "birthday_gift": "買生日禮物",
                "library_books": "續借圖書館的書",
            ]
        }
    }
}
