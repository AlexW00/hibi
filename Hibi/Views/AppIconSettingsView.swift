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

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.body)
                        .foregroundStyle(isUnlocked ? .primary : .secondary)
                    MarqueeText(text: String(localized: option.subtitle), pixelsPerSecond: 13)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                trailingIcon
            }
            .padding(.vertical, 4)
        }
        .disabled(!isUnlocked)
        .tint(.primary)
    }

    @ViewBuilder
    private var trailingIcon: some View {
        if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.accent)
                .font(.title3)
        }
    }

    private var iconPreview: some View {
        Image(option.previewAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isUnlocked ? 1 : 0.4)
    }
}
