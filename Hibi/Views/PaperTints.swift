import SwiftUI
import UIKit

/// Progressive paper tints — depth cue for the tear stack.
/// Light: white → off-white → beige (lower layers recede warmer).
/// Dark: "high-contrast stack" — front is lightest, back layers melt into
/// pure black so depth reads as recession, not illumination.
enum PaperTints {
    static let card1 = dynamic(
        light: (0.984, 0.980, 0.969),
        dark:  (0.141, 0.141, 0.141)   // #242424
    )
    static let card2 = dynamic(
        light: (0.960, 0.953, 0.938),
        dark:  (0.078, 0.078, 0.078)   // #141414
    )
    static let card3 = dynamic(
        light: (0.937, 0.929, 0.901),
        dark:  (0.000, 0.000, 0.000)   // #000000 — matches app background
    )

    /// Color used for binding-hole fill — sits on top of the paper, matches
    /// a slightly deeper tint of card3 in each appearance.
    static let bindingHole = dynamic(
        light: (0.898, 0.882, 0.839),
        dark:  (0.000, 0.000, 0.000)
    )

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(displayP3Red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension Color {
    /// Softens an EKCalendar's native color so it reads like marker ink on
    /// paper in light mode and stays visible but desaturated on the dark
    /// radial background. Returned Color responds dynamically to appearance.
    static func pastelized(cgColor: CGColor?) -> Color {
        let base = UIColor(cgColor: cgColor ?? UIColor.systemGray.cgColor)
        return Color(uiColor: UIColor { trait in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            if trait.userInterfaceStyle == .dark {
                return UIColor(
                    hue: h,
                    saturation: min(s, 0.55),
                    brightness: max(0.70, min(b, 0.85)),
                    alpha: 1
                )
            } else {
                return UIColor(
                    hue: h,
                    saturation: min(s, 0.45),
                    brightness: max(b, 0.78),
                    alpha: 1
                )
            }
        })
    }
}
