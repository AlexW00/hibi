import Foundation

/// Runtime flags injected by the automated-screenshot UI test
/// (`fastlane snapshot`, see `scripts/screenshots.sh`).
///
/// The UI test launches the app with `-uiTestScreenshots` so the app forces
/// **demo mode** on regardless of the persisted Settings toggle, and skips the
/// onboarding / "What's New" sheets that would otherwise cover the screen on a
/// fresh install. Demo mode is `#if DEBUG`-only, so screenshots are taken from
/// a Debug build (the Fastfile builds Debug).
enum DemoEnvironment {
    /// True when the app was launched by the screenshot UI test.
    static let isScreenshotRun: Bool =
        ProcessInfo.processInfo.arguments.contains("-uiTestScreenshots")

    /// Seeds the Day view's tear gesture at a fixed mid-swipe so the "pull to
    /// tear" interaction can be captured statically (a real drag would snap back
    /// or commit — there is no resting mid-tear state). Set only for the final
    /// Day-peek screenshot launch.
    static let dayPeekScreenshot: Bool =
        ProcessInfo.processInfo.arguments.contains("-uiTestDayPeek")

    /// Seeds the Day view collapsed (schedule expanded) so that state can be
    /// captured without dragging the separator.
    static let dayCollapsedScreenshot: Bool =
        ProcessInfo.processInfo.arguments.contains("-uiTestDayCollapsed")

    /// Which widget the in-app gallery should render for a screenshot, if any.
    /// The app shows `WidgetGalleryView` instead of `ContentView` when set.
    enum WidgetGallery {
        case schedule, today
    }

    static let widgetGallery: WidgetGallery? = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTestWidgetsSchedule") { return .schedule }
        if args.contains("-uiTestWidgetsToday") { return .today }
        return nil
    }()
}
