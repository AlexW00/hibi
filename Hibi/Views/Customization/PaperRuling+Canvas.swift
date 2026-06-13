import SwiftUI

/// Canvas-based ruling renderer for paper cards.
///
/// The geometry logic lives in a `PaperRuling` extension so Stage 4 snap tests
/// can call `draw(into:size:ink:)` directly, independent of the enclosing view.
extension PaperRuling {

    /// Spacing between ruling lines / lattice nodes, in points.
    static let spacing: CGFloat = 22

    /// Dot radius for the `.dots` ruling style.
    static let dotRadius: CGFloat = 1

    /// Draws the ruling pattern into a `GraphicsContext`.
    ///
    /// - Parameters:
    ///   - context: The `GraphicsContext` provided by a `Canvas`.
    ///   - size: The `CGSize` of the canvas provided by a `Canvas`.
    ///   - ink: The resolved `Color` to use for the lines / dots.
    ///     Pass `AdaptivePalette.rulingInk` for standard paper ruling.
    func draw(into context: inout GraphicsContext, size: CGSize, ink: Color) {
        switch self {
        case .plain:
            break

        case .lines:
            drawHorizontalLines(into: &context, size: size, ink: ink)

        case .grid:
            drawHorizontalLines(into: &context, size: size, ink: ink)
            drawVerticalLines(into: &context, size: size, ink: ink)

        case .dots:
            drawDotLattice(into: &context, size: size, ink: ink)
        }
    }

    // MARK: - Private geometry helpers

    private func drawHorizontalLines(
        into context: inout GraphicsContext,
        size: CGSize,
        ink: Color
    ) {
        var y = PaperRuling.spacing
        while y < size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(ink), lineWidth: 0.5)
            y += PaperRuling.spacing
        }
    }

    private func drawVerticalLines(
        into context: inout GraphicsContext,
        size: CGSize,
        ink: Color
    ) {
        var x = PaperRuling.spacing
        while x < size.width {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(ink), lineWidth: 0.5)
            x += PaperRuling.spacing
        }
    }

    private func drawDotLattice(
        into context: inout GraphicsContext,
        size: CGSize,
        ink: Color
    ) {
        let r = PaperRuling.dotRadius
        var y = PaperRuling.spacing
        while y < size.height {
            var x = PaperRuling.spacing
            while x < size.width {
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(ink))
                x += PaperRuling.spacing
            }
            y += PaperRuling.spacing
        }
    }
}

/// A `Canvas`-based view that renders the ruling pattern for a `PaperRuling` token.
///
/// Compose this as an overlay inside `PaperSubstrate`. The `Canvas` resolves the
/// dynamic `UIColor`-backed `AdaptivePalette.rulingInk` per scheme on every draw.
struct RulingCanvas: View {
    var ruling: PaperRuling
    var ink: Color = AdaptivePalette.rulingInk

    var body: some View {
        Canvas { context, size in
            ruling.draw(into: &context, size: size, ink: ink)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
