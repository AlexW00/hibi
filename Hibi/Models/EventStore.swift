import CalendarPermission
import EventKit
import Foundation
import Observation
import PermissionsKit
import SwiftUI

@MainActor
@Observable
final class EventStore {
    let ekStore = EKEventStore()
    private(set) var hasCalendarAccess: Bool
    private(set) var calendarAccessDenied: Bool
    private(set) var hasReminderAccess: Bool
    private(set) var reminderAccessDenied: Bool
    /// Debug demo mode: fixture data only, persisted. Release UI toggle is `#if DEBUG` only.
    private(set) var isDemoMode: Bool
    private(set) var eventsByMonth: [MonthKey: [Int: [CalendarEvent]]] = [:]
    private(set) var remindersByMonth: [MonthKey: [Int: [CalendarReminder]]] = [:]
    private(set) var hiddenCalendarIDs: Set<String>
    private var loadedMonths: Set<MonthKey> = []
    private var loadedReminderMonths: Set<MonthKey> = []
    @ObservationIgnored nonisolated(unsafe) private var observerToken: NSObjectProtocol?

    private static let hiddenIDsDefaultsKey = "hiddenCalendarIDs"
    private static let demoModeDefaultsKey = "demoMode"

    /// Month/stream/day views use this instead of checking access alone so demo works without EventKit.
    var showsCalendarContent: Bool {
        isDemoMode || hasCalendarAccess
    }

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .autoupdatingCurrent
        return c
    }()

    init() {
        let permission = Permission.calendar(access: .full)
        self.hasCalendarAccess = permission.authorized
        self.calendarAccessDenied = permission.denied
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        self.hasReminderAccess = reminderStatus == .fullAccess
        self.reminderAccessDenied = reminderStatus == .denied
        #if DEBUG
        self.isDemoMode = UserDefaults.standard.bool(forKey: Self.demoModeDefaultsKey)
        #else
        self.isDemoMode = false
        #endif
        self.hiddenCalendarIDs = Set(
            UserDefaults.standard.stringArray(forKey: Self.hiddenIDsDefaultsKey) ?? []
        )
        if isDemoMode {
            applyDemoFixtures()
        }
        observerToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: ekStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccessStatus()
                self?.reloadAll()
            }
        }
    }

    private func refreshAccessStatus() {
        let permission = Permission.calendar(access: .full)
        hasCalendarAccess = permission.authorized
        calendarAccessDenied = permission.denied
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        hasReminderAccess = reminderStatus == .fullAccess
        reminderAccessDenied = reminderStatus == .denied
    }

    func setDemoMode(_ enabled: Bool) {
        #if !DEBUG
        guard !enabled else { return }
        #endif
        UserDefaults.standard.set(enabled, forKey: Self.demoModeDefaultsKey)
        isDemoMode = enabled
        eventsByMonth = [:]
        loadedMonths = []
        if enabled {
            applyDemoFixtures()
        } else {
            for key in DemoFixtures.events.keys {
                reload(year: key.year, month: key.month)
            }
        }
    }

    private func applyDemoFixtures() {
        eventsByMonth = DemoFixtures.events
        loadedMonths = Set(DemoFixtures.events.keys)
    }

    deinit {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Access

    func requestAccess() async {
        // Use EventKit directly rather than routing through PermissionsKit:
        // the native API returns `granted: Bool` so we update our @Observable
        // state deterministically, without a post-request status re-query.
        // PermissionsKit's status getter is eventually consistent after a
        // grant; relying on it here left the UI stuck on "Allow" until the
        // app was relaunched. PermissionsKit still drives status reads on
        // init and scenePhase transitions, which don't have this race.
        let granted: Bool
        do {
            granted = try await ekStore.requestFullAccessToEvents()
        } catch {
            refreshAccessStatus()
            return
        }
        hasCalendarAccess = granted
        calendarAccessDenied = !granted
            && EKEventStore.authorizationStatus(for: .event) == .denied
        if granted {
            // Flush any cached unauthorized state so calendars(for:) /
            // events(matching:) see the newly granted data without a restart.
            ekStore.reset()
            reloadAll()
        }
    }

    func requestReminderAccess() async {
        let granted: Bool
        do {
            granted = try await ekStore.requestFullAccessToReminders()
        } catch {
            refreshAccessStatus()
            return
        }
        hasReminderAccess = granted
        reminderAccessDenied = !granted
            && EKEventStore.authorizationStatus(for: .reminder) == .denied
        if granted {
            ekStore.reset()
            reloadAllReminders()
        }
    }

    /// Re-check the system permission on the next run loop tick. Call after the app
    /// returns to the foreground — users may have flipped the toggle in Settings.
    func refreshAccessFromScenePhase() {
        let wasAuthorized = hasCalendarAccess
        let wasReminderAuthorized = hasReminderAccess
        refreshAccessStatus()
        if hasCalendarAccess {
            if !wasAuthorized { ekStore.reset() }
            reloadAll()
        }
        if hasReminderAccess {
            if !wasReminderAuthorized { ekStore.reset() }
            reloadAllReminders()
        }
    }

    /// Deep-link to Hibi's Settings page where the user can toggle calendar access.
    func openCalendarSettings() {
        Permission.calendar(access: .full).openSettingPage()
    }

    // MARK: - Calendar selection

    /// All event calendars known to EventKit, across every account source.
    func allCalendars() -> [EKCalendar] {
        guard !isDemoMode else { return [] }
        guard hasCalendarAccess else { return [] }
        return ekStore.calendars(for: .event)
    }

    func allReminderLists() -> [EKCalendar] {
        guard !isDemoMode else { return [] }
        guard hasReminderAccess else { return [] }
        return ekStore.calendars(for: .reminder)
    }

    func isHidden(_ calendar: EKCalendar) -> Bool {
        guard !isDemoMode else { return false }
        return hiddenCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func setCalendar(_ calendar: EKCalendar, hidden: Bool) {
        guard !isDemoMode else { return }
        let id = calendar.calendarIdentifier
        let wasHidden = hiddenCalendarIDs.contains(id)
        if hidden == wasHidden { return }
        if hidden {
            hiddenCalendarIDs.insert(id)
        } else {
            hiddenCalendarIDs.remove(id)
        }
        UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: Self.hiddenIDsDefaultsKey)
        reloadAll()
        reloadAllReminders()
    }

    // MARK: - Loading

    func ensureLoaded(year: Int, month: Int) {
        guard !isDemoMode else { return }
        let key = MonthKey(year: year, month: month)
        if !loadedMonths.contains(key) {
            reload(year: year, month: month)
        }
        if hasReminderAccess && !loadedReminderMonths.contains(key) {
            Task { await reloadReminders(year: year, month: month) }
        }
    }

    func reload(year: Int, month: Int) {
        guard !isDemoMode else { return }
        guard hasCalendarAccess else { return }
        let key = MonthKey(year: year, month: month)

        var comps = DateComponents(year: year, month: month, day: 1)
        guard let start = calendar.date(from: comps) else { return }
        comps.month = month + 1
        guard let end = calendar.date(from: comps) else { return }

        let visible = ekStore.calendars(for: .event).filter {
            !hiddenCalendarIDs.contains($0.calendarIdentifier)
        }
        // All calendars hidden → render nothing for this month.
        if visible.isEmpty {
            eventsByMonth[key] = [:]
            loadedMonths.insert(key)
            return
        }

        let predicate = ekStore.predicateForEvents(withStart: start, end: end, calendars: visible)
        let raw = ekStore.events(matching: predicate)

        var grouped: [Int: [CalendarEvent]] = [:]
        for ek in raw {
            // Multi-day events get placed in every day-of-month bucket they overlap
            // within this month's window. Clamp the event's [startDate, endDate) to
            // [start, end) so cross-month events only populate the days that belong
            // to the month we're currently loading.
            let clampedStart = max(ek.startDate, start)
            let clampedEnd = min(ek.endDate, end)
            guard clampedEnd > clampedStart else { continue }

            var cursor = calendar.startOfDay(for: clampedStart)
            while cursor < clampedEnd {
                let day = calendar.component(.day, from: cursor)
                grouped[day, default: []].append(makeCalendarEvent(from: ek, day: day))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        for d in grouped.keys {
            grouped[d]?.sort { lhs, rhs in
                if lhs.allDay != rhs.allDay { return lhs.allDay && !rhs.allDay }
                return (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
            }
        }

        eventsByMonth[key] = grouped
        loadedMonths.insert(key)
    }

    private func reloadAll() {
        guard !isDemoMode else { return }
        for key in loadedMonths {
            reload(year: key.year, month: key.month)
        }
        reloadAllReminders()
    }

    // MARK: - Reminder Loading

    func ensureRemindersLoaded(year: Int, month: Int) {
        guard !isDemoMode else { return }
        let key = MonthKey(year: year, month: month)
        guard !loadedReminderMonths.contains(key) else { return }
        Task { await reloadReminders(year: year, month: month) }
    }

    func reloadReminders(year: Int, month: Int) async {
        guard !isDemoMode else { return }
        guard hasReminderAccess else { return }
        let key = MonthKey(year: year, month: month)

        var comps = DateComponents(year: year, month: month, day: 1)
        guard let monthStart = calendar.date(from: comps) else { return }
        comps.month = month + 1
        guard let monthEnd = calendar.date(from: comps) else { return }

        let visibleLists = ekStore.calendars(for: .reminder).filter {
            !hiddenCalendarIDs.contains($0.calendarIdentifier)
        }
        if visibleLists.isEmpty {
            remindersByMonth[key] = [:]
            loadedReminderMonths.insert(key)
            return
        }

        let incompletePredicate = ekStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: monthEnd,
            calendars: visibleLists
        )
        let completedPredicate = ekStore.predicateForCompletedReminders(
            withCompletionDateStarting: monthStart,
            ending: monthEnd,
            calendars: visibleLists
        )

        async let incompleteResult = fetchReminders(matching: incompletePredicate)
        async let completedResult = fetchReminders(matching: completedPredicate)

        let incomplete = (try? await incompleteResult) ?? []
        let completed = (try? await completedResult) ?? []

        let today = calendar.startOfDay(for: Date())
        let todayDay = calendar.component(.day, from: today)
        let todayMonth = calendar.component(.month, from: today)
        let todayYear = calendar.component(.year, from: today)
        let isCurrentMonth = (year == todayYear && month == todayMonth)

        var grouped: [Int: [CalendarReminder]] = [:]

        for ek in incomplete {
            guard let dueComps = ek.dueDateComponents,
                  let dueDate = calendar.date(from: dueComps) else { continue }

            let dueDay = calendar.startOfDay(for: dueDate)
            let isOverdue = dueDay < today && !ek.isCompleted

            if dueDay >= monthStart && dueDay < monthEnd {
                let day = calendar.component(.day, from: dueDay)
                grouped[day, default: []].append(
                    makeCalendarReminder(from: ek, day: day, dueDate: dueDate, isOverdue: isOverdue)
                )
            } else if isOverdue && isCurrentMonth && dueDay < monthStart {
                // Overdue from a previous month: show on today only
                grouped[todayDay, default: []].append(
                    makeCalendarReminder(from: ek, day: todayDay, dueDate: dueDate, isOverdue: true)
                )
            }
        }

        for ek in completed {
            guard let dueComps = ek.dueDateComponents,
                  let dueDate = calendar.date(from: dueComps) else { continue }

            let dueDay = calendar.startOfDay(for: dueDate)
            guard dueDay >= monthStart && dueDay < monthEnd else { continue }

            let day = calendar.component(.day, from: dueDay)
            grouped[day, default: []].append(
                makeCalendarReminder(from: ek, day: day, dueDate: dueDate, isOverdue: false)
            )
        }

        // Sort: incomplete first, then by due date
        for d in grouped.keys {
            grouped[d]?.sort { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return (lhs.dueDate ?? .distantPast) < (rhs.dueDate ?? .distantPast)
            }
        }

        remindersByMonth[key] = grouped
        loadedReminderMonths.insert(key)
    }

    private func reloadAllReminders() {
        guard !isDemoMode else { return }
        guard hasReminderAccess else { return }
        let months = loadedReminderMonths.union(loadedMonths)
        for key in months {
            Task { await reloadReminders(year: key.year, month: key.month) }
        }
    }

    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            ekStore.fetchReminders(matching: predicate) { reminders in
                if let reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Queries

    func events(year: Int, month: Int, day: Int) -> [CalendarEvent] {
        eventsByMonth[MonthKey(year: year, month: month)]?[day] ?? []
    }

    func hasEvents(year: Int, month: Int) -> Bool {
        !(eventsByMonth[MonthKey(year: year, month: month)]?.isEmpty ?? true)
    }

    func ekEvent(matching event: CalendarEvent) -> EKEvent? {
        guard !isDemoMode else { return nil }
        guard let identifier = event.eventIdentifier else { return nil }

        // For recurring events, `event(withIdentifier:)` returns the first
        // occurrence (the series "master"). Handing that to
        // EKEventEditViewController makes the "Delete This Event Only" action
        // remove the past master rather than the occurrence the user tapped,
        // so the visible occurrence persists. Re-query the day's occurrences
        // and pick the one whose start matches the tapped instance.
        if event.isRecurring, let occurrenceStart = event.startDate {
            let dayStart = calendar.startOfDay(for: occurrenceStart)
            if let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) {
                let predicate = ekStore.predicateForEvents(
                    withStart: dayStart, end: dayEnd, calendars: nil
                )
                let matches = ekStore.events(matching: predicate)
                    .filter { $0.eventIdentifier == identifier }
                if let exact = matches.min(by: {
                    abs($0.startDate.timeIntervalSince(occurrenceStart))
                        < abs($1.startDate.timeIntervalSince(occurrenceStart))
                }) {
                    return exact
                }
            }
        }

        return ekStore.event(withIdentifier: identifier)
    }

    func reminders(year: Int, month: Int, day: Int) -> [CalendarReminder] {
        remindersByMonth[MonthKey(year: year, month: month)]?[day] ?? []
    }

    func hasReminders(year: Int, month: Int) -> Bool {
        !(remindersByMonth[MonthKey(year: year, month: month)]?.isEmpty ?? true)
    }

    func hasReminders(year: Int, month: Int, day: Int) -> Bool {
        !(remindersByMonth[MonthKey(year: year, month: month)]?[day]?.isEmpty ?? true)
    }

    func toggleReminderCompletion(_ reminder: CalendarReminder) {
        guard !isDemoMode else { return }
        guard hasReminderAccess else { return }
        guard let ekReminder = ekStore.calendarItem(withIdentifier: reminder.reminderIdentifier) as? EKReminder else { return }
        ekReminder.isCompleted = !ekReminder.isCompleted
        do {
            try ekStore.save(ekReminder, commit: true)
        } catch {
            // EKEventStoreChanged won't fire on failure; no action needed.
        }
    }

    // MARK: - Mutations (drag & drop)

    /// Move the instance of an event displayed on `from` to land on `to`.
    ///
    /// - Single-day events shift entirely by the day delta (duration preserved).
    /// - Multi-day events adjust a boundary:
    ///   - Dragging the first-day instance moves `startDate` by the delta.
    ///   - Dragging the last-day instance moves `endDate` by the delta.
    ///   - Dragging a middle day moves whichever boundary lies in the drag's direction.
    ///
    /// No-ops in demo mode, without full access, for events without identifiers,
    /// or when source and destination are the same day.
    @discardableResult
    func moveEventInstance(
        identifier: String,
        from: (year: Int, month: Int, day: Int),
        to: (year: Int, month: Int, day: Int)
    ) -> Bool {
        guard !isDemoMode else { return false }
        guard hasCalendarAccess else { return false }
        guard let ek = ekStore.event(withIdentifier: identifier) else { return false }

        guard
            let fromMidnight = calendar.date(from: DateComponents(year: from.year, month: from.month, day: from.day)),
            let toMidnight = calendar.date(from: DateComponents(year: to.year, month: to.month, day: to.day)),
            let dayDelta = calendar.dateComponents([.day], from: fromMidnight, to: toMidnight).day,
            dayDelta != 0
        else { return false }

        // Effective last-day midnight: treat an exact-midnight endDate (EK's
        // exclusive-end convention for all-day and on-the-minute events) as
        // belonging to the previous day.
        let startMidnight = calendar.startOfDay(for: ek.startDate)
        let endMidnightRaw = calendar.startOfDay(for: ek.endDate)
        let lastDayMidnight: Date = (ek.endDate == endMidnightRaw)
            ? (calendar.date(byAdding: .day, value: -1, to: endMidnightRaw) ?? startMidnight)
            : endMidnightRaw
        let isSingleDay = startMidnight == lastDayMidnight

        let newStart: Date
        let newEnd: Date
        if isSingleDay {
            guard
                let s = calendar.date(byAdding: .day, value: dayDelta, to: ek.startDate),
                let e = calendar.date(byAdding: .day, value: dayDelta, to: ek.endDate)
            else { return false }
            newStart = s
            newEnd = e
        } else if fromMidnight == startMidnight {
            // First-day instance dragged: move the start.
            guard let s = calendar.date(byAdding: .day, value: dayDelta, to: ek.startDate) else { return false }
            newStart = s
            newEnd = ek.endDate
        } else if fromMidnight == lastDayMidnight {
            // Last-day instance dragged: move the end.
            guard let e = calendar.date(byAdding: .day, value: dayDelta, to: ek.endDate) else { return false }
            newStart = ek.startDate
            newEnd = e
        } else if dayDelta > 0 {
            // Middle-day dragged forward: extend end.
            guard let e = calendar.date(byAdding: .day, value: dayDelta, to: ek.endDate) else { return false }
            newStart = ek.startDate
            newEnd = e
        } else {
            // Middle-day dragged backward: extend start.
            guard let s = calendar.date(byAdding: .day, value: dayDelta, to: ek.startDate) else { return false }
            newStart = s
            newEnd = ek.endDate
        }

        guard newEnd > newStart else { return false }

        ek.startDate = newStart
        ek.endDate = newEnd
        do {
            try ekStore.save(ek, span: .thisEvent)
            // .EKEventStoreChanged fires → reloadAll() refreshes cached months.
            return true
        } catch {
            return false
        }
    }

    func allLoadedEvents() -> [(year: Int, month: Int, event: CalendarEvent)] {
        // Multi-day events appear in every day bucket they span; dedupe by id so
        // search shows one hit per event. Keep the earliest (year, month, day)
        // instance so the result's subtitle points to where the event starts.
        var bestByID: [String: (year: Int, month: Int, event: CalendarEvent)] = [:]
        for (key, days) in eventsByMonth {
            for (_, events) in days {
                for e in events {
                    if let existing = bestByID[e.id] {
                        let isEarlier = (key.year, key.month, e.day) <
                            (existing.year, existing.month, existing.event.day)
                        if isEarlier {
                            bestByID[e.id] = (key.year, key.month, e)
                        }
                    } else {
                        bestByID[e.id] = (key.year, key.month, e)
                    }
                }
            }
        }
        return Array(bestByID.values)
    }

    // MARK: - Adapters

    private func makeCalendarEvent(from ek: EKEvent, day: Int) -> CalendarEvent {
        let tint = Color.pastelized(cgColor: ek.calendar?.cgColor)
        return CalendarEvent(
            id: ek.eventIdentifier ?? UUID().uuidString,
            eventIdentifier: ek.eventIdentifier,
            day: day,
            startDate: ek.startDate,
            endDate: ek.endDate,
            title: ek.title ?? "",
            tint: tint,
            location: ek.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            allDay: ek.isAllDay,
            isRecurring: ek.hasRecurrenceRules
        )
    }

    private func makeCalendarReminder(from ek: EKReminder, day: Int, dueDate: Date, isOverdue: Bool) -> CalendarReminder {
        let tint = Color.pastelized(cgColor: ek.calendar?.cgColor)
        let hasTime: Bool = {
            guard let comps = ek.dueDateComponents else { return false }
            return comps.hour != nil && comps.hour != NSDateComponentUndefined
        }()
        return CalendarReminder(
            id: "\(ek.calendarItemIdentifier)-\(day)",
            reminderIdentifier: ek.calendarItemIdentifier,
            day: day,
            dueDate: dueDate,
            hasTime: hasTime,
            title: ek.title ?? "",
            tint: tint,
            isCompleted: ek.isCompleted,
            isOverdue: isOverdue,
            isRecurring: ek.hasRecurrenceRules
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
