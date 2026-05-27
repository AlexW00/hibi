import SwiftUI
import WidgetKit

struct TodaysPageWidgetView: View {
    let entry: TodaysPageEntry

    @Environment(\.widgetFamily) private var family

    private var isPlus: Bool { PlusEntitlementStore().isPlus }

    var body: some View {
        content.plusLocked(!isPlus)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemLarge:
            LargePaperView(entry: entry)
        default:
            SmallPaperView(
                day: entry.day,
                month: entry.month,
                year: entry.year,
                isToday: true
            )
        }
    }
}
