import SwiftUI

// MARK: - Layout constants

private enum HPLayout {
    static let collapsed = CGSize(width: 280, height: 280)
    static let stampExpandedHeight: CGFloat = 420
    static let featureExpandedHeight: CGFloat = 540
    static let featureExpandedHeightPurchased: CGFloat = 480
    static let peek: CGFloat = 9
    static let side: CGFloat = 14
    static let corner: CGFloat = 18
    static let tearThreshold: CGFloat = 70
    static let offScreen: CGFloat = 700
    static let collapseSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let hintHeight: CGFloat = 18
    static let backBottomContentProtection: CGFloat = 56
}

private let earlyAccessEndDate: Date = {
    var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? cal.timeZone
    return cal.date(from: c) ?? Date()
}()

// MARK: - Stamp (Metal seal)

struct HibiStamp: View {
    let purchased: Bool
    let date: Date?
    var size: CGFloat = 154
    var rotation: Double = -6
    /// Bumped by the owner to replay the stamp-in animation.
    var stampToken: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var pressScale: CGFloat = 1
    @State private var appeared = false
    @State private var pendingStampIn = false

    // Metal stamp state
    @State private var compositeImage: CGImage?
    @State private var compositeTask: Task<Void, Never>?
    @State private var isGenerating = false
    @State private var motion = MotionStore()
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    // Noise parameters. Release builds always ship the default preset; DEBUG
    // builds read the values tuned in the Stamp Noise debug menu.
    #if DEBUG
    @AppStorage(StampNoise.valuesKey) private var noiseRaw = StampNoise.defaultRaw
    private var noiseValues: [Float] { StampNoise.decode(noiseRaw) }
    #else
    private var noiseValues: [Float] { StampNoise.defaultValues }
    #endif

    var body: some View {
        Group {
            if purchased {
                sealBody
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(appeared ? pressScale : 1.18)
                    .opacity(appeared ? 1 : 0)
                    .onChange(of: stampToken, initial: true) { _, _ in
                        appeared = false
                        pendingStampIn = true
                    }
            } else {
                slotBody
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(purchased ? accessibilityDateLabel : Text("Awaiting your seal"))
    }

    private var accessibilityDateLabel: Text {
        if let date {
            let formatted = date.formatted(.dateTime.year().month().day())
            return Text("Hibi Plus seal, dated \(formatted)")
        }
        return Text("Hibi Plus seal")
    }

    private func runStampIn() {
        guard !reduceMotion else { appeared = true; pressScale = 1; return }
        withAnimation(.easeOut(duration: 0.28)) { appeared = true }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { pressScale = 0.96 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12)) { pressScale = 1 }
    }

    private var sealBody: some View {
        Group {
            if let compositeImage {
                if reduceMotion || isLowPower {
                    staticStamp(image: compositeImage)
                } else {
                    liveStamp(image: compositeImage)
                }
            } else {
                sealPlaceholder
            }
        }
        .onAppear { buildComposite() }
        .onChange(of: date) { _, _ in buildComposite() }
        .onChange(of: stampToken) { _, _ in
            buildComposite()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func staticStamp(image: CGImage) -> some View {
        return Image(decorative: image, scale: displayScale)
            .resizable()
            .frame(width: size, height: size)
            .layerEffect(
                ShaderLibrary.stampEffect(
                    .float2(Float(size), Float(size)),
                    .float(Float(StampConfig.seed(from: date ?? Date()))),
                    .float2(0, 0),
                    .color(PaperTints.sealInk),
                    .floatArray(noiseValues)
                ),
                maxSampleOffset: CGSize(width: 2, height: 2)
            )
    }

    private func liveStamp(image: CGImage) -> some View {
        return Image(decorative: image, scale: displayScale)
            .resizable()
            .frame(width: size, height: size)
            .layerEffect(
                ShaderLibrary.stampEffect(
                    .float2(Float(size), Float(size)),
                    .float(Float(StampConfig.seed(from: date ?? Date()))),
                    .float2(Float(motion.tiltX), Float(motion.tiltY)),
                    .color(PaperTints.sealInk),
                    .floatArray(noiseValues)
                ),
                maxSampleOffset: CGSize(width: 2, height: 2)
            )
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
    }

    static let compositeSize: CGFloat = 310

    private func buildComposite() {
        compositeTask?.cancel()
        guard let date else { compositeImage = nil; return }
        let seed = StampConfig.seed(from: date)
        guard let def = StampConfig.definition(for: seed) else { compositeImage = nil; return }
        let scale = displayScale
        let compositeSize = Self.compositeSize

        // Fast path: memory or disk cache → instant stamp with full shader.
        if let cached = StampCompositor.cachedComposite(
            definition: def, date: date, outputSize: compositeSize, scale: scale
        ) {
            compositeImage = cached
            isGenerating = false
            flushStampIn()
            return
        }

        // Slow path: generate async, persist for next time.
        isGenerating = true
        compositeTask = Task.detached(priority: .userInitiated) {
            let image = StampCompositor.composite(
                definition: def,
                date: date,
                outputSize: compositeSize,
                scale: scale
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                compositeImage = image
                isGenerating = false
                flushStampIn()
            }
        }
    }

    private var sealPlaceholder: some View {
        Circle()
            .fill(PaperTints.sealInk.opacity(0.06))
            .overlay {
                if isGenerating {
                    VStack(spacing: 6) {
                        ProgressView()
                            .tint(PaperTints.sealInk.opacity(0.4))
                        Text("Generating your seal…")
                            .font(.custom(AppFont.serifItalic, size: 11))
                            .foregroundStyle(PaperTints.sealInk.opacity(0.5))
                    }
                }
            }
    }

    /// Plays the stamp-in animation if one was deferred until the composite loaded.
    private func flushStampIn() {
        guard pendingStampIn else { return }
        pendingStampIn = false
        runStampIn()
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
}

// MARK: - App icon carousel

private struct AppIconTile: View {
    let assetName: String
    var size: CGFloat = 42

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.10), radius: 4, y: 2)
    }
}

struct AppIconCarousel: View {
    var size: CGFloat = 42
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let assets = AppIconManager.icons.map(\.previewAssetName)
    private var count: Int { Self.assets.count }
    private var spacing: CGFloat { size * 0.27 }
    private var shadowPadding: CGFloat { max(8, size * 0.20) }
    private var stripHeight: CGFloat { size + shadowPadding * 2 }
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
                        ForEach(0..<(count * 3), id: \.self) { i in
                            AppIconTile(assetName: Self.assets[i % count], size: size)
                        }
                    }
                    .offset(x: offset)
                }
                .clipped()
        }
        .frame(height: stripHeight)
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

private struct IconFan: View {
    private let size: CGFloat = 26
    private let icons = ["AppIconPreview-Porcelain", "AppIconPreview-Default", "AppIconPreview-DiscoBalloon"]

    var body: some View {
        ZStack {
            miniIcon(icons[0])
                .rotationEffect(.degrees(-12))
                .offset(x: -8, y: 1)
            miniIcon(icons[1])
                .zIndex(1)
            miniIcon(icons[2])
                .rotationEffect(.degrees(12))
                .offset(x: 8, y: 1)
        }
        .frame(width: 44, height: 38)
        .accessibilityHidden(true)
    }

    private func miniIcon(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
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

private struct RadarPingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 16
    private let dotSize: CGFloat = 5
    private let cycle: TimeInterval = 1.8
    private let green = Color(red: 0.20, green: 0.78, blue: 0.35)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0 : elapsed.truncatingRemainder(dividingBy: cycle) / cycle

            ZStack {
                if reduceMotion {
                    Circle()
                        .strokeBorder(green.opacity(0.24), lineWidth: 1)
                        .frame(width: 10, height: 10)
                } else {
                    pingRing(phase: CGFloat(phase))
                    pingRing(phase: CGFloat((phase + 0.52).truncatingRemainder(dividingBy: 1)))
                }

                Circle()
                    .fill(green)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: green.opacity(0.32), radius: 3, y: 1)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    private func pingRing(phase: CGFloat) -> some View {
        let ringSize = dotSize + (size - dotSize) * phase
        let opacity = Double((1 - phase) * 0.38)

        return Circle()
            .stroke(green.opacity(opacity), lineWidth: 1.1)
            .frame(width: ringSize, height: ringSize)
    }
}

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
                RadarPingIndicator()
                Text("Currently in early access")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(daysLeft) days left")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .layoutPriority(1)
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
                        .lineLimit(1)
                    Text("On your home screen — paper, every day.")
                        .font(.custom(AppFont.serifItalic, size: 11.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
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
    }
}

// MARK: - Purchase CTA

struct PlusCTA: View {
    /// True once the success morph has played; owner drives the rest.
    @Binding var showSuccess: Bool
    var isGenerating: Bool = false
    let onPurchase: () -> Void

    private var isActive: Bool { showSuccess || isGenerating }

    var body: some View {
        Button {
            guard !showSuccess else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showSuccess = true }
            onPurchase()
        } label: {
            Group {
                if isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Generating your seal…")
                            .font(.custom(AppFont.serifItalic, size: 13))
                    }
                } else if showSuccess {
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
            .foregroundStyle(isActive ? Color.white : PaperTints.card1)
            .background(isActive ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.primary)
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isGenerating ? Text("Generating your seal") :
            showSuccess ? Text("Purchased. Thank you.") :
            Text("Buy Hibi Plus, $4.99 one-time")
        )
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
    var deckFade: Double = 0
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
                    .lineLimit(1)
                    .padding(.top, 2)
                    .opacity(deckFade)
            }
        }
    }
}

// Card 1 — stamp

private struct StampCardBody: View {
    let purchased: Bool
    let date: Date?
    let expandFraction: CGFloat
    let chromeFade: Double
    let stampToken: Int
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    var body: some View {
        VStack(spacing: 18) {
            HibiStamp(purchased: purchased, date: date,
                      size: 200 + 110 * expandFraction, stampToken: stampToken)
            if !purchased {
                Text("Purchase Hibi Plus to receive your personalized seal.")
                    .font(.appSerif(size: 15, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(chromeFade)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

// Card 2 — feature card

private struct FeatureCardBody: View {
    let purchased: Bool
    let chromeFade: Double
    @Binding var ctaSuccess: Bool
    var isGenerating: Bool = false
    let onPurchase: () -> Void
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                PlusHeader(deck: "Your support matters a lot.", deckFade: chromeFade)
                    .padding(.top, 14)

                HStack(spacing: 8) {
                    Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
                    Text(verbatim: "·").foregroundStyle(.tertiary)
                    Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
                }
                .frame(width: 180)
                .opacity(chromeFade)
                .padding(.top, 16 * chromeFade).padding(.bottom, 12 * chromeFade)

                AppIconCarousel(size: 42)
                    .padding(.bottom, 14 * chromeFade)

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
                .opacity(chromeFade)
                .padding(.bottom, 12 * chromeFade)

                EarlyAccessTile()
                    .opacity(chromeFade)
                    .padding(.bottom, (purchased ? 10 : 14) * chromeFade)

                if purchased {
                    Text("Thank you for supporting Hibi.")
                        .font(.appSerif(size: 11.5, italic: true, simple: useSimpleFont))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .opacity(chromeFade)
                        .padding(.bottom, 30 * chromeFade)
                }

                if !purchased {
                    VStack(spacing: 8) {
                        PlusCTA(showSuccess: $ctaSuccess, isGenerating: isGenerating, onPurchase: onPurchase)
                        RestorePurchasesLink()
                    }
                    .opacity(chromeFade)
                    .padding(.bottom, 26 * chromeFade)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text("Tap to see what's inside.")
                .font(.appSerif(size: 11.5, italic: true, simple: useSimpleFont))
                .foregroundStyle(.tertiary)
                .opacity(1 - chromeFade)
                .padding(.bottom, 22)
        }
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
                    .lineLimit(1)
                title()
                    .font(.appSerif(size: 14, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                    .lineSpacing(-1)
                    .lineLimit(1)
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
    @Binding var collapseProgress: CGFloat
    private var expanded: Bool { collapseProgress < 0.5 }
    private var chromeFade: Double {
        Double(max(0, 1 - collapseProgress * 1.25))
    }
    @State private var isPlus = false
    @State private var purchaseDate: Date?

    // animation state
    @State private var dragY: CGFloat = 0
    @State private var isAnimating = false
    @State private var cardShift: CGFloat = 0          // 0…1, back rises to front
    @State private var commitCount = 0                 // haptic
    @State private var ctaSuccess = false
    @State private var stampToken = 0
    @State private var isGeneratingStamp = false
    @State private var generationTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    private var backIndex: Int { 1 - frontIndex }

    private func expandedHeight(for index: Int) -> CGFloat {
        if index == 0 { return HPLayout.stampExpandedHeight }
        return isPlus ? HPLayout.featureExpandedHeightPurchased : HPLayout.featureExpandedHeight
    }
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ef = 1 - collapseProgress
            let frontW = HPLayout.collapsed.width + (w - 32 - HPLayout.collapsed.width) * ef
            let frontH = HPLayout.collapsed.height + (expandedHeight(for: frontIndex) - HPLayout.collapsed.height) * ef
            let backW = HPLayout.collapsed.width + (w - 32 - HPLayout.collapsed.width) * ef
            let backH = HPLayout.collapsed.height + (expandedHeight(for: backIndex) - HPLayout.collapsed.height) * ef
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
        .animation(HPLayout.collapseSpring, value: isPlus)
    }

    private var totalHeight: CGFloat {
        let ef = 1 - collapseProgress
        let frontH = HPLayout.collapsed.height + (expandedHeight(for: frontIndex) - HPLayout.collapsed.height) * ef
        let backH = HPLayout.collapsed.height + (expandedHeight(for: backIndex) - HPLayout.collapsed.height) * ef
        let h = lerp(frontH, backH, cardShift)
        let hintH = HPLayout.hintHeight * ef
        return h + 14 + hintH
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
                    shadowAmount: 0, chromeAmount: 0,
                    bottomContentProtection: HPLayout.backBottomContentProtection,
                    bottomChromeAmount: 1
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
                chromeAmount: Double(cardShift),
                bottomContentProtection: lerp(HPLayout.backBottomContentProtection, 0, cardShift),
                bottomChromeAmount: 1
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
        shadowAmount: Double, chromeAmount: Double,
        bottomContentProtection: CGFloat = 0,
        bottomChromeAmount: Double = 0
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: HPLayout.corner, style: .continuous)
        let edgeHighlight = 1 - chromeAmount
        let bottomChromeOpacity = max(chromeAmount, bottomChromeAmount)
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
                GeometryReader { proxy in
                    cardBody(index: index)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                        .allowsHitTesting(chromeAmount >= 1)
                        .mask {
                            HStack(spacing: 0) {
                                LinearGradient(
                                    stops: [.init(color: .clear, location: 0),
                                            .init(color: .black, location: 1)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .frame(width: 16)
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .frame(height: max(0, proxy.size.height - bottomContentProtection))
                                    Spacer(minLength: 0)
                                }
                                LinearGradient(
                                    stops: [.init(color: .black, location: 0),
                                            .init(color: .clear, location: 1)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .frame(width: 16)
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
            }
            .overlay(alignment: .bottom) {
                if bottomChromeOpacity > 0 {
                    PerforationEdge().padding(.bottom, 6).opacity(bottomChromeOpacity)
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
                          expandFraction: 1 - collapseProgress,
                          chromeFade: chromeFade, stampToken: stampToken)
        } else {
            FeatureCardBody(purchased: isPlus, chromeFade: chromeFade,
                            ctaSuccess: $ctaSuccess, isGenerating: isGeneratingStamp,
                            onPurchase: purchase)
        }
    }

    private var hint: some View {
        let ef = 1 - collapseProgress
        return Text("Pull to tear · ↑ Next · ↓ Prev")
            .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: HPLayout.hintHeight * ef)
            .opacity(chromeFade)
            .clipped()
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
        let target: CGFloat = collapseProgress >= 0.5 ? 0 : 1
        var t = Transaction()
        t.animation = HijackingScrollView<EmptyView>.snapSpring
        t.scrollContentOffsetAdjustmentBehavior = .disabled
        withTransaction(t) { collapseProgress = target }
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
    /// Pre-generate the stamp composite so flipping to the stamp card is instant.
    private func purchase() {
        let date = Date()
        purchaseDate = date
        let scale = displayScale

        // Capture values before entering detached context.
        let seed = StampConfig.seed(from: date)
        let def = StampConfig.definition(for: seed)
        let compositeSize = HibiStamp.compositeSize

        // Start composite generation immediately so the cache is warm
        // before the stamp card appears.
        generationTask?.cancel()
        generationTask = Task.detached(priority: .userInitiated) {
            guard let def else { return }
            _ = StampCompositor.composite(
                definition: def, date: date,
                outputSize: compositeSize, scale: scale
            )
        }

        // 1) Show checkmark for 0.8s, then switch to "Generating…" on the CTA
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.25)) { isGeneratingStamp = true }
        }

        // 2) Wait for composite to finish, then flip to stamp card
        Task {
            await generationTask?.value
            await MainActor.run { finishPurchaseFlip() }
        }
    }

    /// Flips to the stamp card and stamps the seal once the composite is ready.
    private func finishPurchaseFlip() {
        isGeneratingStamp = false
        isPlus = true

        if frontIndex != 0 {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.32)) { dragY = HPLayout.offScreen }
            withAnimation(.easeOut(duration: 0.32)) { cardShift = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) {
                    frontIndex = 0
                    dragY = 0; cardShift = 0; isAnimating = false
                    collapseProgress = 1
                }
                ctaSuccess = false
                // Stamp the seal after the card has settled
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    stampToken &+= 1
                }
            }
        } else {
            collapseProgress = 1
            ctaSuccess = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                stampToken &+= 1
            }
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}
