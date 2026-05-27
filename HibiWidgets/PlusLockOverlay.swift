import SwiftUI

/// Locked-state treatment for the Hibi Plus widgets.
///
/// The user's real day still renders underneath — desaturated and dimmed — so
/// the widget reads as "your schedule, behind a small paywall" rather than a
/// blank placeholder. A centered lock chip with a short prompt sits on top.
/// Cleared automatically once `PlusStore` records the entitlement and reloads
/// timelines.
struct PlusLockOverlay: ViewModifier {
    func body(content: Content) -> some View {
        content
            .grayscale(1)
            .opacity(0.5)
            .overlay {
                VStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(verbatim: "Hibi Plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Unlock widgets in the app")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 13)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(PaperTints.card1.opacity(0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                )
                .padding(8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Locked. Unlock widgets with Hibi Plus in the app."))
    }
}

extension View {
    /// Applies the Hibi Plus lock treatment when `locked` is `true`.
    @ViewBuilder
    func plusLocked(_ locked: Bool) -> some View {
        if locked {
            modifier(PlusLockOverlay())
        } else {
            self
        }
    }
}
