import SwiftUI
import WidgetKit

/// Screenshot-only screen that renders the home-screen widgets *inside* the app
/// so `fastlane snapshot` can capture them (XCUITest can't screenshot real
/// SpringBoard widgets). Shown as the app root in place of `ContentView` when
/// launched with `-uiTestScene widgetsSchedule` / `widgetsToday` (see
/// `DemoEnvironment.widgetGallery` and `HibiApp`).
///
/// Each widget view is hosted at its real point size on the paper background
/// the widget config supplies via `.containerBackground` (which only applies in
/// a real widget, so we add it here), with the family forced through
/// `familyOverride`.
struct WidgetGalleryView: View {
    let kind: DemoEnvironment.WidgetGallery

    /// Medium Schedule widget: 1 (pleasant) reminder + 2 events = 3 items, so it
    /// fills cleanly without spilling into the >3 peek/fade state.
    private var scheduleMediumEntry: EventsEntry {
        EventsEntry(
            date: Date(),
            day: SampleData.todayDay, month: SampleData.todayMonth, year: SampleData.todayYear,
            events: DemoFixtures.widgetEvents(limit: 2),
            reminders: DemoFixtures.widgetReminders(limit: 1, pleasantOnly: true)
        )
    }

    /// Large Schedule widget: a fuller list (all reminders + three events).
    private var scheduleLargeEntry: EventsEntry {
        EventsEntry(
            date: Date(),
            day: SampleData.todayDay, month: SampleData.todayMonth, year: SampleData.todayYear,
            events: DemoFixtures.widgetEvents(limit: 3),
            reminders: DemoFixtures.widgetReminders()
        )
    }

    private var todayEntry: TodaysPageEntry {
        TodaysPageEntry(
            date: Date(),
            day: SampleData.todayDay, month: SampleData.todayMonth, year: SampleData.todayYear,
            snapshot: DemoFixtures.widgetWeatherSnapshot(),
            daysSinceCapture: 0
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient().ignoresSafeArea()

            VStack(spacing: 26) {
                switch kind {
                case .schedule:
                    chrome(width: 364, height: 170) {
                        EventsWidgetView(entry: scheduleMediumEntry, familyOverride: .systemMedium)
                    }
                    chrome(width: 364, height: 382) {
                        EventsWidgetView(entry: scheduleLargeEntry, familyOverride: .systemLarge)
                    }
                case .today:
                    chrome(width: 170, height: 170) {
                        TodaysPageWidgetView(entry: todayEntry, familyOverride: .systemSmall)
                    }
                    chrome(width: 364, height: 382) {
                        TodaysPageWidgetView(entry: todayEntry, familyOverride: .systemLarge)
                    }
                }
            }
        }
    }

    /// Wraps a widget view in its real-size shell: paper background, rounded
    /// widget corner, and a soft drop shadow so it reads as a home-screen tile.
    @ViewBuilder
    private func chrome<V: View>(
        width: CGFloat, height: CGFloat, @ViewBuilder _ content: () -> V
    ) -> some View {
        content()
            .frame(width: width, height: height)
            .background(PaperTints.card1)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
    }
}
