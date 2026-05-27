import SwiftUI
import WidgetKit

struct TodaysPageWidget: Widget {
    let kind = "TodaysPageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysPageTimelineProvider()) { entry in
            let isPlus = PlusEntitlementStore().isPlus
            TodaysPageWidgetView(entry: entry)
                .containerBackground(PaperTints.card1, for: .widget)
                .widgetURL(URL(string: isPlus ? "hibi://today" : "hibi://plus"))
        }
        .configurationDisplayName(String(localized: "Today's Page"))
        .description(String(localized: "Today as a tear-off page."))
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}
