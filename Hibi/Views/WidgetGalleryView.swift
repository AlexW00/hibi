import SwiftUI
import UIKit
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

    /// Medium Events widget for the Home Screen mock: a clean three-event list
    /// (no reminders), so the tile reads as "the events widget, 3 events".
    private var homeMediumEntry: EventsEntry {
        EventsEntry(
            date: Date(),
            day: SampleData.todayDay, month: SampleData.todayMonth, year: SampleData.todayYear,
            events: DemoFixtures.widgetEvents(limit: 3),
            reminders: []
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

    /// The iOS 26 wallpaper backing the Home Screen mock (`.home`). Loaded from a
    /// loose bundle resource that is excluded from Release builds (see
    /// `Config.xcconfig` / `docs/screenshots.md`), so `nil` outside Debug — the
    /// mock then falls back to a plain backdrop rather than crashing.
    private static let wallpaper: Image? = {
        guard
            let url = Bundle.main.url(forResource: "ScreenshotWallpaper", withExtension: "jpg"),
            let ui = UIImage(contentsOfFile: url.path)
        else { return nil }
        return Image(uiImage: ui)
    }()

    var body: some View {
        ZStack {
            background

            switch kind {
            case .schedule:
                VStack(spacing: 26) {
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
                }
            case .today:
                VStack(spacing: 26) {
                    chrome(width: 170, height: 170) {
                        TodaysPageWidgetView(entry: todayEntry, familyOverride: .systemSmall)
                    }
                    chrome(width: 364, height: 382) {
                        TodaysPageWidgetView(entry: todayEntry, familyOverride: .systemLarge)
                    }
                }
            case .home:
                // Home Screen mock: big day widget (large Today's Page) above the
                // medium Events widget, on the blurred wallpaper — with real drop
                // shadows, since over an opaque wallpaper there's no green to key.
                VStack(spacing: 28) {
                    chrome(width: 364, height: 382, shadow: true) {
                        TodaysPageWidgetView(entry: todayEntry, familyOverride: .systemLarge)
                    }
                    chrome(width: 364, height: 170, shadow: true) {
                        EventsWidgetView(entry: homeMediumEntry, familyOverride: .systemMedium)
                    }
                }
            }
        }
    }

    /// Chroma-key green for `.schedule`/`.today` (keyed out later); the blurred
    /// iOS 26 wallpaper for the `.home` mock.
    @ViewBuilder
    private var background: some View {
        switch kind {
        case .schedule, .today:
            Self.chromaGreen.ignoresSafeArea()
        case .home:
            // A black base backs the slight blur's softened edges (and is the
            // whole backdrop in Release, where the wallpaper resource is absent).
            Color.black.ignoresSafeArea()
            if let wallpaper = Self.wallpaper {
                wallpaper
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 14)
                    .scaleEffect(1.08) // hide the blur's translucent edge bleed
                    .ignoresSafeArea()
            }
        }
    }

    /// Wraps a widget view in its real-size shell: paper background and rounded
    /// widget corner. `shadow` adds a soft home-screen drop shadow — opt-in,
    /// because over the chroma-key green it would leave a gray halo when keyed.
    @ViewBuilder
    private func chrome<V: View>(
        width: CGFloat, height: CGFloat, shadow: Bool = false, @ViewBuilder _ content: () -> V
    ) -> some View {
        let tile = content()
            .frame(width: width, height: height)
            .background(PaperTints.card1)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        // Shadow is opt-in: the chroma-key (`.schedule`/`.today`) path takes no
        // `.shadow` at all, so those cutouts key out exactly as before; only the
        // `.home` mock over the opaque wallpaper gets a home-screen drop shadow.
        if shadow {
            tile.shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        } else {
            tile
        }
    }
}
