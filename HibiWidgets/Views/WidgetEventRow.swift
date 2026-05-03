import SwiftUI

struct WidgetEventRow: View {
    let event: WidgetEvent
    let timeFormatRaw: String

    private var tintColor: Color {
        Color.fromHSB(
            hue: event.tintHue,
            saturation: event.tintSaturation,
            brightness: event.tintBrightness
        )
    }

    private var timeText: String {
        if event.allDay { return "ALL DAY" }
        guard let start = event.startDate else { return "" }
        let formatter = DateFormatter()
        if timeFormatRaw == "h24" {
            formatter.dateFormat = "HH:mm"
        } else if timeFormatRaw == "h12" {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.timeStyle = .short
        }
        return formatter.string(from: start)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(event.allDay ? "ALL DAY" : timeText)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.2)
                .foregroundStyle(tintColor.mix(with: .black, by: 0.15))
                .multilineTextAlignment(.center)
                .frame(width: 52)
                .frame(maxHeight: .infinity)

            Rectangle()
                .fill(tintColor.opacity(0.4))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let loc = event.location {
                    Text(loc)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .background(tintColor.opacity(event.allDay ? 0.38 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tintColor.opacity(0.35), lineWidth: 0.5)
        )
    }
}
