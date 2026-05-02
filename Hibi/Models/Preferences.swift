import Foundation

/// Settings-screen preference for temperature display unit.
///
/// Default is `.system`, which resolves to Fahrenheit in US-units regions
/// (`Locale.measurementSystem == .us`) and Celsius everywhere else —
/// matching the rest of the system's behavior.
enum TemperatureUnit: String, CaseIterable, Identifiable {
    case system, celsius, fahrenheit

    static let defaultsKey = "temperatureUnit"

    var id: String { rawValue }

    var labelResource: LocalizedStringResource {
        switch self {
        case .system:     "System"
        case .celsius:    "Celsius"
        case .fahrenheit: "Fahrenheit"
        }
    }

    /// The concrete unit to render in, resolving `.system` through the current locale.
    var resolved: UnitTemperature {
        switch self {
        case .system:
            return Locale.autoupdatingCurrent.measurementSystem == .us ? .fahrenheit : .celsius
        case .celsius:    return .celsius
        case .fahrenheit: return .fahrenheit
        }
    }

    /// Converts a Celsius reading to this unit and rounds to the nearest integer.
    /// `DayWeather` stores Celsius with full precision so rounding only happens at display.
    func display(celsius: Double) -> Int {
        let m = Measurement<UnitTemperature>(value: celsius, unit: .celsius)
        return Int(m.converted(to: resolved).value.rounded())
    }
}

/// Settings-screen preference for clock format.
///
/// Default is `.system`, which follows the user's iOS region settings
/// (short-time style on `Locale.autoupdatingCurrent`).
enum TimeFormat: String, CaseIterable, Identifiable {
    case system, twelveHour, twentyFourHour

    static let defaultsKey = "timeFormat"

    var id: String { rawValue }

    var labelResource: LocalizedStringResource {
        switch self {
        case .system:          "System"
        case .twelveHour:      "12-hour"
        case .twentyFourHour:  "24-hour"
        }
    }

    /// Shared formatters — `DateFormatter` is documented thread-safe on iOS 7+
    /// for 64-bit apps, so the same instance can service every view.
    private static let systemFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let twelveHourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let twentyFourHourFormatter: DateFormatter = {
        let f = DateFormatter()
        // en_GB ensures 24-hour even if the device's region prefers AM/PM.
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()

    var formatter: DateFormatter {
        switch self {
        case .system:         Self.systemFormatter
        case .twelveHour:     Self.twelveHourFormatter
        case .twentyFourHour: Self.twentyFourHourFormatter
        }
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

/// Settings-screen preference for which sun-related times appear on the
/// Day-view paper card. Civil dawn/dusk (sun 6° below the horizon) is the
/// "everyday twilight" most people mean by Morgen-/Abenddämmerung.
enum SunTimeMode: String, CaseIterable, Identifiable {
    case sunriseSunset, dawnDusk, both

    static let defaultsKey = "sunTimeMode"

    var id: String { rawValue }

    var labelResource: LocalizedStringResource {
        switch self {
        case .sunriseSunset: "Sunrise / sunset"
        case .dawnDusk:      "Dawn / dusk"
        case .both:          "Both"
        }
    }
}
