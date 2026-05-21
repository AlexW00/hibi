import Foundation
import WidgetKit

struct TodaysPageEntry: TimelineEntry, Sendable {
    /// Wall-clock time at which WidgetKit should switch to this entry.
    /// Each entry represents "today" at its own `date`.
    let date: Date

    /// Calendar day this entry represents (derived from `date` in the local
    /// calendar at provider time). Carrying it on the entry avoids any
    /// re-derivation in the view body.
    let day: Int
    let month: Int
    let year: Int

    /// Cached weather forecast for this entry's date, if present in the
    /// App Group store AND its `(year, month, day)` matches this entry's
    /// date. `nil` otherwise.
    let snapshot: WidgetWeatherSnapshot?

    /// Whole days between the snapshot's `capturedAt` and this entry's
    /// `date`, in the local calendar. `nil` if no snapshot exists yet.
    /// Used by the large body to decide when to show the "Open Hibi to
    /// update" stale hint (≥ 3 days).
    let daysSinceCapture: Int?
}
