import Foundation
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
    /// Absolute start/end — views format against the user's time-format
    /// preference at render time (see `TimeFormat`).
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
         startDate: Date? = nil,
         endDate: Date? = nil,
         title: String,
         tint: Color,
         location: String? = nil,
         allDay: Bool = false) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.day = day
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
    ///
    /// - Parameters:
    ///   - useDemoTimeOfDay: When true and the list is showing **SampleData’s fixed “today”**,
    ///     progress uses the device’s **time-of-day** against this event’s start/end times so demo
    ///     screenshots show a partial fill even when the system calendar isn’t on that date.
    ///   - listYear, listMonth, listDay: The calendar day of the row containing this event
    ///     (stream / day view). Required for the demo branch to activate.
    func progress(
        at now: Date,
        useDemoTimeOfDay: Bool = false,
        listYear: Int? = nil,
        listMonth: Int? = nil,
        listDay: Int? = nil
    ) -> Double {
        guard !allDay, let s = startDate, let e = endDate, e > s else { return 0 }

        if useDemoTimeOfDay,
           let y = listYear, let m = listMonth, let d = listDay,
           SampleData.isDemoAnchor(year: y, month: m, day: d) {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            let startM = cal.component(.hour, from: s) * 60 + cal.component(.minute, from: s)
            let endM = cal.component(.hour, from: e) * 60 + cal.component(.minute, from: e)
            let nowM = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
            guard endM > startM else { return 0 }
            if nowM <= startM { return 0 }
            if nowM >= endM { return 1 }
            return Double(nowM - startM) / Double(endM - startM)
        }

        if now <= s { return 0 }
        if now >= e { return 1 }
        return now.timeIntervalSince(s) / e.timeIntervalSince(s)
    }
}

struct DayWeather: Hashable {
    /// Stored in Celsius with full decimal precision. Views convert + round
    /// at display time so switching the temperature unit doesn't accumulate
    /// rounding error (e.g. 23.4°C → 23 → 73°F instead of the correct 74°F).
    let high: Double
    let low: Double
    let code: WeatherCode
    let sunrise: Date?
    let sunset: Date?
}
