import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.system.rawValue

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
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
                            Text(a.label).tag(a.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Calendar") {
                    LabeledContent("Apple Calendar", value: "Not connected")
                    LabeledContent("Default Category", value: "Work")
                }

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
}
