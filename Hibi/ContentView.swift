import EventKit
import SwiftUI

enum CalendarTab: Hashable {
    case month, stream, day
}

struct ContentView: View {
    @State private var selection: CalendarTab = .stream
    @State private var scrollToNowToken: Int = 0
    @State private var showSettings = false
    @State private var displayedYear = SampleData.todayYear
    @State private var displayedMonth = SampleData.todayMonth
    @State private var selectedDay = SampleData.todayDay
    @State private var eventStore = EventStore()
    @State private var weatherStore = WeatherStore()
    @State private var editorMode: EventEditorSheet.Mode?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw: String = SettingsView.Appearance.system.rawValue

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
                        onTapEvent: openEditor(for:)
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
                    // Month name is already locale-aware via the accessor.
                    Text(verbatim: "\(MonthNames.full[displayedMonth - 1]) · \(String(displayedYear))")
                        .font(.custom(AppFont.serifItalic, size: 15))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewEvent()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(eventStore.isDemoMode || eventStore.authorization != .fullAccess)
                }
            }
            .background(backgroundGradient.ignoresSafeArea())
        }
        .environment(eventStore)
        .environment(weatherStore)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(eventStore)
        }
        .sheet(item: $editorMode) { mode in
            EventEditorSheet(store: eventStore.ekStore, mode: mode) {
                editorMode = nil
            }
            .ignoresSafeArea()
        }
        .task {
            if eventStore.authorization != .fullAccess, !eventStore.isDemoMode {
                await eventStore.requestAccess()
            }
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
            weatherStore.requestAccess()
            weatherStore.refresh()
        }
        .onChange(of: displayedYear) { _, _ in
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
        }
        .onChange(of: displayedMonth) { _, _ in
            eventStore.ensureLoaded(year: displayedYear, month: displayedMonth)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { weatherStore.refresh() }
        }
        .preferredColorScheme(colorScheme)
        .tint(.primary)
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

    @ViewBuilder
    private var backgroundGradient: some View {
        if colorScheme == .dark {
            RadialGradient(
                colors: [
                    Color(.displayP3, red: 0.102, green: 0.102, blue: 0.122),
                    Color(.displayP3, red: 0.047, green: 0.047, blue: 0.055),
                ],
                center: UnitPoint(x: 0.2, y: 0.0),
                startRadius: 0,
                endRadius: 600
            )
        } else {
            RadialGradient(
                colors: [
                    Color(.displayP3, red: 0.984, green: 0.980, blue: 0.965),
                    Color(.displayP3, red: 0.953, green: 0.945, blue: 0.918),
                    Color(.displayP3, red: 0.929, green: 0.914, blue: 0.867),
                ],
                center: UnitPoint(x: 0.15, y: -0.1),
                startRadius: 0,
                endRadius: 700
            )
        }
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
        let time = "\(item.event.start ?? "")–\(item.event.end ?? "")"
        if let loc = item.event.location {
            return "\(date) · \(time) · \(loc)"
        }
        return "\(date) · \(time)"
    }
}

#Preview {
    ContentView()
}
