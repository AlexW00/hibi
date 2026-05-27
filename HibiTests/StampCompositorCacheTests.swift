import Foundation
import XCTest
@testable import Hibi

/// Regression test for stamp disk cache atomicity (F-09).
///
/// Two detached generators racing the same cache path could produce a torn PNG
/// if the write isn't atomic. This test verifies that a written composite can
/// be read back as a valid image.
@MainActor
final class StampCompositorCacheTests: XCTestCase {

    func testWrittenCompositeCanBeReadBack() {
        guard let def = StampConfig.definition(for: 42) else {
            XCTFail("No stamp definitions available")
            return
        }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let outputSize: CGFloat = 64
        let scale: CGFloat = 2

        // Generate a composite (writes to both memory and disk cache)
        guard let image = StampCompositor.composite(
            definition: def, date: date, outputSize: outputSize, scale: scale
        ) else {
            XCTFail("Composite generation returned nil")
            return
        }
        XCTAssertGreaterThan(image.width, 0)

        // Clear memory cache so the next lookup hits disk
        StampCompositor._test_clearMemoryCache()

        // Read back from disk — should succeed if the write was valid
        let cached = StampCompositor.cachedComposite(
            definition: def, date: date, outputSize: outputSize, scale: scale
        )
        XCTAssertNotNil(cached,
                        "Disk-cached composite must be readable — a torn write would produce nil here")
        XCTAssertEqual(cached?.width, image.width)
        XCTAssertEqual(cached?.height, image.height)
    }
}
