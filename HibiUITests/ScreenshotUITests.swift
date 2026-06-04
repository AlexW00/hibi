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
        // Snapshot adds the per-run locale args (-AppleLanguages/-AppleLocale) to
        // launchArguments; capture them as the base so each relaunch keeps the
        // locale while swapping only our screenshot flag.
        let baseArgs = app.launchArguments

        // --- Tab screenshots (one launch) ---
        app.launchArguments = baseArgs
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar never appeared")
        // Tabs in ContentView order: Month = 0, Week = 1, Day = 2.

        tabBar.buttons.element(boundBy: 0).tap()   // 1 — Month (current month)
        sleep(2)
        snapshot("01-Month")

        tabBar.buttons.element(boundBy: 1).tap()   // 2 — Week (current day)
        sleep(2)
        snapshot("02-Week")

        tabBar.buttons.element(boundBy: 2).tap()   // 3 — Day
        sleep(2)
        snapshot("03-Day")

        // The app opens on the Day tab, so the seeded Day-view states below need
        // no navigation after launch.

        // Each special state is selected by a single -uiTestScene value.

        // 4 — Day with the paper torn mid-swipe (seeded; a real drag snaps back).
        relaunch(app, args: baseArgs + ["-uiTestScene", "dayTear"])
        snapshot("04-Day-Tear")

        // 5 — Day collapsed (schedule expanded).
        relaunch(app, args: baseArgs + ["-uiTestScene", "dayCollapsed"])
        snapshot("05-Day-Collapsed")

        // 6 — Schedule widget (medium + large), rendered in-app.
        relaunch(app, args: baseArgs + ["-uiTestScene", "widgetsSchedule"])
        snapshot("06-Widget-Schedule")

        // 7 — Today's Page widget (small + large), rendered in-app.
        relaunch(app, args: baseArgs + ["-uiTestScene", "widgetsToday"])
        snapshot("07-Widget-Today")

        // 8 — Home Screen mock: big day widget over the medium Events widget on
        // the blurred iOS 26 wallpaper. A finished, directly-uploadable shot (not
        // a green-screen cutout) — see docs/screenshots.md.
        relaunch(app, args: baseArgs + ["-uiTestScene", "widgetsHome"])
        snapshot("08-Widget-Home")
    }

    @MainActor
    private func relaunch(_ app: XCUIApplication, args: [String]) {
        app.terminate()
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        sleep(3)
    }
}
