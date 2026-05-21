import AppIntents
import WidgetKit

/// User-configurable knobs for the Upcoming Events widget.
///
/// Exposed via long-press → Edit Widget on the home screen. The view doesn't
/// see this directly; the timeline provider applies the filter when building
/// each entry so views stay dumb.
struct EventsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Upcoming Events"

    /// All-day events have no progress and tend to dominate the small widget
    /// when shown. Default on — most users want them visible — but offer a
    /// toggle for people whose calendars are dominated by birthdays or
    /// long-running travel blocks.
    @Parameter(title: "Show all-day events", default: true)
    var showAllDay: Bool
}
