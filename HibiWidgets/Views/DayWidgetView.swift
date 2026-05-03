import SwiftUI
import WidgetKit

struct DayWidgetView: View {
    let entry: DayEntry

    var body: some View {
        WidgetPaperCard(
            day: entry.day,
            month: entry.month,
            year: entry.year,
            dayName: entry.dayName,
            monthName: entry.monthName,
            isToday: entry.isToday,
            useSimpleFont: entry.useSimpleFont,
            weatherHigh: entry.weatherHigh,
            weatherLow: entry.weatherLow,
            weatherCode: entry.weatherCode,
            sunrise: entry.sunrise,
            sunset: entry.sunset,
            locationName: entry.locationName,
            timeFormatRaw: entry.timeFormatRaw
        )
        .widgetURL(URL(string: "hibi://day?year=\(entry.year)&month=\(entry.month)&day=\(entry.day)"))
    }
}
