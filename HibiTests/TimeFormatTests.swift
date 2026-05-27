import Foundation
import Testing
@testable import Hibi

@Suite("TimeFormat.string(from:)")
struct TimeFormatTests {

    @Test func twentyFourHourFormat() {
        let f = TimeFormat.twentyFourHour.formatter
        let result = f.string(from: f.date(from: "14:30")!)
        #expect(result == "14:30")
    }

    @Test func twelveHourFormat() {
        let f = TimeFormat.twelveHour.formatter
        let result = f.string(from: f.date(from: "2:30 PM")!)
        #expect(result == "2:30 PM")
    }

    @Test func systemFormatProducesNonEmpty() {
        let result = TimeFormat.system.string(from: Date())
        #expect(!result.isEmpty)
    }

    @Test func twentyFourHourMidnight() {
        let f = TimeFormat.twentyFourHour.formatter
        let result = f.string(from: f.date(from: "00:00")!)
        #expect(result == "00:00")
    }

    @Test func twelveHourMidnight() {
        let f = TimeFormat.twelveHour.formatter
        let result = f.string(from: f.date(from: "12:00 AM")!)
        #expect(result == "12:00 AM")
    }

    @Test func twentyFourHourNoon() {
        let f = TimeFormat.twentyFourHour.formatter
        let result = f.string(from: f.date(from: "12:00")!)
        #expect(result == "12:00")
    }

    @Test func twelveHourNoon() {
        let f = TimeFormat.twelveHour.formatter
        let result = f.string(from: f.date(from: "12:00 PM")!)
        #expect(result == "12:00 PM")
    }

    @Test func twentyFourHourEndOfDay() {
        let f = TimeFormat.twentyFourHour.formatter
        let result = f.string(from: f.date(from: "23:59")!)
        #expect(result == "23:59")
    }
}
