import SwiftUI
import WidgetKit

struct EventsWidget: Widget {
    let kind = "EventsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EventsWidgetConfigurationIntent.self,
            provider: EventsTimelineProvider()
        ) { entry in
            EventsWidgetView(entry: entry)
                // Matches the in-app canvas behind events (cream radial in
                // light, near-black radial in dark) — not the paper card,
                // which reads as a warm yellow against the widget's host.
                .containerBackground(for: .widget) { AppBackgroundGradient() }
                // TODO: per-event deep links (open the tapped event in-app).
                // For now any tap opens the Day tab.
                .widgetURL(URL(string: "hibi://today"))
        }
        .configurationDisplayName(String(localized: "Upcoming Events"))
        .description(String(localized: "Today's events at a glance."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
