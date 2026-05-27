import SwiftUI

/// Single-line text that scrolls horizontally like a news ticker when it
/// doesn't fit the available width, with a soft fade on both edges. Renders
/// statically (no fade) when the text fits, and collapses to zero height
/// when the text is empty.
///
/// Picks up font / foregroundStyle / tracking from the environment, so the
/// caller styles it like any other `Text`.
struct MarqueeText: View {
    let text: String
    var pixelsPerSecond: CGFloat = 10
    var fadeWidth: CGFloat = 14
    var gap: CGFloat = 36
    var leadingPause: Double = 1.2

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animOffset: CGFloat = 0
    @State private var animationToken: Int = 0

    private var overflows: Bool {
        textWidth > 0 && containerWidth > 0 && textWidth > containerWidth + 0.5
    }

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    // The shell is a horizontally flexible single-line Text: it gives the
    // parent a stable line height and never pushes wider than what the
    // layout offers (so siblings keep their space). It's hidden when the
    // ticker is on; otherwise it's the static rendering.
    private var content: some View {
        Text(verbatim: text)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(overflows ? 0 : 1)
            .overlay(alignment: .leading) { tickerOverlay }
            .background(alignment: .leading) { textWidthMeasurer }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                guard abs(width - containerWidth) > 0.5 else { return }
                containerWidth = width
            }
            .onChange(of: overflows) { _, nowOverflows in
                if nowOverflows { restart() }
            }
            .mask { maskShape }
    }

    @ViewBuilder
    private var tickerOverlay: some View {
        if overflows {
            HStack(spacing: gap) {
                Text(verbatim: text).lineLimit(1).fixedSize()
                Text(verbatim: text).lineLimit(1).fixedSize()
            }
            .offset(x: animOffset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var textWidthMeasurer: some View {
        Text(verbatim: text)
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                guard abs(width - textWidth) > 0.5 else { return }
                textWidth = width
            }
    }

    @ViewBuilder
    private var maskShape: some View {
        if overflows {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                Rectangle().fill(.black)
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
            }
        } else {
            Rectangle().fill(.black)
        }
    }

    private func restart() {
        animationToken += 1
        let token = animationToken
        animOffset = 0
        let cycle = textWidth + gap
        let duration = max(4, Double(cycle / pixelsPerSecond))
        DispatchQueue.main.asyncAfter(deadline: .now() + leadingPause) {
            guard token == animationToken else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                animOffset = -cycle
            }
        }
    }
}
