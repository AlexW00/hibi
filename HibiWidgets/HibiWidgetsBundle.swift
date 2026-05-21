import SwiftUI
import WidgetKit

@main
struct HibiWidgetsBundle: WidgetBundle {
    init() {
        // Each process has its own font namespace, so the widget extension
        // must register fonts itself even though the main app already did.
        AppFont.registerFonts()
    }

    var body: some Widget {
        TodaysPageWidget()
    }
}
