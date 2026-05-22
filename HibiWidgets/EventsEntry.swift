import Foundation
import WidgetKit

struct EventsEntry: TimelineEntry, Sendable {
    /// Wall-clock time at which WidgetKit should switch to this entry.
    let date: Date

    /// Calendar day this entry represents (derived from `date` in the local
    /// calendar at provider time).
    let day: Int
    let month: Int
    let year: Int

    /// Today's events, sourced from the App Group snapshot if its
    /// `(year, month, day)` matches this entry's date. Empty otherwise —
    /// which the view renders as the "Open page" empty state.
    let events: [WidgetEventsSnapshot.Event]

    /// Today's reminders (due today + overdue carry-over). Same staleness
    /// rules as `events`. Filtered by the widget's config intent before
    /// landing here — completed reminders are dropped when `upcomingOnly`
    /// is on; the whole array is dropped when `showReminders` is off.
    let reminders: [WidgetEventsSnapshot.Reminder]
}
