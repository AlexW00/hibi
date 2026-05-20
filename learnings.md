# Learnings

Hard-won lessons from building Hibi's infinite calendar scrolling. Read this before touching `MonthsScrollView` or `StreamView`.

## Infinite-scroll architecture in pure SwiftUI (iOS 26)

SwiftUI has no recycling container. `LazyVStack` is *lazy*, not *recycling* — once a view is created it stays in memory until the enclosing `ScrollView` is destroyed. Memory grows monotonically. The only workable pattern is a **bounded sliding window** of items, extended at the edges as the user scrolls, trimmed when it overflows a cap. See [`CalendarWindow`](Hibi/Views/MonthView.swift) and [`StreamWindow`](Hibi/Views/StreamView.swift).

A fixed-length ForEach over a huge range (e.g. `ForEach(-600...600)`) does not work: SwiftUI instantiates views cascade-style during initial layout and performance collapses.

## Don't extend mid-fling — defer to `.idle`

**Symptom we hit:** fast upward scroll caused "subtle drift for multiple years" per fling.

**Cause:** with `.scrollPosition(anchor: .center)`, every prepend during an active fling triggers SwiftUI to shift content to keep the pinned item centered. The fling's momentum continues in the opposite direction — so each prepend visually *adds* to the user's scroll distance. Many prepends per fling = years of drift. This is the documented iOS 26 batch-prepend anchor bug (Apple Developer Forums 731271).

**Fix:** extend only when `onScrollPhaseChange` reports `.idle`. No prepends mid-fling → no compounding drift. Size the initial window wide enough (`windowRadius = 24` months / `60` days) that a single fling almost never hits the wall.

## `onScrollGeometryChange` fires every frame — dangerous for pagination

**Symptom we hit:** flinging to the end loaded dozens of years in a few seconds and became laggy.

**Cause:** `onScrollGeometryChange` runs its `transform` on every frame during active scroll. Using it to trigger "extend by 6 months" means 30–120 frames of extension per fling. A synchronous `isExtending` guard doesn't hold across frames because each frame re-runs the closure after the previous extend completed.

**Fix:** don't use it for pagination at all. Drive extension off `position.viewID` (the visible item) changing, inside `.onScrollPhaseChange { .idle }`. One extend per settled position.

## Use invariant-based edge extension, not fixed batches

Instead of "when near edge, add N items," maintain an **invariant**: always keep ≥ `windowRadius` items on each side of the visible item. `extendIfNearEdge` computes `neededAbove` / `neededBelow` and refills exactly that many (capped by `extendBatch`). This is self-throttling — extensions stop as soon as the buffer is restored, regardless of how the user scrolls.

## `ScrollPosition` (imperative) beats `scrollPosition(id: $binding)` for programmatic scroll

**Symptom we hit:** tapping the active tab ("return to now") flakily jumped to the start of the list instead of today.

**Cause:** two races:
1. Setting `scrollTarget = today` when it already equalled today (re-tap after recent scroll) is a no-op binding update — SwiftUI doesn't re-scroll.
2. When the window also rebuilt (`recenter`) in the same tick, SwiftUI could process the data change first — losing the anchor and resetting scroll to top — before the binding update landed.

**Fix:** use `@State var position = ScrollPosition(idType: Int.self)` with `.scrollPosition($position, anchor: .center)`, and command scrolls imperatively via `position.scrollTo(id:)`. The command is always queued after the current state transaction, so it applies cleanly after content is laid out. Wrap in `withAnimation` if you want a glide.

## `.defaultScrollAnchor(.center)` ≠ "start on item X"

**Symptom we hit:** app opened to February instead of April (the seeded center month).

**Cause:** `defaultScrollAnchor(.center)` centers the *content pixels* in the viewport, not a specific item. `LazyVStack` doesn't know all item heights upfront, and asymmetric padding (e.g. `.padding(.bottom, 120)`) skews the midpoint. The pixel center lands on a different item than the array middle.

**Fix:** initialize `ScrollPosition` in the view's `init` with a pending `scrollTo(id: seedID, anchor: .center)`. SwiftUI applies it on first layout and lands exactly on the seeded item. Drop `defaultScrollAnchor`.

## Composite-Int IDs beat String IDs for scroll targets

`MonthKey.id = year * 100 + month` and `DayKey.id = year * 10_000 + month * 100 + day` are stable, cheap, and `Hashable` without `DateFormatter` allocations. `ScrollPosition(idType: Int.self)` + `position.viewID(type: Int.self)` works directly with `ForEach`'s implicit Identifiable id — no explicit `.id(key)` needed. Decompose with `/` and `%` when you need the components back.

## Non-target UI goes outside `.scrollTargetLayout()`

Decorative views (e.g. `EndOfListIndicator`) that shouldn't receive scroll targeting must live *outside* the container `.scrollTargetLayout()` is attached to — typically by wrapping the `LazyVStack` in a non-lazy `VStack` and putting decorations as siblings. Otherwise `position.viewID` can return nil when the decoration is centered, breaking edge-detection.

Make `onScrollPhaseChange` resilient anyway:

```swift
let id = position.viewID(type: Int.self) ?? window.visibleMonthID
window.extendIfNearEdge(visibleID: id)
```

## What we rejected

- **Fixed huge range** (`ForEach(-600...600)`): cascade instantiation during `scrollPosition(initialAnchor:)` resolution. Fatbobman documents this as a known perf trap.
- **Geometry-based edge trigger** (`onScrollGeometryChange` + `EdgeProximity`): fires per-frame, `Equatable` debouncing doesn't help because content-size changes flip the value back. Root cause of our multi-year cascade.
- **`scrollPosition(id: $scrollTarget)` binding for programmatic scroll**: race-prone when data and position update in the same tick; no-op when binding value hasn't changed.
- **`defaultScrollAnchor(.center)` for "start on today"**: imprecise with lazy, variable-height content.

## `GeometryReader` inside `.background` causes flicker when the container resizes per-frame

**Symptom we hit:** the draggable Schedule separator in `DayView` flickered heavily during slow drags. Both the paper stack *and* the events list rows rippled. When the user stopped moving but kept their finger down, the flicker would **smoothly settle over ~10-20 frames** — not snap. That settling pattern is the signature.

**Cause:** every `DayEventRow` had a progress fill drawn with this pattern:

```swift
.background(alignment: .leading) {
    GeometryReader { geo in
        event.tint.opacity(...)
            .frame(width: geo.size.width * CGFloat(fillAmount))
    }
}
```

`GeometryReader` reports geometry in a **follow-up layout pass**, not synchronously. When a drag resizes the ScrollView's container 60×/sec, every row's GR re-reports its width in an async pass, that triggers another layout pass, which the GR republishes again. The system iterates toward convergence over many frames — visible as flicker mid-drag and as a deceleration-style settle when input stops. Apple flagged this in WWDC23 *Demystify SwiftUI performance* and shipped `onGeometryChange` (iOS 18) as the replacement.

A second-order contributor was the gesture transaction inheriting an ambient animation context (TabView / NavigationStack iOS-26 transitions wrap their content in animated transactions). Without `t.disablesAnimations = true` on the per-frame writes, `Animatable` `.padding` / `.frame` modifiers got re-bound to that inherited animation.

**Fix.** For fractional-width fills, use `.scaleEffect` on a full-width `Rectangle`:

```swift
.background(alignment: .leading) {
    Rectangle()
        .fill(event.tint.opacity(...))
        .scaleEffect(x: CGFloat(fillAmount), y: 1, anchor: .leading)
}
```

`scaleEffect` is a render-time transform — no layout pass, no async geometry, pixel-identical visual. For any per-frame state write driving layout (gestures, animation drivers), also set both flags on the transaction:

```swift
var t = Transaction()
t.disablesAnimations = true
t.scrollContentOffsetAdjustmentBehavior = .disabled   // iOS 18+
withTransaction(t) { state = newValue }
```

The scroll-offset flag stops a `ScrollView` from animating its own content offset when its container size changes; the disabled-animations flag stops inherited animation contexts from re-binding to our writes. Both are needed when the per-frame write resizes a `ScrollView`'s container.

**Diagnostic heuristic.** If a slow drag flickers and the flicker *smooths out over a fraction of a second* when input stops, suspect an async-layout convergence loop — almost always a `GeometryReader` placed where a fractional `.frame` or `.padding` could be a `.scaleEffect` instead. Value-scoped `.animation(_:value:)` modifiers are a red herring here: they only fire when *their* value changes, not when neighboring layout changes.

## Reference: the research brief

The full background on why SwiftUI infinite scrolling is structurally hard (vs. `UICollectionView`), and why HorizonCalendar (UIKit) beats any pure-SwiftUI implementation for flat memory over decades of scroll, is in the original deep-research document — ask the user for it if needed. Hibi's approach is the "90% solution" sliding-window pattern it recommends.
