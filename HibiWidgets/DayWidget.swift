import SwiftUI
import WidgetKit

struct DayWidget: Widget {
    let kind = "DayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayTimelineProvider()) { entry in
            DayWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Day")
        .description("Today's date at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
