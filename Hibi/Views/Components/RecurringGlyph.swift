import SwiftUI

/// Small "this event repeats" indicator shown next to a title in event rows/cards.
struct RecurringGlyph: View {
    var size: CGFloat = 9

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Recurring"))
    }
}
