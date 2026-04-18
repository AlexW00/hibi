import SwiftUI

struct MonthView: View {
    let year: Int
    let month: Int
    var onPickDay: (Int) -> Void

    var body: some View {
        let totalDays = SampleData.daysInMonth(year: year, month: month)
        let firstWeekday = SampleData.firstWeekday(year: year, month: month)
        let cells: [Int?] = Array(repeating: nil, count: firstWeekday)
            + (1...totalDays).map { Optional($0) }
        let padded = cells + Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        let weekCount = padded.count / 7

        VStack(alignment: .leading, spacing: 0) {
            header(weekCount: weekCount)
            weekdayHeader
            grid(cells: padded)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
    }

    private func header(weekCount: Int) -> some View {
        VStack(alignment: .leading, spacing: -4) {
            Text(String(year))
                .font(.custom(AppFont.serifItalic, size: 15))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline) {
                Text(MonthNames.full[month - 1])
                    .font(.custom(AppFont.serifRegular, size: 72))
                    .tracking(-1.5)
                    .foregroundStyle(.primary)
                Spacer()
                Text("WK \(weekCount)")
                    .font(.system(size: 11))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 14)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(DayNames.short[i])
                    .font(.system(size: 11))
                    .tracking(1.2)
                    .foregroundStyle((i == 0 || i == 6) ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 0.5)
        }
        .padding(.bottom, 6)
    }

    private func grid(cells: [Int?]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let d = day {
                    DayCell(year: year, month: month, day: d)
                        .onTapGesture { onPickDay(d) }
                } else {
                    Color.clear.frame(minHeight: 60)
                }
            }
        }
    }
}

private struct DayCell: View {
    let year: Int
    let month: Int
    let day: Int

    var body: some View {
        let events = SampleData.events(forDay: day)
        let isToday = SampleData.isToday(year: year, month: month, day: day)

        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.custom(AppFont.serifRegular, size: 22))
                    .tracking(-0.2)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if isToday {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 1.25)
                                .frame(width: 36, height: 36)
                        }
                    }

                HStack(spacing: 2.5) {
                    ForEach(events.prefix(4)) { e in
                        Circle()
                            .fill(e.category.tint)
                            .frame(width: 4, height: 4)
                            .opacity(0.9)
                    }
                    if events.count > 4 {
                        Text("+\(events.count - 4)")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 5)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .contentShape(Rectangle())
    }
}
