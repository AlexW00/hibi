import SwiftUI
import UIKit

/// Builds widget entry payloads from demo data for the in-app widget screenshot
/// gallery (`WidgetGalleryView`). Mirrors what `EventStore` / `WeatherStore`
/// write to the App Group, but constructed directly from `DemoFixtures` for
/// today so the gallery doesn't depend on the live stores.
///
/// The `limit` parameters let the gallery curate per widget size — the medium
/// Schedule widget shows fewer items so it doesn't overflow into the peek/fade
/// state, while the large one shows more.
extension DemoFixtures {
    private static var todaysEvents: [CalendarEvent] {
        events[MonthKey(year: SampleData.todayYear, month: SampleData.todayMonth)]?[SampleData.todayDay] ?? []
    }

    private static var todaysReminders: [CalendarReminder] {
        reminders[MonthKey(year: SampleData.todayYear, month: SampleData.todayMonth)]?[SampleData.todayDay] ?? []
    }

    /// Today's demo events as widget-snapshot events, optionally capped.
    static func widgetEvents(limit: Int? = nil) -> [WidgetEventsSnapshot.Event] {
        let mapped = todaysEvents.map { e in
            WidgetEventsSnapshot.Event(
                id: e.id, title: e.title, location: e.location,
                startDate: e.startDate, endDate: e.endDate, allDay: e.allDay,
                tintRGB: rgba(from: e.tint)
            )
        }
        return limit.map { Array(mapped.prefix($0)) } ?? mapped
    }

    /// The **large** Schedule widget's events: today's events plus two extra
    /// curated events that exist *only* here, so the large tile fills its seven
    /// rows in the screenshot gallery instead of leaving a gap below the live
    /// three-event day. These are not inserted into the app's event map, so the
    /// Day and Week views are unaffected.
    static func widgetLargeScheduleEvents() -> [WidgetEventsSnapshot.Event] {
        let today = dayInfo(offsetDays: 0)
        func extra(_ id: String, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int,
                   _ titleKey: String, _ tint: Color, loc: String?) -> WidgetEventsSnapshot.Event {
            WidgetEventsSnapshot.Event(
                id: id, title: DemoStrings.eventTitle(titleKey, resolvedLanguage),
                location: loc.map { DemoStrings.location($0) },
                startDate: date(today.y, today.m, today.d, h: sh, min: sm),
                endDate: date(today.y, today.m, today.d, h: eh, min: em),
                allDay: false, tintRGB: rgba(from: tint)
            )
        }
        let extras = [
            extra("demo-wlg-lunch", 12, 30, 13, 30, "lunch", peach, loc: "lumi"),
            extra("demo-wlg-coffee", 16, 0, 16, 30, "coffee", sea, loc: "bluebottle"),
        ]
        return (widgetEvents() + extras).sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
    }

    /// Today's demo reminders as widget-snapshot reminders, optionally capped.
    /// `pleasantOnly` drops completed / overdue items (nicer for the small
    /// curated medium widget).
    static func widgetReminders(limit: Int? = nil, pleasantOnly: Bool = false) -> [WidgetEventsSnapshot.Reminder] {
        var source = todaysReminders
        if pleasantOnly { source = source.filter { !$0.isCompleted && !$0.isOverdue } }
        let mapped = source.map { r in
            WidgetEventsSnapshot.Reminder(
                id: r.id, reminderIdentifier: r.reminderIdentifier, title: r.title,
                dueDate: r.dueDate, hasTime: r.hasTime, isCompleted: r.isCompleted,
                isOverdue: r.isOverdue, isRecurring: r.isRecurring, tintRGB: rgba(from: r.tint)
            )
        }
        return limit.map { Array(mapped.prefix($0)) } ?? mapped
    }

    /// Today's demo weather as a widget weather snapshot.
    static func widgetWeatherSnapshot(now: Date = Date()) -> WidgetWeatherSnapshot {
        let w = demoWeather(
            year: SampleData.todayYear, month: SampleData.todayMonth, day: SampleData.todayDay
        )
        return WidgetWeatherSnapshot(
            year: SampleData.todayYear, month: SampleData.todayMonth, day: SampleData.todayDay,
            high: w.high, low: w.low, code: w.code,
            sunrise: w.sunrise, sunset: w.sunset,
            locationName: demoCityName,
            capturedAt: now
        )
    }

    private static func rgba(from color: Color) -> WidgetEventsSnapshot.RGBA {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return .init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }
}
