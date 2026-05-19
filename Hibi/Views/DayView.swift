import EventKit
import SwiftUI

struct DayView: View {
    let year: Int
    let month: Int
    @Binding var day: Int
    let scrollToNowToken: Int
    let onTapEvent: (CalendarEvent) -> Void
    /// Called when a tear commits a day change that crosses a month or year
    /// boundary. ContentView uses this to update displayedYear/Month/selectedDay
    /// atomically in a single state transaction — avoids a flicker frame where
    /// day=1 still shows the old month.
    var onDateChange: ((_ year: Int, _ month: Int, _ day: Int) -> Void)?

    @Environment(EventStore.self) private var eventStore
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("invertDaySwipe") private var invertDaySwipe: Bool = false
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false
    @State private var dragY: CGFloat = 0
    @State private var isTearing: Bool = false
    @State private var cardShiftAmount: CGFloat = 0
    @State private var tearDirection: Int = 1  // +1 = next (drag up), -1 = prev (drag down)
    @State private var scheduleOpacity: Double = 1  // driven directly during tear (old fades out → new fades in)
    @State private var scheduleShowsIncomingDay: Bool = false  // flips mid-tear when old events are fully hidden
    @State private var tearCommitCount: Int = 0
    @State private var incomingCardY: CGFloat = -400   // off-screen above for backward tear
    @State private var scheduleSlideY: CGFloat = 0     // slide-up offset for schedule fade-in

    // Schedule-separator drawer: drag the "Schedule" divider to shrink the
    // paper stack and give the events list more room. Two snap positions —
    // expanded (calendar full size) and collapsed (calendar minimal).
    @State private var separatorExpanded: Bool = false      // true = events expanded, calendar collapsed
    @State private var separatorDragDelta: CGFloat = 0      // live drag offset on the separator

    // MARK: - Layout constants

    private let peekAmount: CGFloat = 10      // pts each card behind peeks below the one in front
    private let narrowStep: CGFloat = 14      // pts narrower per side per depth level
    private let tearThreshold: CGFloat = 80
    private let offScreen: CGFloat = 700

    // Schedule-separator constants. The collapsed height is sized to fit the
    // numeral block at its natural size (≈198pt) once the top/bottom rows
    // shrink — so the day number and weekday text never scale down.
    private let tearStackExpandedHeight: CGFloat = 380
    private let tearStackCollapsedHeight: CGFloat = 290
    private let extraHorizontalPaddingWhenCollapsed: CGFloat = 18
    private let pullToTearHintExpandedHeight: CGFloat = 36
    /// Total upward travel the separator gets: tear-stack shrink + hint shrink.
    private var maxSeparatorTravel: CGFloat {
        (tearStackExpandedHeight - tearStackCollapsedHeight) + pullToTearHintExpandedHeight
    }

    /// 0 = paper fully expanded (default), 1 = paper collapsed to minimum.
    /// Drives every aspect of the drawer animation (frame height, padding,
    /// chrome fade, hint fade). Combines the snapped base state with the
    /// live drag delta and clamps to [0, 1].
    private var collapseProgress: CGFloat {
        let base: CGFloat = separatorExpanded ? 1 : 0
        let live: CGFloat = base - separatorDragDelta / maxSeparatorTravel
        return max(0, min(1, live))
    }

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
            // VStack reflow (driven by `tearStack` / `pullToTearHint` shrinking
            // during a separator drag) gives the ScrollView a new implicit
            // frame on every drag frame. Without `geometryGroup()`, the rows
            // inside interpret those frame changes independently and visibly
            // flicker. Placed at the outermost level so it sits immediately
            // before the dynamic frame the VStack imposes.
            .geometryGroup()
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

    /// Date used by the schedule section. Stays on the current day during the
    /// fade-out phase, flips to the incoming day (including month/year) once
    /// old events are hidden.
    private var scheduleDate: (day: Int, month: Int, year: Int) {
        scheduleShowsIncomingDay ? dayInfo(offsetBy: tearDirection) : (day, month, year)
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
    /// Also fades and collapses to zero height as the schedule separator is dragged up.
    private var tearHintOpacity: Double {
        if isTearing { return 0 }
        let dragFade = 1 - min(Double(abs(dragY)) / tearThreshold, 1)
        return dragFade * Double(1 - collapseProgress)
    }

    private var pullToTearHint: some View {
        Text(invertDaySwipe
             ? "Pull to tear · ↑ Prev · ↓ Next"
             : "Pull to tear · ↑ Next · ↓ Prev")
            .font(.system(size: 10))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            // See note on `tearStack` — same jitter mitigation.
            .geometryGroup()
            .frame(height: pullToTearHintExpandedHeight * (1 - collapseProgress))
            .opacity(tearHintOpacity)
            .animation(.easeOut(duration: 0.32), value: isTearing)
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack {
            // Typographic constant — identical across all locales per design.
            Text(verbatim: "日々 · No. \(String(format: "%03d", day))")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(day)))
            Spacer()
            // Typographic constant — identical across all locales per design.
            Text(verbatim: "est. MMXXVI")
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
            let goingForward = tearDirection == 1

            ZStack(alignment: .top) {
                // --- Deepest placeholder (forward tear only) ---
                // Fades in behind during forward tear so the stack still has 3
                // cards at rest after reset.
                paperCard(
                    dayInfo: dayInfo(offsetBy: 3),
                    baseFill: card3Fill,
                    overlayFill: card3Fill,
                    overlayOpacity: 0,
                    horizontalInset: narrowStep * 2,
                    bottomPeek: 0,
                    shadowAmount: 0,
                    chromeAmount: 0
                )
                .opacity(goingForward ? cardShiftAmount : 0)

                // Card 3 (back): rest inset = 2·narrowStep, peek = 0.
                // Forward: shifts into Card 2 slot.
                // Backward: fades out (stack loses its deepest card).
                paperCard(
                    dayInfo: dayInfo(offsetBy: 2),
                    baseFill: card3Fill,
                    overlayFill: card2Fill,
                    overlayOpacity: goingForward ? cardShiftAmount : 0,
                    horizontalInset: goingForward
                        ? narrowStep * (2 - cardShiftAmount)
                        : narrowStep * 2,
                    bottomPeek: goingForward ? peekAmount * cardShiftAmount : 0,
                    shadowAmount: 0,
                    chromeAmount: 0
                )
                .opacity(goingForward ? 1 : 1 - cardShiftAmount)

                // Card 2 (middle): rest inset = narrowStep, peek = peekAmount.
                // Forward: shifts into Card 1 slot (gains shadow/chrome).
                // Backward: shifts into Card 3 slot (deeper).
                paperCard(
                    dayInfo: dayInfo(offsetBy: 1),
                    baseFill: card2Fill,
                    overlayFill: goingForward ? card1Fill : card3Fill,
                    overlayOpacity: cardShiftAmount,
                    horizontalInset: goingForward
                        ? narrowStep * (1 - cardShiftAmount)
                        : narrowStep * (1 + cardShiftAmount),
                    bottomPeek: goingForward
                        ? peekAmount * (1 + cardShiftAmount)
                        : peekAmount * (1 - cardShiftAmount),
                    shadowAmount: goingForward ? Double(cardShiftAmount) : 0,
                    chromeAmount: goingForward ? Double(cardShiftAmount) : 0
                )

                // Card 1 (front): widest, shortest.
                // Forward: slides off via dragY.
                // Backward: shifts into Card 2 slot (loses shadow/chrome) while
                // incoming card lands on top.
                paperCard(
                    dayInfo: (day: day, month: month, year: year),
                    baseFill: card1Fill,
                    overlayFill: goingForward ? card1Fill : card2Fill,
                    overlayOpacity: goingForward ? 0 : cardShiftAmount,
                    horizontalInset: goingForward ? 0 : narrowStep * cardShiftAmount,
                    bottomPeek: goingForward
                        ? peekAmount * 2
                        : peekAmount * (2 - cardShiftAmount),
                    shadowAmount: goingForward ? 1 : Double(1 - cardShiftAmount),
                    chromeAmount: goingForward ? 1 : Double(1 - cardShiftAmount)
                )
                .offset(y: goingForward ? dragY : 0)
                .rotationEffect(
                    goingForward ? .degrees(Double(dragY * 0.02)) : .zero,
                    anchor: dragY > 0 ? .top : .bottom
                )
                .opacity(goingForward ? 1 - min(Double(abs(dragY)) / 400, 0.6) : 1)
                .gesture(
                    DragGesture()
                        .onChanged { g in
                            guard !isTearing else { return }
                            dragY = g.translation.height
                            if abs(g.translation.height) > 2 {
                                let dragUp = g.translation.height < 0
                                tearDirection = (dragUp != invertDaySwipe) ? 1 : -1
                            }
                            // Backward drag: incoming card peeks from the edge
                            // the user is dragging from (top or bottom).
                            if tearDirection == -1 {
                                let fromTop = dragY > 0
                                incomingCardY = (fromTop ? -400 : 400) + dragY
                            } else {
                                incomingCardY = -400
                            }
                        }
                        .onEnded { _ in handleRelease() }
                )

            }
            .frame(width: width, height: maxH)

            // Incoming card (backward tear): slides in from above/below to
            // the Card 1 slot. Rendered outside the clipped stack so it's
            // visible beyond the stack edges during the drag/tear.
            paperCard(
                dayInfo: dayInfo(offsetBy: -1),
                baseFill: card1Fill,
                overlayFill: card1Fill,
                overlayOpacity: 0,
                horizontalInset: 0,
                bottomPeek: peekAmount * 2,
                shadowAmount: 1,
                chromeAmount: 1
            )
            .offset(y: incomingCardY)
            .rotationEffect(
                .degrees(abs(incomingCardY) > 10 ? Double(incomingCardY) * 0.005 : 0),
                anchor: incomingCardY < 0 ? .bottom : .top
            )
            .opacity(max(0, 1 - abs(incomingCardY) / 400))
            .allowsHitTesting(false)
        }
        // Without this, the card overlays (binding holes, perforation, page
        // content) interpret the parent frame's animating height independently
        // per frame and visibly jitter during slow drags. `geometryGroup()`
        // (iOS 17+) makes the frame change resolve atomically before being
        // propagated to children.
        .geometryGroup()
        .frame(height: tearStackExpandedHeight - (tearStackExpandedHeight - tearStackCollapsedHeight) * collapseProgress)
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
                    preview: chromeAmount < 1,
                    chromeOpacity: Double(1 - collapseProgress)
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
            // The collapse-time extra inset is folded in here (per-card) rather
            // than applied as an outer padding on `tearStack`. Applying it
            // outside would change the GeometryReader's width on every drag
            // frame and cascade layout into every card. `geometryGroup()` then
            // makes the resulting per-card width change resolve atomically so
            // the overlays (page content, binding holes, perforation) don't
            // interpret the changing parent geometry independently per frame.
            .geometryGroup()
            .padding(.horizontal, horizontalInset + extraHorizontalPaddingWhenCollapsed * collapseProgress)
            .padding(.bottom, bottomPeek)
    }

    // MARK: - Schedule

    private var scheduleHeader: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.quaternary).frame(height: 0.5)
            Text("Schedule")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(.secondary)
            Rectangle().fill(.quaternary).frame(height: 0.5)
        }
        // Slightly generous vertical padding so the divider is comfortable
        // to grab as a drawer handle.
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .gesture(separatorDrag)
        .sensoryFeedback(.selection, trigger: separatorExpanded)
    }

    /// Drawer-style drag on the "Schedule" divider. Follows the finger live,
    /// then snaps magnetically to the nearer of expanded / collapsed on release.
    private var separatorDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { g in
                guard !isTearing else { return }
                // Explicitly run the live drag update without any animation —
                // otherwise a stray implicit animation (from a parent
                // `.animation(...)` modifier elsewhere in the view tree) can
                // interpolate between drag frames and produce visible flicker
                // during slow drags.
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    separatorDragDelta = g.translation.height
                }
            }
            .onEnded { _ in
                let snapToCollapsed = collapseProgress >= 0.5
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    separatorExpanded = snapToCollapsed
                    separatorDragDelta = 0
                }
            }
    }

    private var scheduleEvents: some View {
        let sd = scheduleDate
        let events = eventStore.events(year: sd.year, month: sd.month, day: sd.day)
        let reminders = eventStore.reminders(year: sd.year, month: sd.month, day: sd.day)
        return Group {
            if !eventStore.showsCalendarContent {
                CalendarAccessPrompt(isDenied: eventStore.calendarAccessDenied) {
                    Task { await eventStore.requestAccess() }
                }
            } else if events.isEmpty && reminders.isEmpty {
                Text("An open day.")
                    .font(.appSerif(size: 20, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    VStack(spacing: 6) {
                        ForEach(reminders) { r in
                            ReminderRow(reminder: r) {
                                eventStore.toggleReminderCompletion(r)
                            }
                        }
                        ForEach(events) { e in
                            Button {
                                onTapEvent(e)
                            } label: {
                                DayEventRow(
                                    event: e,
                                    progress: e.progress(
                                        at: ctx.date,
                                        useDemoTimeOfDay: eventStore.isDemoMode,
                                        listYear: sd.year,
                                        listMonth: sd.month,
                                        listDay: sd.day
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
        .offset(y: scheduleSlideY)
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
            // Default: pull up → next. Inverted: pull up → previous.
            tear(to: -offScreen, next: !invertDaySwipe)
        } else if dragY > tearThreshold {
            // Default: pull down → previous. Inverted: pull down → next.
            tear(to: offScreen, next: invertDaySwipe)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                dragY = 0
                // Snap incoming card back to whichever edge it came from.
                incomingCardY = incomingCardY > 0 ? 400 : -400
            }
        }
    }

    private func tear(to destination: CGFloat, next: Bool) {
        tearCommitCount &+= 1
        tearDirection = next ? 1 : -1

        // Ensure the incoming day's month is loaded so the schedule swap
        // doesn't show an empty list while waiting for a fetch.
        let incoming = dayInfo(offsetBy: tearDirection)
        if incoming.month != month || incoming.year != year {
            eventStore.ensureLoaded(year: incoming.year, month: incoming.month)
        }

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

        if next {
            tearForward(destination: destination, startingOpacity: startingOpacity)
        } else {
            tearBackward(startingOpacity: startingOpacity)
        }
    }

    /// Forward tear: front page slides off, back cards shift forward.
    private func tearForward(destination: CGFloat, startingOpacity: Double) {
        withAnimation(.easeIn(duration: 0.28)) {
            dragY = destination
        }
        withAnimation(.easeOut(duration: 0.28)) {
            cardShiftAmount = 1.0
        }

        animateScheduleSwap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            self.resetAfterTear(next: true)
        }
    }

    /// Backward tear: incoming card slides in from above, existing cards shift
    /// deeper into the stack.
    private func tearBackward(startingOpacity: Double) {
        // Card 1 springs back from its drag position while shifting to Card 2.
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            dragY = 0
        }
        // Existing cards shift one level deeper simultaneously.
        withAnimation(.easeOut(duration: 0.28)) {
            cardShiftAmount = 1.0
        }
        // Incoming card slides in from above to the front position.
        withAnimation(.easeOut(duration: 0.30)) {
            incomingCardY = 0
        }

        animateScheduleSwap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            self.resetAfterTear(next: false)
        }
    }

    /// Two-phase schedule crossfade: old events fade out, incoming day slides
    /// up and fades in.
    private func animateScheduleSwap() {
        let fadeOut: TimeInterval = 0.14
        let fadeIn: TimeInterval = 0.28
        withAnimation(.easeIn(duration: fadeOut)) {
            scheduleOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                scheduleShowsIncomingDay = true
                scheduleSlideY = 18
            }
            withAnimation(.easeOut(duration: fadeIn)) {
                scheduleOpacity = 1
                scheduleSlideY = 0
            }
        }
    }

    /// Reset all tear state without animation. The static cards at
    /// cardShiftAmount=0 render the same content as the shifted overlays
    /// at cardShiftAmount=1 once `day` advances — pixel-identical, no pop.
    private func resetAfterTear(next: Bool) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            advance(next: next)
            dragY = 0
            cardShiftAmount = 0
            incomingCardY = -400
            scheduleShowsIncomingDay = false
            scheduleOpacity = 1
            scheduleSlideY = 0
        }
        withAnimation(.easeOut(duration: 0.32)) {
            isTearing = false
        }
    }

    private func advance(next: Bool) {
        let target = dayInfo(offsetBy: next ? 1 : -1)
        if target.month != month || target.year != year {
            // Cross-month: let the parent update all three atomically.
            onDateChange?(target.year, target.month, target.day)
        } else {
            day = target.day
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
    /// 1 = corner widgets fully visible at their full row heights.
    /// 0 = sunrise/sunset/weather/Apple-Weather are invisible and the
    /// top/bottom rows shrink to give the numeral + weekday more room.
    /// Driven by the schedule-separator drawer in `DayView`.
    var chromeOpacity: Double = 1

    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false
    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue
    @AppStorage(TemperatureUnit.defaultsKey) private var temperatureUnitRaw: String = TemperatureUnit.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnitRaw) ?? .system
    }

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
        // Shrinks to just enough for the weekday text when chrome is fully
        // faded, so the numeral block keeps its full size as the card shrinks.
        let rowHeight: CGFloat = 30 + 14 * CGFloat(chromeOpacity)  // 30 → 44
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "sunrise")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(weather?.sunrise.map { timeFormat.string(from: $0) } ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(weather?.sunrise == nil ? 0 : chromeOpacity)
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
                Text(weather?.sunset.map { timeFormat.string(from: $0) } ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(weather?.sunset == nil ? 0 : chromeOpacity)
        }
        .frame(height: rowHeight)
    }

    private var numeralBlock: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(day)")
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
            // Month name is already localized via the MonthNames accessor;
            // separator + year are locale-invariant. `verbatim:` skips the
            // LocalizedStringKey lookup so we don't pollute the catalog with a
            // generic "%@ · %@" key.
            Text(verbatim: "\(MonthNames.full[month - 1]) · \(String(year))")
                .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomRow: some View {
        // Always render the row at a fixed height — fade the weather pill to
        // opacity 0 on days without weather so the paper's vertical rhythm
        // doesn't change between days. The whole row also collapses to zero
        // height as the schedule separator drawer is dragged up.
        HStack(alignment: .bottom) {
            HStack(spacing: 8) {
                WeatherIcon(code: weather?.code ?? .sun, size: 22)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text(verbatim: "\(temperatureUnit.display(celsius: weather?.high ?? 0))°")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(-0.3)
                        Text(verbatim: " / \(temperatureUnit.display(celsius: weather?.low ?? 0))°")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    MarqueeText(text: locationName ?? "")
                        .font(.system(size: 9.5))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(weather == nil ? 0 : chromeOpacity)
            Spacer()
            AppleWeatherAttribution()
                .opacity(weather == nil ? 0 : chromeOpacity)
        }
        .frame(height: 56 * CGFloat(chromeOpacity))
        .clipped()
    }
}

/// Apple Weather attribution required by WeatherKit when weather data is
/// displayed (App Store Review Guideline 5.2.5). Renders the Apple Weather
/// trademark — the apple-logo glyph + the word "Weather" — and links to the
/// legal source page. Tappable; opens the attribution page in Safari.
private struct AppleWeatherAttribution: View {
    var body: some View {
        Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
            (Text(Image(systemName: "apple.logo")) + Text(verbatim: "\u{00a0}Weather"))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(Text("Apple Weather"))
    }
}
