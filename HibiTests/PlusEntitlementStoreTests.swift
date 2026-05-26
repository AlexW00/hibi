import Foundation
import XCTest
@testable import Hibi

/// Verifies the App-Group-backed entitlement mirror that `PlusStore` writes to
/// and the widget reads from. Uses isolated `UserDefaults` suites so tests
/// never touch the real shared store.
@MainActor
final class PlusEntitlementStoreTests: XCTestCase {

    /// A clean, uniquely-named suite per test (keyed off the calling method) so
    /// cases stay independent without a shared `setUp`/`tearDown`.
    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "com.weichart.hibi.tests.\(name)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    func testDefaultsToNotPlus() {
        let store = PlusEntitlementStore(defaults: freshDefaults())
        XCTAssertFalse(store.isPlus)
        XCTAssertNil(store.purchaseDate)
    }

    func testPersistsEntitlementAcrossInstances() {
        let defaults = freshDefaults()
        PlusEntitlementStore(defaults: defaults).setIsPlus(true)
        XCTAssertTrue(PlusEntitlementStore(defaults: defaults).isPlus)

        PlusEntitlementStore(defaults: defaults).setIsPlus(false)
        XCTAssertFalse(PlusEntitlementStore(defaults: defaults).isPlus)
    }

    func testPersistsAndClearsPurchaseDate() {
        let defaults = freshDefaults()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        PlusEntitlementStore(defaults: defaults).setPurchaseDate(date)
        XCTAssertEqual(PlusEntitlementStore(defaults: defaults).purchaseDate, date)

        PlusEntitlementStore(defaults: defaults).setPurchaseDate(nil)
        XCTAssertNil(PlusEntitlementStore(defaults: defaults).purchaseDate)
    }

    func testNilDefaultsIsSafe() {
        let store = PlusEntitlementStore(defaults: nil)
        XCTAssertFalse(store.isPlus)
        store.setIsPlus(true)            // must not crash
        store.setPurchaseDate(Date())    // must not crash
        XCTAssertFalse(store.isPlus)
        XCTAssertNil(store.purchaseDate)
    }

    func testProductIdentifierContract() {
        // The product ID must match App Store Connect and Hibi.storekit.
        XCTAssertEqual(PlusProduct.id, "com.weichart.hibi.plus")
    }
}
