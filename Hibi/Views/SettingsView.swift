import EventKit
import SwiftUI
import WhatsNewKit

struct SettingsView: View {
    /// Called by the "Review permissions" button. ContentView latches this and
    /// presents the onboarding sheet once Settings dismisses (can't stack sheets).
    let onReopenPermissions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(EventStore.self) private var eventStore
    @Environment(WeatherStore.self) private var weatherStore
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.system.rawValue
    @AppStorage("invertDaySwipe") private var invertDaySwipe: Bool = false
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false
    @AppStorage(TemperatureUnit.defaultsKey) private var temperatureUnitRaw: String = TemperatureUnit.system.rawValue
    @AppStorage(TimeFormat.defaultsKey) private var timeFormatRaw: String = TimeFormat.system.rawValue
    @State private var showWhatsNew = false

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
                        .tint(.black)
                }

                Section("Day View") {
                    Toggle("Invert swipe direction", isOn: $invertDaySwipe)
                        .tint(.black)
                }

                Section("Units") {
                    Picker("Temperature", selection: $temperatureUnitRaw) {
                        ForEach(TemperatureUnit.allCases) { u in
                            Text(u.labelResource).tag(u.rawValue)
                        }
                    }
                    Picker("Time", selection: $timeFormatRaw) {
                        ForEach(TimeFormat.allCases) { f in
                            Text(f.labelResource).tag(f.rawValue)
                        }
                    }
                }

                Section("Calendars & Reminders") {
                    NavigationLink {
                        CalendarSelectionView()
                    } label: {
                        LabeledContent("Calendars") {
                            Text(calendarSummary)
                        }
                    }
                    if eventStore.hasReminderAccess {
                        LabeledContent("Reminder Lists") {
                            Text(reminderSummary)
                        }
                    }
                }

                if hasMissingPermission {
                    Section("Permissions") {
                        Button {
                            onReopenPermissions()
                            dismiss()
                        } label: {
                            LabeledContent("Review permissions") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Toggle("Demo Mode", isOn: Binding(
                        get: { eventStore.isDemoMode },
                        set: { eventStore.setDemoMode($0) }
                    ))
                    .tint(.black)
                }
                #endif

                Section("About") {
                    Link(destination: URL(string: "https://apps.weichart.de")!) {
                        HStack(spacing: 12) {
                            Image("WeichartApps")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("More Apps")
                                    .foregroundStyle(.primary)
                                Text(verbatim: "apps.weichart.de")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                        (Text("Weather data provided by ") + Text(Image(systemName: "apple.logo")) + Text(verbatim: "\u{00a0}Weather"))
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }

                Section("Release") {
                    Button("What's New") { showWhatsNew = true }
                        .tint(.primary)
                    LabeledContent("Version", value: Self.versionLabel)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView(whatsNew: WhatsNewContent.latest)
            }
        }
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private var calendarSummary: LocalizedStringResource {
        if eventStore.isDemoMode { return "Demo" }
        guard eventStore.hasCalendarAccess else { return "Not connected" }
        let all = eventStore.allCalendars()
        let visible = all.filter { !eventStore.isHidden($0) }.count
        return "\(visible) / \(all.count)"
    }

    private var reminderSummary: LocalizedStringResource {
        let all = eventStore.allReminderLists()
        let visible = all.filter { !eventStore.isHidden($0) }.count
        return "\(visible) / \(all.count)"
    }

    private var hasMissingPermission: Bool {
        !eventStore.hasCalendarAccess || !weatherStore.hasLocationAccess
    }
}
