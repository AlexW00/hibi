import Foundation
import Testing
@testable import Hibi

@Suite("SampleData calendar math")
struct SampleDataTests {

    // MARK: - daysInMonth

    @Test func feb2024LeapYear() {
        #expect(SampleData.daysInMonth(year: 2024, month: 2) == 29)
    }

    @Test func feb2026NonLeapYear() {
        #expect(SampleData.daysInMonth(year: 2026, month: 2) == 28)
    }

    @Test(arguments: [
        (2026, 1, 31), (2026, 3, 31), (2026, 4, 30),
        (2026, 5, 31), (2026, 6, 30), (2026, 7, 31),
        (2026, 8, 31), (2026, 9, 30), (2026, 10, 31),
        (2026, 11, 30), (2026, 12, 31),
    ])
    func monthLengths(year: Int, month: Int, expected: Int) {
        #expect(SampleData.daysInMonth(year: year, month: month) == expected)
    }

    // MARK: - weekday

    @Test func knownWeekday() {
        // 2026-01-01 is a Thursday. Calendar.weekday: 1=Sun, so Thu=5.
        // SampleData.weekday subtracts 1 → 4.
        #expect(SampleData.weekday(year: 2026, month: 1, day: 1) == 4)
    }

    @Test func sundayWeekday() {
        // 2026-01-04 is a Sunday → weekday 0
        #expect(SampleData.weekday(year: 2026, month: 1, day: 4) == 0)
    }

    @Test func saturdayWeekday() {
        // 2026-01-03 is a Saturday → weekday 6
        #expect(SampleData.weekday(year: 2026, month: 1, day: 3) == 6)
    }

    // MARK: - isDemoAnchor

    @Test func demoAnchorMatchesConstants() {
        #expect(SampleData.isDemoAnchor(
            year: SampleData.demoAnchorYear,
            month: SampleData.demoAnchorMonth,
            day: SampleData.demoAnchorDay
        ))
    }

    @Test func nonAnchorReturnsFalse() {
        #expect(!SampleData.isDemoAnchor(year: 1999, month: 1, day: 1))
    }
}
