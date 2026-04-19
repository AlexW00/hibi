import EventKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EventStore.self) private var eventStore
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.system.rawValue
    @AppStorage("invertDaySwipe") private var invertDaySwipe: Bool = false
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        /// Deferred-lookup resource so SwiftUI re-resolves when the locale changes.
        var labelResource: LocalizedStringResource {
            switch self {
            case .system: "System"
            case .light:  "Light"
            case .dark:   "Dark"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(Appearance.allCases) { a in
                            Text(a.labelResource).tag(a.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Simple font", isOn: $useSimpleFont)
                }

                Section("Day View") {
                    Toggle("Invert swipe direction", isOn: $invertDaySwipe)
                }

                Section("Calendars") {
                    NavigationLink {
                        CalendarSelectionView()
                    } label: {
                        LabeledContent("Calendars") {
                            Text(calendarSummary)
                        }
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Toggle("Demo Mode", isOn: Binding(
                        get: { eventStore.isDemoMode },
                        set: { eventStore.setDemoMode($0) }
                    ))
                }
                #endif

                Section {
                    LabeledContent("Version", value: "1.0 (1)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var calendarSummary: LocalizedStringResource {
        if eventStore.isDemoMode { return "Demo" }
        guard eventStore.authorization == .fullAccess else { return "Not connected" }
        let all = eventStore.allCalendars()
        let visible = all.filter { !eventStore.isHidden($0) }.count
        return "\(visible) / \(all.count)"
    }
}
