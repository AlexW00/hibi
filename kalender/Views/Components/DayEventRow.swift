import SwiftUI

struct DayEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 0) {
            Text(event.allDay ? "ALL DAY" : (event.start ?? ""))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(event.category.tint.mix(with: .black, by: 0.15))
                .multilineTextAlignment(.center)
                .frame(width: 76)
                .frame(maxHeight: .infinity)
                .background(event.category.tint.opacity(0.22))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(event.category.tint.opacity(0.25))
                        .frame(width: 0.5)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .tracking(-0.15)
                    .foregroundStyle(.primary)
                if let loc = event.location {
                    Text(loc)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        .background(event.category.tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(event.category.tint.opacity(0.22), lineWidth: 0.5)
        )
    }
}

extension Color {
    func mix(with other: Color, by fraction: Double) -> Color {
        #if canImport(UIKit)
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
        #else
        return self
        #endif
    }
}
