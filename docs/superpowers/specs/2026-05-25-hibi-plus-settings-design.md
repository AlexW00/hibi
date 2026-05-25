# Hibi Plus — Settings UI (design)

Date: 2026-05-25
Branch: `claude/sharp-cannon-oZ0T9`

## What we're building

A "Hibi Plus" support-tier surface at the **top of Settings**, rendered as a
miniature **two-page paper stack** that reuses the Day view's look and feel:

- A **stamp card** (Frontrunner) — a placeholder hanko-style seal. Empty
  ("slot") before purchase; stamped after.
- A **"what's inside" feature card** — app-icon carousel, two perks, an
  early-access (Widgets) promo tile, and the purchase CTA.

The user can **swipe** to switch between the two pages and **tap** to
expand/collapse the front page — both using the same animation grammar as the
Day view tear stack. Purchasing runs a success animation, then flips back to
the stamp card and places the seal.

This pass implements the **UI and interaction only**. No real IAP — the CTA
toggles a non-persistent in-memory `isPlus` flag. The stamp is a placeholder
intended to be replaced by a custom Metal shader later.

## Non-goals (explicitly out of scope)

- No StoreKit / real in-app purchase. CTA toggles in-memory state only; not
  persisted across launches.
- App-icon carousel uses the **current app icon repeated** (a SwiftUI
  facsimile) — no real alternate icons yet.
- Stamp + stamp-in animation are **placeholders**, structured so a Metal
  shader can replace the seal's internals later.

## Constraints / environment

- Built on Linux **without Xcode** — code is written against existing patterns
  but **cannot be compiled or run here**. On-device verification is required
  before merge, especially: (a) drag-vs-List-scroll gesture precedence,
  (b) animation feel, (c) layout sizing in light + dark.
- iOS 26 min target, SwiftUI only, `@Observable` stores, `de_DE`-pinned
  calendar locale, Instrument Serif via `AppFont`.

## Architecture

### Approach: dedicated component (not a Day-view refactor)

A new, self-contained `HibiPlusView` reuses the Day view's animation
*grammar* (peek/inset constants, the collapse spring
`.spring(response: 0.38, dampingFraction: 0.86)`, easeIn/easeOut tear
timings, the no-anim reset transaction) but does **not** share code with
`DayView.tearStack`. The Day view stack is intricate, fragile (see
`learnings.md`), tied to 3 cards + schedule/weather content, and battle-tested
— forking cleanly avoids regressing the core Day view for no real gain.

### State (owned by `HibiPlusView`, all in-memory `@State`)

- `frontIndex: Int` — 0 = stamp card, 1 = feature card. Default 0.
- `expanded: [Bool]` (count 2) — per-card expand state, preserved across swipes.
- `isPlus: Bool`, `purchaseDate: Date?` — non-persistent purchase state.
- Drag/animation: `dragY`, `isAnimating`, `cardShiftAmount`, `tearDirection`,
  `tearCommitCount` (haptic), `stampToken` (triggers stamp-in),
  `ctaState` (idle/success).

Nothing else in the app needs Plus state today, so no app-wide store. If that
changes later, lift to an `@Observable PlusStore` injected via `.environment`.

## The two-card stack

- **Front card** (z-top): active card; draggable; carries the bottom
  perforation edge (`PerforationEdge`). Shadowed like Day view's front card.
- **Back card** (z-below): the *other* card, peeking with horizontal inset +
  bottom peek, styled like Day view's `--d1` (card2 tint, hairline border,
  softer shadow). Body content hidden (only the front card's body shows).
- **No binding holes** on either card (key difference from Day view).
- Only ever **two** cards rendered — never a third in the stack.

### Sizes

- **Collapsed** ≈ Day view collapsed paper: ~280×280, centered.
- **Stamp card expanded** ≈ Day view expanded paper: full content width
  (container − horizontal padding) × ~420.
- **Feature card expanded**: bigger — full content width × ~510
  (≈ ~450 when purchased, since CTA + Restore disappear).
- The stack container animates `width`/`height` between the active card's
  collapsed/expanded size with the collapse spring; card content cross-fades
  (quick opacity swap) between its collapsed and expanded layouts.

### Interaction: symmetric infinite swipe

Because there are only two cards and the other card always sits below the
front, a vertical drag past threshold in **either** direction flips
front/back:

1. On drag: front follows finger (`dragY`), slight rotation like Day view.
2. On release past threshold: front slides fully off **in the drag direction**
   (up → −offscreen, down → +offscreen) while the back card rises from its
   peek/inset into the front slot (gains shadow, loses inset/peek), and a
   "new back" layer fades into the back slot showing the departing card's
   content (mirrors Day view's deepest-placeholder fade-in).
3. After the animation, a no-animation reset transaction swaps `frontIndex`
   and clears transforms — the static two-card stack is pixel-identical to the
   mid-animation end state, so there's no pop.
4. Below threshold: spring back to rest.

`invertDaySwipe` is **not** consulted here (no semantic "next/prev day"); both
directions simply toggle the active card.

### Interaction: tap to expand/collapse

Tap on the front card toggles `expanded[frontIndex]`. The stack frame springs
to the new size; the card body cross-fades between collapsed/expanded layouts.
Back-card taps are ignored (navigation is swipe-only), matching the prototype.

### Static hint

A static italic line below the stack, verbatim from the Day view:
`Pull to tear · ↑ Next · ↓ Prev`.

## Card content

### Card 1 — Stamp / Frontrunner

- **Collapsed**: centered `HibiStamp` (~154pt). Slot state before purchase
  ("Awaiting your seal"), active seal after.
- **Expanded**: bigger `HibiStamp` (~186pt) + a quiet italic deck:
  - not purchased → "Purchase Hibi Plus to receive your personalized seal."
  - purchased → "Thank you."

### Card 2 — What's inside / Feature card

- **Collapsed**: header (`日々` eyebrow + big italic "Hibi Plus") +
  `AppIconCarousel` + italic hint "Tap to see what's inside."
- **Expanded**: header + deck "Your support matters a lot." + hairline rule +
  `AppIconCarousel` + two perk blocks ("App icons / Dress Hibi up.",
  "Early access / Try features first.") + `EarlyAccessTile` (Widgets) +
  footer. Footer when **not** purchased: `PlusCTA` ("$4.99 · one-time") +
  "Restore purchases" link. When purchased: footer empty (card shrinks).

## Sub-components

### `HibiStamp`

Self-contained SwiftUI seal, isolated so its internals can be replaced by a
Metal shader later (mark the swap point with a comment).

- **Slot** (not purchased): dashed circle, small-caps "AWAITING" over italic
  "your seal".
- **Active** (purchased): vermillion (`#c8362a`, P3) ring + "HIBI · PLUS" arc
  text at top + large italic `日々` centered + purchase date in mono at the
  bottom. Built from `Circle`/`Text` (no SVG turbulence). Slight rotation
  (~−6°).
- **Stamp-in animation**: scale bounce (1.18 → 0.96 → 1.0) + fade, triggered
  by `stampToken`, ~0.7s, matching the prototype keyframe. A no-op under
  Reduce Motion (snap to placed).

### `AppIconCarousel`

Auto-scrolling horizontal row of the **current app icon repeated**, rendered
as a SwiftUI facsimile (paper-card tile, two faint binding dots, italic "26").
The real app icon ships as a Liquid Glass `.icon` bundle with no usable PNG in
the asset catalog, so a facsimile is used (matches the icon's design). Seamless
loop via duplicated track translated −50% (`TimelineView`-driven or a repeating
animation). Edge fade mask on left/right. Paused under Reduce Motion.

### `EarlyAccessTile`

Widgets promo. Header rule: pulsing vermillion dot + "Currently in early
access" + "Xd left". Body: widget illustration (mini paper page on a
wallpaper-tinted tile) + name "Widgets" + note "On your home screen — paper,
every day."

- **Hard-coded** `earlyAccessEndDate` constant (e.g. `2026-06-30`, editable in
  one place). "Xd left" = `max(0, days from today → endDate)`, computed live
  via the same `de_DE` calendar. When the window has passed (0d), still render
  the tile but show "ending soon" / "0d left" gracefully (no negative numbers).

### `PlusCTA`

Pill button:

- **Idle**: black pill, mono "$4.99" + small italic "one-time".
- **Tap** → morph to **success** state (checkmark + "Thank you", brief
  ~0.5s) → set `isPlus = true`, `purchaseDate = Date()` → animate stack to
  `frontIndex = 0` (stamp card) → trigger `stampToken` so the seal stamps in.
- "Restore purchases" link below: present but non-functional (no-op; for
  layout/realism per the prototype).

## Placement & integration

- Add a new `Hibi/Views/HibiPlusView.swift`.
- In `SettingsView.body`, insert `HibiPlusView()` as the **first `Section`**
  of the existing `Form`, above "General", with
  `.listRowInsets(EdgeInsets())` + `.listRowBackground(Color.clear)` and no
  header so it reads as a borderless header (matches the Monologue reference +
  prototype).
- **Gesture precedence risk**: the card's vertical drag must win over the
  `Form`/`List` scroll. Attach the swipe/tear `DragGesture` via
  `.highPriorityGesture` (with a small `minimumDistance`) so dragging on the
  card tears instead of scrolling the list; the tap uses `.onTapGesture`.
  This is the top thing to verify on-device.

## Colors / type

- Vermillion seal ink: `#c8362a` as a P3 `Color` (add to `PaperTints` or a
  local constant).
- Paper fills: reuse `PaperTints.card1/card2`. Front = card1, back = card2.
- Type: `AppFont.appSerif(...)` for serif display/italic; system sans for
  eyebrows/labels; system monospaced for price/date. Respect `useSimpleFont`.

## Localization (required — all 11 locales)

Per AGENTS.md, every new visible string goes through `String(localized:)` /
`Text` and gets an entry in `Hibi/Localizable.xcstrings` filled for **all 11
locales** (`de, en, es, it, ja, ko, ms, pt-BR, zh-Hans-CN, zh-Hant-HK,
zh-Hant-TW`), translated naturally (not literally).

New strings include: "Hibi Plus", "Your support matters a lot.",
"Tap to see what's inside.", "App icons", "Dress Hibi up.", "Early access",
"Try features first.", "Currently in early access", "Widgets",
"On your home screen — paper, every day.", "%d d left" (or a properly
pluralized form), "one-time", "Restore purchases", "Thank you.",
"Awaiting your seal", "your seal", "Purchase Hibi Plus to receive your
personalized seal.", and the hint "Pull to tear · ↑ Next · ↓ Prev" (reuse the
existing key if one already exists for the Day view hint).

The stamp's `日々` / "HIBI · PLUS" / the formatted date are treated as a brand
seal mark and are **not** localized. The "$4.99" price string is a placeholder
(no real IAP); keep it as a non-localized literal for now, or a single
constant.

## Accessibility

- Stack: expose card title + "expanded/collapsed" state; swipe via
  accessibility actions (next/previous) so VoiceOver users aren't stuck.
- Reduce Motion: disable carousel auto-scroll and the stamp-in bounce (snap to
  final state); keep cross-fades minimal.
- CTA / Restore are real buttons with labels.

## Testing / verification

No test target in the project. Verification is manual on-device:

1. Stack renders at top of Settings, light + dark, both cards.
2. Swipe up and swipe down both flip cards (infinite); animation matches Day
   view feel; no pop on reset.
3. Tap expands/collapses front card; each card keeps its own state across
   swipes; sizes match spec.
4. Drag on the card tears/swipes rather than scrolling the Form.
5. Purchase: CTA → success → flip to stamp card → seal stamps in; deck shows
   "Thank you"; CTA/Restore gone; feature card shrinks.
6. Early-access countdown shows correct "Xd left" from the hard-coded date.
7. VoiceOver + Reduce Motion behave per spec.
