import SwiftUI

struct ReminderCard: View {
    let reminder: CalendarReminder
    let onToggle: () -> Void

    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var hasSubtitle: Bool {
        reminder.hasTime || reminder.isOverdue
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(reminder.tint.mix(with: .black, by: 0.1))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            ZStack(alignment: .leading) {
                // Completed: title only, vertically centered
                HStack(spacing: 5) {
                    Text(reminder.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(true)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if reminder.isRecurring {
                        RecurringGlyph()
                    }
                }
                .opacity(reminder.isCompleted ? 1 : 0)

                // Uncompleted: title + subtitle stacked
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(reminder.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if reminder.isRecurring {
                            RecurringGlyph()
                        }
                    }
                    if hasSubtitle {
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
                }
                .opacity(reminder.isCompleted ? 0 : 1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            reminder.tint.opacity(reminder.isCompleted ? 0.38 : 0.10)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(reminder.tint.opacity(0.35), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.3), value: reminder.isCompleted)
        .sensoryFeedback(reminder.isCompleted ? .success : .selection, trigger: reminder.isCompleted)
    }
}
