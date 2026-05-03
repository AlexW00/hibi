import EventKit
import SwiftUI

/// Lists every event calendar known to EventKit grouped by account source
/// (iCloud, Google, Subscriptions, Birthdays, …). Each row is a toggle that
/// controls whether events from that calendar appear in the app.
struct CalendarSelectionView: View {
    @Environment(EventStore.self) private var eventStore

    var body: some View {
        Group {
            if eventStore.hasCalendarAccess || eventStore.isDemoMode {
                content
            } else {
                CalendarAccessPrompt(isDenied: eventStore.calendarAccessDenied) {
                    Task { await eventStore.requestAccess() }
                }
            }
        }
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        let calendarGroups = grouped(eventStore.allCalendars())
        let reminderGroups = grouped(eventStore.allReminderLists())
        if calendarGroups.isEmpty && reminderGroups.isEmpty {
            ContentUnavailableView(
                "No calendars",
                systemImage: "calendar",
                description: Text("No event calendars are configured on this device.")
            )
        } else {
            List {
                ForEach(calendarGroups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.calendars, id: \.calendarIdentifier) { cal in
                            CalendarRow(calendar: cal)
                        }
                    }
                }
                if !reminderGroups.isEmpty {
                    ForEach(reminderGroups, id: \.title) { group in
                        Section("Reminders — \(group.title)") {
                            ForEach(group.calendars, id: \.calendarIdentifier) { cal in
                                CalendarRow(calendar: cal)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private struct CalendarGroup {
        let title: String
        let calendars: [EKCalendar]
    }

    private func grouped(_ calendars: [EKCalendar]) -> [CalendarGroup] {
        let bySource = Dictionary(grouping: calendars) { $0.source.title }
        return bySource
            .map { CalendarGroup(title: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
            .sorted { lhs, rhs in
                sourceRank(lhs.title) < sourceRank(rhs.title)
                    || (sourceRank(lhs.title) == sourceRank(rhs.title) && lhs.title < rhs.title)
            }
    }

    /// Accounts first (iCloud/Google/Exchange), then subscriptions, then
    /// system sources like Birthdays last.
    private func sourceRank(_ title: String) -> Int {
        let lower = title.lowercased()
        if lower.contains("birthday") { return 3 }
        if lower.contains("subscri")  { return 2 }
        if lower.contains("holiday")  { return 2 }
        return 1
    }
}

private struct CalendarRow: View {
    @Environment(EventStore.self) private var eventStore
    let calendar: EKCalendar

    var body: some View {
        let isHidden = eventStore.isHidden(calendar)
        Toggle(isOn: Binding(
            get: { !isHidden },
            set: { eventStore.setCalendar(calendar, hidden: !$0) }
        )) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(uiColor: UIColor(cgColor: calendar.cgColor ?? UIColor.systemGray.cgColor)))
                    .frame(width: 10, height: 10)
                Text(calendar.title)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
            }
        }
        .tint(.green)
    }
}
