import Foundation
import Testing
@testable import Hibi

@Suite("WidgetEventsSnapshot.togglingReminderCompletion")
struct WidgetEventsSnapshotTests {

    private let tint = WidgetEventsSnapshot.RGBA(red: 1, green: 0, blue: 0, alpha: 1)

    private func reminder(
        id: String, identifier: String, completed: Bool, overdue: Bool
    ) -> WidgetEventsSnapshot.Reminder {
        WidgetEventsSnapshot.Reminder(
            id: id,
            reminderIdentifier: identifier,
            title: "Test \(id)",
            dueDate: Date(),
            hasTime: true,
            isCompleted: completed,
            isOverdue: overdue,
            isRecurring: false,
            tintRGB: tint
        )
    }

    private func snapshot(
        reminders: [WidgetEventsSnapshot.Reminder]
    ) -> WidgetEventsSnapshot {
        WidgetEventsSnapshot(
            year: 2026, month: 5, day: 27,
            events: [],
            reminders: reminders,
            capturedAt: Date()
        )
    }

    @Test func togglingIncompleteMakesComplete() {
        let snap = snapshot(reminders: [
            reminder(id: "1", identifier: "r1", completed: false, overdue: true),
        ])
        let toggled = snap.togglingReminderCompletion(identifier: "r1")
        let r = try! #require(toggled.reminders.first)
        #expect(r.isCompleted == true)
    }

    @Test func completingClearsOverdue() {
        let snap = snapshot(reminders: [
            reminder(id: "1", identifier: "r1", completed: false, overdue: true),
        ])
        let toggled = snap.togglingReminderCompletion(identifier: "r1")
        let r = try! #require(toggled.reminders.first)
        #expect(r.isOverdue == false)
    }

    @Test func uncompletingPreservesOverdue() {
        let snap = snapshot(reminders: [
            reminder(id: "1", identifier: "r1", completed: true, overdue: true),
        ])
        let toggled = snap.togglingReminderCompletion(identifier: "r1")
        let r = try! #require(toggled.reminders.first)
        #expect(r.isCompleted == false)
        #expect(r.isOverdue == true)
    }

    @Test func otherRemindersUntouched() {
        let snap = snapshot(reminders: [
            reminder(id: "1", identifier: "r1", completed: false, overdue: false),
            reminder(id: "2", identifier: "r2", completed: true, overdue: false),
        ])
        let toggled = snap.togglingReminderCompletion(identifier: "r1")
        let other = toggled.reminders.first { $0.reminderIdentifier == "r2" }!
        #expect(other.isCompleted == true)
    }

    @Test func unknownIdentifierIsNoOp() {
        let snap = snapshot(reminders: [
            reminder(id: "1", identifier: "r1", completed: false, overdue: false),
        ])
        let toggled = snap.togglingReminderCompletion(identifier: "nonexistent")
        #expect(toggled.reminders.first!.isCompleted == false)
    }

    @Test func eventsPreserved() {
        let event = WidgetEventsSnapshot.Event(
            id: "e1", title: "Meeting", location: nil,
            startDate: Date(), endDate: Date().addingTimeInterval(3600),
            allDay: false, tintRGB: tint
        )
        let snap = WidgetEventsSnapshot(
            year: 2026, month: 5, day: 27,
            events: [event],
            reminders: [reminder(id: "1", identifier: "r1", completed: false, overdue: false)],
            capturedAt: Date()
        )
        let toggled = snap.togglingReminderCompletion(identifier: "r1")
        #expect(toggled.events.count == 1)
        #expect(toggled.events.first?.id == "e1")
    }
}
