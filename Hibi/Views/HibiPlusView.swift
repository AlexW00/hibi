import SwiftUI

// MARK: - Layout constants

private enum HPLayout {
    static let collapsed = CGSize(width: 280, height: 280)
    static let stampExpandedHeight: CGFloat = 420
    static let featureExpandedHeight: CGFloat = 510
    static let featureExpandedHeightPurchased: CGFloat = 450
    static let peek: CGFloat = 9
    static let side: CGFloat = 14
    static let corner: CGFloat = 18
    static let tearThreshold: CGFloat = 70
    static let offScreen: CGFloat = 700
    static let collapseSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

private let earlyAccessEndDate: Date = {
    var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: "de_DE")
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
                    .onAppear { runStampIn() }
                    .onChange(of: stampToken) { _, _ in
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
                Text("HIBI · PLUS")
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

    private static func format(_ date: Date?) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd · MM · yyyy"
        return f.string(from: date ?? Date())
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
                    .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
            }
            .overlay(alignment: .top) {
                HStack {
                    Circle().frame(width: 3, height: 3)
                    Spacer()
                    Circle().frame(width: 3, height: 3)
                }
                .foregroundStyle(.black.opacity(0.35))
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }
            .overlay {
                Text(verbatim: "26")
                    .font(.custom(AppFont.serifItalic, size: size * 0.58))
                    .foregroundStyle(.black)
            }
            .frame(width: size, height: size)
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.10), radius: 4, y: 2)
    }
}

struct AppIconCarousel: View {
    var size: CGFloat = 42
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    private let count = 8
    private var spacing: CGFloat { size * 0.27 }
    private var unitWidth: CGFloat { CGFloat(count) * (size + spacing) }

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: spacing) {
                ForEach(0..<(count * 2), id: \.self) { _ in
                    AppIconTile(size: size)
                }
            }
            .offset(x: offset)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                    offset = -unitWidth
                }
            }
        }
        .frame(height: size)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.14),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .accessibilityHidden(true)
    }
}
