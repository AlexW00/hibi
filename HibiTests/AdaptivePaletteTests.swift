import Testing
import SwiftUI
import UIKit
@testable import Hibi

@MainActor struct AdaptivePaletteTests {

    // MARK: - Helpers

    /// Resolve a SwiftUI Color to rounded RGB channels (×1000) for stable Hashable comparison.
    private func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> [Int] {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Int((r * 1000).rounded()), Int((g * 1000).rounded()), Int((b * 1000).rounded())]
    }

    /// Perceived luminance (sRGB approximation) of a resolved color.
    private func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }

    // MARK: - Tests

    @Test func everyTintResolvesToADistinctLightDarkPair() {
        let lightValues = PaperTint.allCases.map { rgb(AdaptivePalette.paperFill($0), .light) }
        let darkValues  = PaperTint.allCases.map { rgb(AdaptivePalette.paperFill($0), .dark) }

        // All 6 light values are distinct
        #expect(Set(lightValues).count == PaperTint.allCases.count)
        // All 6 dark values are distinct
        #expect(Set(darkValues).count == PaperTint.allCases.count)
        // Light ≠ dark for each tint
        for i in lightValues.indices {
            #expect(lightValues[i] != darkValues[i])
        }
    }

    @Test func depthDarkensMonotonicallyIncludingFractional() {
        let d0    = luminance(AdaptivePalette.paperFill(.cream, depth: 0),   .light)
        let dHalf = luminance(AdaptivePalette.paperFill(.cream, depth: 0.5), .light)
        let d1    = luminance(AdaptivePalette.paperFill(.cream, depth: 1),   .light)
        let d2    = luminance(AdaptivePalette.paperFill(.cream, depth: 2),   .light)
        // Fractional depth blends smoothly; strictly decreasing luminance
        #expect(d0 > dHalf && dHalf > d1 && d1 > d2)
    }
}
