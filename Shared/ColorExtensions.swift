import SwiftUI
import UIKit

extension Color {
    func mix(with other: Color, by fraction: Double) -> Color {
        let uiSelf = UIColor(self)
        let uiOther = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiSelf.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiOther.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(fraction)
        return Color(.displayP3,
                     red:   Double(r1 + (r2 - r1) * f),
                     green: Double(g1 + (g2 - g1) * f),
                     blue:  Double(b1 + (b2 - b1) * f),
                     opacity: Double(a1 + (a2 - a1) * f))
    }

    static func pastelized(cgColor: CGColor?) -> Color {
        let base = UIColor(cgColor: cgColor ?? UIColor.systemGray.cgColor)
        return Color(uiColor: UIColor { trait in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
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

    static func fromHSB(hue: Double, saturation: Double, brightness: Double) -> Color {
        Color(uiColor: UIColor { trait in
            let isGrey = saturation < 0.08
            if trait.userInterfaceStyle == .dark {
                return UIColor(
                    hue: hue,
                    saturation: isGrey ? saturation : min(saturation, 0.70),
                    brightness: isGrey
                        ? max(0.55, min(brightness, 0.75))
                        : max(0.78, min(brightness, 0.90)),
                    alpha: 1
                )
            } else {
                return UIColor(
                    hue: hue,
                    saturation: isGrey ? saturation : max(min(saturation, 0.65), 0.45),
                    brightness: isGrey
                        ? min(max(brightness, 0.45), 0.62)
                        : min(max(brightness, 0.58), 0.72),
                    alpha: 1
                )
            }
        })
    }
}
