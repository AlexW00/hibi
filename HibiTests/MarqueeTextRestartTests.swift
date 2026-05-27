import Foundation
import XCTest
@testable import Hibi

/// Regression test for MarqueeText restart on text change (F-13).
///
/// When swapping between two overflowing strings, the `overflows` computed
/// property stays `true` (so .onChange(of: overflows) doesn't fire), but the
/// text width changes. Without a .onChange(of: textWidth) trigger, the
/// animation continues scrolling by the stale first string's width.
///
/// This test verifies the MarqueeText.shouldRestart logic:
/// if overflows is true AND textWidth changed, animation must restart.
@MainActor
final class MarqueeTextRestartTests: XCTestCase {

    func testShouldRestartReturnsTrueWhenWidthChangesWhileOverflowing() {
        XCTAssertTrue(
            MarqueeText.shouldRestart(
                overflows: true,
                oldTextWidth: 200,
                newTextWidth: 250
            ),
            "Must restart animation when text width changes while overflowing"
        )
    }

    func testShouldRestartReturnsFalseWhenNotOverflowing() {
        XCTAssertFalse(
            MarqueeText.shouldRestart(
                overflows: false,
                oldTextWidth: 200,
                newTextWidth: 250
            ),
            "No restart needed when text doesn't overflow"
        )
    }

    func testShouldRestartReturnsFalseWhenWidthUnchanged() {
        XCTAssertFalse(
            MarqueeText.shouldRestart(
                overflows: true,
                oldTextWidth: 200,
                newTextWidth: 200
            ),
            "No restart needed when width hasn't changed"
        )
    }
}
