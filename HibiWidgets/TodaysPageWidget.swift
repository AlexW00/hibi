import SwiftUI
import WidgetKit

struct TodaysPageWidget: Widget {
    let kind = "TodaysPageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysPageTimelineProvider()) { entry in
            TodaysPageWidgetView(entry: entry)
                .containerBackground(PaperTints.card1, for: .widget)
                .widgetURL(URL(string: "hibi://today"))
        }
        .configurationDisplayName(String(localized: "Today's Page"))
        .description(String(localized: "Today as a tear-off page."))
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}
