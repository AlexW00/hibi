import Foundation
import XCTest
@testable import Hibi

/// The stamp's randomness must be seeded from the purchase UUID and be stable:
/// the same UUID always yields the same seed, and the value stays inside the
/// 24-bit range the Metal shader requires.
@MainActor
final class StampSeedTests: XCTestCase {

    func testSeedIsDeterministicForSameUUID() {
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        XCTAssertEqual(StampConfig.seed(from: uuid), StampConfig.seed(from: uuid))
    }

    func testSeedStaysInFloatSafeRange() {
        for _ in 0..<1000 {
            XCTAssertLessThanOrEqual(StampConfig.seed(from: UUID()), 0x00FF_FFFF)
        }
    }

    func testDistinctUUIDsRarelyCollide() {
        var seeds = Set<UInt64>()
        for _ in 0..<200 { seeds.insert(StampConfig.seed(from: UUID())) }
        // 200 draws into a 24-bit space should almost never collide.
        XCTAssertGreaterThan(seeds.count, 195)
    }
}
