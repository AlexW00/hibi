import EventKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class EventStore {
    let ekStore = EKEventStore()
    private(set) var authorization: EKAuthorizationStatus
    /// Debug demo mode: fixture data only, persisted. Release UI toggle is `#if DEBUG` only.
    private(set) var isDemoMode: Bool
    private(set) var eventsByMonth: [MonthKey: [Int: [CalendarEvent]]] = [:]
    private(set) var hiddenCalendarIDs: Set<String>
    private var loadedMonths: Set<MonthKey> = []
    @ObservationIgnored nonisolated(unsafe) private var observerToken: NSObjectProtocol?

    private static let hiddenIDsDefaultsKey = "hiddenCalendarIDs"
    private static let demoModeDefaultsKey = "demoMode"

    /// Month/stream/day views use this instead of checking `authorization` alone so demo works without EventKit.
    var showsCalendarContent: Bool {
        isDemoMode || authorization == .fullAccess
    }

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .autoupdatingCurrent
        return c
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    init() {
        self.authorization = EKEventStore.authorizationStatus(for: .event)
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
                self?.reloadAll()
            }
        }
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
        do {
            let granted = try await ekStore.requestFullAccessToEvents()
            authorization = EKEventStore.authorizationStatus(for: .event)
            if granted {
                reloadAll()
            }
        } catch {
            authorization = EKEventStore.authorizationStatus(for: .event)
        }
    }

    // MARK: - Calendar selection

    /// All event calendars known to EventKit, across every account source.
    func allCalendars() -> [EKCalendar] {
        guard !isDemoMode else { return [] }
        guard authorization == .fullAccess else { return [] }
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
        guard authorization == .fullAccess else { return }
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
            let day = calendar.component(.day, from: ek.startDate)
            let event = makeCalendarEvent(from: ek, day: day)
            grouped[day, default: []].append(event)
        }
        for d in grouped.keys {
            grouped[d]?.sort { lhs, rhs in
                if lhs.allDay != rhs.allDay { return lhs.allDay && !rhs.allDay }
                return (lhs.start ?? "") < (rhs.start ?? "")
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

    func allLoadedEvents() -> [(year: Int, month: Int, event: CalendarEvent)] {
        var out: [(Int, Int, CalendarEvent)] = []
        for (key, days) in eventsByMonth {
            for (_, events) in days {
                for e in events {
                    out.append((key.year, key.month, e))
                }
            }
        }
        return out
    }

    // MARK: - Adapters

    private func makeCalendarEvent(from ek: EKEvent, day: Int) -> CalendarEvent {
        let start: String? = ek.isAllDay ? nil : timeFormatter.string(from: ek.startDate)
        let end: String? = ek.isAllDay ? nil : timeFormatter.string(from: ek.endDate)
        let tint = Color.pastelized(cgColor: ek.calendar?.cgColor)
        return CalendarEvent(
            id: ek.eventIdentifier ?? UUID().uuidString,
            eventIdentifier: ek.eventIdentifier,
            day: day,
            start: start,
            end: end,
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
