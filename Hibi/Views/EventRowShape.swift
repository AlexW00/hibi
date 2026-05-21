import SwiftUI

/// Per-corner radii for an event/reminder row, depending on its position
/// in a vertical stack. Outer corners (the top of the first row, the
/// bottom of the last) use the host's default; inner corners — where
/// rows face each other across the schedule gap — use a tighter shape so
/// the stack reads as one continuous list rather than detached cards.
///
/// Shared between the in-app Day view rows and the widget so the visual
/// grammar stays identical at both scales. Only the *outer* radius
/// changes: the app uses its own 12pt corner; the widget extends to its
/// host container's bigger curve (~22pt) so the row visually traces the
/// widget edge.
struct EventRowEdges: Equatable {
    var top: Bool
    var bottom: Bool

    static let solo = EventRowEdges(top: true, bottom: true)

    /// Inner radius — the same value across the app and the widget so the
    /// gap between two stacked rows reads identically in both contexts.
    /// Significantly tighter than the outer 12pt so the seam is obvious.
    static let innerRadius: CGFloat = 5

    func radii(outer: CGFloat) -> RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: top ? outer : Self.innerRadius,
            bottomLeading: bottom ? outer : Self.innerRadius,
            bottomTrailing: bottom ? outer : Self.innerRadius,
            topTrailing: top ? outer : Self.innerRadius
        )
    }

    func shape(outer: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: radii(outer: outer), style: .continuous)
    }
}
