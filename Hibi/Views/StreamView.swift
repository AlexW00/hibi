import EventKit
import SwiftUI
import UniformTypeIdentifiers

/// Transferable payload for long-press drag of an event instance in the week view.
/// Carries the source day so `EventStore.moveEventInstance(...)` can decide whether
/// the user grabbed the first, middle, or last day of a multi-day span.
struct DraggedEvent: Codable, Transferable {
    let eventIdentifier: String
    let sourceYear: Int
    let sourceMonth: Int
    let sourceDay: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

struct StreamView: View {
    @Binding var displayedYear: Int
    @Binding var displayedMonth: Int
    let scrollToNowToken: Int
    let onPickDay: (Int, Int, Int) -> Void
    let onTapEvent: (CalendarEvent) -> Void

    @Environment(EventStore.self) private var eventStore
    @State private var window: StreamWindow
    @State private var position: ScrollPosition

    init(
        displayedYear: Binding<Int>,
        displayedMonth: Binding<Int>,
        scrollToNowToken: Int,
        onPickDay: @escaping (Int, Int, Int) -> Void,
        onTapEvent: @escaping (CalendarEvent) -> Void
    ) {
        self._displayedYear = displayedYear
        self._displayedMonth = displayedMonth
        self.scrollToNowToken = scrollToNowToken
        self.onPickDay = onPickDay
        self.onTapEvent = onTapEvent

        let y = displayedYear.wrappedValue
        let m = displayedMonth.wrappedValue
        let isTodayMonth = y == SampleData.todayYear && m == SampleData.todayMonth
        let seedDay = isTodayMonth ? SampleData.todayDay : 15
        let seed = DayKey(year: y, month: m, day: seedDay)
        _window = State(initialValue: StreamWindow(center: seed))
        var initial = ScrollPosition(idType: Int.self)
        initial.scrollTo(id: seed.id, anchor: .center)
        _position = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            if !eventStore.showsCalendarContent {
                CalendarAccessPrompt(status: eventStore.authorization) {
                    Task { await eventStore.requestAccess() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }

            VStack(spacing: 0) {
                EndOfListIndicator()
                LazyVStack(spacing: 0) {
                    ForEach(window.days) { key in
                        StreamDayRow(
                            year: key.year,
                            month: key.month,
                            day: key.day,
                            onPickDay: { d in onPickDay(key.year, key.month, d) },
                            onTapEvent: onTapEvent
                        )
                    }
                }
                .scrollTargetLayout()
                EndOfListIndicator()
            }
            .padding(.top, 4)
            .padding(.bottom, 160)
        }
        .scrollPosition($position, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.selection, trigger: position.viewID(type: Int.self))
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .idle {
                let id = position.viewID(type: Int.self) ?? window.visibleDayID
                // After inserting rows, the viewport's content offset shifts to
                // keep the centered day centered — but `.viewAligned` may still
                // decide to snap to a neighbour because the new layout lands a
                // few pixels off-grid. Re-pinning to the same id pre-empts that
                // snap, which the user saw as "jumping a few days after slowing
                // down."
                if window.extendIfNearEdge(visibleID: id), let id {
                    position.scrollTo(id: id)
                }
            }
        }
        .task(id: windowMonthsSignature) {
            var seen = Set<MonthKey>()
            for key in window.days {
                let month = MonthKey(year: key.year, month: key.month)
                if seen.insert(month).inserted {
                    eventStore.ensureLoaded(year: month.year, month: month.month)
                }
            }
        }
        .onChange(of: position.viewID(type: Int.self)) { _, newID in
            guard let newID else { return }
            window.visibleDayID = newID
            let y = newID / 10_000
            let m = (newID / 100) % 100
            if y != displayedYear { displayedYear = y }
            if m != displayedMonth { displayedMonth = m }
        }
        .onChange(of: scrollToNowToken) { _, _ in
            let today = DayKey(
                year: SampleData.todayYear,
                month: SampleData.todayMonth,
                day: SampleData.todayDay
            )
            window.recenter(on: today)
            withAnimation(.snappy(duration: 0.35)) {
                position.scrollTo(id: today.id)
            }
        }
    }

    // Signature that changes only when the window's month range changes, so the
    // preload `.task` re-fires on extension but not on every scroll tick.
    private var windowMonthsSignature: Int {
        let first = window.days.first.map { $0.year * 100 + $0.month } ?? 0
        let last = window.days.last.map { $0.year * 100 + $0.month } ?? 0
        return first &* 1_000_000 &+ last
    }
}

struct DayKey: Hashable, Identifiable {
    let year: Int
    let month: Int
    let day: Int
    var id: Int { year * 10_000 + month * 100 + day }

    static func offset(_ delta: Int, from base: DayKey) -> DayKey {
        var comps = DateComponents()
        comps.year = base.year
        comps.month = base.month
        comps.day = base.day
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps),
              let shifted = cal.date(byAdding: .day, value: delta, to: date) else {
            return base
        }
        return DayKey(
            year: cal.component(.year, from: shifted),
            month: cal.component(.month, from: shifted),
            day: cal.component(.day, from: shifted)
        )
    }
}

@MainActor
@Observable
final class StreamWindow {
    private(set) var days: [DayKey]
    var visibleDayID: DayKey.ID?

    private var isExtending = false
    private let windowRadius: Int
    private let extendBatch: Int
    private let maxWindow: Int

    init(
        center: DayKey,
        windowRadius: Int = 60,
        extendBatch: Int = 60,
        maxWindow: Int = 240
    ) {
        self.windowRadius = windowRadius
        self.extendBatch = extendBatch
        self.maxWindow = maxWindow
        self.days = (-windowRadius...windowRadius).map {
            DayKey.offset($0, from: center)
        }
        self.visibleDayID = center.id
    }

    /// Returns `true` when the window was mutated, so the caller can re-anchor
    /// the scroll position before `.viewAligned` decides to snap to a neighbour.
    @discardableResult
    func extendIfNearEdge(visibleID: DayKey.ID?) -> Bool {
        guard !isExtending,
              let id = visibleID,
              let idx = days.firstIndex(where: { $0.id == id }) else { return false }

        let neededAbove = windowRadius - idx
        let neededBelow = windowRadius - (days.count - 1 - idx)
        let cap = extendBatch

        if neededAbove > 0, let first = days.first {
            isExtending = true
            let count = min(neededAbove, cap)
            let prepended = (1...count).reversed().map {
                DayKey.offset(-$0, from: first)
            }
            days.insert(contentsOf: prepended, at: 0)
            trimTrailingIfOverflow()
            isExtending = false
            return true
        } else if neededBelow > 0, let last = days.last {
            isExtending = true
            let count = min(neededBelow, cap)
            let appended = (1...count).map { DayKey.offset($0, from: last) }
            days.append(contentsOf: appended)
            trimLeadingIfOverflow()
            isExtending = false
            return true
        }
        return false
    }

    func recenter(on key: DayKey) {
        if days.contains(where: { $0.id == key.id }) { return }
        days = (-windowRadius...windowRadius).map {
            DayKey.offset($0, from: key)
        }
        visibleDayID = key.id
    }

    private func trimLeadingIfOverflow() {
        let excess = days.count - maxWindow
        guard excess > 0 else { return }
        let pinnedIdx = days.firstIndex { $0.id == visibleDayID } ?? (days.count / 2)
        let safeTrim = min(excess, max(0, pinnedIdx - windowRadius))
        if safeTrim > 0 {
            days.removeFirst(safeTrim)
        }
    }

    private func trimTrailingIfOverflow() {
        let excess = days.count - maxWindow
        guard excess > 0 else { return }
        let pinnedIdx = days.firstIndex { $0.id == visibleDayID } ?? (days.count / 2)
        let distanceToTail = days.count - 1 - pinnedIdx
        let safeTrim = min(excess, max(0, distanceToTail - windowRadius))
        if safeTrim > 0 {
            days.removeLast(safeTrim)
        }
    }
}

private struct StreamDayRow: View {
    let year: Int
    let month: Int
    let day: Int
    let onPickDay: (Int) -> Void
    let onTapEvent: (CalendarEvent) -> Void

    @Environment(EventStore.self) private var eventStore
    @Environment(WeatherStore.self) private var weatherStore
    @State private var isDropTargeted: Bool = false
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false

    var body: some View {
        let events = eventStore.events(year: year, month: month, day: day)
        let wx = weatherStore.weather(year: year, month: month, day: day)
        let weekday = SampleData.weekday(year: year, month: month, day: day)
        let isToday = SampleData.isToday(year: year, month: month, day: day)
        // Row divider appears at the start of each week so the stream reads as
        // week-sized groups. Uses locale's first weekday (German=Mon, Sun else).
        let firstDayOfWeek = Calendar.autoupdatingCurrent.firstWeekday - 1
        let isWeekStartOrMonthStart = (weekday == firstDayOfWeek) || (day == 1)

        HStack(alignment: .top, spacing: 0) {
            Button {
                onPickDay(day)
            } label: {
                dateRail(weekday: weekday, isToday: isToday)
                    .frame(width: 64, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
                    // Tick once a minute so the fill advances with the day.
                    TimelineView(.periodic(from: .now, by: 60)) { ctx in
                        ForEach(events) { event in
                            eventButton(event: event, now: ctx.date)
                        }
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
            if isWeekStartOrMonthStart {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 0.5)
            }
        }
        .background {
            // Subtle highlight while a dragged event hovers this row.
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.06))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
        .contentShape(Rectangle())
        .dropDestination(for: DraggedEvent.self) { items, _ in
            guard let payload = items.first else { return false }
            guard
                payload.sourceYear != year ||
                payload.sourceMonth != month ||
                payload.sourceDay != day
            else { return false }
            return eventStore.moveEventInstance(
                identifier: payload.eventIdentifier,
                from: (payload.sourceYear, payload.sourceMonth, payload.sourceDay),
                to: (year, month, day)
            )
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .task(id: MonthKey(year: year, month: month)) {
            eventStore.ensureLoaded(year: year, month: month)
        }
    }

    @ViewBuilder
    private func eventButton(event: CalendarEvent, now: Date) -> some View {
        let card = EventCard(
            event: event,
            progress: event.progress(
                at: now,
                useDemoTimeOfDay: eventStore.isDemoMode,
                listYear: year,
                listMonth: month,
                listDay: day
            )
        )
        let button = Button {
            onTapEvent(event)
        } label: {
            card
        }
        .buttonStyle(.plain)

        if let id = event.eventIdentifier, !eventStore.isDemoMode {
            button.draggable(DraggedEvent(
                eventIdentifier: id,
                sourceYear: year,
                sourceMonth: month,
                sourceDay: day
            )) {
                // Drag preview — render the card at its own intrinsic size.
                card.frame(maxWidth: 320)
            }
        } else {
            button
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
                    .font(.appSerif(size: 11, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 14)
        .padding(.leading, 20)
    }

    private func streamDayNumberText() -> some View {
        Text(verbatim: "\(day)")
            .font(.appSerif(size: 34, simple: useSimpleFont))
            .tracking(-0.5)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func weatherCell(wx: DayWeather?) -> some View {
        if let wx {
            VStack(spacing: 2) {
                WeatherIcon(code: wx.code, size: 18)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(wx.high)°")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(wx.low)°")
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
