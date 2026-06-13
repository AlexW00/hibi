import SwiftUI
import UIKit

/// Single source of truth mapping customization colour tokens → light/dark-adaptive SwiftUI `Color`s.
///
/// Depth ramp: `depth = 0` is the front/active card; higher values recede into the stack.
/// Darkening is computed **inside** the `UIColor { trait in … }` adaptive closure so that the
/// resolved colour re-evaluates on every appearance change — never snapshots a single scheme.
enum AdaptivePalette {

    // MARK: - Paper fill

    /// Returns a light/dark-adaptive fill for `tint` at a (possibly fractional) stack depth.
    ///
    /// - Parameters:
    ///   - tint: The semantic paper tint token.
    ///   - depth: Stack depth. 0 = front card; increases toward back. Fractional values are
    ///     interpolated continuously so a tear-off crossfade can pass `cardDepth − dragProgress`.
    ///
    /// - Important: Darkening is computed **inside** the UIColor adaptive closure.
    ///   The closure picks the base RGB for the current trait first, then darkens as a continuous
    ///   function of `depth`. This guarantees dark-mode adaptivity at every depth — including
    ///   during animated tears.
    static func paperFill(_ tint: PaperTint, depth: Double = 0) -> Color {
        // Base (light, dark) tuples per tint — displayP3 (R, G, B).
        // Light values from design source of truth; dark values hand-tuned toward tint hue
        // on the #242424 paper base (NOT the light value dimmed).
        let (light, dark): ((CGFloat, CGFloat, CGFloat), (CGFloat, CGFloat, CGFloat))
        switch tint {
        case .cream:
            light = (0.984, 0.980, 0.969)   // #FBFAF7
            dark  = (0.141, 0.141, 0.141)   // #242424
        case .blush:
            light = (0.965, 0.910, 0.898)   // #F6E8E5
            dark  = (0.165, 0.141, 0.133)   // #2A2422
        case .sky:
            light = (0.894, 0.925, 0.953)   // #E4ECF3
            dark  = (0.125, 0.137, 0.153)   // #202327
        case .sage:
            light = (0.906, 0.925, 0.882)   // #E7ECE1
            dark  = (0.137, 0.153, 0.133)   // #232722
        case .butter:
            light = (0.961, 0.933, 0.843)   // #F5EED7
            dark  = (0.153, 0.141, 0.125)   // #272420
        case .lilac:
            light = (0.925, 0.898, 0.945)   // #ECE5F1
            dark  = (0.145, 0.129, 0.157)   // #252128
        }

        return Color(uiColor: UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            let base = isDark ? dark : light

            if isDark {
                // Dark: lerp base → black as a function of depth.
                // t = min(1, 0.4 × depth), clamped to [0, 1].
                let t = min(1.0, max(0.0, 0.4 * depth))
                let r = base.0 * (1 - t)
                let g = base.1 * (1 - t)
                let b = base.2 * (1 - t)
                return UIColor(
                    displayP3Red: min(1, max(0, r)),
                    green: min(1, max(0, g)),
                    blue: min(1, max(0, b)),
                    alpha: 1
                )
            } else {
                // Light: scale each channel by (1 − 0.06 × depth), clamped to [0, 1].
                let factor = max(0.0, 1.0 - 0.06 * depth)
                let r = base.0 * factor
                let g = base.1 * factor
                let b = base.2 * factor
                return UIColor(
                    displayP3Red: min(1, max(0, r)),
                    green: min(1, max(0, g)),
                    blue: min(1, max(0, b)),
                    alpha: 1
                )
            }
        })
    }

    // MARK: - Ink colours

    /// Adaptive primary ink: near-black in light mode, near-white in dark mode.
    /// Used for ruling lines and later for text/widget ink.
    static var primaryInk: Color {
        Color(uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(displayP3Red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            } else {
                return UIColor(displayP3Red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
            }
        })
    }

    /// Ruling ink: hairline, low-opacity — ~9% black in light, ~10% white in dark.
    static var rulingInk: Color {
        Color(uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(displayP3Red: 1.0, green: 1.0, blue: 1.0, alpha: 0.10)
            } else {
                return UIColor(displayP3Red: 0.0, green: 0.0, blue: 0.0, alpha: 0.09)
            }
        })
    }
}
