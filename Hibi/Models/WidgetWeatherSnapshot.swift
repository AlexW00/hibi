import Foundation

/// Snapshot of today's weather, written by `WeatherStore` to the App Group
/// and read by the Today's Page widget timeline provider.
///
/// Only today's forecast is included — the widget never shows other days.
/// `WeatherCode` is already `RawRepresentable: String`, so it Codables for
/// free.
///
/// The `.v1` in the snapshot's `UserDefaults` key (`AppGroup.Key.snapshot`)
/// is forward-defence: if this shape ever changes, bump the key so a stale
/// blob from an old install can't crash a fresh widget.
struct WidgetWeatherSnapshot: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// Celsius. Display layer converts to the user's chosen unit.
    let high: Double
    /// Celsius.
    let low: Double

    let code: WeatherCode
    let sunrise: Date?
    let sunset: Date?

    let locationName: String?

    /// Wall-clock time of the fetch that produced this snapshot. Used by the
    /// widget to decide when to surface "Open Hibi to update" (after 3+ days
    /// of no successful fetch).
    let capturedAt: Date
}
