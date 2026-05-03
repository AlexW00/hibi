import SwiftUI
import WidgetKit

struct EventsWidget: Widget {
    let kind = "EventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventsTimelineProvider()) { entry in
            EventsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AppBackgroundGradient()
                }
        }
        .configurationDisplayName("Events")
        .description("Today's upcoming events.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
