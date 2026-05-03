import SwiftUI
import WidgetKit

struct DayEventsWidget: Widget {
    let kind = "DayEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventsTimelineProvider()) { entry in
            DayEventsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AppBackgroundGradient()
                }
        }
        .configurationDisplayName("Day + Events")
        .description("Today's date and upcoming events.")
        .supportedFamilies([.systemMedium])
    }
}
