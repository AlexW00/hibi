import SwiftUI

struct MonthView: View {
    let year: Int
    let month: Int
    var onPickDay: (Int) -> Void

    @Environment(EventStore.self) private var eventStore
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false

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
        .task(id: MonthKey(year: year, month: month)) {
            eventStore.ensureLoaded(year: year, month: month)
        }
    }

    private func header(weekCount: Int) -> some View {
        VStack(alignment: .leading, spacing: -4) {
            Text(String(year))
                .font(.appSerif(size: 15, italic: true, simple: useSimpleFont))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline) {
                Text(MonthNames.full[month - 1])
                    .font(.appSerif(size: 72, simple: useSimpleFont))
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
        let cal = Calendar.autoupdatingCurrent
        let start = cal.firstWeekday - 1  // 0=Sun..6=Sat
        let symbols = DayNames.short      // Sunday-indexed
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { col in
                let weekdayIndex = (start + col) % 7
                let isWeekend = (weekdayIndex == 0 || weekdayIndex == 6)
                Text(symbols[weekdayIndex])
                    .font(.system(size: 11))
                    .tracking(1.2)
                    .foregroundStyle(isWeekend ? .tertiary : .secondary)
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

    @Environment(EventStore.self) private var eventStore
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false

    var body: some View {
        let events = eventStore.events(year: year, month: month, day: day)
        let isToday = SampleData.isToday(year: year, month: month, day: day)

        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                Text(verbatim: "\(day)")
                    .font(.appSerif(size: 22, simple: useSimpleFont))
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
                            .fill(e.tint)
                            .frame(width: 4, height: 4)
                            .opacity(0.9)
                    }
                    if events.count > 4 {
                        Text(verbatim: "+\(events.count - 4)")
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

struct MonthsScrollView: View {
    @Binding var displayedYear: Int
    @Binding var displayedMonth: Int
    let scrollToNowToken: Int
    var onPickDay: (Int, Int, Int) -> Void

    @State private var window: CalendarWindow
    @State private var position: ScrollPosition

    init(
        displayedYear: Binding<Int>,
        displayedMonth: Binding<Int>,
        scrollToNowToken: Int,
        onPickDay: @escaping (Int, Int, Int) -> Void
    ) {
        self._displayedYear = displayedYear
        self._displayedMonth = displayedMonth
        self.scrollToNowToken = scrollToNowToken
        self.onPickDay = onPickDay
        let seed = MonthKey(
            year: displayedYear.wrappedValue,
            month: displayedMonth.wrappedValue
        )
        _window = State(initialValue: CalendarWindow(center: seed))
        var initial = ScrollPosition(idType: Int.self)
        initial.scrollTo(id: seed.id, anchor: .center)
        _position = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                EndOfListIndicator()
                LazyVStack(alignment: .leading, spacing: 32) {
                    ForEach(window.months) { key in
                        MonthView(
                            year: key.year,
                            month: key.month,
                            onPickDay: { day in
                                onPickDay(key.year, key.month, day)
                            }
                        )
                    }
                }
                .scrollTargetLayout()
                EndOfListIndicator()
            }
            .padding(.bottom, 120)
        }
        .scrollPosition($position, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.selection, trigger: position.viewID(type: Int.self))
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .idle {
                let id = position.viewID(type: Int.self) ?? window.visibleMonthID
                window.extendIfNearEdge(visibleID: id)
            }
        }
        .onChange(of: position.viewID(type: Int.self)) { _, newID in
            guard let newID else { return }
            window.visibleMonthID = newID
            let y = newID / 100
            let m = newID % 100
            if y != displayedYear { displayedYear = y }
            if m != displayedMonth { displayedMonth = m }
        }
        .onChange(of: scrollToNowToken) { _, _ in
            let today = MonthKey(year: SampleData.todayYear, month: SampleData.todayMonth)
            window.recenter(on: today)
            withAnimation(.snappy(duration: 0.35)) {
                position.scrollTo(id: today.id)
            }
        }
    }
}

struct EndOfListIndicator: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(.tertiary)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity(index: i, t: t))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func dotOpacity(index: Int, t: Double) -> Double {
        let cycle = 1.4
        let offset = Double(index) * (cycle / 3.0)
        let phase = ((t + offset).truncatingRemainder(dividingBy: cycle)) / cycle
        return 0.25 + 0.75 * (0.5 + 0.5 * sin(phase * 2 * .pi))
    }
}

struct MonthKey: Hashable, Identifiable {
    let year: Int
    let month: Int
    var id: Int { year * 100 + month }

    static func offset(_ delta: Int, from base: MonthKey) -> MonthKey {
        let total = (base.year * 12 + (base.month - 1)) + delta
        return MonthKey(year: total / 12, month: (total % 12) + 1)
    }
}

@MainActor
@Observable
final class CalendarWindow {
    private(set) var months: [MonthKey]
    var visibleMonthID: MonthKey.ID?

    private var isExtending = false
    private let windowRadius: Int
    private let extendBatch: Int
    private let maxWindow: Int

    init(
        center: MonthKey,
        windowRadius: Int = 24,
        extendBatch: Int = 24,
        maxWindow: Int = 96
    ) {
        self.windowRadius = windowRadius
        self.extendBatch = extendBatch
        self.maxWindow = maxWindow
        self.months = (-windowRadius...windowRadius).map {
            MonthKey.offset($0, from: center)
        }
        self.visibleMonthID = center.id
    }

    func extendIfNearEdge(visibleID: MonthKey.ID?) {
        guard !isExtending,
              let id = visibleID,
              let idx = months.firstIndex(where: { $0.id == id }) else { return }

        let neededAbove = windowRadius - idx
        let neededBelow = windowRadius - (months.count - 1 - idx)
        let cap = extendBatch

        if neededAbove > 0, let first = months.first {
            isExtending = true
            let count = min(neededAbove, cap)
            let prepended = (1...count).reversed().map {
                MonthKey.offset(-$0, from: first)
            }
            months.insert(contentsOf: prepended, at: 0)
            trimTrailingIfOverflow()
            isExtending = false
        } else if neededBelow > 0, let last = months.last {
            isExtending = true
            let count = min(neededBelow, cap)
            let appended = (1...count).map {
                MonthKey.offset($0, from: last)
            }
            months.append(contentsOf: appended)
            trimLeadingIfOverflow()
            isExtending = false
        }
    }

    func recenter(on key: MonthKey) {
        if months.contains(where: { $0.id == key.id }) { return }
        months = (-windowRadius...windowRadius).map {
            MonthKey.offset($0, from: key)
        }
        visibleMonthID = key.id
    }

    private func trimLeadingIfOverflow() {
        let excess = months.count - maxWindow
        guard excess > 0 else { return }
        let pinnedIdx = months.firstIndex { $0.id == visibleMonthID } ?? (months.count / 2)
        let safeTrim = min(excess, max(0, pinnedIdx - windowRadius))
        if safeTrim > 0 {
            months.removeFirst(safeTrim)
        }
    }

    private func trimTrailingIfOverflow() {
        let excess = months.count - maxWindow
        guard excess > 0 else { return }
        let pinnedIdx = months.firstIndex { $0.id == visibleMonthID } ?? (months.count / 2)
        let distanceToTail = months.count - 1 - pinnedIdx
        let safeTrim = min(excess, max(0, distanceToTail - windowRadius))
        if safeTrim > 0 {
            months.removeLast(safeTrim)
        }
    }
}
