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
    @State private var stackProgress: CGFloat = 0
    @State private var snapTick: Int = 0

    private let stackExpandedHeight: CGFloat = 360
    private let stackCollapsedHeight: CGFloat = 210
    private let stackCollapseRange: CGFloat = 150

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
                .frame(height: stackHeight)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { toggleStackCollapse() }
                .zIndex(1)
            HijackingScrollView(
                progress: $stackProgress,
                collapseDistance: stackCollapseRange,
                onSnap: { snapTick &+= 1 }
            ) {
                settingsContent
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: snapTick)
            .background(Color(.systemGroupedBackground))
            .zIndex(0)
        }
        .navigationTitle(Text(verbatim: "Hibi"))
        .noteletSheet(
            notes: WhatsNewContent.allNotes,
            version: whatsNewVersion,
            onDismiss: { whatsNewVersion = nil },
            configuration: WhatsNewContent.configuration
        )
    }

    private var stackHeight: CGFloat {
        stackExpandedHeight + (stackCollapsedHeight - stackExpandedHeight) * stackProgress
    }

    private func toggleStackCollapse() {
        let target: CGFloat = stackProgress >= 0.5 ? 0 : 1
        guard target != stackProgress else { return }
        snapTick &+= 1
        var t = Transaction()
        t.animation = .spring(response: 0.38, dampingFraction: 0.86)
        t.scrollContentOffsetAdjustmentBehavior = .disabled
        withTransaction(t) {
            stackProgress = target
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 18) {
            GroupBox {
                VStack(spacing: 0) {
                    settingsRow {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            Label("Appearance", systemImage: "paintbrush")
                        }
                    }
                    Divider()
                    settingsRow {
                        NavigationLink {
                            UnitsSettingsView()
                        } label: {
                            Label("Units", systemImage: "ruler")
                        }
                    }
                    Divider()
                    settingsRow {
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
                }
            } label: { Text("General") }

            if hasMissingPermission {
                GroupBox {
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
                } label: { Text("Permissions") }
            }

            GroupBox {
                VStack(spacing: 0) {
                    settingsRow {
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
                    }
                    Divider()
                    settingsRow {
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
                }
            } label: { Text("About") }

            #if DEBUG
            GroupBox {
                Toggle(isOn: Binding(
                    get: { eventStore.isDemoMode },
                    set: { eventStore.setDemoMode($0) }
                )) {
                    Label("Demo Mode", systemImage: "wand.and.stars")
                }
                .tint(.black)
            } label: { Text("Debug") }
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground).opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)
        }
    }

    private func settingsRow<LabelView: View>(@ViewBuilder _ label: () -> LabelView) -> some View {
        label()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
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
