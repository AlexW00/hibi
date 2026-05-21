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
    @Environment(Clock.self) private var clock
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("invertDaySwipe") private var invertDaySwipe: Bool = false
    @AppStorage("preferCompactDayView") private var preferCompactDayView: Bool = false
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false
    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue
    @AppStorage(TemperatureUnit.defaultsKey) private var temperatureUnitRaw: String = TemperatureUnit.system.rawValue
    @State private var dragY: CGFloat = 0
    @State private var isTearing: Bool = false
    @State private var cardShiftAmount: CGFloat = 0
    @State private var tearDirection: Int = 1  // +1 = next (drag up), -1 = prev (drag down)
    @State private var scheduleOpacity: Double = 1  // driven directly during tear (old fades out → new fades in)
    @State private var scheduleShowsIncomingDay: Bool = false  // flips mid-tear when old events are fully hidden
    @State private var tearCommitCount: Int = 0
    @State private var incomingCardY: CGFloat = -400   // off-screen above for backward tear
    @State private var scheduleSlideY: CGFloat = 0     // slide-up offset for schedule fade-in

    // MARK: - Schedule separator drag
    //
    // Single source of truth for the draggable Schedule separator. All visual
    // responses (paper height, aspect-ratio inset, chrome fade, hint collapse)
    // derive deterministically from `scheduleProgress` so they animate in
    // lockstep inside one transaction — that's what keeps a slow drag flicker-
    // free. During drag the gesture writes scheduleProgress directly (no
    // withAnimation); on release a single withAnimation(.spring) drives the
    // magnetic snap.

    /// 0 = paper stack at full size (default); 1 = collapsed, events list expanded.
    /// Initial value is seeded from `preferCompactDayView` in `init` so the app
    /// launches into the user's preferred state. Within a session, the user
    /// can drag freely — the preference is only consulted on view creation.
    @State private var scheduleProgress: CGFloat
    /// Progress at the moment the current drag began. Translation is applied
    /// relative to this so the separator tracks the finger 1:1.
    @State private var scheduleDragBaseProgress: CGFloat = 0
    /// True while a finger is on the separator.
    @State private var isDraggingSchedule: Bool = false
    /// Tick for haptic on snap.
    @State private var scheduleSnapCount: Int = 0

    // MARK: - Layout constants

    private let peekAmount: CGFloat = 10      // pts each card behind peeks below the one in front
    private let narrowStep: CGFloat = 14      // pts narrower per side per depth level
    private let tearThreshold: CGFloat = 80
    private let offScreen: CGFloat = 700

    // Schedule-collapse geometry. The paper stack and the "Pull to tear" hint
    // shrink toward `…Collapsed` values as scheduleProgress → 1. Drag range
    // is tuned to match the total visual displacement so the finger and the
    // separator move at roughly 1:1.
    //
    // `paperHeightCollapsed` is the floor for the paper-stack height; on top
    // of it the hint row contributes 36pt of additional collapse. Together
    // they place the schedule separator near the vertical center of the
    // screen at maximum collapse (the spec's stop position — "don't let it
    // go all the way to the top"). 380→260 + 36→0 ≈ 156pt of upward travel.
    private let paperHeightExpanded: CGFloat = 380
    private let paperHeightCollapsed: CGFloat = 260
    private let hintHeightExpanded: CGFloat = 36
    private let scheduleDragRange: CGFloat = 160

    // Progressive paper tints — white → off-white → beige (depth cue).
    private let card1Fill = PaperTints.card1
    private let card2Fill = PaperTints.card2
    private let card3Fill = PaperTints.card3

    init(
        year: Int,
        month: Int,
        day: Binding<Int>,
        scrollToNowToken: Int,
        onTapEvent: @escaping (CalendarEvent) -> Void,
        onDateChange: ((_ year: Int, _ month: Int, _ day: Int) -> Void)? = nil
    ) {
        self.year = year
        self.month = month
        self._day = day
        self.scrollToNowToken = scrollToNowToken
        self.onTapEvent = onTapEvent
        self.onDateChange = onDateChange
        // Seed initial collapse state from preference. Read once at view
        // creation so the user can still drag freely during the session.
        let preferCompact = UserDefaults.standard.bool(forKey: "preferCompactDayView")
        self._scheduleProgress = State(initialValue: preferCompact ? 1 : 0)
    }

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
            HijackingScrollView(
                progress: $scheduleProgress,
                collapseDistance: scheduleDragRange,
                onSnap: { scheduleSnapCount &+= 1 }
            ) {
                scheduleEvents
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 140)
            }
            // Opacity + slide are applied OUTSIDE the HijackingScrollView so
            // withAnimation transactions resolve in the native SwiftUI tree.
            // When these modifiers lived inside the closure they sat on the
            // hosted content of a UIHostingController, and the animation
            // context didn't propagate across that UIKit boundary — the
            // tear-time fade was a hard cut, and interrupted animations
            // could leave the events stuck at a mid-fade opacity (~0.5) until
            // the app was restarted.
            .opacity(eventsOpacity)
            .offset(y: scheduleSlideY)
            .mask(scrollFadeMask)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sensoryFeedback(.selection, trigger: scrollToNowToken)
        // Toggling the preference in Settings should switch the UI immediately
        // — otherwise users wonder why nothing happened. Animate with the same
        // spring used for the drag-release snap so the motion feels familiar.
        .onChange(of: preferCompactDayView) { _, newValue in
            let target: CGFloat = newValue ? 1 : 0
            guard scheduleProgress != target else { return }
            scheduleSnapCount &+= 1
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                scheduleProgress = target
            }
        }
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
    private var tearHintOpacity: Double {
        if isTearing { return 0 }
        return 1 - min(Double(abs(dragY)) / tearThreshold, 1)
    }

    // MARK: - Schedule-collapse derived values

    /// Dynamic paper stack height. Interpolates expanded → collapsed.
    private var paperHeight: CGFloat {
        paperHeightExpanded + (paperHeightCollapsed - paperHeightExpanded) * scheduleProgress
    }

    /// Dynamic height for the "Pull to tear" hint row. Collapses to 0 as the
    /// stack collapses so the schedule header moves up rather than just fading.
    private var hintHeight: CGFloat {
        hintHeightExpanded * (1 - scheduleProgress)
    }

    /// 0…1 fade for paper-card chrome that should disappear when collapsed:
    /// sunrise/sunset, weather pill, Apple Weather attribution, and the
    /// month/year sub-text. The big day number, weekday, and today underline
    /// remain at full opacity. A slight overshoot (1.25) makes chrome reach
    /// fully invisible well before the snap completes, which reads cleaner
    /// than a linear fade.
    private var chromeFadeOpacity: Double {
        Double(max(0, 1 - scheduleProgress * 1.25))
    }

    /// Horizontal inset (per side) added to each paper card to keep its
    /// aspect ratio constant as the stack height shrinks. Computed from the
    /// container width inside the tearStack's GeometryReader.
    private func paperShrinkInset(containerWidth: CGFloat) -> CGFloat {
        guard scheduleProgress > 0 else { return 0 }
        let scale = paperHeight / paperHeightExpanded
        let amount = containerWidth * (1 - scale) / 2
        return max(0, amount)
    }

    private var pullToTearHint: some View {
        Text(invertDaySwipe
             ? "Pull to tear · ↑ Prev · ↓ Next"
             : "Pull to tear · ↑ Next · ↓ Prev")
            .font(.system(size: 10))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: hintHeight, alignment: .center)
            .opacity(tearHintOpacity * chromeFadeOpacity)
            .clipped()
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
            let maxH: CGFloat = min(geo.size.height, paperHeightExpanded)
            let width = geo.size.width
            let goingForward = tearDirection == 1
            // Per-card inset that preserves the paper's aspect ratio as the
            // stack shrinks vertically. Computed once per geometry change so
            // every card in the stack moves in unison.
            let aspectInset = paperShrinkInset(containerWidth: width)

            ZStack(alignment: .top) {
                // --- Deepest placeholder (forward tear only) ---
                // Fades in behind during forward tear so the stack still has 3
                // cards at rest after reset.
                paperCard(
                    dayInfo: dayInfo(offsetBy: 3),
                    baseFill: card3Fill,
                    overlayFill: card3Fill,
                    overlayOpacity: 0,
                    horizontalInset: aspectInset + narrowStep * 2,
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
                    horizontalInset: aspectInset + (goingForward
                        ? narrowStep * (2 - cardShiftAmount)
                        : narrowStep * 2),
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
                    horizontalInset: aspectInset + (goingForward
                        ? narrowStep * (1 - cardShiftAmount)
                        : narrowStep * (1 + cardShiftAmount)),
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
                    horizontalInset: aspectInset + (goingForward ? 0 : narrowStep * cardShiftAmount),
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
                horizontalInset: aspectInset,
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
        .frame(height: paperHeight)
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
        let isToday = clock.isToday(year: dayInfo.year, month: dayInfo.month, day: dayInfo.day)

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
                    chromeFade: Double(1 - scheduleProgress),
                    useSimpleFont: useSimpleFont,
                    timeFormat: TimeFormat(rawValue: timeFormatRaw) ?? .system,
                    temperatureUnit: TemperatureUnit(rawValue: temperatureUnitRaw) ?? .system
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

    /// Centered pill handle flanked by hairlines that run out to the edges.
    private var scheduleHeader: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.quaternary).frame(height: 0.5)
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
            Rectangle().fill(.quaternary).frame(height: 0.5)
        }
        .padding(.vertical, 12)              // generous vertical hit area
        .contentShape(Rectangle())           // entire row receives the drag
        .gesture(scheduleDragGesture)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: scheduleSnapCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Schedule"))
    }

    /// Vertical drag on the schedule separator. Drives `scheduleProgress`
    /// directly during the drag (no animation, follows the finger), then on
    /// release snaps to whichever end (0 or 1) the user is closer to inside
    /// a single spring animation. We use velocity to bias the snap target —
    /// a quick flick commits even from below the halfway point, matching
    /// iOS sheet behavior.
    ///
    /// Every write to `scheduleProgress` propagates inside a transaction
    /// that sets `scrollContentOffsetAdjustmentBehavior = .disabled`. The
    /// schedule list's ScrollView would otherwise treat each per-frame
    /// growth of its container as a reason to animate its own content
    /// offset (UIScrollView-style deceleration), which surfaces as flicker
    /// during slow drags — and as the characteristic "settle" after the
    /// finger stops. Pair that with `.defaultScrollAnchor(.top, for:
    /// .sizeChanges)` on the ScrollView so any residual adjustment pins
    /// the content's top edge rather than its visible centroid.
    private var scheduleDragGesture: some Gesture {
        // .global so translation tracks the finger in screen space — the
        // separator's own layout position shifts up as scheduleProgress
        // grows, which would skew .local translation and cause feedback.
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                if !isDraggingSchedule {
                    scheduleDragBaseProgress = scheduleProgress
                    isDraggingSchedule = true
                }
                // Up-translation is negative; up increases progress (collapses).
                let delta = -value.translation.height / scheduleDragRange
                let raw = scheduleDragBaseProgress + delta
                let clamped = max(0, min(1, raw))
                if clamped != scheduleProgress {
                    // Per-frame writes must be (a) un-animated and (b) must
                    // not let the ScrollView animate its content offset for
                    // the resulting container resize. Setting both flags
                    // explicitly defends against an ambient animation
                    // context being inherited from an ancestor (TabView /
                    // NavigationStack iOS-26 transitions do wrap content in
                    // animated transactions, and value-scoped .animation
                    // modifiers elsewhere in the tree could otherwise
                    // re-bind to our Animatable padding/frame writes).
                    var t = Transaction()
                    t.disablesAnimations = true
                    t.scrollContentOffsetAdjustmentBehavior = .disabled
                    withTransaction(t) {
                        scheduleProgress = clamped
                    }
                }
            }
            .onEnded { value in
                isDraggingSchedule = false
                // Predict where the gesture would land if momentum continued —
                // the same heuristic UISheetPresentationController uses.
                let predicted = value.predictedEndTranslation.height
                let predictedDelta = -predicted / scheduleDragRange
                let projected = scheduleDragBaseProgress + predictedDelta
                let target: CGFloat = projected >= 0.5 ? 1 : 0
                if target != scheduleProgress {
                    scheduleSnapCount &+= 1
                }
                var t = Transaction()
                t.animation = .spring(response: 0.38, dampingFraction: 0.86)
                t.scrollContentOffsetAdjustmentBehavior = .disabled
                withTransaction(t) {
                    scheduleProgress = target
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
