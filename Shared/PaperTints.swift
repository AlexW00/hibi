import SwiftUI
import UIKit

enum PaperTints {
    static let card1 = dynamic(
        light: (0.984, 0.980, 0.969),
        dark:  (0.141, 0.141, 0.141)
    )
    static let card2 = dynamic(
        light: (0.960, 0.953, 0.938),
        dark:  (0.078, 0.078, 0.078)
    )
    static let card3 = dynamic(
        light: (0.937, 0.929, 0.901),
        dark:  (0.000, 0.000, 0.000)
    )

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
