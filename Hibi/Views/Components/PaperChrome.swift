import SwiftUI

/// Two binding holes at the top of a paper page.
struct BindingHoles: View {
    var body: some View {
        HStack(spacing: 80) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(PaperTints.bindingHole)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                    }
            }
        }
        .padding(.top, 10)
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
