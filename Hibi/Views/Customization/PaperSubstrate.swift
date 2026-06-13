import SwiftUI

/// The reusable paper-card primitive.
///
/// Layers (bottom to top):
/// 1. **Fill** — the resolved tint colour (caller passes `AdaptivePalette.paperFill(_:depth:)`).
/// 2. **Texture** — `bakedTexture` when provided (Task 3), else a static gradient placeholder
///    that approximates each texture's character without Metal. The placeholder is the "floor":
///    the substrate renders correctly even with reduce-motion / low-power mode.
/// 3. **Ruling** — a `Canvas`-drawn `RulingCanvas` overlay.
/// 4. **Tilt specular** — wired via `tiltEnabled` (no-op this task; Task 3 adds the Metal
///    `.layerEffect`). The parameter is accepted so callers can pass `!reduceMotion && !lowPower`
///    now and automatically benefit when Task 3 activates it.
/// 5. **Chrome** — `strokeBorder` edge + `BindingHoles` (top) + `PerforationEdge` (bottom),
///    scaled by `chromeAmount`.
///
/// The entire layers 1–3 are clipped to a `RoundedRectangle` before the chrome overlays are
/// applied, so the texture and ruling never bleed past the card corners.
struct PaperSubstrate: View {

    // MARK: - Inputs

    var texture: PaperTexture
    var ruling: PaperRuling
    /// Caller resolves this via `AdaptivePalette.paperFill(_:depth:)`.
    var fill: Color
    /// Task 3 baked paper-field texture. `nil` → static gradient floor (Task 2 behaviour).
    var bakedTexture: Image? = nil
    /// Task 3 live tilt specular. Accepted now so callers are future-proof; no-op until Task 3.
    var tiltEnabled: Bool = false
    /// Controls binding holes, perforation edge, and border opacity. 1 = full chrome; 0 = none.
    var chromeAmount: Double = 1
    var cornerRadius: CGFloat = 18

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        ZStack {
            // ── Layer 1: tint fill ──────────────────────────────────────────
            shape.fill(fill)

            // ── Layer 2: texture ────────────────────────────────────────────
            // When a baked texture is provided (Task 3), draw it as a resizable image.
            // Until then, use a cheap static gradient placeholder so every texture
            // reads as visually distinct even without Metal.
            if let bakedTexture {
                bakedTexture
                    .resizable()
                    .scaledToFill()
                    .clipShape(shape)
            } else {
                TexturePlaceholder(texture: texture, shape: shape)
            }

            // ── Layer 3: ruling ─────────────────────────────────────────────
            RulingCanvas(ruling: ruling)
                .clipShape(shape)

            // ── Layer 4 (Task 3): tilt specular ─────────────────────────────
            // tiltEnabled is stored so Task 3 can gate the .layerEffect here.
            // No-op for Task 2.

            // ── Layer 5: chrome ─────────────────────────────────────────────
            if chromeAmount > 0 {
                // Hairline border — defines the card silhouette in dark mode (critical:
                // back cards reach pitch-black so a black border vanishes; use white).
                // Mirrors DayView's adaptive border approach.
                let borderColor: Color = colorScheme == .dark
                    ? .white.opacity(0.12)
                    : .black.opacity(0.08)
                shape
                    .strokeBorder(borderColor, lineWidth: 1)
                    .opacity(chromeAmount)

                // Binding holes — top
                VStack {
                    BindingHoles()
                    Spacer()
                }
                .opacity(chromeAmount)

                // Perforation edge — bottom
                VStack {
                    Spacer()
                    PerforationEdge()
                }
                .opacity(chromeAmount)
            }
        }
        .clipShape(shape)
        // NOTE: shadows are intentionally left for callers (DayView manages its
        // own shadow parameters per card depth and drag progress).
    }
}

// MARK: - Texture placeholder

/// Static gradient / pattern approximation for each `PaperTexture` value.
///
/// This is the "floor" that makes each texture visually distinct without Metal.
/// Task 3 supersedes this entirely by passing a baked `Image` into `PaperSubstrate.bakedTexture`.
private struct TexturePlaceholder<S: Shape>: View {
    var texture: PaperTexture
    var shape: S

    var body: some View {
        switch texture {
        case .smooth:
            // Smooth paper: no overlay — the tint fill alone is correct.
            Color.clear

        case .linen:
            // Linen: two sets of faint diagonal hairlines at ±45°, approximating
            // woven thread. Design recipe: 45°/−45° repeating @6% warm-brown.
            LinenPatternView()
                .clipShape(shape)

        case .kraft:
            // Kraft: warm tan base darkening toward edges, suggesting pressed pulp.
            LinearGradient(
                colors: [
                    Color(.displayP3, red: 0.82, green: 0.72, blue: 0.56, opacity: 0.18),
                    Color(.displayP3, red: 0.68, green: 0.55, blue: 0.38, opacity: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)

        case .news:
            // Newsprint: soft warm-grey overall tint suggesting coarse pulp.
            // (A halftone dot grid at 4pt is Task 3 territory; a flat tint
            // reads clearly as "newsprint" at this scale.)
            Color(.displayP3, red: 0.88, green: 0.85, blue: 0.78, opacity: 0.20)
                .clipShape(shape)

        case .vellum:
            // Vellum: diagonal soft veil suggesting translucency. Design recipe:
            // diagonal gradient at low opacity.
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.04),
                    Color.white.opacity(0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)
        }
    }
}

/// Two sets of faint diagonal stripes approximating linen weave.
private struct LinenPatternView: View {
    var body: some View {
        Canvas { context, size in
            // +45° hairlines
            drawDiagonalStripes(into: &context, size: size, angle: .pi / 4)
            // −45° hairlines
            drawDiagonalStripes(into: &context, size: size, angle: -.pi / 4)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawDiagonalStripes(
        into context: inout GraphicsContext,
        size: CGSize,
        angle: CGFloat
    ) {
        // Stripe spacing in points (matches design: "repeating @6% brown")
        let stripeSpacing: CGFloat = 8
        let inkColor = Color(.displayP3, red: 0.55, green: 0.45, blue: 0.32, opacity: 0.06)
        let diagonal = sqrt(size.width * size.width + size.height * size.height)
        let count = Int(diagonal / stripeSpacing) + 2
        let cx = size.width / 2
        let cy = size.height / 2

        for i in (-count)...count {
            let offset = CGFloat(i) * stripeSpacing
            // Compute start/end points by rotating a horizontal line
            let cos = Foundation.cos(angle)
            let sin = Foundation.sin(angle)
            let halfLen = diagonal / 2
            let startX = cx + (-halfLen * cos - offset * (-sin))
            let startY = cy + (-halfLen * sin + offset * cos)
            let endX   = cx + (halfLen * cos - offset * (-sin))
            let endY   = cy + (halfLen * sin + offset * cos)

            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(path, with: .color(inkColor), lineWidth: 0.5)
        }
    }
}

// MARK: - Preview

#Preview("PaperSubstrate — all combos") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
            spacing: 12
        ) {
            ForEach(PaperTint.allCases, id: \.self) { tint in
                ForEach(PaperTexture.allCases, id: \.self) { texture in
                    ForEach(PaperRuling.allCases, id: \.self) { ruling in
                        VStack(spacing: 4) {
                            PaperSubstrate(
                                texture: texture,
                                ruling: ruling,
                                fill: AdaptivePalette.paperFill(tint)
                            )
                            .frame(width: 140, height: 160)
                            .shadow(
                                color: .black.opacity(0.12),
                                radius: 8, x: 0, y: 4
                            )

                            Text("\(tintName(tint)) · \(textureName(texture)) · \(rulingName(ruling))")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

// MARK: - Preview helpers (file-private)

private func tintName(_ tint: PaperTint) -> String {
    switch tint {
    case .cream: "Cream"
    case .blush: "Blush"
    case .sky: "Sky"
    case .sage: "Sage"
    case .butter: "Butter"
    case .lilac: "Lilac"
    }
}

private func textureName(_ texture: PaperTexture) -> String {
    switch texture {
    case .smooth: "Smooth"
    case .linen: "Linen"
    case .kraft: "Kraft"
    case .news: "News"
    case .vellum: "Vellum"
    }
}

private func rulingName(_ ruling: PaperRuling) -> String {
    switch ruling {
    case .plain: "Plain"
    case .lines: "Lines"
    case .grid: "Grid"
    case .dots: "Dots"
    }
}
