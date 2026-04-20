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

## Re-anchor after window extension to stop `.viewAligned` re-snapping

**Symptom we hit:** scrolling the Week stream would "jump a few days" right as the fling settled. Small, occasional, always at the end of a scroll.

**Cause:** when `onScrollPhaseChange` hits `.idle` near an edge, we prepend/append rows. `.scrollPosition(anchor: .center)` does re-center the pinned id, but the new layout lands a handful of pixels off the `.viewAligned` grid, so the scroll behavior animates a corrective snap — often landing on the neighbouring day/month.

**Fix:** have `extendIfNearEdge` return `Bool` and, when it mutated the window, immediately call `position.scrollTo(id: pinnedID)`. The imperative command is queued after the data change and pre-empts `.viewAligned`'s snap. Cheap, no animation needed.

## Preload the window's months so row heights don't shift mid-deceleration

**Symptom we hit:** `StreamDayRow` has variable height (`minHeight: events.isEmpty ? 92 : nil`). `ensureLoaded` is triggered per-row via `.task(id: MonthKey(...))`, so on a fast scroll into an unseen month, rows first render empty (92pt) and grow a frame or two later once EventKit returns. If that height change lands during deceleration, `.viewAligned` recomputes its snap target against the new layout — user sees a jump.

**Fix:** drive `ensureLoaded` from the window itself with `.task(id: windowMonthsSignature)` over the unique `MonthKey`s in `window.days`. Re-fires on extend, not on every scroll tick. Events are cached before the row even appears, so heights are stable when the scroll arrives.

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

## Reference: the research brief

The full background on why SwiftUI infinite scrolling is structurally hard (vs. `UICollectionView`), and why HorizonCalendar (UIKit) beats any pure-SwiftUI implementation for flat memory over decades of scroll, is in the original deep-research document — ask the user for it if needed. Hibi's approach is the "90% solution" sliding-window pattern it recommends.
