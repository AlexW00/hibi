import SwiftUI
import WidgetKit

@main
struct HibiWidgets: WidgetBundle {
    var body: some Widget {
        DayWidget()
        DayEventsWidget()
        EventsWidget()
    }
}
