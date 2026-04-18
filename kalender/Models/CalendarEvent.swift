import SwiftUI

enum EventCategory: String, CaseIterable, Identifiable, Hashable {
    case work, life, focus, health, social

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work: "Work"
        case .life: "Life"
        case .focus: "Focus"
        case .health: "Health"
        case .social: "Social"
        }
    }

    var tint: Color {
        switch self {
        case .work:   Color(.displayP3, red: 0.235, green: 0.557, blue: 0.831)
        case .life:   Color(.displayP3, red: 0.914, green: 0.565, blue: 0.424)
        case .focus:  Color(.displayP3, red: 0.553, green: 0.486, blue: 0.804)
        case .health: Color(.displayP3, red: 0.310, green: 0.686, blue: 0.522)
        case .social: Color(.displayP3, red: 0.788, green: 0.612, blue: 0.341)
        }
    }
}

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
    let id = UUID()
    let day: Int
    let start: String?
    let end: String?
    let title: String
    let category: EventCategory
    let location: String?
    let allDay: Bool

    init(day: Int,
         start: String? = nil,
         end: String? = nil,
         title: String,
         category: EventCategory,
         location: String? = nil,
         allDay: Bool = false) {
        self.day = day
        self.start = start
        self.end = end
        self.title = title
        self.category = category
        self.location = location
        self.allDay = allDay
    }
}

struct DayWeather: Hashable {
    let high: Int
    let low: Int
    let code: WeatherCode
}
