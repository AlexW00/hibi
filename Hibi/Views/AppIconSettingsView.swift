import SwiftUI

struct AppIconSettingsView: View {
    @Environment(AppIconManager.self) private var iconManager

    var body: some View {
        List {
            ForEach(AppIconManager.icons) { option in
                AppIconRow(
                    option: option,
                    isSelected: iconManager.selectedIconID == option.id,
                    isUnlocked: iconManager.isUnlocked(option)
                ) {
                    Task { await iconManager.select(option) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .task { await iconManager.loadInstallDate() }
    }
}

private struct AppIconRow: View {
    let option: AppIconOption
    let isSelected: Bool
    let isUnlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(option.previewAssetName)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.ultraThinMaterial, in: Circle())
                                .offset(x: 4, y: 4)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.body)
                        .foregroundStyle(isUnlocked ? .primary : .secondary)
                    Text(option.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !isUnlocked {
                        Text("Available to early users")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accent)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(!isUnlocked)
        .tint(.primary)
    }
}
