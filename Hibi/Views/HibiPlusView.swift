import SwiftUI
import UIKit

// MARK: - Layout constants

private enum HPLayout {
    static let collapsed = CGSize(width: 280, height: 280)
    static let stampExpandedHeight: CGFloat = 486
    static let featureExpandedHeight: CGFloat = 522
    static let featureExpandedHeightGenerating: CGFloat = 492
    static let featureExpandedHeightPurchased: CGFloat = 470
    static let peek: CGFloat = 9
    static let side: CGFloat = 14
    static let corner: CGFloat = 18
    static let tearThreshold: CGFloat = 70
    static let offScreen: CGFloat = 700
    static let collapseSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let hintHeight: CGFloat = 18
    static let backBottomContentProtection: CGFloat = 36
}


// MARK: - Stamp (Metal)

struct HibiStamp: View {
    let purchased: Bool
    /// Drives the stamp design choice and the shader's ink noise. Derived from
    /// the purchase UUID (stable), independent of the displayed `date`.
    let seed: UInt64
    /// The purchase date, rendered as the dated text on the stamp.
    let date: Date?
    var size: CGFloat = 154
    var rotation: Double = -6
    /// Bumped by the owner to replay the stamp-in animation.
    var stampToken: Int = 0
    /// When true, the stamp stays invisible until `stampToken` triggers the
    /// punch animation. Used during the purchase→flip reveal sequence.
    var holdStamp: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var pressScale: CGFloat = 1
    @State private var appeared = false
    @State private var shouldAnimatePunch = false

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
            } else {
                slotBody
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(purchased ? accessibilityDateLabel : Text("Awaiting your stamp"))
    }

    private var accessibilityDateLabel: Text {
        if let date {
            let formatted = date.formatted(.dateTime.year().month().day())
            return Text("Hibi Plus stamp, dated \(formatted)")
        }
        return Text("Hibi Plus stamp")
    }

    private func runStampIn() {
        guard !appeared else { return }

        if shouldAnimatePunch && !reduceMotion {
            shouldAnimatePunch = false
            withAnimation(.easeIn(duration: 0.18)) {
                appeared = true
                pressScale = 0.92
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    pressScale = 1.0
                }
            }
        } else {
            shouldAnimatePunch = false
            appeared = true
            pressScale = 1
        }
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
        .onChange(of: seed) { _, _ in buildComposite() }
        .onChange(of: stampToken) { _, _ in
            appeared = false
            shouldAnimatePunch = true
            UIImpactFeedbackGenerator(style: .heavy).prepare()
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
                    .float(Float(seed)),
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
                    .float(Float(seed)),
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
        guard let def = StampConfig.definition(for: seed) else { compositeImage = nil; return }
        let scale = displayScale
        let compositeSize = Self.compositeSize

        // Fast path: memory or disk cache → instant stamp with full shader.
        if let cached = StampCompositor.cachedComposite(
            definition: def, date: date, outputSize: compositeSize, scale: scale
        ) {
            compositeImage = cached
            isGenerating = false
            if holdStamp && !shouldAnimatePunch {
                // Purchase reveal: keep hidden until stampToken fires.
            } else if shouldAnimatePunch {
                DispatchQueue.main.async { runStampIn() }
            } else {
                runStampIn()
            }
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
                if !(holdStamp && !shouldAnimatePunch) {
                    runStampIn()
                }
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
                        Text("Personalizing your Stamp…")
                            .font(.custom(AppFont.serifItalic, size: 11))
                            .foregroundStyle(PaperTints.sealInk.opacity(0.5))
                    }
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
                    Text("your stamp")
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
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18), radius: 4, y: 2)
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
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18), radius: 3, y: 1.5)
    }
}

// MARK: - Perk tile visuals (stamp preview)

private struct MiniStamp: View {
    private let size: CGFloat = 36

    var body: some View {
        Image("StampPreview")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Widgets promo tile

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

struct WidgetsTile: View {
    var body: some View {
        HStack(spacing: 10) {
            WidgetIllustration()
            VStack(alignment: .leading, spacing: 2) {
                Text("Widgets")
                    .font(.custom(AppFont.serifRegular, size: 18))
                    .lineLimit(1)
                Text("On your home screen — paper, every day.")
                    .font(.custom(AppFont.serifItalic, size: 11.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
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
    /// StoreKit purchase sheet is in flight (before success is known).
    var isPurchasing: Bool = false
    var isGenerating: Bool = false
    var isDone: Bool = false
    /// Localized price, e.g. "$4.99". `nil` until StoreKit returns the product;
    /// while `nil` the button shows a spinner and is disabled so a wrong-currency
    /// placeholder is never shown.
    var price: String?
    let onPurchase: () -> Void

    private var isBusy: Bool { isDone || isGenerating || isPurchasing }
    /// Tappable only once a real price has loaded and no flow is in flight.
    private var isReady: Bool { price != nil && !isBusy }
    /// Waiting on StoreKit for the price (no other flow in flight) — dim the
    /// capsule so it reads as not-yet-interactive.
    private var isLoadingPrice: Bool { price == nil && !isBusy }

    var body: some View {
        Button {
            guard isReady else { return }
            onPurchase()
        } label: {
            Group {
                if isDone {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                    }
                } else if isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(PaperTints.card1)
                            .scaleEffect(0.8)
                        Text("Personalizing your Stamp…")
                            .font(.custom(AppFont.serifItalic, size: 13))
                    }
                } else if let price, !isPurchasing {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: price)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                        Text("one-time")
                            .font(.custom(AppFont.serifItalic, size: 12.5))
                            .opacity(0.7)
                    }
                } else {
                    // Purchase in flight, or the price hasn't loaded yet.
                    ProgressView()
                        .tint(PaperTints.card1)
                        .scaleEffect(0.9)
                        .frame(height: 18)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .foregroundStyle(PaperTints.card1)
            .background(Color.primary)
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18), radius: 6, y: 2)
            .opacity(isLoadingPrice ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        if isDone { return Text("Done") }
        if isGenerating { return Text("Personalizing your Stamp") }
        if isPurchasing { return Text("Purchasing…") }
        if let price { return Text("Buy Hibi Plus, \(price) one-time") }
        return Text("Loading price…")
    }
}

struct RestorePurchasesLink: View {
    let onRestore: () -> Void

    var body: some View {
        Button(action: onRestore) {
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
    let seed: UInt64
    let date: Date?
    let expandFraction: CGFloat
    let chromeFade: Double
    let stampToken: Int
    var holdStamp: Bool = false
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    var body: some View {
        let height = HPLayout.collapsed.height
            + (HPLayout.stampExpandedHeight - HPLayout.collapsed.height) * expandFraction

        ZStack {
            HibiStamp(purchased: purchased, seed: seed, date: date,
                      size: 200 + 110 * expandFraction, stampToken: stampToken,
                      holdStamp: holdStamp)
                .frame(maxWidth: .infinity)

            if !purchased {
                Text("Purchase Hibi Plus to receive your personalized stamp.")
                    .font(.appSerif(size: 15, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(max(0, 1 - Double(1 - expandFraction) * 3))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 44)
            }
        }
        .frame(height: height)
        .padding(.horizontal, 16)
    }
}

// Card 2 — feature card

private struct FeatureCardBody: View {
    let purchased: Bool
    let chromeFade: Double
    var isPurchasing: Bool = false
    var isGenerating: Bool = false
    var isDone: Bool = false
    var price: String?
    let onPurchase: () -> Void
    let onRestore: () -> Void
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
                    .overlay(alignment: .bottom) {
                        Text("Tap to find out more...")
                            .font(.appSerif(size: 11.5, italic: true, simple: useSimpleFont))
                            .foregroundStyle(.tertiary)
                            .opacity(1 - chromeFade)
                            .offset(y: 58)
                    }

                HStack(spacing: 12) {
                    perkTile {
                        IconFan()
                    } rule: {
                        Text("App icons")
                    } title: {
                        Text("Dress Hibi up.")
                    }
                    perkTile {
                        MiniStamp()
                    } rule: {
                        Text("Custom stamp")
                    } title: {
                        Text("Uniquely yours.")
                    }
                }
                .opacity(chromeFade)
                .padding(.bottom, 12 * chromeFade)

                WidgetsTile()
                    .opacity(chromeFade)
                    .padding(.bottom, (purchased ? 10 : 14) * chromeFade)

                if purchased && !isGenerating && !isDone {
                    Text("Thank you for supporting Hibi.")
                        .font(.appSerif(size: 11.5, italic: true, simple: useSimpleFont))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .opacity(chromeFade)
                        .padding(.top, 8 * chromeFade)
                        .padding(.bottom, 55 * chromeFade)
                }

                if !purchased || isGenerating || isDone {
                    VStack(spacing: 14) {
                        PlusCTA(isPurchasing: isPurchasing,
                                isGenerating: isGenerating,
                                isDone: isDone,
                                price: price,
                                onPurchase: onPurchase)
                        if !purchased {
                            RestorePurchasesLink(onRestore: onRestore)
                        }
                    }
                    .opacity(chromeFade)
                    .padding(.bottom, 70 * chromeFade)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
    @State private var frontIndex: Int
    @Binding var collapseProgress: CGFloat
    private let expandOnAppear: Bool
    private var expanded: Bool { collapseProgress < 0.5 }

    init(collapseProgress: Binding<CGFloat>, expandPlus: Bool = false, isPurchased: Bool) {
        _collapseProgress = collapseProgress
        // Default the front card by purchase state: non-purchasers see the Hibi
        // Plus pitch (feature card), purchasers see their earned stamp. Avoids
        // the confusing empty "awaiting your stamp" slot on first open.
        _frontIndex = State(initialValue: isPurchased ? 0 : 1)
        expandOnAppear = expandPlus
    }
    private var chromeFade: Double {
        Double(max(0, 1 - collapseProgress * 1.25))
    }
    @Environment(PlusStore.self) private var plusStore
    private var isPlus: Bool { plusStore.isPlus }
    private var purchaseDate: Date? { plusStore.purchaseDate }
    /// Stamp randomness seed: derived from the cached purchase UUID, falling
    /// back to the date only if no UUID has been recorded yet.
    private var stampSeed: UInt64 {
        if let uuid = plusStore.seedUUID { return StampConfig.seed(from: uuid) }
        if let date = purchaseDate { return StampConfig.seed(from: date) }
        return 0
    }

    // animation state
    @State private var dragY: CGFloat = 0
    @State private var isAnimating = false
    @State private var cardShift: CGFloat = 0          // 0…1, back rises to front
    @State private var commitCount = 0                 // haptic
    @State private var isPurchasing = false
    @State private var stampToken = 0
    @State private var pendingStampReveal = false
    @State private var isGeneratingStamp = false
    @State private var isDoneGenerating = false
    @State private var generationTask: Task<Void, Never>?

    @State private var motion = MotionStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    private var backIndex: Int { 1 - frontIndex }

    private func expandedHeight(for index: Int) -> CGFloat {
        if index == 0 { return HPLayout.stampExpandedHeight }
        if isPlus && !isGeneratingStamp && !isDoneGenerating { return HPLayout.featureExpandedHeightPurchased }
        if isGeneratingStamp || isDoneGenerating { return HPLayout.featureExpandedHeightGenerating }
        return HPLayout.featureExpandedHeight
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
        .onAppear { updateMotion() }
        .onDisappear { motion.stop() }
        .onChange(of: scenePhase) { _, _ in updateMotion() }
        .onChange(of: reduceMotion) { _, _ in updateMotion() }
    }

    private var totalHeight: CGFloat {
        let ef = 1 - collapseProgress
        let frontH = HPLayout.collapsed.height + (expandedHeight(for: frontIndex) - HPLayout.collapsed.height) * ef
        let backH = HPLayout.collapsed.height + (expandedHeight(for: backIndex) - HPLayout.collapsed.height) * ef
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
                    shadowAmount: 0, chromeAmount: 0,
                    bottomContentProtection: HPLayout.backBottomContentProtection,
                    bottomChromeAmount: 1
                )
                .modifier(parallax(depth: 2))
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
            .modifier(parallax(depth: 1))
            .zIndex(1)

            // Front card — draggable; slides off in the drag direction on commit.
            paperCard(
                index: frontIndex,
                baseFill: PaperTints.card1,
                overlayFill: PaperTints.card1, overlayOpacity: 0,
                horizontalInset: 0, bottomPeek: peek,
                shadowAmount: 1, chromeAmount: 1
            )
            .modifier(parallax(depth: 0))
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
            StampCardBody(purchased: isPlus, seed: stampSeed, date: purchaseDate,
                          expandFraction: 1 - collapseProgress,
                          chromeFade: chromeFade, stampToken: stampToken,
                          holdStamp: pendingStampReveal)
        } else {
            FeatureCardBody(purchased: isPlus, chromeFade: chromeFade,
                            isPurchasing: isPurchasing,
                            isGenerating: isGeneratingStamp,
                            isDone: isDoneGenerating,
                            price: plusStore.displayPrice,
                            onPurchase: purchase,
                            onRestore: restore)
        }
    }

    private var hint: some View {
        Text("Pull to tear · ↑ Next · ↓ Prev")
            .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: HPLayout.hintHeight)
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

    /// CTA tapped: run the StoreKit purchase. The CTA shows a spinner while the
    /// system sheet is up; only a verified success plays the celebratory
    /// checkmark → stamp-generation → flip sequence. Cancel/failure quietly
    /// returns to the price.
    private func purchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            let success = await plusStore.purchase()
            isPurchasing = false
            guard success else { return }
            pendingStampReveal = true
            withAnimation(.easeInOut(duration: 0.25)) { isGeneratingStamp = true }
            beginStampReveal()
        }
    }

    /// Pre-generate the stamp composite (seeded from the recorded purchase
    /// date) so flipping to the stamp card is instant, then flip.
    private func beginStampReveal() {
        let date = purchaseDate ?? Date()
        let scale = displayScale
        let def = StampConfig.definition(for: stampSeed)
        let compositeSize = HibiStamp.compositeSize

        generationTask?.cancel()
        generationTask = Task.detached(priority: .userInitiated) {
            guard let def else { return }
            _ = StampCompositor.composite(
                definition: def, date: date,
                outputSize: compositeSize, scale: scale
            )
        }

        Task {
            await generationTask?.value
            await MainActor.run { finishPurchaseFlip() }
        }
    }

    /// Restore a prior purchase (e.g. on a new device). On success the
    /// entitlement flips and the card collapses into its Plus state.
    private func restore() {
        Task { await plusStore.restore() }
    }

    /// Shows "Done" briefly, then flips to the stamp card.
    private func finishPurchaseFlip() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isGeneratingStamp = false
            isDoneGenerating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            performFlipToStamp()
        }
    }

    private func performFlipToStamp() {
        isDoneGenerating = false

        if frontIndex != 0 {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.78)) { dragY = -HPLayout.offScreen }
            withAnimation(.easeOut(duration: 0.78)) { cardShift = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.83) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) {
                    frontIndex = 0
                    dragY = 0; cardShift = 0; isAnimating = false
                }
                stampToken &+= 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    pendingStampReveal = false
                }
            }
        } else {
            stampToken &+= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                pendingStampReveal = false
            }
        }
    }

    private func updateMotion() {
        if scenePhase == .active && !reduceMotion {
            motion.start()
        } else {
            motion.stop()
        }
    }

    private func parallax(depth: Int) -> ParallaxOffset {
        ParallaxOffset(motion: motion, depth: depth, maxOffset: 2.8, reduceMotion: reduceMotion)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}
