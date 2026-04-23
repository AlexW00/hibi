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
    /// Debug demo mode: fixture data only, persisted. Release UI toggle is `#if DEBUG` only.
    private(set) var isDemoMode: Bool
    private(set) var eventsByMonth: [MonthKey: [Int: [CalendarEvent]]] = [:]
    private(set) var hiddenCalendarIDs: Set<String>
    private var loadedMonths: Set<MonthKey> = []
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

    /// Re-check the system permission on the next run loop tick. Call after the app
    /// returns to the foreground — users may have flipped the toggle in Settings.
    func refreshAccessFromScenePhase() {
        let wasAuthorized = hasCalendarAccess
        refreshAccessStatus()
        if hasCalendarAccess {
            if !wasAuthorized { ekStore.reset() }
            reloadAll()
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
    }

    // MARK: - Loading

    func ensureLoaded(year: Int, month: Int) {
        guard !isDemoMode else { return }
        let key = MonthKey(year: year, month: month)
        guard !loadedMonths.contains(key) else { return }
        reload(year: year, month: month)
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
        return ekStore.event(withIdentifier: identifier)
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
            allDay: ek.isAllDay
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
