import Foundation
import XCTest
@testable import Hibi

/// Regression tests for the WeatherStore refresh throttle (F-02, F-03).
///
/// F-02: Between requestLocation() and the location callback, both lastFetchAt
/// and inFlight are nil, so concurrent callers bypass the throttle.
/// Fix: isLocationPending flag prevents re-entry.
///
/// F-03: Failed location sets no backoff (hammers retries); successful location
/// + failed weather stamps lastFetchAt before the nil-guard (suppresses retries
/// for 30 min). Two opposite, both-wrong behaviors.
/// Fix: lastFailureAt provides short backoff; lastFetchAt moves after guard.
@MainActor
final class WeatherRefreshTests: XCTestCase {

    // MARK: - F-02: Throttle bypass via isLocationPending

    func testRefreshSetsLocationPending() {
        let store = WeatherStore()
        store._test_setAccess(true)
        XCTAssertFalse(store.isLocationPending)
        store.refresh()
        XCTAssertTrue(store.isLocationPending,
                      "refresh() must set isLocationPending to prevent re-entry during the requestLocation→callback gap")
    }

    func testRefreshBlockedWhileLocationPending() {
        let store = WeatherStore()
        store._test_setAccess(true)
        store.refresh()
        XCTAssertTrue(store.isLocationPending)
        // Simulate a second refresh — should not clear or double-fire
        let fetchAtBefore = store.lastFetchAt
        store.refresh()
        XCTAssertTrue(store.isLocationPending,
                      "Second refresh() during pending location must be a no-op")
        XCTAssertEqual(store.lastFetchAt, fetchAtBefore,
                       "Second refresh() must not change lastFetchAt")
    }

    // MARK: - F-03: Failure backoff

    func testRefreshBlockedDuringFailureBackoff() {
        let store = WeatherStore()
        store._test_setAccess(true)
        store._test_simulateLocationFailure()
        XCTAssertNotNil(store.lastFailureAt)
        // Immediately after a failure, refresh should be blocked
        store.refresh()
        XCTAssertFalse(store.isLocationPending,
                       "refresh() must respect failure backoff — should not proceed immediately after a location failure")
    }

    // MARK: - Existing throttle sanity checks

    func testRefreshBlockedWithoutAccess() {
        let store = WeatherStore()
        store._test_setAccess(false)
        store.refresh()
        XCTAssertFalse(store.isLocationPending,
                       "refresh() must not proceed without location access")
    }

    func testRefreshBlockedDuringCooldown() {
        let store = WeatherStore()
        store._test_setAccess(true)
        store._test_simulateSuccessfulFetch()
        XCTAssertNotNil(store.lastFetchAt)
        store.refresh()
        XCTAssertFalse(store.isLocationPending,
                       "refresh() must not proceed during the 30-min cooldown")
    }

    func testInitialStateAllowsRefresh() {
        let store = WeatherStore()
        store._test_setAccess(true)
        XCTAssertNil(store.lastFetchAt)
        XCTAssertNil(store.lastFailureAt)
        XCTAssertFalse(store.isLocationPending)
    }
}
