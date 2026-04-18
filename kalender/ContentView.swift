import SwiftUI

enum CalendarTab: Hashable {
    case month, stream, day, search
}

struct ContentView: View {
    @State private var selection: CalendarTab = .stream
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var displayedYear = SampleData.todayYear
    @State private var displayedMonth = SampleData.todayMonth
    @State private var selectedDay = SampleData.todayDay
    @AppStorage("appearance") private var appearanceRaw: String = SettingsView.Appearance.system.rawValue

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                Tab("Month", systemImage: "square.grid.3x3", value: CalendarTab.month) {
                    ScrollView {
                        MonthView(
                            year: displayedYear,
                            month: displayedMonth,
                            onPickDay: { day in
                                selectedDay = day
                                selection = .day
                            }
                        )
                    }
                }

                Tab("Stream", systemImage: "text.alignleft", value: CalendarTab.stream) {
                    StreamView(year: displayedYear, month: displayedMonth)
                }

                Tab("Day", systemImage: "calendar", value: CalendarTab.day) {
                    DayView(year: displayedYear, month: displayedMonth, day: $selectedDay)
                }

                Tab(value: CalendarTab.search, role: .search) {
                    SearchResultsView(query: searchText,
                                      year: displayedYear,
                                      month: displayedMonth)
                }
            }
            .searchable(text: $searchText, prompt: "Search events")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(MonthNames.full[displayedMonth - 1]) · \(String(displayedYear))")
                        .font(.custom(AppFont.serifItalic, size: 15))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: present create event sheet
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(backgroundGradient.ignoresSafeArea())
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .preferredColorScheme(colorScheme)
        .tint(.primary)
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
    let year: Int
    let month: Int

    var body: some View {
        let matches: [CalendarEvent] = {
            guard !query.isEmpty else { return [] }
            return SampleData.events.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                ($0.location?.localizedCaseInsensitiveContains(query) ?? false)
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
                List(matches) { event in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.category.tint)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.body)
                            Text(subtitle(for: event))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func subtitle(for event: CalendarEvent) -> String {
        let monthShort = MonthNames.short[month - 1]
        let date = "\(monthShort) \(event.day)"
        if event.allDay {
            return "\(date) · All day"
        }
        let time = "\(event.start ?? "")–\(event.end ?? "")"
        if let loc = event.location {
            return "\(date) · \(time) · \(loc)"
        }
        return "\(date) · \(time)"
    }
}

#Preview {
    ContentView()
}
