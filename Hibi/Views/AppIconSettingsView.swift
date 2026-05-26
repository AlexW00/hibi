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
                iconPreview
                labels
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

    private var iconPreview: some View {
        Image(option.previewAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if !isUnlocked {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.background.opacity(0.55))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
    }

    @ViewBuilder
    private var labels: some View {
        if isUnlocked {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.body)
                Text(option.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("Available to early users")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
