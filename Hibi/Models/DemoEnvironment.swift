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
}
