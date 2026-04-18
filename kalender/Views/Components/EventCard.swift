import SwiftUI

struct EventCard: View {
    let event: CalendarEvent

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
                .fill(event.category.tint)
                .frame(width: 4, height: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text("ALL DAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(event.category.tint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(event.category.tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(event.category.tint.opacity(0.30), lineWidth: 0.5)
        )
    }

    private var timedCard: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.tint)
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
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}
