import WidgetKit
import Foundation

struct DayTimelineProvider: TimelineProvider {
    typealias Entry = DayEntry

    func placeholder(in context: Context) -> DayEntry {
        DayEntry(
            date: .now,
            day: 3,
            month: 5,
            year: 2026,
            dayName: "Saturday",
            monthName: "May",
            isToday: true,
            useSimpleFont: false,
            weatherHigh: 22,
            weatherLow: 14,
            weatherCode: "sun",
            sunrise: Calendar.current.date(bySettingHour: 5, minute: 42, second: 0, of: .now),
            sunset: Calendar.current.date(bySettingHour: 20, minute: 18, second: 0, of: .now),
            locationName: "Tokyo",
            timeFormatRaw: "system"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(makeCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let entry = makeCurrentEntry()
        let nextMidnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func makeCurrentEntry() -> DayEntry {
        let year = CalendarHelpers.todayYear
        let month = CalendarHelpers.todayMonth
        let day = CalendarHelpers.todayDay
        let weekdayIndex = CalendarHelpers.weekday(year: year, month: month, day: day)
        let suite = SharedDefaults.suite
        let useSimpleFont = suite.bool(forKey: SharedDefaults.useSimpleFontKey)
        let timeFormatRaw = suite.string(forKey: SharedDefaults.timeFormatKey) ?? "system"
        let locationName = suite.string(forKey: SharedDefaults.locationNameKey)

        var weatherHigh: Double?
        var weatherLow: Double?
        var weatherCode: String?
        var sunrise: Date?
        var sunset: Date?

        if let data = suite.data(forKey: SharedDefaults.todayWeatherKey),
           let weather = try? JSONDecoder().decode(SharedWeatherData.self, from: data),
           weather.year == year && weather.month == month && weather.day == day {
            weatherHigh = weather.high
            weatherLow = weather.low
            weatherCode = weather.weatherCode
            sunrise = weather.sunrise
            sunset = weather.sunset
        }

        return DayEntry(
            date: .now,
            day: day,
            month: month,
            year: year,
            dayName: DayNames.full[weekdayIndex],
            monthName: MonthNames.full[month - 1],
            isToday: true,
            useSimpleFont: useSimpleFont,
            weatherHigh: weatherHigh,
            weatherLow: weatherLow,
            weatherCode: weatherCode,
            sunrise: sunrise,
            sunset: sunset,
            locationName: locationName,
            timeFormatRaw: timeFormatRaw
        )
    }
}
