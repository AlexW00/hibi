import Testing
import Foundation
@testable import Hibi

struct SyncStatusTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private func ago(_ s: TimeInterval) -> Date { now.addingTimeInterval(-s) }

    @Test func nilIsNever() { #expect(SyncStatus.phrase(lastSync: nil, now: now) == .never) }

    @Test func justNowUnderAMinute() {
        #expect(SyncStatus.phrase(lastSync: ago(0), now: now) == .justNow)
        #expect(SyncStatus.phrase(lastSync: ago(59), now: now) == .justNow)
    }

    @Test func negativeElapsedIsJustNow() {
        #expect(SyncStatus.phrase(lastSync: now.addingTimeInterval(120), now: now) == .justNow)
    }

    @Test func minutesBucket() {
        #expect(SyncStatus.phrase(lastSync: ago(60), now: now) == .fewMinutes)
        #expect(SyncStatus.phrase(lastSync: ago(3599), now: now) == .fewMinutes)
    }

    @Test func hoursBucket() {
        #expect(SyncStatus.phrase(lastSync: ago(3600), now: now) == .fewHours)
        #expect(SyncStatus.phrase(lastSync: ago(86_399), now: now) == .fewHours)
    }

    @Test func daysBucket() {
        #expect(SyncStatus.phrase(lastSync: ago(86_400), now: now) == .fewDays)
        #expect(SyncStatus.phrase(lastSync: ago(604_799), now: now) == .fewDays)
    }

    @Test func aWhileBucket() {
        #expect(SyncStatus.phrase(lastSync: ago(604_800), now: now) == .aWhile)
    }
}
