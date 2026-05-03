import WidgetKit
import EventKit
import UIKit

struct EventsTimelineProvider: TimelineProvider {
    typealias Entry = EventsEntry

    func placeholder(in context: Context) -> EventsEntry {
        EventsEntry(
            date: .now,
            day: 3,
            month: 5,
            year: 2026,
            dayName: "Saturday",
            monthName: "May",
            isToday: true,
            events: [
                WidgetEvent(id: "1", title: "Morning Run", startDate: nil, endDate: nil, tintHue: 0.33, tintSaturation: 0.5, tintBrightness: 0.7, location: nil, allDay: false, isRecurring: true),
                WidgetEvent(id: "2", title: "Team Standup", startDate: nil, endDate: nil, tintHue: 0.6, tintSaturation: 0.5, tintBrightness: 0.7, location: "Zoom", allDay: false, isRecurring: false),
            ],
            useSimpleFont: false,
            timeFormatRaw: "system",
            weatherHigh: 22,
            weatherLow: 14,
            weatherCode: "sun",
            sunrise: nil,
            sunset: nil,
            locationName: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (EventsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let entry = makeCurrentEntry(events: fetchTodayEvents())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventsEntry>) -> Void) {
        let events = fetchTodayEvents()
        let now = Date()

        var entryDates: [Date] = [now]
        for event in events {
            if let start = event.startDate, start > now {
                entryDates.append(start)
            }
            if let end = event.endDate, end > now {
                entryDates.append(end)
            }
        }
        entryDates.sort()
        if entryDates.count > 12 {
            entryDates = Array(entryDates.prefix(12))
        }

        let entries = entryDates.map { date in
            makeEntry(at: date, events: events)
        }

        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: now)!
        )
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    private func makeCurrentEntry(events: [WidgetEvent]) -> EventsEntry {
        makeEntry(at: .now, events: events)
    }

    private func makeEntry(at date: Date, events: [WidgetEvent]) -> EventsEntry {
        let year = CalendarHelpers.todayYear
        let month = CalendarHelpers.todayMonth
        let day = CalendarHelpers.todayDay
        let weekdayIndex = CalendarHelpers.weekday(year: year, month: month, day: day)
        let suite = SharedDefaults.suite
        let useSimpleFont = suite.bool(forKey: SharedDefaults.useSimpleFontKey)
        let timeFormatRaw = suite.string(forKey: SharedDefaults.timeFormatKey) ?? "system"

        let locationName = suite.string(forKey: SharedDefaults.locationNameKey)
        var weatherHigh: Double?
        var weatherLow: Double?
        var weatherCode: String?
        var sunrise: Date?
        var sunset: Date?

        if let data = suite.data(forKey: SharedDefaults.todayWeatherKey),
           let weather = try? JSONDecoder().decode(SharedWeatherData.self, from: data),
           weather.year == year && weather.month == month && weather.day == day {
            weatherHigh = weather.high
            weatherLow = weather.low
            weatherCode = weather.weatherCode
            sunrise = weather.sunrise
            sunset = weather.sunset
        }

        let upcomingEvents = events.filter { event in
            if event.allDay { return true }
            guard let end = event.endDate else { return true }
            return end > date
        }

        return EventsEntry(
            date: date,
            day: day,
            month: month,
            year: year,
            dayName: DayNames.full[weekdayIndex],
            monthName: MonthNames.full[month - 1],
            isToday: true,
            events: upcomingEvents,
            useSimpleFont: useSimpleFont,
            timeFormatRaw: timeFormatRaw,
            weatherHigh: weatherHigh,
            weatherLow: weatherLow,
            weatherCode: weatherCode,
            sunrise: sunrise,
            sunset: sunset,
            locationName: locationName
        )
    }

    private func fetchTodayEvents() -> [WidgetEvent] {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else { return [] }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let hiddenIDs = Set(SharedDefaults.suite.stringArray(forKey: SharedDefaults.hiddenCalendarIDsKey) ?? [])
        let calendars = store.calendars(for: .event).filter { !hiddenIDs.contains($0.calendarIdentifier) }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
            }
            .map { ekEvent in
                let color = UIColor(cgColor: ekEvent.calendar.cgColor)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

                return WidgetEvent(
                    id: ekEvent.eventIdentifier ?? UUID().uuidString,
                    title: ekEvent.title ?? "Event",
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    tintHue: Double(h),
                    tintSaturation: Double(s),
                    tintBrightness: Double(b),
                    location: ekEvent.location,
                    allDay: ekEvent.isAllDay,
                    isRecurring: ekEvent.hasRecurrenceRules
                )
            }
    }
}
