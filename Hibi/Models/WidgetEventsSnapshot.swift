import Foundation

/// Snapshot of today's events and reminders, written by `EventStore` to the
/// App Group and read by the Schedule widget timeline provider.
///
/// Only today's items are included — the widget never shows other days.
///
/// The `.v2` in the snapshot's `UserDefaults` key (`AppGroup.Key.eventsSnapshot`)
/// is forward-defence: if this shape ever changes, bump the key so a stale
/// blob from an old install can't crash a fresh widget. (v1 = events only,
/// v2 = adds reminders.)
struct WidgetEventsSnapshot: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    let events: [Event]
    let reminders: [Reminder]

    /// Wall-clock time of the snapshot. The provider treats the snapshot as
    /// stale (and renders the empty state) when its `(year, month, day)`
    /// doesn't match the entry's date — which happens at midnight rollovers
    /// if the app hasn't been opened since.
    let capturedAt: Date

    struct Event: Codable, Hashable, Sendable, Identifiable {
        let id: String
        let title: String
        let location: String?
        /// Absolute start. `nil` mirrors `CalendarEvent.startDate` semantics.
        let startDate: Date?
        let endDate: Date?
        let allDay: Bool
        /// Raw EKCalendar color, stored as displayP3 RGBA so the widget can
        /// re-run `Color.pastelized(cgColor:)` at render time and get an
        /// appearance-aware (light vs dark) tint matching the in-app rows.
        let tintRGB: RGBA
    }

    struct Reminder: Codable, Hashable, Sendable, Identifiable {
        let id: String
        /// The EKReminder's `calendarItemIdentifier` — what the widget's
        /// toggle-completion intent uses to look the reminder up again.
        let reminderIdentifier: String
        let title: String
        /// Resolved due date (combining due-date components with optional
        /// time). `nil` is possible for reminders without a due date, but
        /// `EventStore` filters those out before snapshotting.
        let dueDate: Date?
        let hasTime: Bool
        let isCompleted: Bool
        let isOverdue: Bool
        let isRecurring: Bool
        let tintRGB: RGBA
    }

    struct RGBA: Codable, Hashable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    /// Return a copy with the matching reminder's `isCompleted` flag toggled.
    /// Used by `ToggleReminderCompletionIntent` to update the snapshot
    /// optimistically before the host app re-syncs from EventKit.
    func togglingReminderCompletion(identifier: String) -> WidgetEventsSnapshot {
        let updated = reminders.map { reminder -> Reminder in
            guard reminder.reminderIdentifier == identifier else { return reminder }
            return Reminder(
                id: reminder.id,
                reminderIdentifier: reminder.reminderIdentifier,
                title: reminder.title,
                dueDate: reminder.dueDate,
                hasTime: reminder.hasTime,
                isCompleted: !reminder.isCompleted,
                // A completed reminder is no longer "overdue".
                isOverdue: reminder.isCompleted ? reminder.isOverdue : false,
                isRecurring: reminder.isRecurring,
                tintRGB: reminder.tintRGB
            )
        }
        return WidgetEventsSnapshot(
            year: year, month: month, day: day,
            events: events,
            reminders: updated,
            capturedAt: capturedAt
        )
    }
}
