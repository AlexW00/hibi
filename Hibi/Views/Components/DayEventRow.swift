import SwiftUI

struct DayEventRow: View {
    let event: CalendarEvent
    /// 0 before the event starts, 1 after it ends, linear in between.
    /// Ignored for all-day events — those always render fully filled.
    var progress: Double = 0

    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var fillAmount: Double {
        event.allDay ? 1 : max(0, min(1, progress))
    }

    private var startText: String {
        event.startDate.map { timeFormat.string(from: $0) } ?? ""
    }

    var body: some View {
        HStack(spacing: 0) {
            // "ALL DAY" goes through LocalizedStringKey (auto-localized);
            // timed events format against the user's time-format preference.
            timeLabel(event.allDay ? Text("ALL DAY") : Text(verbatim: startText))
            Rectangle()
                .fill(event.tint.opacity(0.4))
                .frame(width: 1)
            titleBlock
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        // Two stacked backgrounds: the progress fill sits above the base tint,
        // so the row shows a subtle category color by default and darkens
        // left-to-right as the event elapses.
        .background(alignment: .leading) {
            GeometryReader { geo in
                event.tint.opacity(event.allDay ? 0.28 : 0.26)
                    .frame(width: geo.size.width * CGFloat(fillAmount))
            }
        }
        .background(event.tint.opacity(event.allDay ? 0.38 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(event.tint.opacity(0.35), lineWidth: 0.5)
        )
    }

    private func timeLabel(_ text: Text) -> some View {
        text
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(0.3)
            .foregroundStyle(event.tint.mix(with: .black, by: 0.15))
            .multilineTextAlignment(.center)
            .frame(width: 76)
            .frame(maxHeight: .infinity)
    }

    private var titleBlock: some View {
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
