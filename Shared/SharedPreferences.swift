import Foundation

enum SharedDefaults {
    static let suiteName = "group.com.weichart.hibi"
    static let hiddenCalendarIDsKey = "hiddenCalendarIDs"
    static let useSimpleFontKey = "useSimpleFont"
    static let timeFormatKey = "timeFormat"
    static let todayWeatherKey = "todayWeather"
    static let locationNameKey = "locationName"

    static var suite: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

struct SharedWeatherData: Codable {
    let high: Double
    let low: Double
    let weatherCode: String
    let sunrise: Date?
    let sunset: Date?
    let year: Int
    let month: Int
    let day: Int
}
