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
            .opacity(0.4)
            .blur(radius: 3)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                    Text("Purchase Hibi Plus to unlock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Locked. Purchase Hibi Plus to unlock."))
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
