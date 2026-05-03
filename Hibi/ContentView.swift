import SwiftUI
import WhatsNewKit

enum CalendarTab: Hashable {
    case month, stream, day
}

struct ContentView: View {
    @State private var selection: CalendarTab = .day
    @State private var scrollToNowToken: Int = 0
    @State private var showSettings = false
    @State private var displayedYear = SampleData.todayYear
    @State private var displayedMonth = SampleData.todayMonth
    @State private var selectedDay = SampleData.todayDay
    @State private var eventStore = EventStore()
    @State private var weatherStore = WeatherStore()
    @State private var editorMode: EventEditorSheet.Mode?
    @State private var showOnboarding = false
    /// Latched by SettingsView — when Settings dismisses with this set we
    /// present the onboarding sheet. Can't show two sheets at once, so we
    /// chain via `onDismiss`.
    @State private var reopenOnboardingAfterSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw: String = SettingsView.Appearance.system.rawValue
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false

    private var selectionBinding: Binding<CalendarTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == selection {
                    returnToNow()
                }
                selection = newValue
            }
        )
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
                        scrollToNowToken: scrollToNowToken,
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
        .whatsNewSheet()
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
            // Auto-present only when a REQUIRED permission is missing.
            // Location is optional — users enable it later from Settings.
            if !eventStore.isDemoMode, !eventStore.hasCalendarAccess {
                showOnboarding = true
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
            }
        }
        .preferredColorScheme(colorScheme)
        .tint(.primary)
        .onOpenURL { url in
            guard url.scheme == "hibi", url.host() == "day" else { return }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let items = components?.queryItems ?? []
            guard let y = items.first(where: { $0.name == "year" })?.value.flatMap(Int.init),
                  let m = items.first(where: { $0.name == "month" })?.value.flatMap(Int.init),
                  let d = items.first(where: { $0.name == "day" })?.value.flatMap(Int.init)
            else { return }
            displayedYear = y
            displayedMonth = m
            selectedDay = d
            selection = .day
        }
    }

    private func openEditor(for event: CalendarEvent) {
        guard !eventStore.isDemoMode else { return }
        guard let ek = eventStore.ekEvent(matching: event) else { return }
        editorMode = .edit(ek)
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
    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue

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
