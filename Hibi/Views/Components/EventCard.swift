import SwiftUI

struct EventCard: View {
    let event: CalendarEvent
    /// 0 before the event starts, 1 after it ends. Ignored for all-day events.
    var progress: Double = 0

    private var fillAmount: Double {
        event.allDay ? 1 : max(0, min(1, progress))
    }

    var body: some View {
        if event.allDay {
            allDayCard
        } else {
            timedCard
        }
    }

    private var allDayCard: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.tint)
                .frame(width: 4, height: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text("ALL DAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(event.tint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(filledBackground(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(event.tint.opacity(0.30), lineWidth: 0.5)
        )
    }

    private var timedCard: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.tint)
                .frame(width: 3)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .tracking(-0.15)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(event.start ?? "")–\(event.end ?? "")")
                        .font(.system(size: 10.5, design: .monospaced))
                        .tracking(0.2)
                        .foregroundStyle(.secondary)
                    if let loc = event.location {
                        Text("·")
                            .foregroundStyle(.secondary)
                            .opacity(0.4)
                        Text(loc)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(filledBackground(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(event.tint.opacity(0.22), lineWidth: 0.5)
        )
    }

    /// Light category tint underneath, progress-driven tint on top, clipped
    /// to the card's rounded rectangle. Matches the DayEventRow styling.
    private func filledBackground(cornerRadius: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            event.tint.opacity(0.08)
            GeometryReader { geo in
                event.tint.opacity(0.22)
                    .frame(width: geo.size.width * CGFloat(fillAmount))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
