import SwiftUI
import WidgetKit

struct DayEventsWidgetView: View {
    let entry: EventsEntry

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
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
                .frame(width: geo.size.height)

                VStack(alignment: .leading, spacing: 4) {
                    if entry.events.isEmpty {
                        Spacer()
                        Text("An open day.")
                            .font(.appSerif(size: 13, italic: true, simple: entry.useSimpleFont))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                    } else {
                        ForEach(entry.events.prefix(3)) { event in
                            WidgetEventRow(event: event, timeFormatRaw: entry.timeFormatRaw)
                        }
                        if entry.events.count > 3 {
                            Text("+\(entry.events.count - 3) more")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 10)
                .padding(.trailing, 10)
                .padding(.leading, 6)
            }
        }
        .widgetURL(URL(string: "hibi://day?year=\(entry.year)&month=\(entry.month)&day=\(entry.day)"))
    }
}
