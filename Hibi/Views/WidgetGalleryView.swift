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

    /// Large Schedule widget: a full seven-row list — both today's reminders
    /// plus five events (today's three + two widget-only extras) so the tile
    /// fills cleanly without the trailing gap.
    private var scheduleLargeEntry: EventsEntry {
        EventsEntry(
            date: Date(),
            day: SampleData.todayDay, month: SampleData.todayMonth, year: SampleData.todayYear,
            events: DemoFixtures.widgetLargeScheduleEvents(),
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

    /// Chroma-key green for the widget backdrop. A device screen capture has no
    /// alpha channel, so a *transparent* background isn't possible — instead we
    /// render a pure, saturated green that's easy to key out later. It's far from
    /// the widgets' pastel mint/sea tints, so keying won't eat the content.
    private static let chromaGreen = Color(.sRGB, red: 0, green: 1, blue: 0)

    var body: some View {
        ZStack {
            Self.chromaGreen.ignoresSafeArea()

            VStack(spacing: 26) {
                switch kind {
                case .schedule:
                    chrome(width: 364, height: 170) {
                        EventsWidgetView(entry: scheduleMediumEntry, familyOverride: .systemMedium)
                    }
                    chrome(width: 364, height: 382) {
                        EventsWidgetView(
                            entry: scheduleLargeEntry,
                            familyOverride: .systemLarge,
                            fillsTallContainer: true
                        )
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
            // No drop shadow: a soft shadow over the chroma-key green would
            // leave a gray halo when the green is keyed out.
    }
}
