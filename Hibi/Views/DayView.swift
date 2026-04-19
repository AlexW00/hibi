import EventKit
import SwiftUI

struct DayView: View {
    let year: Int
    let month: Int
    @Binding var day: Int
    let scrollToNowToken: Int
    let onTapEvent: (CalendarEvent) -> Void

    @Environment(EventStore.self) private var eventStore
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false
    @State private var dragY: CGFloat = 0
    @State private var isTearing: Bool = false
    @State private var cardShiftAmount: CGFloat = 0
    @State private var tearDirection: Int = 1  // +1 = next (drag up), -1 = prev (drag down)
    @State private var scheduleOpacity: Double = 1  // driven directly during tear (old fades out → new fades in)
    @State private var scheduleShowsIncomingDay: Bool = false  // flips mid-tear when old events are fully hidden
    @State private var tearCommitCount: Int = 0

    // MARK: - Layout constants

    private let peekAmount: CGFloat = 10      // pts each card behind peeks below the one in front
    private let narrowStep: CGFloat = 14      // pts narrower per side per depth level
    private let tearThreshold: CGFloat = 80
    private let offScreen: CGFloat = 700

    // Progressive paper tints — white → off-white → beige (depth cue).
    private let card1Fill = PaperTints.card1
    private let card2Fill = PaperTints.card2
    private let card3Fill = PaperTints.card3

    var body: some View {
        VStack(spacing: 0) {
            masthead
            tearStack
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .sensoryFeedback(.impact(weight: .medium), trigger: tearCommitCount)
            pullToTearHint
            scheduleHeader
                .padding(.horizontal, 20)
            ScrollView {
                scheduleEvents
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .mask(scrollFadeMask)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sensoryFeedback(.selection, trigger: scrollToNowToken)
    }

    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0), .black],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            Rectangle().fill(.black)
        }
    }

    /// Day used by the schedule section. Stays on the current day during the
    /// fade-out phase, flips to the incoming day once old events are hidden.
    private var scheduleDay: Int {
        scheduleShowsIncomingDay ? dayInfo(offsetBy: tearDirection).day : day
    }

    /// Opacity applied to the event rows only — the "SCHEDULE" header stays opaque.
    /// During drag: fades toward a minimum (events stay legible, matching the
    /// paper's own partial fade). During tear: `scheduleOpacity` is driven
    /// through a two-phase animation (current → 0 → 1 for the incoming day).
    private var eventsOpacity: Double {
        if isTearing { return scheduleOpacity }
        let minOpacity = 0.35
        let progress = min(Double(abs(dragY)) / tearThreshold, 1)
        return 1 - progress * (1 - minOpacity)
    }

    /// "Pull to tear" hint — fades out as the paper is pulled, back in after tear settles.
    private var tearHintOpacity: Double {
        if isTearing { return 0 }
        return 1 - min(Double(abs(dragY)) / tearThreshold, 1)
    }

    private var pullToTearHint: some View {
        Text("PULL TO TEAR · ↑ NEXT · ↓ PREV")
            .font(.system(size: 10))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .opacity(tearHintOpacity)
            .animation(.easeOut(duration: 0.32), value: isTearing)
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack {
            Text("Hibi · No. \(String(format: "%03d", day))")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(day)))
            Spacer()
            Text("est. MMXXVI")
                .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 14)
    }

    // MARK: - Tear stack (3-card paper stack)

    private var tearStack: some View {
        GeometryReader { geo in
            let maxH: CGFloat = min(geo.size.height, 380)
            let width = geo.size.width

            ZStack(alignment: .top) {
                // New deepest card — fades in behind during tear so the stack
                // still has 3 at rest after reset. Stays at Card 3's rest slot.
                paperCard(
                    dayInfo: dayInfo(offsetBy: tearDirection * 3),
                    baseFill: card3Fill,
                    overlayFill: card3Fill,
                    overlayOpacity: 0,
                    horizontalInset: narrowStep * 2,
                    bottomPeek: 0,
                    shadowAmount: 0,
                    chromeAmount: 0
                )
                .opacity(cardShiftAmount)

                // Card 3 (back): rest inset = 2·narrowStep, peek = 0 (tallest).
                // During tear: inset → narrowStep, peek → peekAmount (shifts into Card 2 slot).
                paperCard(
                    dayInfo: dayInfo(offsetBy: tearDirection * 2),
                    baseFill: card3Fill,
                    overlayFill: card2Fill,
                    overlayOpacity: cardShiftAmount,
                    horizontalInset: narrowStep * (2 - cardShiftAmount),
                    bottomPeek: peekAmount * cardShiftAmount,
                    shadowAmount: 0,
                    chromeAmount: 0
                )

                // Card 2 (middle): rest inset = narrowStep, peek = peekAmount.
                // During tear: inset → 0, peek → 2·peekAmount (shifts into Card 1 slot).
                // Shadow + chrome fade in smoothly with the shift so there's no
                // boolean pop mid-animation and the hand-off to Card 1 at reset
                // has matching intensity.
                paperCard(
                    dayInfo: dayInfo(offsetBy: tearDirection),
                    baseFill: card2Fill,
                    overlayFill: card1Fill,
                    overlayOpacity: cardShiftAmount,
                    horizontalInset: narrowStep * (1 - cardShiftAmount),
                    bottomPeek: peekAmount * (1 + cardShiftAmount),
                    shadowAmount: Double(cardShiftAmount),
                    chromeAmount: Double(cardShiftAmount)
                )

                // Card 1 (front): widest, shortest (reveals cards behind peeking below).
                paperCard(
                    dayInfo: (day: day, month: month, year: year),
                    baseFill: card1Fill,
                    overlayFill: card1Fill,
                    overlayOpacity: 0,
                    horizontalInset: 0,
                    bottomPeek: peekAmount * 2,
                    shadowAmount: 1,
                    chromeAmount: 1
                )
                .offset(y: dragY)
                .rotationEffect(.degrees(Double(dragY * 0.02)), anchor: dragY > 0 ? .top : .bottom)
                .opacity(1 - min(Double(abs(dragY)) / 400, 0.6))
                .gesture(
                    DragGesture()
                        .onChanged { g in
                            guard !isTearing else { return }
                            dragY = g.translation.height
                            if abs(g.translation.height) > 2 {
                                // Drag up → next (+1); drag down → prev (-1).
                                tearDirection = g.translation.height < 0 ? 1 : -1
                            }
                        }
                        .onEnded { _ in handleRelease() }
                )

            }
            .frame(width: width, height: maxH)
        }
        .frame(height: 380)
    }

    // MARK: - Paper card builder

    private func paperCard(
        dayInfo: (day: Int, month: Int, year: Int),
        baseFill: Color,
        overlayFill: Color,
        overlayOpacity: CGFloat,
        horizontalInset: CGFloat,
        bottomPeek: CGFloat,
        shadowAmount: Double,   // 0 = no shadow, 1 = full
        chromeAmount: Double    // 0 = no holes/perforation, 1 = full
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        let weather = weatherStore.weather(year: dayInfo.year, month: dayInfo.month, day: dayInfo.day)
        let isToday = SampleData.isToday(year: dayInfo.year, month: dayInfo.month, day: dayInfo.day)

        // Hairline border for cards behind the front — defines the card
        // silhouette against the background (critical in dark mode where
        // the back card is pitch black) and reads as subtle paper edge in
        // light mode. Fades out as a card shifts forward and takes over
        // the front role, which has no border.
        let edgeHighlightAmount = 1 - chromeAmount
        let borderColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)

        let card = shape
            .fill(baseFill)
            .overlay { shape.fill(overlayFill).opacity(overlayOpacity) }
            .overlay {
                shape
                    .strokeBorder(borderColor, lineWidth: 1)
                    .opacity(edgeHighlightAmount)
            }
            .overlay(alignment: .top) {
                if chromeAmount > 0 { BindingHoles().opacity(chromeAmount) }
            }
            .overlay {
                PageContent(
                    day: dayInfo.day,
                    month: dayInfo.month,
                    year: dayInfo.year,
                    isToday: isToday,
                    weather: weather,
                    locationName: weatherStore.locationName,
                    preview: chromeAmount < 1
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                if chromeAmount > 0 { PerforationEdge().opacity(chromeAmount) }
            }
            .clipShape(shape)

        return card
            .shadow(
                color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18 * shadowAmount),
                radius: 22, x: 0, y: 18
            )
            .shadow(
                color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.08 * shadowAmount),
                radius: 4, x: 0, y: 2
            )
            .padding(.horizontal, horizontalInset)
            .padding(.bottom, bottomPeek)
    }

    // MARK: - Schedule

    private var scheduleHeader: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.quaternary).frame(height: 0.5)
            Text("SCHEDULE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(.secondary)
            Rectangle().fill(.quaternary).frame(height: 0.5)
        }
        .padding(.bottom, 10)
        .padding(.top, 4)
    }

    private var scheduleEvents: some View {
        let events = eventStore.events(year: year, month: month, day: scheduleDay)
        return Group {
            if !eventStore.showsCalendarContent {
                CalendarAccessPrompt(status: eventStore.authorization) {
                    Task { await eventStore.requestAccess() }
                }
            } else if events.isEmpty {
                Text("An open day.")
                    .font(.appSerif(size: 20, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                // Tick once a minute so the progress fill advances with the day.
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    VStack(spacing: 6) {
                        ForEach(events) { e in
                            Button {
                                onTapEvent(e)
                            } label: {
                                DayEventRow(
                                    event: e,
                                    progress: e.progress(
                                        at: ctx.date,
                                        useDemoTimeOfDay: eventStore.isDemoMode,
                                        listYear: year,
                                        listMonth: month,
                                        listDay: scheduleDay
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .opacity(eventsOpacity)
    }


    // MARK: - Day math

    private func dayInfo(offsetBy delta: Int) -> (day: Int, month: Int, year: Int) {
        var d = day
        var m = month
        var y = year
        var steps = delta
        while steps > 0 {
            let total = SampleData.daysInMonth(year: y, month: m)
            if d == total {
                d = 1
                if m == 12 { m = 1; y += 1 } else { m += 1 }
            } else {
                d += 1
            }
            steps -= 1
        }
        while steps < 0 {
            if d == 1 {
                if m == 1 { m = 12; y -= 1 } else { m -= 1 }
                d = SampleData.daysInMonth(year: y, month: m)
            } else {
                d -= 1
            }
            steps += 1
        }
        return (d, m, y)
    }

    // MARK: - Tear logic

    private func handleRelease() {
        if dragY < -tearThreshold {
            // Pull up → next day
            tear(to: -offScreen, next: true)
        } else if dragY > tearThreshold {
            // Pull down → previous day
            tear(to: offScreen, next: false)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                dragY = 0
            }
        }
    }

    private func tear(to destination: CGFloat, next: Bool) {
        tearCommitCount &+= 1
        tearDirection = next ? 1 : -1

        // Seed scheduleOpacity with the drag's current value so the fade-out
        // starts smoothly from the release point (~0.35) rather than snapping.
        let startingOpacity = eventsOpacity
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            scheduleOpacity = startingOpacity
            scheduleShowsIncomingDay = false
            isTearing = true
        }

        // Front page slides off.
        withAnimation(.easeIn(duration: 0.28)) {
            dragY = destination
        }
        // Back cards shift forward one depth simultaneously — same duration
        // as dragY so all paper motion lands together.
        withAnimation(.easeOut(duration: 0.28)) {
            cardShiftAmount = 1.0
        }

        // Two-phase schedule animation:
        // Phase 1 — fade old events fully out (current opacity → 0).
        // Phase 2 — swap to incoming day, fade 0 → 1.
        let fadeOut: TimeInterval = 0.14
        let fadeIn: TimeInterval = 0.14
        withAnimation(.easeIn(duration: fadeOut)) {
            scheduleOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                scheduleShowsIncomingDay = true
            }
            withAnimation(.easeOut(duration: fadeIn)) {
                scheduleOpacity = 1
            }
        }

        // After the tear, swap `day` and reset state without animation.
        // Because the static cards at cardShiftAmount=0 render the same content
        // as the shifted overlays at cardShiftAmount=1 once `day` advances,
        // the reset is pixel-identical — no pop.
        // 40ms settle buffer past the 0.28s animation guarantees the
        // interpolation engine is at rest before we flip state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                advance(next: next)
                dragY = 0
                cardShiftAmount = 0
                scheduleShowsIncomingDay = false
                scheduleOpacity = 1
            }
            // Flip isTearing outside the disabled-animation transaction so the
            // pull-to-tear hint fades in with the new day instead of popping.
            withAnimation(.easeOut(duration: 0.32)) {
                isTearing = false
            }
        }
    }

    private func advance(next: Bool) {
        let total = SampleData.daysInMonth(year: year, month: month)
        if next {
            day = (day == total) ? 1 : day + 1
        } else {
            day = (day == 1) ? total : day - 1
        }
    }
}

// MARK: - Page Content

private struct PageContent: View {
    let day: Int
    let month: Int
    let year: Int
    let isToday: Bool
    let weather: DayWeather?
    let locationName: String?
    let preview: Bool

    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false

    private static let sunFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Spacer(minLength: 0)
            numeralBlock
            Spacer(minLength: 0)
            bottomRow
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 20)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "sunrise")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(weather?.sunrise.map { Self.sunFormatter.string(from: $0) } ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(weather?.sunrise == nil ? 0 : 1)
            Spacer()
            Text(DayNames.full[SampleData.weekday(year: year, month: month, day: day)])
                .font(.appSerif(size: 19, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
                .padding(.top, 2)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "sunset")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(weather?.sunset.map { Self.sunFormatter.string(from: $0) } ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(weather?.sunset == nil ? 0 : 1)
        }
        .frame(height: 44)
    }

    private var numeralBlock: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.appSerif(size: 180, simple: useSimpleFont))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(day)))
                .frame(maxWidth: .infinity, alignment: .center)
                .overlay(alignment: .bottom) {
                    if isToday {
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 80, height: 1.5)
                            .offset(y: -8)
                    }
                }
            Text("\(MonthNames.full[month - 1].uppercased()) · \(String(year))")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomRow: some View {
        // Always render the row at a fixed height — fade the weather pill to
        // opacity 0 on days without weather so the paper's vertical rhythm
        // doesn't change between days.
        HStack(alignment: .bottom) {
            HStack(spacing: 8) {
                WeatherIcon(code: weather?.code ?? .sun, size: 22)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("\(weather?.high ?? 0)°")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(-0.3)
                        Text(" / \(weather?.low ?? 0)°")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    Text(locationName?.uppercased() ?? "")
                        .font(.system(size: 9.5))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(weather == nil ? 0 : 1)
            Spacer()
        }
        .frame(height: 56)
    }
}
