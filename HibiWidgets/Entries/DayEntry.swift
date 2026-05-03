import WidgetKit

struct DayEntry: TimelineEntry {
    let date: Date
    let day: Int
    let month: Int
    let year: Int
    let dayName: String
    let monthName: String
    let isToday: Bool
    let useSimpleFont: Bool
    let weatherHigh: Double?
    let weatherLow: Double?
    let weatherCode: String?
    let sunrise: Date?
    let sunset: Date?
    let locationName: String?
    let timeFormatRaw: String
}
