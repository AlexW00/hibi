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
            let isPlus = PlusEntitlementStore().isPlus
            EventsWidgetView(entry: entry)
                .containerBackground(PaperTints.card1, for: .widget)
                .widgetURL(URL(string: isPlus ? "hibi://today" : "hibi://plus"))
        }
        .configurationDisplayName(String(localized: "Upcoming Events"))
        .description(String(localized: "Today's events at a glance."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
