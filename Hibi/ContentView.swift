import SwiftUI
import WhatsNewKit

enum CalendarTab: Hashable {
    case month, stream, day
}

struct ContentView: View {
    @State private var selection: CalendarTab = .day
    @State private var scrollToNowToken: Int = 0
    /// Bumped whenever the user changes tabs. List-based tabs (Month, Week)
    /// observe this and recenter their scroll position on the shared
    /// displayed date so switching tabs lands near where the previous tab
    /// was looking, instead of wherever each tab was last left.
    @State private var tabSwitchToken: Int = 0
    /// (year, month) captured when the user enters the Month tab. On exit,
    /// if the user scrolled Month to a different month, we anchor the
    /// destination on day 1 (Month has no notion of a single "current day").
    /// If they left Month on the same month they entered, selectedDay is
    /// preserved so Day → Month → Day round-trips don't lose the day.
    @State private var monthEntry: (year: Int, month: Int)?
    @State private var showSettings = false
    @State private var displayedYear = SampleData.todayYear
    @State private var displayedMonth = SampleData.todayMonth
    @State private var selectedDay = SampleData.todayDay
    @State private var eventStore = EventStore()
    @State private var weatherStore = WeatherStore()
    @State private var clock = Clock()
    @State private var editorMode: EventEditorSheet.Mode?
    @State private var showOnboarding = false
    @State private var needsOnboarding = false
    /// Latched by SettingsView — when Settings dismisses with this set we
    /// present the onboarding sheet. Can't show two sheets at once, so we
    /// chain via `onDismiss`.
    @State private var reopenOnboardingAfterSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw: String = SettingsView.Appearance.system.rawValue
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont: Bool = false

    private var selectionBinding: Binding<CalendarTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == selection {
                    returnToNow()
                } else {
                    // Leaving Month: only anchor the destination on day 1 if
                    // the user actually scrolled Month to a different month.
                    // Otherwise they were just visiting and we preserve
                    // selectedDay so Day → Month → Day stays on the same day.
                    if selection == .month, let entry = monthEntry,
                       entry.year != displayedYear || entry.month != displayedMonth {
                        selectedDay = 1
                    }
                    if selection == .month {
                        monthEntry = nil
                    }
                    if newValue == .month {
                        monthEntry = (displayedYear, displayedMonth)
                    }
                    tabSwitchToken &+= 1
                }
                selection = newValue
            }
        )
    }

    /// Triggered by `NSCalendarDayChanged` and by scene-foreground transitions
    /// (catches the case where the app was backgrounded across midnight). If
    /// the user was looking at "today" before the rollover, advance their
    /// displayed date so they stay on today; otherwise leave the selection
    /// alone — the today highlight will refresh on its own because views read
    /// from the `Clock` we just updated. The new month is also pre-loaded so
    /// reminders that pivot on `Date()` (overdue carry-over) reflect the new day.
    private func handleDayChange() {
        let wasOnOldToday = displayedYear == clock.year
            && displayedMonth == clock.month
            && selectedDay == clock.day
        guard clock.refresh() != nil else { return }
        if wasOnOldToday {
            displayedYear = clock.year
            displayedMonth = clock.month
            selectedDay = clock.day
            // Bump the scroll token so list-based tabs recenter on the new
            // today — without it, the Week list still shows the previous
            // day at center after midnight even though selectedDay advanced.
            scrollToNowToken &+= 1
        }
        eventStore.ensureLoaded(year: clock.year, month: clock.month)
    }

    private func returnToNow() {
        withAnimation(.snappy(duration: 0.35)) {
            displayedYear = SampleData.todayYear
            displayedMonth = SampleData.todayMonth
            selectedDay = SampleData.todayDay
        }
        scrollToNowToken &+= 1
    }

    var body: some View {
        NavigationStack {
            TabView(selection: selectionBinding) {
                Tab("Month", systemImage: "square.grid.3x3", value: CalendarTab.month) {
                    MonthsScrollView(
                        displayedYear: $displayedYear,
                        displayedMonth: $displayedMonth,
                        scrollToNowToken: scrollToNowToken,
                        tabSwitchToken: tabSwitchToken,
                        onPickDay: { year, month, day in
                            displayedYear = year
                            displayedMonth = month
                            selectedDay = day
                            selection = .day
                        }
                    )
                }

                Tab("Week", systemImage: "text.alignleft", value: CalendarTab.stream) {
                    StreamView(
                        displayedYear: $displayedYear,
                        displayedMonth: $displayedMonth,
                        selectedDay: $selectedDay,
                        scrollToNowToken: scrollToNowToken,
                        tabSwitchToken: tabSwitchToken,
                        onPickDay: { year, month, day in
                            displayedYear = year
                            displayedMonth = month
                            selectedDay = day
                            selection = .day
                        },
                        onTapEvent: openEditor(for:)
                    )
                }

                Tab("Day", systemImage: "calendar", value: CalendarTab.day) {
                    DayView(
                        year: displayedYear,
                        month: displayedMonth,
                        day: $selectedDay,
                        scrollToNowToken: scrollToNowToken,
                        onTapEvent: openEditor(for:),
                        onDateChange: { y, m, d in
                            displayedYear = y
                            displayedMonth = m
                            selectedDay = d
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .principal) {
                    // Month name is already locale-aware via the accessor;
                    // verbatim skips the pointless "%@ · %@" catalog entry.
                    Text(verbatim: "\(MonthNames.full[displayedMonth - 1]) · \(String(displayedYear))")
                        .font(.appSerif(size: 15, italic: true, simple: useSimpleFont))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewEvent()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(eventStore.isDemoMode || !eventStore.hasCalendarAccess)
                }
            }
            .background(AppBackgroundGradient().ignoresSafeArea())
        }
        .environment(eventStore)
        .environment(weatherStore)
        .environment(clock)
        .onOpenURL { url in
            guard url.scheme == "hibi" else { return }
            switch url.host {
            case "today", nil:
                // Anchor the displayed date on the device's real "today" —
                // not whatever the user had selected. The widget always
                // shows today, so tapping it should land you there.
                displayedYear = SampleData.todayYear
                displayedMonth = SampleData.todayMonth
                selectedDay = SampleData.todayDay
                selection = .day
                scrollToNowToken &+= 1
            case "event":
                // hibi://event/{identifier} — emitted by the Schedule
                // widget when a specific event pill is tapped. Land on
                // today (the widget only shows today) and present the
                // editor for that event.
                let identifier = url.pathComponents.dropFirst().first ?? ""
                guard !identifier.isEmpty else { return }
                displayedYear = SampleData.todayYear
                displayedMonth = SampleData.todayMonth
                selectedDay = SampleData.todayDay
                selection = .day
                scrollToNowToken &+= 1
                openEditor(forEventIdentifier: identifier)
            default:
                break
            }
        }
        .whatsNewSheet(onDismiss: {
            if needsOnboarding {
                showOnboarding = true
            }
        })
        .sheet(isPresented: $showSettings, onDismiss: {
            if reopenOnboardingAfterSettings {
                reopenOnboardingAfterSettings = false
                showOnboarding = true
            }
        }) {
            SettingsView(
                onReopenPermissions: {
                    reopenOnboardingAfterSettings = true
                }
            )
            .environment(eventStore)
            .environment(weatherStore)
        }
        .sheet(item: $editorMode) { mode in
            EventEditorSheet(store: eventStore.ekStore, mode: mode) {
                editorMode = nil
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
            weatherStore.refresh()
        }) {
            PermissionsOnboardingSheet(
                items: onboardingItems,
                onContinue: { }
            )
        }
        .task {
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
            weatherStore.refresh()
            if !eventStore.isDemoMode {
                // Show onboarding when calendar isn't granted yet (fresh install),
                // OR when calendar is granted but reminders haven't been asked
                // (upgrade from a version without reminder support).
                let shouldOnboard = !eventStore.hasCalendarAccess
                    || (!eventStore.hasReminderAccess && !eventStore.reminderAccessDenied)
                if shouldOnboard {
                    let whatsNewWillPresent = !UserDefaultsWhatsNewVersionStore()
                        .hasPresented(WhatsNewContent.version)
                    needsOnboarding = true
                    if !whatsNewWillPresent {
                        showOnboarding = true
                    }
                    // else: onboarding shows after WhatsNew dismisses (via onDismiss)
                }
            }
        }
        .onChange(of: displayedYear) { _, _ in
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
        }
        .onChange(of: displayedMonth) { _, _ in
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
        }
        .onChange(of: eventStore.hasCalendarAccess) { _, newValue in
            // Cover any path that flips access on — inline CalendarAccessPrompt,
            // Settings toggle, or onboarding sheet. ensureLoaded only fetches
            // months not yet in the cache, so this is cheap and idempotent.
            if newValue {
                eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                eventStore.refreshAccessFromScenePhase()
                weatherStore.refresh()
                handleDayChange()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            handleDayChange()
        }
        .preferredColorScheme(colorScheme)
        .tint(.primary)
    }

    private func openEditor(for event: CalendarEvent) {
        guard !eventStore.isDemoMode else { return }
        guard let ek = eventStore.ekEvent(matching: event) else { return }
        editorMode = .edit(ek)
    }

    /// Open the editor for an event identified by its EventKit identifier
    /// — entry point for the `hibi://event/{identifier}` widget deep link.
    ///
    /// First tries to route through `openEditor(for:)` (which has the
    /// recurrence-aware occurrence picker), falling back to a direct
    /// EventKit lookup if today's events haven't loaded yet (cold launch
    /// from the widget tap, before `ensureLoaded` settles).
    private func openEditor(forEventIdentifier identifier: String) {
        guard !eventStore.isDemoMode else { return }
        let todays = eventStore.events(
            year: SampleData.todayYear,
            month: SampleData.todayMonth,
            day: SampleData.todayDay
        )
        if let match = todays.first(where: { $0.eventIdentifier == identifier }) {
            openEditor(for: match)
            return
        }
        if let ek = eventStore.ekStore.event(withIdentifier: identifier) {
            editorMode = .edit(ek)
        }
    }

    private func startNewEvent() {
        let (y, m, d): (Int, Int, Int)
        switch selection {
        case .day:
            (y, m, d) = (displayedYear, displayedMonth, selectedDay)
        default:
            (y, m, d) = (SampleData.todayYear, SampleData.todayMonth, SampleData.todayDay)
        }
        var comps = DateComponents(year: y, month: m, day: d, hour: 9, minute: 0)
        comps.calendar = Calendar(identifier: .gregorian)
        guard let date = comps.date else { return }
        editorMode = .new(defaultStart: date)
    }

    private var onboardingItems: [PermissionOnboardingItem] {
        [
            PermissionOnboardingItem(
                id: "calendar",
                icon: "calendar",
                tint: Color(.displayP3, red: 0.78, green: 0.49, blue: 0.42, opacity: 1),
                title: "Calendar",
                description: "Show and edit the events from your system calendars.",
                isRequired: true,
                isGranted: { eventStore.hasCalendarAccess },
                isDenied: { eventStore.calendarAccessDenied },
                request: { await eventStore.requestAccess() },
                openSettings: { eventStore.openCalendarSettings() }
            ),
            PermissionOnboardingItem(
                id: "reminders",
                icon: "checklist",
                tint: Color(.displayP3, red: 0.55, green: 0.72, blue: 0.42, opacity: 1),
                title: "Reminders",
                description: "Display your reminders alongside calendar events.",
                isRequired: false,
                isGranted: { eventStore.hasReminderAccess },
                isDenied: { eventStore.reminderAccessDenied },
                request: { await eventStore.requestReminderAccess() },
                openSettings: { eventStore.openCalendarSettings() }
            ),
            PermissionOnboardingItem(
                id: "location",
                icon: "location.fill",
                tint: Color(.displayP3, red: 0.38, green: 0.55, blue: 0.76, opacity: 1),
                title: "Location",
                description: "Local weather and sunrise / sunset on each day.",
                isRequired: false,
                isGranted: { weatherStore.hasLocationAccess },
                isDenied: { weatherStore.locationAccessDenied },
                request: { await weatherStore.requestAccess() },
                openSettings: { weatherStore.openLocationSettings() }
            ),
        ]
    }

    private var colorScheme: ColorScheme? {
        switch SettingsView.Appearance(rawValue: appearanceRaw) {
        case .light: .light
        case .dark:  .dark
        default:     nil
        }
    }
}

private struct SearchResultsView: View {
    let query: String
    @Environment(EventStore.self) private var eventStore
    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults) private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    var body: some View {
        let matches: [(year: Int, month: Int, event: CalendarEvent)] = {
            guard !query.isEmpty else { return [] }
            return eventStore.allLoadedEvents().filter { item in
                item.event.title.localizedCaseInsensitiveContains(query) ||
                (item.event.location?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }()

        Group {
            if query.isEmpty {
                ContentUnavailableView(
                    "Search events",
                    systemImage: "magnifyingglass",
                    description: Text("Find events by title or location.")
                )
            } else if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(matches, id: \.event.id) { item in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.event.tint)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.event.title)
                                .font(.body)
                            Text(subtitle(for: item))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func subtitle(for item: (year: Int, month: Int, event: CalendarEvent)) -> String {
        let monthShort = MonthNames.short[item.month - 1]
        let date = "\(monthShort) \(item.event.day)"
        if item.event.allDay {
            return "\(date) · \(String(localized: "All day"))"
        }
        let start = item.event.startDate.map { timeFormat.string(from: $0) } ?? ""
        let end = item.event.endDate.map { timeFormat.string(from: $0) } ?? ""
        let time = "\(start)–\(end)"
        if let loc = item.event.location {
            return "\(date) · \(time) · \(loc)"
        }
        return "\(date) · \(time)"
    }
}

#Preview {
    ContentView()
}
