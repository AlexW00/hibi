import SwiftUI

// MARK: - Layout constants

private enum HPLayout {
    static let collapsed = CGSize(width: 280, height: 280)
    static let stampExpandedHeight: CGFloat = 420
    static let featureExpandedHeight: CGFloat = 540
    static let featureExpandedHeightPurchased: CGFloat = 450
    static let peek: CGFloat = 9
    static let side: CGFloat = 14
    static let corner: CGFloat = 18
    static let tearThreshold: CGFloat = 70
    static let offScreen: CGFloat = 700
    static let collapseSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let hintHeight: CGFloat = 18
}

private let earlyAccessEndDate: Date = {
    var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? cal.timeZone
    return cal.date(from: c) ?? Date()
}()

// MARK: - Stamp (placeholder seal)
//
// PLACEHOLDER. The seal is intentionally drawn with plain SwiftUI shapes/Text
// so the inner rendering can later be replaced by a custom Metal shader
// (.colorEffect / .layerEffect on the `sealBody`). Keep `sealBody` isolated so
// the swap is localized to this view.

struct HibiStamp: View {
    let purchased: Bool
    let date: Date?
    var size: CGFloat = 154
    var rotation: Double = -6
    /// Bumped by the owner to replay the stamp-in animation.
    var stampToken: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressScale: CGFloat = 1
    @State private var appeared = false

    var body: some View {
        Group {
            if purchased {
                sealBody
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(appeared ? pressScale : 1.18)
                    .opacity(appeared ? 1 : 0)
                    .onChange(of: stampToken, initial: true) { _, _ in
                        appeared = false
                        runStampIn()
                    }
            } else {
                slotBody
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(purchased ? Text("Hibi Plus seal") : Text("Awaiting your seal"))
    }

    private func runStampIn() {
        guard !reduceMotion else { appeared = true; pressScale = 1; return }
        withAnimation(.easeOut(duration: 0.28)) { appeared = true }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { pressScale = 0.96 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12)) { pressScale = 1 }
    }

    // The replaceable seal artwork.
    private var sealBody: some View {
        ZStack {
            Circle()
                .fill(PaperTints.sealInk.opacity(0.06))
                .padding(4)
            Circle()
                .strokeBorder(PaperTints.sealInk.opacity(0.94), lineWidth: size * 0.045)
                .padding(6)
            VStack(spacing: size * 0.04) {
                Text(verbatim: "HIBI · PLUS")
                    .font(.system(size: size * 0.10, weight: .medium))
                    .tracking(size * 0.04)
                    .foregroundStyle(PaperTints.sealInk.opacity(0.92))
                Text(verbatim: "日々")
                    .font(.custom(AppFont.serifItalic, size: size * 0.42))
                    .foregroundStyle(PaperTints.sealInk.opacity(0.96))
                Text(verbatim: Self.format(date))
                    .font(.system(size: size * 0.085, design: .monospaced))
                    .tracking(size * 0.012)
                    .foregroundStyle(PaperTints.sealInk.opacity(0.86))
            }
        }
    }

    private var slotBody: some View {
        Circle()
            .strokeBorder(Color.primary.opacity(0.20), style: StrokeStyle(lineWidth: 1.25, dash: [4, 4]))
            .background(Circle().fill(Color.primary.opacity(0.02)))
            .overlay {
                VStack(spacing: 4) {
                    Text("AWAITING")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(.tertiary)
                    Text("your seal")
                        .font(.custom(AppFont.serifItalic, size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private static let sealFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd · MM · yyyy"
        return f
    }()

    private static func format(_ date: Date?) -> String {
        sealFormatter.string(from: date ?? Date())
    }
}

// MARK: - App icon carousel
//
// Placeholder: repeats a SwiftUI facsimile of the current app icon. The real
// icon ships as a Liquid Glass `.icon` bundle (no usable PNG in the asset
// catalog), so we render a facsimile that matches its design: a paper tile,
// two faint binding dots, an italic "26".

private struct AppIconTile: View {
    var size: CGFloat = 42
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(PaperTints.card1)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
            .overlay(alignment: .top) {
                HStack {
                    Circle().frame(width: 3, height: 3)
                    Spacer()
                    Circle().frame(width: 3, height: 3)
                }
                .foregroundStyle(.primary.opacity(0.35))
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }
            .overlay {
                Text(verbatim: "26")
                    .font(.custom(AppFont.serifItalic, size: size * 0.58))
                    .foregroundStyle(.primary)
            }
            .frame(width: size, height: size)
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.10), radius: 4, y: 2)
    }
}

struct AppIconCarousel: View {
    var size: CGFloat = 42
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let count = 8
    private var spacing: CGFloat { size * 0.27 }
    private var unitWidth: CGFloat { CGFloat(count) * (size + spacing) }
    private var speed: CGFloat { unitWidth / 28 }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let raw = CGFloat(elapsed) * speed
            let offset = -(raw.truncatingRemainder(dividingBy: unitWidth))
            Color.clear
                .overlay {
                    HStack(spacing: spacing) {
                        ForEach(0..<(count * 3), id: \.self) { _ in
                            AppIconTile(size: size)
                        }
                    }
                    .offset(x: offset)
                }
                .clipped()
        }
        .frame(height: size)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Perk tile visuals

private struct MiniIconTile: View {
    var size: CGFloat = 26
    var background: Color
    var foreground: Color
    var glyph: String
    var italic: Bool = true
    var dotColor: Color = .primary

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(background)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
            .overlay(alignment: .top) {
                HStack {
                    Circle().frame(width: 2, height: 2)
                    Spacer()
                    Circle().frame(width: 2, height: 2)
                }
                .foregroundStyle(dotColor.opacity(0.35))
                .padding(.horizontal, size * 0.14)
                .padding(.top, size * 0.10)
            }
            .overlay {
                Text(verbatim: glyph)
                    .font(.custom(italic ? AppFont.serifItalic : AppFont.serifRegular,
                                  size: size * 0.58))
                    .foregroundStyle(foreground)
            }
            .frame(width: size, height: size)
    }
}

private struct IconFan: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            MiniIconTile(
                background: PaperTints.card1,
                foreground: .primary,
                glyph: "26",
                dotColor: .primary
            )
            .rotationEffect(.degrees(-12))
            .offset(x: -8, y: 1)

            MiniIconTile(
                background: Color(red: 0.04, green: 0.04, blue: 0.04),
                foreground: Color(red: 0.984, green: 0.980, blue: 0.969),
                glyph: "日",
                italic: false,
                dotColor: .white
            )
            .zIndex(1)

            MiniIconTile(
                background: Color(red: 0.784, green: 0.212, blue: 0.165),
                foreground: Color(red: 1, green: 0.98, blue: 0.94),
                glyph: "26",
                dotColor: Color(red: 1, green: 0.98, blue: 0.94)
            )
            .rotationEffect(.degrees(12))
            .offset(x: 8, y: 1)
        }
        .frame(width: 44, height: 38)
        .accessibilityHidden(true)
    }
}

private struct MiniPaperCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(PaperTints.card1)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
            .overlay(alignment: .top) {
                HStack(spacing: 11) {
                    Circle()
                        .fill(PaperTints.bindingHole)
                        .overlay {
                            Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                        }
                        .frame(width: 2.5, height: 2.5)
                    Circle()
                        .fill(PaperTints.bindingHole)
                        .overlay {
                            Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                        }
                        .frame(width: 2.5, height: 2.5)
                }
                .padding(.top, 3)
            }
            .overlay {
                Text(verbatim: "23")
                    .font(.custom(AppFont.serifItalic, size: 19))
                    .foregroundStyle(.primary)
                    .offset(y: 2)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.primary.opacity(0.22))
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            .frame(width: 38, height: 38)
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18),
                    radius: 2, y: 1)
            .rotationEffect(.degrees(-3))
            .accessibilityHidden(true)
    }
}

// MARK: - Early access tile (Widgets promo)

private struct WidgetIllustration: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [Color(red: 0.83, green: 0.85, blue: 0.89),
                             Color(red: 0.55, green: 0.59, blue: 0.69)],
                    center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: 92
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PaperTints.card1)
                    .overlay {
                        VStack(spacing: 2) {
                            HStack(spacing: 18) {
                                Circle().fill(PaperTints.bindingHole).frame(width: 4, height: 4)
                                Circle().fill(PaperTints.bindingHole).frame(width: 4, height: 4)
                            }
                            Text(verbatim: "Thursday")
                                .font(.custom(AppFont.serifItalic, size: 8))
                                .foregroundStyle(.secondary)
                            Text(verbatim: "23")
                                .font(.custom(AppFont.serifRegular, size: 38))
                                .foregroundStyle(.primary)
                                .overlay(alignment: .bottom) {
                                    Rectangle().frame(width: 22, height: 1.25).foregroundStyle(.primary)
                                }
                        }
                        .padding(.vertical, 6)
                    }
                    .padding(8)
                    .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.10), radius: 4, y: 1)
            }
            .frame(width: 76, height: 76)
            .accessibilityHidden(true)
    }
}

struct EarlyAccessTile: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var daysLeft: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? cal.timeZone
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: earlyAccessEndDate)
        return max(0, cal.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.20, green: 0.78, blue: 0.35))
                    .frame(width: 5, height: 5)
                    .opacity(pulse ? 0.5 : 1)
                    .scaleEffect(pulse ? 0.85 : 1)
                Text("Currently in early access")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("\(daysLeft) days left")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
                Rectangle().frame(height: 0.5).foregroundStyle(Color.primary.opacity(0.10))
            }

            HStack(spacing: 10) {
                WidgetIllustration()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widgets")
                        .font(.custom(AppFont.serifRegular, size: 18))
                    Text("On your home screen — paper, every day.")
                        .font(.custom(AppFont.serifItalic, size: 11.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Purchase CTA

struct PlusCTA: View {
    /// True once the success morph has played; owner drives the rest.
    @Binding var showSuccess: Bool
    let onPurchase: () -> Void

    var body: some View {
        Button {
            guard !showSuccess else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showSuccess = true }
            onPurchase()
        } label: {
            Group {
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Thank you")
                            .font(.system(size: 15, weight: .semibold))
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "$4.99")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                        Text("one-time")
                            .font(.custom(AppFont.serifItalic, size: 12.5))
                            .opacity(0.7)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .foregroundStyle(showSuccess ? Color.white : PaperTints.card1)
            .background(showSuccess ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.primary)
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showSuccess ? Text("Purchased. Thank you.") : Text("Buy Hibi Plus, $4.99 one-time"))
    }
}

struct RestorePurchasesLink: View {
    var body: some View {
        Button {
            // No-op placeholder — no real IAP yet.
        } label: {
            Text("Restore purchases")
                .font(.custom(AppFont.serifItalic, size: 11.5))
                .foregroundStyle(.tertiary)
                .underline()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared header (collapsed + expanded feature card)

private struct PlusHeader: View {
    var deck: LocalizedStringKey?
    var showDeck: Bool = false
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false
    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: "日々")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(.secondary)
            Text("Hibi Plus")
                .font(.appSerif(size: 36, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
            if let deck {
                Text(deck)
                    .font(.appSerif(size: 13.5, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                    .opacity(showDeck ? 1 : 0)
                    .frame(height: showDeck ? nil : 0)
                    .clipped()
            }
        }
    }
}

// Card 1 — stamp

private struct StampCardBody: View {
    let purchased: Bool
    let date: Date?
    let expanded: Bool
    let stampToken: Int
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    var body: some View {
        VStack(spacing: 18) {
            HibiStamp(purchased: purchased, date: date,
                      size: expanded ? 186 : 154, stampToken: stampToken)
            if expanded {
                Text(purchased
                     ? "Thank you."
                     : "Purchase Hibi Plus to receive your personalized seal.")
                    .font(.appSerif(size: 15, italic: true, simple: useSimpleFont))
                    .foregroundStyle(purchased ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }
}

// Card 2 — feature card

private struct FeatureCardBody: View {
    let purchased: Bool
    let expanded: Bool
    @Binding var ctaSuccess: Bool
    let onPurchase: () -> Void
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    private var chromeFade: Double { expanded ? 1 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            PlusHeader(deck: "Your support matters a lot.", showDeck: expanded)
                .padding(.top, 14)

            // hairline rule with center dot — expanded only
            HStack(spacing: 8) {
                Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
            }
            .frame(width: 180, height: expanded ? nil : 0)
            .opacity(chromeFade)
            .padding(.top, expanded ? 16 : 0).padding(.bottom, expanded ? 12 : 0)

            if !expanded { Spacer(minLength: 0) }

            AppIconCarousel(size: 42)
                .padding(.bottom, expanded ? 14 : 0)

            if !expanded { Spacer(minLength: 0) }

            // perks — expanded only
            HStack(spacing: 12) {
                perkTile {
                    IconFan()
                } rule: {
                    Text("App icons")
                } title: {
                    Text("Dress Hibi up.")
                }
                perkTile {
                    MiniPaperCard()
                } rule: {
                    Text("Early access")
                } title: {
                    Text("Try features first.")
                }
            }
            .frame(height: expanded ? nil : 0)
            .opacity(chromeFade)
            .clipped()
            .padding(.bottom, expanded ? 12 : 0)

            EarlyAccessTile()
                .frame(height: expanded ? nil : 0)
                .opacity(chromeFade)
                .clipped()
                .padding(.bottom, expanded ? 14 : 0)

            if !expanded { Spacer(minLength: 0) }

            if !purchased {
                VStack(spacing: 8) {
                    PlusCTA(showSuccess: $ctaSuccess, onPurchase: onPurchase)
                    RestorePurchasesLink()
                }
                .frame(height: expanded ? nil : 0)
                .opacity(chromeFade)
                .clipped()
                .padding(.bottom, expanded ? 26 : 0)
            }

            // collapsed hint — sits at the bottom, above the perforation
            Text("Tap to see what's inside.")
                .font(.appSerif(size: 11.5, italic: true, simple: useSimpleFont))
                .foregroundStyle(.tertiary)
                .frame(height: expanded ? 0 : nil)
                .opacity(1 - chromeFade)
                .clipped()
                .padding(.bottom, expanded ? 0 : 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func perkTile<V: View, R: View, T: View>(
        @ViewBuilder visual: () -> V,
        @ViewBuilder rule: () -> R,
        @ViewBuilder title: () -> T
    ) -> some View {
        HStack(spacing: 10) {
            visual()
            VStack(alignment: .leading, spacing: 3) {
                rule()
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(.tertiary)
                title()
                    .font(.appSerif(size: 14, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                    .lineSpacing(-1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        }
    }
}

// MARK: - The stack

struct HibiPlusView: View {
    // 0 = stamp card, 1 = feature card
    @State private var frontIndex = 0
    @State private var expanded = false
    @State private var isPlus = false
    @State private var purchaseDate: Date?

    // animation state
    @State private var dragY: CGFloat = 0
    @State private var isAnimating = false
    @State private var cardShift: CGFloat = 0          // 0…1, back rises to front
    @State private var commitCount = 0                 // haptic
    @State private var ctaSuccess = false
    @State private var stampToken = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    private var backIndex: Int { 1 - frontIndex }

    private func expandedHeight(for index: Int) -> CGFloat {
        if index == 0 { return HPLayout.stampExpandedHeight }
        return isPlus ? HPLayout.featureExpandedHeightPurchased : HPLayout.featureExpandedHeight
    }
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let frontW = expanded ? w - 32 : HPLayout.collapsed.width
            let frontH = expanded ? expandedHeight(for: frontIndex) : HPLayout.collapsed.height
            let backW = expanded ? w - 32 : HPLayout.collapsed.width
            let backH = expanded ? expandedHeight(for: backIndex) : HPLayout.collapsed.height
            let stackW = lerp(frontW, backW, cardShift)
            let stackH = lerp(frontH, backH, cardShift)
            VStack(spacing: 0) {
                stack(containerWidth: w, stackWidth: stackW, stackHeight: stackH)
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.impact(weight: .medium), trigger: commitCount)
                hint.padding(.top, 14)
            }
            .frame(width: w)
        }
        .frame(height: totalHeight)
        .animation(HPLayout.collapseSpring, value: expanded)
        .animation(HPLayout.collapseSpring, value: isPlus)
    }

    private var totalHeight: CGFloat {
        let frontH = expanded ? expandedHeight(for: frontIndex) : HPLayout.collapsed.height
        let backH = expanded ? expandedHeight(for: backIndex) : HPLayout.collapsed.height
        let h = lerp(frontH, backH, cardShift)
        return h + 14 + HPLayout.hintHeight
    }

    @ViewBuilder
    private func stack(containerWidth w: CGFloat, stackWidth: CGFloat, stackHeight: CGFloat) -> some View {
        let side = HPLayout.side
        let peek = HPLayout.peek

        ZStack(alignment: .top) {
            // New-back placeholder — fades in during swipe so the stack still
            // has a back card after the departing front resets into the back slot.
            if isAnimating {
                paperCard(
                    index: frontIndex,
                    baseFill: PaperTints.card2,
                    overlayFill: PaperTints.card2, overlayOpacity: 0,
                    horizontalInset: side, bottomPeek: 0,
                    shadowAmount: 0, chromeAmount: 0
                )
                .opacity(Double(cardShift))
                .zIndex(0)
            }

            // Back card — peeks behind the front. During a swipe it rises
            // into the front slot (cardShift 0→1): inset narrows, peek
            // grows, shadow and chrome fade in, fill shifts card2→card1.
            paperCard(
                index: backIndex,
                baseFill: PaperTints.card2,
                overlayFill: PaperTints.card1, overlayOpacity: cardShift,
                horizontalInset: lerp(side, 0, cardShift),
                bottomPeek: lerp(0, peek, cardShift),
                shadowAmount: Double(cardShift),
                chromeAmount: Double(cardShift)
            )
            .zIndex(1)

            // Front card — draggable; slides off in the drag direction on commit.
            paperCard(
                index: frontIndex,
                baseFill: PaperTints.card1,
                overlayFill: PaperTints.card1, overlayOpacity: 0,
                horizontalInset: 0, bottomPeek: peek,
                shadowAmount: 1, chromeAmount: 1
            )
            .offset(y: dragY)
            .rotationEffect(.degrees(Double(dragY * 0.02)),
                            anchor: dragY > 0 ? .top : .bottom)
            .opacity(1 - min(Double(abs(dragY)) / 400, 0.6))
            .zIndex(2)
            .highPriorityGesture(dragGesture)
            .onTapGesture { toggleExpand() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Hibi Plus"))
            .accessibilityValue(expanded ? Text("Expanded") : Text("Collapsed"))
            .accessibilityActions {
                Button("Next page") { commitSwipe(direction: 1) }
                Button("Previous page") { commitSwipe(direction: -1) }
                Button(expanded ? "Collapse" : "Expand") { toggleExpand() }
            }
        }
        .frame(width: stackWidth, height: stackHeight)
    }

    /// Paper card following the DayView pattern: same frame for all cards,
    /// depth illusion via padding-based insets, content always rendered.
    @ViewBuilder
    private func paperCard(
        index: Int,
        baseFill: Color,
        overlayFill: Color, overlayOpacity: CGFloat,
        horizontalInset: CGFloat, bottomPeek: CGFloat,
        shadowAmount: Double, chromeAmount: Double
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: HPLayout.corner, style: .continuous)
        let edgeHighlight = 1 - chromeAmount
        let borderColor: Color = colorScheme == .dark
            ? .white.opacity(0.12) : .black.opacity(0.08)

        shape.fill(baseFill)
            .overlay { shape.fill(overlayFill).opacity(overlayOpacity) }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: 1)
                    .opacity(edgeHighlight)
            }
            .overlay(alignment: .top) {
                if chromeAmount > 0 { BindingHoles().opacity(chromeAmount) }
            }
            .overlay {
                cardBody(index: index)
                    .allowsHitTesting(chromeAmount >= 1)
            }
            .overlay(alignment: .bottom) {
                if chromeAmount > 0 {
                    PerforationEdge().padding(.bottom, 6).opacity(chromeAmount)
                }
            }
            .clipShape(shape)
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

    @ViewBuilder
    private func cardBody(index: Int) -> some View {
        if index == 0 {
            StampCardBody(purchased: isPlus, date: purchaseDate,
                          expanded: expanded, stampToken: stampToken)
        } else {
            FeatureCardBody(purchased: isPlus, expanded: expanded,
                            ctaSuccess: $ctaSuccess, onPurchase: purchase)
        }
    }

    private var hint: some View {
        Text("Pull to tear · ↑ Next · ↓ Prev")
            .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { g in
                guard !isAnimating else { return }
                dragY = g.translation.height
            }
            .onEnded { _ in
                if abs(dragY) > HPLayout.tearThreshold {
                    commitSwipe(direction: dragY < 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragY = 0 }
                }
            }
    }

    private func toggleExpand() {
        guard !isAnimating else { return }
        withAnimation(HPLayout.collapseSpring) { expanded.toggle() }
    }

    /// Flip to the other card, sliding the front off in `direction`
    /// (+1 = up/off-top, -1 = down/off-bottom). Symmetric + infinite.
    private func commitSwipe(direction: Int) {
        guard !isAnimating else { return }
        commitCount &+= 1
        isAnimating = true
        let dest = direction == 1 ? -HPLayout.offScreen : HPLayout.offScreen

        withAnimation(.easeIn(duration: 0.28)) { dragY = dest }
        withAnimation(.easeOut(duration: 0.28)) { cardShift = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) {
                frontIndex = backIndex
                dragY = 0
                cardShift = 0
                isAnimating = false
            }
        }
    }

    /// CTA tapped: success morph has already started (PlusCTA set ctaSuccess).
    /// After a beat, set Plus state, flip to the stamp card, and stamp the seal.
    private func purchase() {
        // 1) let the green checkmark read for a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPlus = true
            purchaseDate = Date()

            // 2) flip to the stamp card (collapsed)
            if frontIndex != 0 {
                isAnimating = true
                withAnimation(.easeIn(duration: 0.32)) { dragY = HPLayout.offScreen }
                withAnimation(.easeOut(duration: 0.32)) { cardShift = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) {
                        frontIndex = 0
                        dragY = 0; cardShift = 0; isAnimating = false
                        expanded = false
                    }
                    ctaSuccess = false
                    // 3) stamp the seal after the card has settled
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        stampToken &+= 1
                    }
                }
            } else {
                expanded = false
                ctaSuccess = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    stampToken &+= 1
                }
            }
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}
