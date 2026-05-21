import Foundation

/// Snapshot of today's events, written by `EventStore` to the App Group
/// and read by the Schedule widget timeline provider.
///
/// Only today's events are included — the widget never shows other days.
///
/// The `.v1` in the snapshot's `UserDefaults` key (`AppGroup.Key.eventsSnapshot`)
/// is forward-defence: if this shape ever changes, bump the key so a stale
/// blob from an old install can't crash a fresh widget.
struct WidgetEventsSnapshot: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    let events: [Event]

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

    struct RGBA: Codable, Hashable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }
}
