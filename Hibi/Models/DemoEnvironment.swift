import Foundation

/// Single source of truth for the screenshot/demo launch flags injected by the
/// UI test (`fastlane snapshot`, see `scripts/screenshots.sh`).
///
/// Two inputs:
///  - `-uiTestScreenshots` — forces demo mode on (curated events / reminders /
///    weather) and skips onboarding / What's New. Present on every screenshot
///    launch.
///  - `-uiTestScene <name>` — selects one special screen/state to capture. All
///    screenshot special-casing keys off this single enum, so it stays in one
///    place rather than sprawling into per-flag booleans.
enum DemoEnvironment {
    /// True when the app was launched by the screenshot UI test.
    static let isScreenshotRun: Bool =
        ProcessInfo.processInfo.arguments.contains("-uiTestScreenshots")

    /// A specific screen/state the screenshot run wants to capture.
    enum Scene: String {
        case dayTear         // Day view, paper torn mid-swipe
        case dayCollapsed    // Day view, schedule expanded
        case widgetsSchedule // in-app gallery: Schedule widget
        case widgetsToday    // in-app gallery: Today's Page widget
    }

    static let scene: Scene? = {
        guard let raw = argValue("-uiTestScene") else { return nil }
        return Scene(rawValue: raw)
    }()

    // MARK: - Derived flags (kept as a stable surface for call sites)

    /// Seeds the Day view's tear gesture at a fixed mid-swipe (a real drag snaps
    /// back or commits — there is no resting mid-tear state).
    static var dayPeekScreenshot: Bool { scene == .dayTear }

    /// Seeds the Day view collapsed (schedule expanded).
    static var dayCollapsedScreenshot: Bool { scene == .dayCollapsed }

    enum WidgetGallery { case schedule, today }

    /// Which widget the in-app gallery should render, if any. When set, `HibiApp`
    /// shows `WidgetGalleryView` instead of `ContentView`.
    static var widgetGallery: WidgetGallery? {
        switch scene {
        case .widgetsSchedule: return .schedule
        case .widgetsToday:    return .today
        default:               return nil
        }
    }

    /// A frozen "now" for screenshot runs: **today at 09:41**, matching the
    /// faked status-bar time fastlane sets. Event progress fills are otherwise a
    /// function of real wall-clock time, so a screenshot's "in-progress" bar
    /// would fill differently every run; freezing it here makes the Week/Day
    /// fills deterministic and identical across runs and locales. `nil` outside
    /// screenshot runs so interactive DEBUG demo mode keeps a live clock.
    static var screenshotNow: Date? {
        guard isScreenshotRun else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(
            year: SampleData.todayYear, month: SampleData.todayMonth, day: SampleData.todayDay,
            hour: 9, minute: 41
        ))
    }

    // MARK: - Helpers

    private static func argValue(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
