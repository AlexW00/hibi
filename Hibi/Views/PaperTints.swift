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
            // Near-grey sources have no meaningful hue — getHue() returns 0
            // (red family) for pure grey, so we must not raise saturation on
            // them or grey calendars would suddenly read as red.
            let isGrey = s < 0.08
            if trait.userInterfaceStyle == .dark {
                return UIColor(
                    hue: h,
                    saturation: isGrey ? s : min(s, 0.70),
                    brightness: isGrey
                        ? max(0.55, min(b, 0.75))
                        : max(0.78, min(b, 0.90)),
                    alpha: 1
                )
            } else {
                return UIColor(
                    hue: h,
                    saturation: isGrey ? s : max(min(s, 0.65), 0.45),
                    brightness: isGrey
                        ? min(max(b, 0.45), 0.62)
                        : min(max(b, 0.58), 0.72),
                    alpha: 1
                )
            }
        })
    }
}

/// Shared app canvas — cream radial in light, near-black radial in dark.
/// Single source of truth used by `ContentView` and the onboarding sheet so
/// the sheet reads as a continuation of the app surface, not system chrome.
struct AppBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            RadialGradient(
                colors: [
                    Color(.displayP3, red: 0.102, green: 0.102, blue: 0.122),
                    Color(.displayP3, red: 0.047, green: 0.047, blue: 0.055),
                ],
                center: UnitPoint(x: 0.2, y: 0.0),
                startRadius: 0,
                endRadius: 600
            )
        } else {
            RadialGradient(
                colors: [
                    Color(.displayP3, red: 0.984, green: 0.980, blue: 0.965),
                    Color(.displayP3, red: 0.953, green: 0.945, blue: 0.918),
                    Color(.displayP3, red: 0.929, green: 0.914, blue: 0.867),
                ],
                center: UnitPoint(x: 0.15, y: -0.1),
                startRadius: 0,
                endRadius: 700
            )
        }
    }
}
