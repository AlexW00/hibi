import SwiftUI

/// Two binding holes at the top of a paper page.
struct BindingHoles: View {
    /// Horizontal gap between the two holes. The in-app paper card is ~330pt
    /// wide and uses 80; smaller surfaces (e.g. the systemSmall widget at
    /// ~158pt) need a proportionally tighter gap.
    var spacing: CGFloat = 80
    /// Diameter of each hole.
    var diameter: CGFloat = 10
    /// Distance from the top of the view to the holes.
    var topPadding: CGFloat = 10

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(PaperTints.bindingHole)
                    .frame(width: diameter, height: diameter)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                    }
            }
        }
        .padding(.top, topPadding)
    }
}

/// Dashed perforation edge along the bottom of a paper page.
struct PerforationEdge: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<60, id: \.self) { _ in
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 3, height: 8)
            }
        }
        .opacity(0.6)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
