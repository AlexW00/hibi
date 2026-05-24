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
                // Paper canvas — matches the Today's Page widget so the two
                // widgets read as a set. In dark mode, the radial app
                // gradient only sampled its outer (near-black) ring at
                // widget dimensions, which crushed the pill tints; the flat
                // card1 surface (cream / #242424) gives the pastel tints
                // enough contrast to read.
                .containerBackground(PaperTints.card1, for: .widget)
                // Per-event `Link` zones inside the view override this
                // widget-wide URL for taps that land on a pill. Anything
                // else — empty state, reminder body, gaps between pills —
                // falls through to opening the Day tab.
                .widgetURL(URL(string: "hibi://today"))
        }
        .configurationDisplayName(String(localized: "Upcoming Events"))
        .description(String(localized: "Today's events at a glance."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
