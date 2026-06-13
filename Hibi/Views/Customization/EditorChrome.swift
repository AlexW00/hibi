import SwiftUI
import UIKit

// MARK: - Adaptive colours (local helpers)

/// Adaptive `paper-card-1` — reuses the existing `PaperTints.card1` token so the two
/// values stay in sync. `#FBFAF7` light / `#242424` dark.
private let paperCard1: Color = PaperTints.card1

/// `ink-edge` border: asymmetric low-opacity — `black@0.08` in light, `white@0.12` in dark.
private let inkEdge = Color(uiColor: UIColor { trait in
    if trait.userInterfaceStyle == .dark {
        return UIColor(white: 1.0, alpha: 0.12)
    } else {
        return UIColor(white: 0.0, alpha: 0.08)
    }
})

// MARK: - IconWellButton

/// A circular icon-well button matching the editor toolbar design.
///
/// Dimensions: 38 × 38 pt, always circular.
/// Fill: `paper-card-1` (adaptive via `PaperTints.card1`).
/// Border: 0.5 pt `ink-edge` (`black@0.08` light / `white@0.12` dark).
/// Shadow: 0 1 pt 2 pt `black@0.08`.
/// Press: `scaleEffect(0.94)`.
///
/// `label` is read by VoiceOver. `symbolName` must be a valid SF Symbol.
struct IconWellButton: View {
    var symbolName: String
    var label: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: symbolName)
                .labelStyle(.iconOnly)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AdaptivePalette.primaryInk)
                .frame(width: 38, height: 38)
                .background(paperCard1, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(inkEdge, lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(_IconWellButtonStyle())
        .accessibilityLabel(label)
    }
}

/// Internal `ButtonStyle` that applies the press-scale with animation.
private struct _IconWellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - SegmentedProgressPill

/// A row of N pill segments indicating wizard progress.
///
/// Each segment is 26 × 6 pt with corner-radius 999 and a 6 pt gap between them.
/// Segments with index ≤ `current` are filled with `AdaptivePalette.primaryInk`;
/// others use `primaryInk` at 18% opacity.
struct SegmentedProgressPill: View {
    var count: Int
    var current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current
                          ? AdaptivePalette.primaryInk
                          : AdaptivePalette.primaryInk.opacity(0.18))
                    .frame(width: 26, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
        .accessibilityValue("\(current + 1)")
    }
}

// MARK: - WizardPrimaryButtonStyle

/// Full-width pill button: ink fill, paper-card-1 label, 15 pt semibold.
/// Press dims the fill opacity.
struct WizardPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(paperCard1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(AdaptivePalette.primaryInk
                        .opacity(configuration.isPressed ? 0.75 : 1.0))
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - WizardSecondaryButtonStyle

/// Full-width pill button: transparent fill, 0.5 pt primaryInk@0.30 border, ink label.
struct WizardSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AdaptivePalette.primaryInk
                .opacity(configuration.isPressed ? 0.6 : 1.0))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .strokeBorder(
                        AdaptivePalette.primaryInk.opacity(0.30),
                        lineWidth: 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - WizardNavBar

/// Bottom navigation bar for the paper-customization wizard.
///
/// - Page 1 (no back action): primary button fills the full width.
/// - Pages 2+ (back action provided): Back (secondary, flex 1) + primary (flex 1), gap 10.
///
/// All title strings are `LocalizedStringKey`; callers supply localized values.
struct WizardNavBar: View {
    /// Title for the primary action button (e.g. "Next", "Done").
    var primaryTitle: LocalizedStringKey
    /// Closure for the primary action.
    var primaryAction: () -> Void
    /// Title for the back button. When `nil` the back button is hidden (page 1).
    var backTitle: LocalizedStringKey?
    /// Closure for the back action. Required when `backTitle` is non-nil.
    var backAction: (() -> Void)?

    var body: some View {
        if let backTitle {
            HStack(spacing: 10) {
                Button(backTitle, action: backAction ?? {})
                    .buttonStyle(WizardSecondaryButtonStyle())

                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(WizardPrimaryButtonStyle())
            }
        } else {
            Button(primaryTitle, action: primaryAction)
                .buttonStyle(WizardPrimaryButtonStyle())
        }
    }
}

// MARK: - Preview

#Preview("Editor Chrome — light") {
    VStack(spacing: 32) {
        // IconWellButton
        HStack(spacing: 12) {
            IconWellButton(symbolName: "xmark", label: "Close", action: {})
            IconWellButton(symbolName: "arrow.uturn.backward", label: "Undo", action: {})
            IconWellButton(symbolName: "arrow.uturn.forward", label: "Redo", action: {})
            IconWellButton(symbolName: "chevron.left", label: "Back", action: {})
            IconWellButton(symbolName: "checkmark", label: "Save", action: {})
        }

        Divider()

        // SegmentedProgressPill — all three states
        VStack(spacing: 8) {
            SegmentedProgressPill(count: 3, current: 0)
            SegmentedProgressPill(count: 3, current: 1)
            SegmentedProgressPill(count: 3, current: 2)
        }

        Divider()

        // Button styles
        VStack(spacing: 12) {
            Button("Next", action: {})
                .buttonStyle(WizardPrimaryButtonStyle())
            Button("Back", action: {})
                .buttonStyle(WizardSecondaryButtonStyle())
        }

        Divider()

        // WizardNavBar — page 1 (primary only)
        VStack(spacing: 12) {
            Text("Page 1 — primary only")
                .font(.caption)
                .foregroundStyle(.secondary)
            WizardNavBar(
                primaryTitle: "Next",
                primaryAction: {}
            )
        }

        // WizardNavBar — pages 2+ (back + primary)
        VStack(spacing: 12) {
            Text("Page 2+ — back + primary")
                .font(.caption)
                .foregroundStyle(.secondary)
            WizardNavBar(
                primaryTitle: "Done",
                primaryAction: {},
                backTitle: "Back",
                backAction: {}
            )
        }
    }
    .padding(24)
    .background(Color(.systemBackground))
}

#Preview("Editor Chrome — dark") {
    VStack(spacing: 32) {
        HStack(spacing: 12) {
            IconWellButton(symbolName: "xmark", label: "Close", action: {})
            IconWellButton(symbolName: "arrow.uturn.backward", label: "Undo", action: {})
            IconWellButton(symbolName: "arrow.uturn.forward", label: "Redo", action: {})
        }

        SegmentedProgressPill(count: 3, current: 1)

        WizardNavBar(
            primaryTitle: "Done",
            primaryAction: {},
            backTitle: "Back",
            backAction: {}
        )
    }
    .padding(24)
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
