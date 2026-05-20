import SwiftUI
import UIKit

// A UIScrollView wrapper that hijacks scroll deltas to drive a bound
// `progress` value (0…1) until fully collapsed, then yields to native
// scrolling. Mirrors UISheetPresentationController's
// `prefersScrollingExpandsWhenScrolledToEdge` behavior: scrolling up at the
// top of the inner list first collapses the paper stack, then scrolls; pulling
// down at the top of the list first re-expands the paper, then rubberbands.
// Pure SwiftUI couldn't do this — SwiftUI ScrollView gives us no per-frame
// delta hook with the ability to cancel the offset change.
//
// All per-frame writes to `progress` go through a transaction that disables
// animations and `scrollContentOffsetAdjustmentBehavior`. See
// learnings.md ("GeometryReader inside .background causes flicker…") for the
// full rationale — the same anti-flicker rules apply here because our progress
// write resizes a SwiftUI ScrollView ancestor (the paper stack region).
struct HijackingScrollView<Content: View>: UIViewRepresentable {
    @Binding var progress: CGFloat
    let collapseDistance: CGFloat
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        let binding = $progress
        return Coordinator(
            writeProgress: { newValue in
                // Per-frame writes must be un-animated AND must suppress the
                // ScrollView's own content-offset adjustment when its
                // container size changes as a side effect. See learnings.md.
                var t = Transaction()
                t.disablesAnimations = true
                t.scrollContentOffsetAdjustmentBehavior = .disabled
                withTransaction(t) { binding.wrappedValue = newValue }
            },
            snapProgress: { target in
                var t = Transaction()
                t.animation = .spring(response: 0.38, dampingFraction: 0.86)
                t.scrollContentOffsetAdjustmentBehavior = .disabled
                withTransaction(t) { binding.wrappedValue = target }
            },
            collapseDistance: collapseDistance,
            initialProgress: progress
        )
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear

        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        host.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(host.view)
        let contentGuide = scrollView.contentLayoutGuide
        let frameGuide = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: frameGuide.widthAnchor),
        ])

        context.coordinator.hostingController = host
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.collapseDistance = collapseDistance
        context.coordinator.currentProgress = progress
        let binding = $progress
        context.coordinator.writeProgress = { newValue in
            var t = Transaction()
            t.disablesAnimations = true
            t.scrollContentOffsetAdjustmentBehavior = .disabled
            withTransaction(t) { binding.wrappedValue = newValue }
        }
        context.coordinator.snapProgress = { target in
            var t = Transaction()
            t.animation = .spring(response: 0.38, dampingFraction: 0.86)
            t.scrollContentOffsetAdjustmentBehavior = .disabled
            withTransaction(t) { binding.wrappedValue = target }
        }
        context.coordinator.hostingController?.rootView = content()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var writeProgress: (CGFloat) -> Void
        var snapProgress: (CGFloat) -> Void
        var collapseDistance: CGFloat
        var currentProgress: CGFloat
        var lastContentOffsetY: CGFloat = 0
        // Strong reference — the scroll view retains only the host's `view`,
        // not the controller itself. Without this, the controller deallocates
        // at the end of makeUIView and rootView updates become no-ops.
        var hostingController: UIHostingController<Content>?

        init(
            writeProgress: @escaping (CGFloat) -> Void,
            snapProgress: @escaping (CGFloat) -> Void,
            collapseDistance: CGFloat,
            initialProgress: CGFloat
        ) {
            self.writeProgress = writeProgress
            self.snapProgress = snapProgress
            self.collapseDistance = collapseDistance
            self.currentProgress = initialProgress
        }

        // Why these delegate methods write progress through a transaction:
        // resizing the SwiftUI ScrollView's frame (which is what driving
        // `progress` does) during a per-frame scroll callback risks
        // (a) inheriting an ambient animation context — async-resolved
        // Animatable modifiers would re-bind to that animation and visibly
        // flicker; (b) the ScrollView animating its own content-offset to
        // compensate for the container resize. Both are addressed by the
        // disablesAnimations + scrollContentOffsetAdjustmentBehavior pair
        // applied inside writeProgress. See learnings.md flicker section.

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            lastContentOffsetY = scrollView.contentOffset.y
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView.isDragging || scrollView.isDecelerating else { return }
            guard collapseDistance > 0 else { return }

            let currentY = scrollView.contentOffset.y
            let dy = currentY - lastContentOffsetY

            if currentProgress < 1, currentY > 0 {
                // Scrolling up while paper not fully collapsed: consume the
                // portion of the motion that crosses into positive territory
                // and leak any leftover dy back to the scroll view so the
                // inner list begins scrolling at the exact pixel the collapse
                // completes.
                //
                // The `currentY > 0` guard (and `fromY` clamp below) are
                // what stop a downward flick's rubberband-return from being
                // misread as "user is scrolling up". Without it, the spring-
                // back from a deep negative offset produces positive dy
                // frames and quietly drives progress toward 1.
                let fromY = max(0, lastContentOffsetY)
                let effectiveDy = currentY - fromY
                if effectiveDy > 0 {
                    let remaining = (1 - currentProgress) * collapseDistance
                    let consumed = min(effectiveDy, remaining)
                    let newProgress = min(1, currentProgress + consumed / collapseDistance)
                    currentProgress = newProgress
                    writeProgress(newProgress)
                    scrollView.contentOffset.y = fromY + (effectiveDy - consumed)
                }
            } else if currentProgress > 0, dy < 0, lastContentOffsetY <= 0 {
                // At top of inner list, pulling down: consume rubberband
                // delta to drive progress back to 0 (re-expand paper).
                let remaining = -currentProgress * collapseDistance
                let consumed = max(dy, remaining)
                let newProgress = max(0, currentProgress + consumed / collapseDistance)
                currentProgress = newProgress
                writeProgress(newProgress)
                scrollView.contentOffset.y = 0
            }

            lastContentOffsetY = scrollView.contentOffset.y
        }

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            // Mid-collapse: kill momentum so the inner list doesn't fling
            // while we're still animating the paper stack snap.
            if currentProgress > 0, currentProgress < 1 {
                targetContentOffset.pointee.y = 0
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                let velocityY = scrollView.panGestureRecognizer.velocity(in: scrollView).y
                snap(velocity: velocityY)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            snap(velocity: 0)
        }

        private func snap(velocity: CGFloat) {
            guard currentProgress > 0, currentProgress < 1 else { return }
            let target: CGFloat
            if velocity < -200 {
                target = 1
            } else if velocity > 200 {
                target = 0
            } else {
                target = currentProgress < 0.5 ? 0 : 1
            }
            currentProgress = target
            snapProgress(target)
        }
    }
}
