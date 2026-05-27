import Foundation
import XCTest
@testable import Hibi

/// Verifies the app-icon gating rules: exactly two icons are free (the default
/// and the early-user perk), and every other icon is behind Hibi Plus.
@MainActor
final class AppIconUnlockTests: XCTestCase {

    private func icon(_ id: String) -> AppIconOption {
        guard let option = AppIconManager.icons.first(where: { $0.id == id }) else {
            fatalError("Missing icon option: \(id)")
        }
        return option
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    func testDefaultIconIsAlwaysFree() {
        let def = icon("default")
        XCTAssertTrue(AppIconManager.isUnlocked(def, isPlus: false, installDate: nil))
        XCTAssertTrue(AppIconManager.isUnlocked(def, isPlus: true, installDate: Date()))
    }

    func testPlusIconRequiresEntitlement() {
        let disco = icon("disco-balloon")
        XCTAssertFalse(AppIconManager.isUnlocked(disco, isPlus: false, installDate: Date()))
        XCTAssertTrue(AppIconManager.isUnlocked(disco, isPlus: true, installDate: nil))
    }

    func testEarlyUserUnlockedByInstallDateNotPlus() {
        let early = icon("early-user")
        // No recorded install date → locked.
        XCTAssertFalse(AppIconManager.isUnlocked(early, isPlus: false, installDate: nil))
        // Installed before the 2026-06-01 cutoff → unlocked even without Plus.
        XCTAssertTrue(AppIconManager.isUnlocked(
            early, isPlus: false, installDate: date("2026-01-01T00:00:00Z")))
        // Installed after the cutoff → locked even *with* Plus (it's an
        // early-adopter perk, not a Plus perk).
        XCTAssertFalse(AppIconManager.isUnlocked(
            early, isPlus: true, installDate: date("2026-12-01T00:00:00Z")))
    }

    func testExactlyTwoIconsAreFreeOfPlus() {
        var alwaysCount = 0
        var beforeDateCount = 0
        var plusCount = 0
        for option in AppIconManager.icons {
            switch option.unlock {
            case .always: alwaysCount += 1
            case .beforeDate: beforeDateCount += 1
            case .plus: plusCount += 1
            }
        }
        XCTAssertEqual(alwaysCount, 1, "Exactly one always-free icon (Default)")
        XCTAssertEqual(beforeDateCount, 1, "Exactly one early-user icon")
        XCTAssertEqual(plusCount, 6, "The remaining six icons are Plus-gated")
    }

    func testAllPlusIconsTrackEntitlement() {
        for option in AppIconManager.icons {
            guard case .plus = option.unlock else { continue }
            XCTAssertFalse(
                AppIconManager.isUnlocked(option, isPlus: false, installDate: Date()),
                "\(option.id) must be locked without Plus")
            XCTAssertTrue(
                AppIconManager.isUnlocked(option, isPlus: true, installDate: Date()),
                "\(option.id) must unlock with Plus")
        }
    }
}
