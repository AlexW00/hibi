import XCTest

/// Drives the app through its three tabs and captures one screenshot each, for
/// `fastlane snapshot`. The app is launched with `-uiTestScreenshots`, which
/// forces **demo mode** on (curated events / reminders / weather) and skips the
/// onboarding + What's New sheets — see `DemoEnvironment`.
///
/// Tabs are tapped **by index** (Month = 0, Week = 1, Day = 2, the order in
/// `ContentView`) rather than by label, so navigation is independent of the
/// locale the run is in. The app launches on the Day tab.
///
/// Run via `scripts/screenshots.sh` (which wires up the target + simulators).
final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-uiTestScreenshots"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar never appeared")

        // The app opens on the Day tab — the hero shot. Give the paper stack and
        // schedule a beat to settle before capturing.
        sleep(3)
        snapshot("01-Day")

        // Week tab.
        tabBar.buttons.element(boundBy: 1).tap()
        sleep(2)
        snapshot("02-Week")

        // Month tab.
        tabBar.buttons.element(boundBy: 0).tap()
        sleep(2)
        snapshot("03-Month")
    }
}
