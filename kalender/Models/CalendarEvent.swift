import SwiftUI

enum WeatherCode: String, Hashable {
    case sun, pcloud, cloud, rain, wind, storm

    var sfSymbol: String {
        switch self {
        case .sun:    "sun.max"
        case .pcloud: "cloud.sun"
        case .cloud:  "cloud"
        case .rain:   "cloud.rain"
        case .wind:   "wind"
        case .storm:  "cloud.bolt.rain"
        }
    }
}

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let eventIdentifier: String?
    let day: Int
    let start: String?
    let end: String?
    /// Absolute start/end — kept separate from the HH:mm strings so progress
    /// computation works for events that span into another day.
    let startDate: Date?
    let endDate: Date?
    let title: String
    /// Pastel-transformed tint derived from the source EKCalendar's color.
    /// Dynamic: resolves differently in light vs dark appearance.
    let tint: Color
    let location: String?
    let allDay: Bool

    init(id: String = UUID().uuidString,
         eventIdentifier: String? = nil,
         day: Int,
         start: String? = nil,
         end: String? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         title: String,
         tint: Color,
         location: String? = nil,
         allDay: Bool = false) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.day = day
        self.start = start
        self.end = end
        self.startDate = startDate
        self.endDate = endDate
        self.title = title
        self.tint = tint
        self.location = location
        self.allDay = allDay
    }
}

extension CalendarEvent {
    /// 0 before the event starts, 1 after it ends, linear in between.
    /// All-day events return 0 here — each row decides how to render those.
    func progress(at now: Date) -> Double {
        guard !allDay, let s = startDate, let e = endDate, e > s else { return 0 }
        if now <= s { return 0 }
        if now >= e { return 1 }
        return now.timeIntervalSince(s) / e.timeIntervalSince(s)
    }
}

struct DayWeather: Hashable {
    let high: Int
    let low: Int
    let code: WeatherCode
    let sunrise: Date?
    let sunset: Date?
}
