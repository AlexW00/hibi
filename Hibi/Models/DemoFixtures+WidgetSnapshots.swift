import SwiftUI
import UIKit

/// Builds the widget entry payloads from demo data for the in-app widget
/// screenshot gallery (`WidgetGalleryView`). Mirrors what `EventStore` /
/// `WeatherStore` write to the App Group, but constructed directly from
/// `DemoFixtures` for today so the gallery doesn't depend on the live stores.
extension DemoFixtures {
    /// Today's demo events as widget-snapshot events.
    static func widgetEvents() -> [WidgetEventsSnapshot.Event] {
        let key = MonthKey(year: SampleData.todayYear, month: SampleData.todayMonth)
        let todays = events[key]?[SampleData.todayDay] ?? []
        return todays.map { e in
            WidgetEventsSnapshot.Event(
                id: e.id,
                title: e.title,
                location: e.location,
                startDate: e.startDate,
                endDate: e.endDate,
                allDay: e.allDay,
                tintRGB: rgba(from: e.tint)
            )
        }
    }

    /// Today's demo reminders as widget-snapshot reminders.
    static func widgetReminders() -> [WidgetEventsSnapshot.Reminder] {
        let key = MonthKey(year: SampleData.todayYear, month: SampleData.todayMonth)
        let todays = reminders[key]?[SampleData.todayDay] ?? []
        return todays.map { r in
            WidgetEventsSnapshot.Reminder(
                id: r.id,
                reminderIdentifier: r.reminderIdentifier,
                title: r.title,
                dueDate: r.dueDate,
                hasTime: r.hasTime,
                isCompleted: r.isCompleted,
                isOverdue: r.isOverdue,
                isRecurring: r.isRecurring,
                tintRGB: rgba(from: r.tint)
            )
        }
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
