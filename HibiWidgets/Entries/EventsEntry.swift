import WidgetKit

struct EventsEntry: TimelineEntry {
    let date: Date
    let day: Int
    let month: Int
    let year: Int
    let dayName: String
    let monthName: String
    let isToday: Bool
    let events: [WidgetEvent]
    let useSimpleFont: Bool
    let timeFormatRaw: String
    let weatherHigh: Double?
    let weatherLow: Double?
    let weatherCode: String?
    let sunrise: Date?
    let sunset: Date?
    let locationName: String?
}
