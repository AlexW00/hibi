import EventKit
import Notelet
import SwiftUI

struct SettingsView: View {
    /// Called by the "Review permissions" button. ContentView latches this and
    /// presents the onboarding sheet once this screen pops (can't show the
    /// onboarding sheet while Settings is still on the navigation stack).
    let onReopenPermissions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(EventStore.self) private var eventStore
    @Environment(WeatherStore.self) private var weatherStore
    @State private var whatsNewVersion: NoteletPresentedVersion?

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
        VStack(spacing: 0) {
            HibiPlusView()
                .background(Color(.systemGroupedBackground))
                .zIndex(1)
            Form {
                Section("General") {
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

            if hasMissingPermission {
                Section("Permissions") {
                    Button {
                        onReopenPermissions()
                        dismiss()
                    } label: {
                        LabeledContent {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        } label: {
                            Label("Review permissions", systemImage: "exclamationmark.triangle")
                        }
                    }
                    .tint(.primary)
                }
            }

            Section("About") {
                Button {
                    whatsNewVersion = .v(WhatsNewContent.version)
                } label: {
                    LabeledContent {
                        Text(Self.versionLabel)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("What's New")
                    }
                }
                .tint(.primary)

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

                NavigationLink {
                    StampNoiseDebugView()
                } label: {
                    Label("Stamp Noise", systemImage: "drop")
                }
            }
            #endif
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color(.systemGroupedBackground),
                             Color(.systemGroupedBackground).opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 24)
                .allowsHitTesting(false)
            }
        }
        .navigationTitle(Text(verbatim: "Hibi"))
        .noteletSheet(
            notes: WhatsNewContent.allNotes,
            version: whatsNewVersion,
            onDismiss: { whatsNewVersion = nil },
            configuration: WhatsNewContent.configuration
        )
    }

    private var calendarSummary: LocalizedStringResource {
        if eventStore.isDemoMode { return "Demo" }
        guard eventStore.hasCalendarAccess else { return "Not connected" }
        let all = eventStore.allCalendars()
        let visible = all.filter { !eventStore.isHidden($0) }.count
        return "\(visible) / \(all.count)"
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

// MARK: - Stamp Noise (DEBUG)

#if DEBUG
/// Coalesces rapid slider updates so the live Metal preview isn't asked to
/// re-render on every drag tick.
private final class Debouncer {
    private var workItem: DispatchWorkItem?
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

private struct StampNoiseDebugView: View {
    @AppStorage(StampNoise.valuesKey) private var raw = StampNoise.defaultRaw
    @AppStorage(StampNoise.presetKey) private var presetID = StampNoise.defaultPresetID
    @State private var values: [Float] = StampNoise.defaultValues
    // Pinned so re-rendering the form never re-triggers the (expensive)
    // composite/SDF rebuild inside the preview's HibiStamp.
    @State private var previewDate = Date()
    @State private var debouncer = Debouncer()

    var body: some View {
        VStack(spacing: 0) {
            // Sticky preview — always visible while the parameters scroll.
            HibiStamp(purchased: true, date: previewDate, size: 180)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGroupedBackground))
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.6)
                }
                .zIndex(1)

            Form {
                Section("Preset") {
                    Picker("Preset", selection: $presetID) {
                        Text(verbatim: "Default").tag(StampNoise.defaultPresetID)
                        Text(verbatim: "Custom").tag(StampNoise.customPresetID)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: presetID) { _, newValue in
                        // Selecting Default resets; Custom is just free-edit mode.
                        guard newValue == StampNoise.defaultPresetID else { return }
                        values = StampNoise.defaultValues
                        persistNow()
                    }
                }

                Section("Parameters") {
                    ForEach(StampNoise.Param.allCases) { param in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(verbatim: param.label)
                                    .font(.subheadline)
                                Spacer()
                                Text(verbatim: String(format: "%.2f", Double(values[param.rawValue])))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: binding(for: param),
                                   in: Double(param.range.lowerBound)...Double(param.range.upperBound))
                                .tint(.black)
                            Text(verbatim: param.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text(verbatim: "Stamp Noise"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { values = StampNoise.decode(raw) }
    }

    private func binding(for param: StampNoise.Param) -> Binding<Double> {
        Binding(
            get: { Double(values[param.rawValue]) },
            set: { newValue in
                values[param.rawValue] = Float(newValue)
                if presetID != StampNoise.customPresetID {
                    presetID = StampNoise.customPresetID
                }
                schedulePersist()
            }
        )
    }

    /// Debounced write — keeps the slider responsive while the preview only
    /// re-renders a few times per second.
    private func schedulePersist() {
        let snapshot = values
        debouncer.schedule(after: 0.09) {
            UserDefaults.standard.set(StampNoise.encode(snapshot), forKey: StampNoise.valuesKey)
        }
    }

    private func persistNow() {
        raw = StampNoise.encode(values)
    }
}
#endif

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
