import SwiftUI

struct StreamView: View {
    let year: Int
    let month: Int

    var body: some View {
        let totalDays = SampleData.daysInMonth(year: year, month: month)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(1...totalDays, id: \.self) { day in
                        StreamDayRow(year: year, month: month, day: day)
                            .id(day)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 160)
            }
            .onAppear {
                if SampleData.todayYear == year && SampleData.todayMonth == month {
                    DispatchQueue.main.async {
                        withAnimation(.none) {
                            proxy.scrollTo(SampleData.todayDay, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

private struct StreamDayRow: View {
    let year: Int
    let month: Int
    let day: Int

    var body: some View {
        let events = SampleData.events(forDay: day)
        let wx = SampleData.weather(forDay: day)
        let weekday = SampleData.weekday(year: year, month: month, day: day)
        let isToday = SampleData.isToday(year: year, month: month, day: day)
        let isMondayOrFirst = (weekday == 1) || (day == 1)

        HStack(alignment: .top, spacing: 0) {
            dateRail(weekday: weekday, isToday: isToday)
                .frame(width: 64, alignment: .leading)

            VStack(spacing: 6) {
                if events.isEmpty {
                    Text("nothing planned")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 10)
                } else {
                    ForEach(events) { event in
                        EventCard(event: event)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            weatherCell(wx: wx)
                .frame(width: 42)
        }
        .frame(minHeight: events.isEmpty ? 92 : nil)
        .overlay(alignment: .top) {
            if isMondayOrFirst {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 0.5)
            }
        }
    }

    private func dateRail(weekday: Int, isToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DayNames.upper[weekday])
                .font(.system(size: 10, weight: isToday ? .semibold : .regular))
                .tracking(1.4)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            streamDayNumberText()
                .overlay {
                    if isToday {
                        Circle()
                            .strokeBorder(.primary, lineWidth: 1.25)
                            .frame(width: 44, height: 44)
                    }
                }
                .frame(minHeight: 36, alignment: .leading)
                .padding(.top, 2)
            if day == 1 {
                Text(MonthNames.short[month - 1])
                    .font(.custom(AppFont.serifItalic, size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 14)
        .padding(.leading, 20)
    }

    private func streamDayNumberText() -> some View {
        Text("\(day)")
            .font(.custom(AppFont.serifRegular, size: 34))
            .tracking(-0.5)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func weatherCell(wx: DayWeather?) -> some View {
        if let wx {
            VStack(spacing: 2) {
                WeatherIcon(code: wx.code, size: 18)
                    .foregroundStyle(.secondary)
                Text("\(wx.high)°")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(wx.low)°")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 16)
            .padding(.trailing, 14)
        } else {
            Color.clear
        }
    }
}
