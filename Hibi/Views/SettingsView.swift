import EventKit
import SwiftUI
import WhatsNewKit

struct SettingsView: View {
    /// Called by the "Review permissions" button. ContentView latches this and
    /// presents the onboarding sheet once Settings dismisses (can't stack sheets).
    let onReopenPermissions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(EventStore.self) private var eventStore

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
                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    NavigationLink {
                        UnitsSettingsView()
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                }

                Section {
                    NavigationLink {
                        CalendarSelectionView()
                    } label: {
                        LabeledContent {
                            Text(calendarSummary)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Calendars & Reminders", systemImage: "calendar")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AboutSettingsView(onReviewPermissions: {
                            onReopenPermissions()
                            dismiss()
                        })
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Toggle(isOn: Binding(
                        get: { eventStore.isDemoMode },
                        set: { eventStore.setDemoMode($0) }
                    )) {
                        Label("Demo Mode", systemImage: "wand.and.stars")
                    }
                    .tint(.black)
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var calendarSummary: LocalizedStringResource {
        if eventStore.isDemoMode { return "Demo" }
        guard eventStore.hasCalendarAccess else { return "Not connected" }
        let all = eventStore.allCalendars()
        let visible = all.filter { !eventStore.isHidden($0) }.count
        return "\(visible) / \(all.count)"
    }
}

// MARK: - Appearance

private struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearanceRaw: String = SettingsView.Appearance.system.rawValue
    @AppStorage("invertDaySwipe") private var invertDaySwipe: Bool = false
    @AppStorage("preferCompactDayView") private var preferCompactDayView: Bool = false
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearanceRaw) {
                    ForEach(SettingsView.Appearance.allCases) { a in
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
                Toggle("Prefer compact mode", isOn: $preferCompactDayView)
                    .tint(.black)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Units

private struct UnitsSettingsView: View {
    @AppStorage(TemperatureUnit.defaultsKey, store: AppGroup.defaults) private var temperatureUnitRaw: String = TemperatureUnit.system.rawValue
    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults) private var timeFormatRaw: String = TimeFormat.system.rawValue

    var body: some View {
        Form {
            Section {
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
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    /// Dismisses Settings and re-opens the permissions onboarding sheet.
    let onReviewPermissions: () -> Void

    @Environment(EventStore.self) private var eventStore
    @Environment(WeatherStore.self) private var weatherStore
    @State private var showWhatsNew = false

    var body: some View {
        Form {
            if hasMissingPermission {
                Section("Permissions") {
                    Button(action: onReviewPermissions) {
                        LabeledContent("Review permissions") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                }
            }

            Section {
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
                    Text("Weather data provided by \(Image(systemName: "apple.logo"))\u{00a0}Weather")
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
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(whatsNew: WhatsNewContent.latest)
        }
    }

    private var hasMissingPermission: Bool {
        !eventStore.hasCalendarAccess || !weatherStore.hasLocationAccess
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
