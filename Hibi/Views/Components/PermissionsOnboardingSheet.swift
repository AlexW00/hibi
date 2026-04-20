import SwiftUI

// MARK: - Item

/// One permission entry rendered in the onboarding sheet. Platform-agnostic
/// (no UIKit/EventKit) so macOS/iPadOS builds and additional permissions —
/// Notifications, Contacts, Reminders — can append rows without view changes.
struct PermissionOnboardingItem: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    /// Required permissions gate the "Continue" button — the user can't finish
    /// onboarding without granting them. Optional permissions can be skipped.
    let isRequired: Bool
    let isGranted: @MainActor () -> Bool
    let isDenied: @MainActor () -> Bool
    let request: @MainActor () async -> Void
    let openSettings: @MainActor () -> Void
}

// MARK: - Sheet

struct PermissionsOnboardingSheet: View {
    let items: [PermissionOnboardingItem]
    let onContinue: () -> Void

    @State private var appeared = false
    /// Snapshotted once on first appearance. Prevents auto-dismiss from firing
    /// when the sheet is re-opened from Settings while everything is already
    /// granted — auto-dismiss should only celebrate a fresh completion.
    @State private var startedWithAllGranted = true
    /// Brief success state shown between the last grant and the actual dismiss,
    /// so the user sees confirmation instead of the sheet just yanking away.
    @State private var isCelebrating = false
    @AppStorage("useSimpleFont") private var useSimpleFont: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 32)
                .padding(.horizontal, 28)

            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PermissionRow(item: item)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.85)
                                .delay(0.18 + Double(index) * 0.08),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .frame(maxWidth: 460)

            Spacer(minLength: 24)

            Button {
                onContinue()
                dismiss()
            } label: {
                continueLabel
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(isCelebrating ? Color.green : .primary)
            // In the normal state the tint is `.primary` (black/white depending
            // on appearance) so the label needs the inverse for contrast.
            // During celebration the tint is green, and white reads on green
            // in both light and dark.
            .foregroundStyle(isCelebrating ? Color.white : Color(.systemBackground))
            .disabled(!canContinue)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .frame(maxWidth: 460)
            .opacity(appeared ? 1 : 0)
            .animation(
                .easeOut(duration: 0.35)
                    .delay(0.18 + Double(items.count) * 0.08 + 0.05),
                value: appeared
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isCelebrating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationBackground {
            AppBackgroundGradient().ignoresSafeArea()
        }
        .onAppear {
            appeared = true
            startedWithAllGranted = allGranted
        }
        .onChange(of: allGranted) { _, newValue in
            // Auto-dismiss only when the user just completed the final grant
            // in THIS session. If the sheet was opened (e.g. from Settings)
            // with everything already granted, don't yank it away — the user
            // came here on purpose.
            guard newValue, !startedWithAllGranted, !isCelebrating else { return }
            isCelebrating = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                onContinue()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var continueLabel: some View {
        if isCelebrating {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                Text("All set")
            }
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        } else {
            Text("Continue")
                .transition(.opacity)
        }
    }

    /// Continue is disabled until every required permission is granted.
    /// Computed each render — `isGranted()` is a light wrapper over PermissionsKit's
    /// system status query, which re-evaluates against the live authorization state.
    private var canContinue: Bool {
        items.filter(\.isRequired).allSatisfy { $0.isGranted() }
    }

    /// True when every row (required + optional) is granted — the cue for
    /// auto-dismiss.
    private var allGranted: Bool {
        items.allSatisfy { $0.isGranted() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome")
                .font(.appSerif(size: 34, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
            Text("A couple of permissions so Hibi can do its thing.")
                .font(.appSerif(size: 16, italic: true, simple: useSimpleFont))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Row

private struct PermissionRow: View {
    let item: PermissionOnboardingItem
    @State private var isRequesting = false

    var body: some View {
        HStack(spacing: 14) {
            iconBadge
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .frame(minWidth: 64)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PaperTints.card1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(item.tint)
                .frame(width: 36, height: 36)
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        // Recompute on every render — PermissionsKit reads system status, cheap.
        let granted = item.isGranted()
        let denied = item.isDenied()

        Group {
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Color.green.gradient)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if isRequesting {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            } else if denied {
                Button {
                    item.openSettings()
                } label: {
                    Text("Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            } else {
                Button {
                    Task { @MainActor in
                        isRequesting = true
                        await item.request()
                        // isGranted flips inside request(); SwiftUI re-evaluates
                        // and the checkmark transitions in. Clear the requesting
                        // flag last so the row never shows both the spinner and
                        // the stale Allow button at the same time.
                        isRequesting = false
                    }
                } label: {
                    Text("Allow")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .foregroundStyle(Color(.systemBackground))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: granted)
        .animation(.easeInOut(duration: 0.2), value: denied)
        .animation(.easeInOut(duration: 0.15), value: isRequesting)
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    PermissionsOnboardingSheet(
        items: [
            PermissionOnboardingItem(
                id: "calendar",
                icon: "calendar",
                tint: Color(.displayP3, red: 0.78, green: 0.49, blue: 0.42, opacity: 1),
                title: "Calendar",
                description: "Show and edit the events from your system calendars.",
                isRequired: true,
                isGranted: { false },
                isDenied: { false },
                request: { },
                openSettings: { }
            ),
            PermissionOnboardingItem(
                id: "location",
                icon: "location.fill",
                tint: Color(.displayP3, red: 0.38, green: 0.55, blue: 0.76, opacity: 1),
                title: "Location",
                description: "Local weather and sunrise / sunset on each day.",
                isRequired: false,
                isGranted: { false },
                isDenied: { false },
                request: { },
                openSettings: { }
            ),
        ],
        onContinue: { }
    )
}
