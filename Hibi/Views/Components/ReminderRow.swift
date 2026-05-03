import SwiftUI

struct ReminderRow: View {
    let reminder: CalendarReminder
    let onToggle: () -> Void

    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    var body: some View {
        HStack(spacing: 0) {
            checkboxArea
            Rectangle()
                .fill(reminder.tint.opacity(0.4))
                .frame(width: 1)
            titleBlock
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        .background(reminder.tint.opacity(reminder.isCompleted ? 0.38 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(reminder.tint.opacity(0.35), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.3), value: reminder.isCompleted)
        .sensoryFeedback(reminder.isCompleted ? .success : .selection, trigger: reminder.isCompleted)
    }

    private var checkboxArea: some View {
        Button(action: onToggle) {
            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(reminder.tint.mix(with: .black, by: 0.1))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .frame(width: 76)
        .frame(maxHeight: .infinity)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(reminder.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .tracking(-0.15)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                if reminder.isRecurring {
                    RecurringGlyph()
                }
            }
            if reminder.hasTime || reminder.isOverdue {
                HStack(spacing: 6) {
                    if reminder.hasTime, let due = reminder.dueDate {
                        Text(verbatim: timeFormat.string(from: due))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if reminder.isOverdue {
                        Text("Overdue")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .opacity(reminder.isCompleted ? 0 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
