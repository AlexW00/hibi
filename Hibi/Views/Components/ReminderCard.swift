import SwiftUI

struct ReminderCard: View {
    let reminder: CalendarReminder
    let onToggle: () -> Void

    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(reminder.tint.mix(with: .black, by: 0.1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(reminder.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(reminder.isCompleted)
                        .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    if reminder.isRecurring {
                        RecurringGlyph()
                    }
                }
                HStack(spacing: 6) {
                    if reminder.hasTime, let due = reminder.dueDate {
                        Text(verbatim: timeFormat.string(from: due))
                            .font(.system(size: 10.5, design: .monospaced))
                            .tracking(0.2)
                            .foregroundStyle(.secondary)
                    }
                    if reminder.isOverdue {
                        Text("Overdue")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            reminder.tint.opacity(reminder.isCompleted ? 0.06 : 0.38)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(reminder.tint.opacity(0.35), lineWidth: 0.5)
        )
        .opacity(reminder.isCompleted ? 0.6 : 1)
    }
}
