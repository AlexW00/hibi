import Foundation
import SwiftUI
import Testing
@testable import Hibi

@Suite("CalendarEvent.progress(at:)")
struct CalendarEventProgressTests {

    private func event(
        start: Date, end: Date, allDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            day: 1,
            startDate: start,
            endDate: end,
            title: "Test",
            tint: .clear,
            allDay: allDay
        )
    }

    private let ref = Date(timeIntervalSinceReferenceDate: 700_000)

    // MARK: - Basic linear interpolation

    @Test func beforeStartReturnsZero() {
        let e = event(start: ref, end: ref.addingTimeInterval(3600))
        #expect(e.progress(at: ref.addingTimeInterval(-1)) == 0)
    }

    @Test func atStartReturnsZero() {
        let e = event(start: ref, end: ref.addingTimeInterval(3600))
        #expect(e.progress(at: ref) == 0)
    }

    @Test func afterEndReturnsOne() {
        let e = event(start: ref, end: ref.addingTimeInterval(3600))
        #expect(e.progress(at: ref.addingTimeInterval(3601)) == 1)
    }

    @Test func atEndReturnsOne() {
        let e = event(start: ref, end: ref.addingTimeInterval(3600))
        #expect(e.progress(at: ref.addingTimeInterval(3600)) == 1)
    }

    @Test func midpointReturnsHalf() {
        let e = event(start: ref, end: ref.addingTimeInterval(3600))
        let p = e.progress(at: ref.addingTimeInterval(1800))
        #expect(abs(p - 0.5) < 1e-9)
    }

    @Test func quarterProgress() {
        let e = event(start: ref, end: ref.addingTimeInterval(1000))
        let p = e.progress(at: ref.addingTimeInterval(250))
        #expect(abs(p - 0.25) < 1e-9)
    }

    // MARK: - Edge cases

    @Test func allDayReturnsZero() {
        let e = event(start: ref, end: ref.addingTimeInterval(86400), allDay: true)
        #expect(e.progress(at: ref.addingTimeInterval(43200)) == 0)
    }

    @Test func zeroDurationReturnsZero() {
        let e = event(start: ref, end: ref)
        #expect(e.progress(at: ref) == 0)
    }

    @Test func negativeDurationReturnsZero() {
        let e = event(start: ref, end: ref.addingTimeInterval(-100))
        #expect(e.progress(at: ref) == 0)
    }

    @Test func nilDatesReturnZero() {
        let e = CalendarEvent(
            day: 1, startDate: nil, endDate: nil,
            title: "No dates", tint: .clear
        )
        #expect(e.progress(at: ref) == 0)
    }

    // MARK: - Demo anchor branch

    @Test func demoAnchorUsesTimeOfDay() {
        let e = event(start: ref, end: ref.addingTimeInterval(7200))
        let p = e.progress(
            at: ref.addingTimeInterval(3600),
            useDemoTimeOfDay: true,
            listYear: SampleData.demoAnchorYear,
            listMonth: SampleData.demoAnchorMonth,
            listDay: SampleData.demoAnchorDay
        )
        #expect(p >= 0)
        #expect(p <= 1)
    }

    @Test func nonDemoAnchorIgnoresFlag() {
        let e = event(start: ref, end: ref.addingTimeInterval(3600))
        let withFlag = e.progress(
            at: ref.addingTimeInterval(1800),
            useDemoTimeOfDay: true,
            listYear: 1999, listMonth: 1, listDay: 1
        )
        let without = e.progress(at: ref.addingTimeInterval(1800))
        #expect(abs(withFlag - without) < 1e-9)
    }
}
