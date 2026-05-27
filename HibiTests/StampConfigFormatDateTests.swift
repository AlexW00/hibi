import Foundation
import Testing
@testable import Hibi

@Suite("StampConfig.formatDate Japanese era")
struct StampConfigFormatDateTests {

    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func allTokensSubstituted() {
        let d = date(year: 2026, month: 4, day: 18)
        let result = StampConfig.formatDate(d, format: "{era}{year}年{month}月{day}日")
        #expect(!result.contains("{era}"))
        #expect(!result.contains("{year}"))
        #expect(!result.contains("{month}"))
        #expect(!result.contains("{day}"))
    }

    @Test func reiwaEraForRecentDate() {
        let d = date(year: 2026, month: 1, day: 1)
        let result = StampConfig.formatDate(d, format: "{era}")
        #expect(result == "令和")
    }

    @Test func correctDayAndMonth() {
        let d = date(year: 2026, month: 4, day: 18)
        let result = StampConfig.formatDate(d, format: "{month}月{day}日")
        #expect(result == "4月18日")
    }

    @Test func reiwaYearIsCorrect() {
        let d = date(year: 2026, month: 1, day: 1)
        let result = StampConfig.formatDate(d, format: "{year}")
        // 2026 = Reiwa 8
        #expect(result == "8")
    }

    @Test func reiwaBoundary() {
        // Reiwa started 2019-05-01
        let d = date(year: 2019, month: 5, day: 1)
        let result = StampConfig.formatDate(d, format: "{era}{year}")
        #expect(result == "令和1")
    }

    @Test func heiseiEraBeforeReiwa() {
        // 2019-04-30 was last day of Heisei
        let d = date(year: 2019, month: 4, day: 30)
        let result = StampConfig.formatDate(d, format: "{era}")
        #expect(result == "平成")
    }

    @Test func plainTextPassedThrough() {
        let d = date(year: 2026, month: 1, day: 1)
        let result = StampConfig.formatDate(d, format: "Hello World")
        #expect(result == "Hello World")
    }

    @Test func emptyFormatReturnsEmpty() {
        let d = date(year: 2026, month: 1, day: 1)
        #expect(StampConfig.formatDate(d, format: "") == "")
    }
}
