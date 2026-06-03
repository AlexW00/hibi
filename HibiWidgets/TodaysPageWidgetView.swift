import SwiftUI
import WidgetKit

struct TodaysPageWidgetView: View {
    let entry: TodaysPageEntry
    /// Forces a family when hosted outside a widget (the in-app screenshot
    /// gallery) — `\.widgetFamily` is read-only. `nil` in the real widget.
    var familyOverride: WidgetFamily? = nil

    @Environment(\.widgetFamily) private var environmentFamily
    private var family: WidgetFamily { familyOverride ?? environmentFamily }

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
