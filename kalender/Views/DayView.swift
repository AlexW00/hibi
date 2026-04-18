import SwiftUI

struct DayView: View {
    let year: Int
    let month: Int
    @Binding var day: Int

    @State private var dragY: CGFloat = 0
    @State private var isTearing: Bool = false
    @State private var cardShiftAmount: CGFloat = 0
    @State private var tearDirection: Int = 1  // +1 = next (drag up), -1 = prev (drag down)
    @State private var scheduleFadeIn: Double = 1  // 0 right after tear, animates to 1

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
            pullToTearHint
            ScrollView {
                scheduleSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Day used by the schedule section. During a tear it points to the
    /// incoming day so the new events can fade in *while* the paper animates
    /// in (rather than after the swap completes).
    private var scheduleDay: Int {
        isTearing ? dayInfo(offsetBy: tearDirection).day : day
    }

    /// Opacity applied to the event rows only — the "SCHEDULE" header stays opaque.
    /// During drag: fades toward a minimum (events stay legible, matching the
    /// paper's own partial fade). During tear: reflects `scheduleFadeIn`
    /// which is animated 0 → 1 concurrently with the tear animation.
    private var eventsOpacity: Double {
        if isTearing { return scheduleFadeIn }
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
            Text("Kalender · No. \(String(format: "%03d", day))")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
            Text("est. MMXXVI")
                .font(.custom(AppFont.serifItalic, size: 13))
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
                    showShadow: false,
                    showChrome: false
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
                    showShadow: false,
                    showChrome: false
                )

                // Card 2 (middle): rest inset = narrowStep, peek = peekAmount.
                // During tear: inset → 0, peek → 2·peekAmount (shifts into Card 1 slot).
                paperCard(
                    dayInfo: dayInfo(offsetBy: tearDirection),
                    baseFill: card2Fill,
                    overlayFill: card1Fill,
                    overlayOpacity: cardShiftAmount,
                    horizontalInset: narrowStep * (1 - cardShiftAmount),
                    bottomPeek: peekAmount * (1 + cardShiftAmount),
                    showShadow: cardShiftAmount > 0.5,
                    showChrome: cardShiftAmount > 0.5
                )

                // Card 1 (front): widest, shortest (reveals cards behind peeking below).
                paperCard(
                    dayInfo: (day: day, month: month, year: year),
                    baseFill: card1Fill,
                    overlayFill: card1Fill,
                    overlayOpacity: 0,
                    horizontalInset: 0,
                    bottomPeek: peekAmount * 2,
                    showShadow: true,
                    showChrome: true
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
        showShadow: Bool,
        showChrome: Bool
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        let weather = SampleData.weather(forDay: dayInfo.day)
        let isToday = SampleData.isToday(year: dayInfo.year, month: dayInfo.month, day: dayInfo.day)

        let card = shape
            .fill(baseFill)
            .overlay { shape.fill(overlayFill).opacity(overlayOpacity) }
            .overlay(alignment: .top) { if showChrome { BindingHoles() } }
            .overlay {
                PageContent(
                    day: dayInfo.day,
                    month: dayInfo.month,
                    year: dayInfo.year,
                    isToday: isToday,
                    weather: weather,
                    preview: !showChrome
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) { if showChrome { PerforationEdge() } }
            .clipShape(shape)

        return card
            .shadow(
                color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(showShadow ? 0.18 : 0),
                radius: 22, x: 0, y: 18
            )
            .shadow(
                color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(showShadow ? 0.08 : 0),
                radius: 4, x: 0, y: 2
            )
            .padding(.horizontal, horizontalInset)
            .padding(.bottom, bottomPeek)
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        let events = SampleData.events(forDay: scheduleDay)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Rectangle().fill(.quaternary).frame(height: 0.5)
                Text("SCHEDULE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)
                Rectangle().fill(.quaternary).frame(height: 0.5)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .padding(.top, 14)

            Group {
                if events.isEmpty {
                    Text("An open day.")
                        .font(.custom(AppFont.serifItalic, size: 20))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    VStack(spacing: 6) {
                        ForEach(events) { e in
                            DayEventRow(event: e)
                        }
                    }
                }
            }
            .opacity(eventsOpacity)
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
        isTearing = true
        tearDirection = next ? 1 : -1

        // Snap scheduleFadeIn to 0 without animation — the schedule section
        // switches to the new day's events instantly, all at opacity 0,
        // and will fade in over the tear duration.
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            scheduleFadeIn = 0
        }

        // Front page slides off.
        withAnimation(.easeIn(duration: 0.28)) {
            dragY = destination
        }
        // Back cards shift forward one depth simultaneously.
        withAnimation(.easeOut(duration: 0.26)) {
            cardShiftAmount = 1.0
        }
        // New events fade in concurrently with the paper animation.
        withAnimation(.easeOut(duration: 0.26)) {
            scheduleFadeIn = 1
        }

        // After the tear, swap `day` and reset state without animation.
        // Because the static cards at cardShiftAmount=0 render the same content
        // as the shifted overlays at cardShiftAmount=1 once `day` advances,
        // the reset is pixel-identical — no pop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                advance(next: next)
                dragY = 0
                cardShiftAmount = 0
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
    let preview: Bool

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
                Text("06:14")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DayNames.full[SampleData.weekday(year: year, month: month, day: day)])
                .font(.custom(AppFont.serifItalic, size: 19))
                .foregroundStyle(.primary)
                .padding(.top, 2)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "sunset")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text("20:42")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 44)
    }

    private var numeralBlock: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.custom(AppFont.serifRegular, size: 180))
                .tracking(-6)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(minWidth: 180)
                .overlay(alignment: .bottom) {
                    if isToday {
                        Rectangle()
                            .fill(.primary)
                            .frame(height: 1.5)
                            .padding(.horizontal, 12)
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
                    Text("COPENHAGEN")
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
