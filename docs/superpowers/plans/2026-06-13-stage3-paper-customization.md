# Stage 3 — Paper Customization (wizard pages 1–3) + global render + shared primitives — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`. Craft tasks: invoke `swiftui-metal-shaders`, `msl-techniques`, `metal-motion-effects`, `stamp-ink-noise`; UI tasks: `swiftui-pro`.

**Goal:** A "Customize calendar" Settings row opens a wizard; swiping the centered paper preview sets **texture / ruling / tint**; the choice dresses **every day page** (and the widget snapshot carries the tokens). Introduces the three load-bearing shared pieces — **`AdaptivePalette`**, **`PaperSubstrate`**, the **editor chrome kit** — that Stages 4/5/9/10 reuse.

**Architecture:** A pure `AdaptivePalette` resolves semantic tokens → light/dark `Color`s (paper tints with a depth ramp; inks). A reusable `PaperSubstrate(texture:ruling:fill:chromeAmount:cornerRadius:)` view layers texture (Metal tilt shader + static fallback) + ruling (Canvas) + fill + chrome on **one** card. `DayView` is refactored to compose `PaperSubstrate` (keeping its existing tear/stack/parallax orchestration). The wizard reads/writes the global `PaperStyle` via `CustomizationStore`. Scope is **day pages only** (Month/Week/app-bg unchanged — confirmed).

**Tech Stack:** SwiftUI (iOS 26), Metal `[[stitchable]]` layer effect (generalizing the stamp pipeline), `MotionStore`, SwiftData (`PaperStyle`), App Group (widget tokens).

---

## Design source of truth
`/Users/alexweichart/Developer/designs/Hibi-customize-2` (`design-system/build-canvas.jsx`, `build-parts.jsx`, `paper-editor.jsx`, `CLAUDE.md`). Concrete values pulled below. The always-circular icon-well button + dots-only language are fixed there.

## Current-code anchors (verified)
- Day card composed in `Hibi/Views/DayView.swift:423-490` (`paperCard()`): `shape.fill(baseFill).overlay(tint blend).overlay(border).overlay(BindingHoles).overlay(PageContent).overlay(PerforationEdge)` + shadows. Stack of 4 cards `DayView.swift:283-419` with progressive `card1/card2/card3` tints and `ParallaxOffset` (`maxOffset = 2.8`, depth factor, reduce-motion gated).
- `PaperTints` (`Hibi/Views/PaperTints.swift:8-40`): `dynamic(light:dark:)` → `UIColor { trait in … }`. `card1/2/3` are the current cream depth ramp (light `#FBFAF7`/`#F4F2F0`/`#EFEDE6`, dark `#242424`/`#141414`/`#000000`).
- `MotionStore` (`Hibi/Models/MotionStore.swift`): `@Observable @MainActor`, `tiltX/tiltY` (~−1…1), `start()/stop()`, reduce-motion gated by callers. Stamp consumes it via `.layerEffect(ShaderLibrary.stampEffect(... .float2(tiltX,tiltY) ...))` in `HibiPlusView.swift:151-167`; static variant passes `(0,0)` when `reduceMotion || isLowPower`.
- Settings: `SettingsDestination` enum (`SettingsView.swift:43-49`), `.navigationDestination(item:)` (`:96-107`), `settingsNavRow(_:systemImage:destination:)` helper (`:338-352`), General section (`:119-147`).
- Widget snapshot: `WidgetWeatherSnapshot` (`Hibi/Models/WidgetWeatherSnapshot.swift`) written by `WeatherStore` to `AppGroup.Key.snapshot`; read in `TodaysPageTimelineProvider`. (Stage 3 writes paper tokens to a SEPARATE App Group key — see Task 7 — so paper changes don't depend on weather fetches.)
- `CustomizationStore.paperStyle() throws -> PaperStyle` (`Hibi/Models/Customization/CustomizationStore.swift`) — singleton fetch/create. `PaperStyle.texture/ruling/tint` computed over `*Raw: Int`.

## Locked sub-decisions (this stage's brainstorming)
- **Scope:** day pages only.
- **Depth ramp:** the user's tint resolves to a 3-step depth ramp (front→back darkening), so the tear-off stack stays cohesive in the chosen colour (cream's ramp == today's `card1/2/3`). `DayView` keeps its tear-blend; `PaperSubstrate` takes a resolved `fill: Color`.
- **Rendering split:** **ruling** = SwiftUI `Canvas` (crisp, scheme-aware, cheap); **tint** = `AdaptivePalette` `Color`; **texture** = SwiftUI gradient base (matching the design's CSS recipes) **+** a Metal tilt-specular shader layered on top (craft). Substrate must render correctly with the shader disabled (reduce-motion/low-power) — the static gradient is the floor, the shader adds tilt.
- **Dark tints (starting values, user vets on-device):** each light tint gets a hand-tuned dark variant on the `#242424` paper base, nudged toward the tint hue (NOT the light value dimmed):

| Tint | Light (design) | Dark (proposed, depth-0) |
|---|---|---|
| Cream | `#FBFAF7` | `#242424` |
| Blush | `#F6E8E5` | `#2A2422` |
| Sky | `#E4ECF3` | `#202327` |
| Sage | `#E7ECE1` | `#232722` |
| Butter | `#F5EED7` | `#272420` |
| Lilac | `#ECE5F1` | `#252128` |

Depth 1/2 darken each toward the app's near-black back (`#141414`→`#000000` in dark; light ramps ~6%/12% darker as cream does).

---

## File Structure
- Create `Hibi/Views/Customization/AdaptivePalette.swift` — token → light/dark `Color` resolver + depth ramp.
- Create `Hibi/Views/Customization/PaperSubstrate.swift` — the reusable card primitive.
- Create `Hibi/Views/Customization/PaperRuling+Canvas.swift` — ruling renderer (lines/grid/dots).
- Create `Hibi/Shaders/PaperTexture.metal` — `[[stitchable]]` grain + tilt-specular (generalize stamp approach).
- Create `Hibi/Views/Customization/EditorChrome.swift` — `IconWellButton`, `SegmentedProgressPill`, `WizardNavBar` (Back/Next/Done), primary/secondary button styles.
- Create `Hibi/Views/Customization/PaperWizardView.swift` — wizard container (pages 1–3) + `PaperPropertyCarousel`.
- Create `Hibi/Models/Customization/PaperSnapshot.swift` — Codable paper tokens for the App Group + writer.
- Modify `Hibi/Views/SettingsView.swift` — add `.customizeCalendar` destination + row.
- Modify `Hibi/Views/DayView.swift` — compose `PaperSubstrate`, read global `PaperStyle`.
- Modify `Hibi/Models/AppGroup.swift` — add the paper-snapshot key.
- Tests under `HibiTests/`: `AdaptivePaletteTests`, `PaperStylePersistenceTests`, `PaperCarouselTests`, `PaperSnapshotTests`.

---

## Task 1: `AdaptivePalette` (pure resolver) + tests

**Files:** Create `Hibi/Views/Customization/AdaptivePalette.swift`; Test `HibiTests/AdaptivePaletteTests.swift`.

The single source of truth for "what colour is this token, in light and dark." Built on the existing `PaperTints.dynamic(light:dark:)` mechanism (reuse it). Resolution is **total** (every token → a defined pair) and **distinct** (no two tints collapse to the same depth-0 pair; no token falls back to a default).

API:
```swift
enum AdaptivePalette {
    /// Paper fill for a tint at a (possibly FRACTIONAL) stack depth.
    /// 0 = front/active; deeper = darker. DayView passes `depth = cardDepth − dragProgress`
    /// during a rip so the tear crossfade is one continuously-resolved fill.
    static func paperFill(_ tint: PaperTint, depth: Double = 0) -> Color
    /// "primary" ink: adaptive black↔near-white. (Used by ruling + later text/widgets.)
    static var primaryInk: Color { get }
    /// Ruling ink (hairline, low-opacity) resolved for scheme.
    static var rulingInk: Color { get }
}
```
**CRITICAL — the darkening MUST happen INSIDE the `UIColor { trait in … }` closure, never by resolving two `Color`s to RGB and lerping in Swift** (that snapshots one appearance and kills dark-mode adaptivity — the exact tear-off regression we're guarding). So: build each tint's fill as `PaperTints.dynamic(light:dark:)` where the closure first picks the base (light or dark) RGB for the current trait, *then* applies a continuous darkening as a function of `depth`: light `×(1 − 0.06·depth)`, dark `lerp(base → black, min(1, 0.4·depth))`, both clamped. Because darkening is continuous in `depth`, fractional depths blend smoothly AND every value re-resolves per appearance. `rulingInk` ≈ `dynamic(light: black@0.09, dark: white@0.10)`.

- [ ] **Step 1: Failing tests**
```swift
import Testing
import SwiftUI
@testable import Hibi

@MainActor struct AdaptivePaletteTests {
    @Test func everyTintResolvesToADistinctLightDarkPair() {
        // Resolve each tint depth-0 in both schemes via UIColor; assert all 6 light values
        // are distinct, all 6 dark values are distinct, and light != dark for each.
        let light = PaperTint.allCases.map { rgb(AdaptivePalette.paperFill($0), .light) }
        let dark  = PaperTint.allCases.map { rgb(AdaptivePalette.paperFill($0), .dark) }
        #expect(Set(light).count == PaperTint.allCases.count)
        #expect(Set(dark).count == PaperTint.allCases.count)
        for i in light.indices { #expect(light[i] != dark[i]) }
    }
    @Test func depthDarkensMonotonicallyIncludingFractional() {
        let d0 = luminance(AdaptivePalette.paperFill(.cream, depth: 0), .light)
        let dHalf = luminance(AdaptivePalette.paperFill(.cream, depth: 0.5), .light)
        let d1 = luminance(AdaptivePalette.paperFill(.cream, depth: 1), .light)
        let d2 = luminance(AdaptivePalette.paperFill(.cream, depth: 2), .light)
        #expect(d0 > dHalf && dHalf > d1 && d1 > d2)   // fractional depth blends smoothly
    }
    // helpers rgb()/luminance() resolve a Color via UIColor(color).resolvedColor(with: traits)
}
```
- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement** (table + `dynamic` + depth math).
- [ ] **Step 4: Run → pass.**
- [ ] **Step 5: Commit** — `feat(customization): AdaptivePalette token resolver`

---

## Task 2: Ruling renderer + `PaperSubstrate` (static texture first)

**Files:** Create `PaperRuling+Canvas.swift`, `PaperSubstrate.swift`; visual via `#Preview`.

**Ruling** (`Canvas`): `plain` = nothing; `lines` = horizontal lines spaced 22pt, `rulingInk`; `grid` = lines both axes 22pt; `dots` = dots at 22pt lattice, radius ~1pt. (Design recipe: spacing 22, ink ~9% black / ~10% white.)

**`PaperSubstrate`** — the reusable primitive (callers resolve `fill` via `AdaptivePalette`):
```swift
struct PaperSubstrate: View {
    var texture: PaperTexture
    var ruling: PaperRuling
    var fill: Color                 // resolved tint (caller uses AdaptivePalette.paperFill)
    var bakedTexture: Image? = nil  // Task 3 baked paper field; nil → gradient floor (Task 2)
    var tiltEnabled: Bool = false   // Task 3 live specular; caller: !reduceMotion && !lowPower
    var chromeAmount: Double = 1    // binding holes / perforation / edge / shadow strength
    var cornerRadius: CGFloat = 18
    // body: RoundedRectangle.fill(fill)
    //   → texture: bakedTexture if present, else static gradient placeholder per `texture`
    //   → ruling Canvas overlay
    //   → (Task 3) tilt-specular .layerEffect when tiltEnabled
    //   → border strokeBorder + BindingHoles(top) + PerforationEdge(bottom) scaled by chromeAmount
    //   → clipShape; shadow applied by caller or here behind chromeAmount
}
```
Texture base for THIS task = cheap static `LinearGradient`/`Canvas` overlays approximating each texture (from design CSS): smooth=none; linen=two 45°/−45° repeating hairlines @6% brown; kraft=warm base + angled hairlines; news=halftone radial dots 4pt; vellum=diagonal veil. This is the **floor** so the substrate is correct without Metal. **Task 3 supersedes this with a baked fBm paper-field texture** (per `paper-shaders-research.md`) sampled via a `texture image` input — design `PaperSubstrate` to accept an optional `bakedTexture: Image?` (when present, draw it instead of the gradient placeholder; when nil, use the gradient floor).

- [ ] **Step 1:** Build `PaperRuling` Canvas + `PaperSubstrate`; add a `#Preview` cycling all texture×ruling×tint combos.
- [ ] **Step 2: Build-verify** (`build-for-testing` → `** TEST BUILD SUCCEEDED **`).
- [ ] **Step 3: Commit** — `feat(customization): PaperSubstrate primitive + ruling renderer (static texture)`

> No unit test (pure visual); ruling geometry math is exercised by Stage 4's snap tests. State that visual verification is on-device.

---

## Task 3: Baked paper-field engine + tilt specular (craft-complete)

**Files:** Create `Hibi/Shaders/PaperTexture.metal`, `Hibi/Models/Customization/PaperFieldBaker.swift`; integrate into `PaperSubstrate`. **Read `docs/paper-shaders-research.md` first.** Invoke `swiftui-metal-shaders` + `msl-techniques` + `metal-motion-effects` + `stamp-ink-noise`.

**This is the §1.6 "bake, don't evaluate-per-frame" mandate + the shared paper-field set.** Two parts:

**(a) `PaperFieldBaker` — bake the paper field to a cached texture (the load-bearing craft piece).**
- Evaluate the paper noise in **canvas space** and **bake to a mipmapped offscreen `MTLTexture`/`CGImage`**, **disk + memory cached** keyed by `(texture, tint-resolved-for-scheme, size-bucket, scheme)` — mirror `StampCompositor`'s cache exactly (don't write a second cache).
- Compose per the research preset table (§L), staged by payoff (§Recommendations 2): **warm base + low-octave formation fBm is the hero** (biggest perceptual win); then a light high-freq **grain/tooth** layer. Per-texture weights: smooth ≈ nearly flat; linen/kraft = fiber grain; news = halftone; vellum = soft veil. fBm conventions per §E (lacunarity≈2.0, gain≈0.5, **3–5 octaves**, detune frequencies ×2.01/×2.03…, rotate domain between octaves). **Contrast: low single-digit % luminance modulation around the warm-cream/tint base** (§G) — if the texture is consciously visible at default zoom it's too strong. **Band-limit** fine detail and rely on mipmaps to avoid moiré (§I).
- **Shared field for later stages:** expose the baked **tooth/height** channel (e.g. in a texture channel or a second small baked map) so Stage 7 ink can sample it (pencil/marker grain = glyph alpha × paper tooth) — this is the §1.6 shared paper-field set being born here. Fiber-direction/absorbency fields are **additive in Stage 7**; just don't architect them out (keep the baker extensible to more channels).
- `PaperSubstrate` consumes the baked texture via its `bakedTexture: Image?` input (Task 2). Re-bake when `(texture, tint, scheme, size-bucket)` changes; resolve the tint for `@Environment(\.colorScheme)` so an appearance flip re-bakes (cache a light **and** dark variant).

**(b) Tilt specular — the only LIVE term.** A `[[stitchable]]` layer effect over the baked texture adding a **subtle tilt-reactive highlight** (generalize `StampShader.metal`'s specular term; `SWGrainGradient` for reference). Inputs: size, `tiltX/tiltY` (from `MotionStore`), the scheme-resolved tint. **Reduce Motion / Low Power → omit the `.layerEffect` (or pass tilt `(0,0)`)** — the baked texture still shows; only the moving highlight stops (mirror the stamp's `staticStamp()` gate). Per `paperTiltEnabled(reduceMotion:lowPower:)` from below.

Integrate in `PaperSubstrate` behind a `var tiltEnabled: Bool` (caller passes `!reduceMotion && !lowPower`); when off, omit the `.layerEffect`. Warm-up via `Shader.compile` if the stamp does. **Re-render on appearance flip (roadmap §1.4):** the resolved tint colour fed into the shader must derive from `@Environment(\.colorScheme)` (read the scheme in the view, pass the scheme-resolved colour into the shader args) so flipping light/dark re-renders the texture instead of keeping the stale-scheme colour.

- [ ] **Step 1 (baker):** Build `PaperFieldBaker` (canvas-space fBm → cached mipmapped texture, `StampCompositor`-style disk/mem cache keyed by texture/tint/scheme/size-bucket). Feed the baked `Image` into `PaperSubstrate.bakedTexture`. Bake light+dark variants; re-bake on token/scheme change.
- [ ] **Step 2 (tilt):** Write `PaperTexture.metal` tilt-specular + wire `.layerEffect` into `PaperSubstrate` (gated by `paperTiltEnabled`). Add `MotionStore` injection (start/stop on appear/disappear, reduce-motion gated) where the substrate is used live (DayView Task 6 / wizard Task 5).
- [ ] **Step 3:** Pure-logic test (`HibiTests`): `paperTiltEnabled(reduceMotion:lowPower:) -> Bool` returns false if either is true (test the table); and a **bake-cache** test mirroring `StampCompositorCacheTests` (same key → cached hit; different texture/tint/scheme → distinct entries).
- [ ] **Step 4: Build-verify.**
- [ ] **Step 5: Commit** — `feat(customization): baked paper-field engine + tilt specular (paper-shaders-research)`

---

## Task 4: Editor chrome kit

**Files:** Create `Hibi/Views/Customization/EditorChrome.swift`. Invoke `swiftui-pro`.

Reusable (Stages 4/5 consume). Match design values:
- `IconWellButton` — always-circular 38×38, fill `paper-card-1`, 0.5pt border `ink-edge` (rgba 0,0,0,0.08), subtle toolbar shadow, `scale(0.94)` on press; takes an SF Symbol + action. (Used for ✕, and later undo/redo/back/save.)
- `SegmentedProgressPill(count:current:)` — N segments 26×6, gap 6, radius 999; filled = `primaryInk`, empty = ink @18%.
- `WizardPrimaryButtonStyle` / `WizardSecondaryButtonStyle` — full-width pill (radius 999), primary = ink fill + paper text, secondary = transparent + 0.5pt border.
- `WizardNavBar` — lays out Back (secondary) + Next/Done (primary) per the design (page 1 = Next only; pages 2+ = Back + Next/Done).

- [ ] **Step 1:** Build the components + a `#Preview`.
- [ ] **Step 2: Build-verify.**
- [ ] **Step 3: Commit** — `feat(customization): editor chrome kit (icon well, progress pill, nav bar)`

---

## Task 5: Paper wizard (pages 1–3) + carousel + persistence

**Files:** Create `Hibi/Views/Customization/PaperWizardView.swift`; Test `HibiTests/PaperCarouselTests.swift`, `HibiTests/PaperStylePersistenceTests.swift`.

- **Carousel model** (testable, pure): `PaperCarousel` holds the working `texture/ruling/tint`, current page (0–2), and `next()/back()/select(index)` mapping. Index↔value mapping per enum order (texture 5, ruling 4, tint 6). Page 1→texture, 2→ruling, 3→tint.
- **Wizard shell:** top bar = `IconWellButton(✕)` + italic-serif page title ("Paper"/"Ruling"/"Colour"); `SegmentedProgressPill(count: 3, current: page)` — **3 segments for now** (a 4th, permanently-unreached segment reads as "unfinished"; bump to 4 when Stage 4 adds page 4); bottom `WizardNavBar`. ✕ → confirm dialog → discard (no save). **Page 3 "Next"** currently commits (Done) — leave a clear seam (`// Stage 4 inserts page 4 here; Done moves to page 4`) so Stage 4 slots page 4 in before the commit.
- **Preview:** centered `PaperSubstrate` (depth-0 fill via `AdaptivePalette`) with two ghost cards behind (design: 326×348, rotate +3°/−2.4°, offset) ; below: italic-serif **name label** + **position dots** (6×6, gap 7). Horizontal swipe (`DragGesture`) + tap chevrons cycle the value; the preview "builds up" (page 1 texture only, page 2 adds ruling, page 3 adds tint).
- **Commit:** on Done → `let s = try store.paperStyle(); s.texture = …; s.ruling = …; s.tint = …; s.updatedAt = .now; save` + write the paper snapshot (Task 7) + dismiss.

- [ ] **Step 1: Failing tests** — `PaperCarousel` index↔value mapping + page build-up flags; `PaperStylePersistence` (commit writes texture/ruling/tint to the singleton, re-fetch returns them) using an in-memory `CustomizationContainer`.
- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement** carousel model + wizard view + commit.
- [ ] **Step 4: Run → pass; build-verify.**
- [ ] **Step 5: Commit** — `feat(customization): paper wizard pages 1–3 + carousel + persistence`

---

## Task 6: Settings row + global DayView render (the load-bearing refactor)

**Files:** Modify `SettingsView.swift`, `DayView.swift`.

- **Settings:** add `case customizeCalendar` to `SettingsDestination`; a row in the General/Appearance section (`settingsNavRow("Customize calendar", systemImage: "paintbrush.pointed", destination: .customizeCalendar)`); destination = `PaperWizardView()`. Localize the title (all 11 locales).
- **DayView refactor (surgical):** inside `paperCard()`, replace the inline fill+border+chrome composition with `PaperSubstrate(texture: style.texture, ruling: style.ruling, fill: AdaptivePalette.paperFill(style.tint, depth: <fractional card depth>), chromeAmount: chromeAmount, cornerRadius: 18)`. **Keep** the tear/stack/parallax orchestration, the shadows, and `PageContent`.
  - **Tear crossfade (replaces the two-layer `baseFill`+`overlayFill.opacity` blend):** pass a **fractional** depth — `depth = cardDepth − dragProgress` (or the existing animation's interpolation parameter) — to `AdaptivePalette.paperFill`. The single continuously-resolved fill reproduces the depth crossfade AND stays appearance-adaptive. **Do NOT** resolve two `Color`s to RGB and lerp in Swift (kills dark mode).
  - **Reactive read (REQUIRED — this is the Done-bar):** read `PaperStyle` with `@Query private var paperStyles: [PaperStyle]` and resolve the survivor (newest `updatedAt`, dedup-convergent) — NOT a one-shot `try store.paperStyle()` in `onAppear`. The wizard writes via the context; `@Query` makes DayView re-render live when the user commits and pops back. (A one-shot fetch shows stale paper until relaunch and passes every build/unit test — the silent failure to avoid.)
  - Pass `tiltEnabled` from the existing reduce-motion / low-power state.
  - **Regression guard:** the tear-off feel (drag-to-rip, parallax, progressive depth) must be unchanged for the default (cream/smooth/plain) style — default DayView looks byte-identical to before. On-device only.

- [ ] **Step 1:** Add the Settings row + destination + localization.
- [ ] **Step 2:** Refactor `DayView.paperCard()` to compose `PaperSubstrate`; wire global `PaperStyle`.
- [ ] **Step 3: Build-verify.**
- [ ] **Step 4: Commit** — `feat(customization): Customize-calendar settings row + DayView composes PaperSubstrate`

---

## Task 7: Widget paper-token snapshot

**Files:** Create `Hibi/Models/Customization/PaperSnapshot.swift`; Modify `AppGroup.swift`; write on commit (Task 5).

- `struct PaperSnapshot: Codable, Sendable { var textureRaw: Int; var rulingRaw: Int; var tintRaw: Int }`.
- `AppGroup.Key.paperSnapshot = "widget.paper.snapshot.v1"`.
- A writer `PaperSnapshot.write(from: PaperStyle)` → encode to App Group + `WidgetCenter.shared.reloadAllTimelines()`. Call it on wizard commit (and once at app launch / paper change so the key is populated).
- Widget *rendering* of these tokens is **Stage 10** — this task only guarantees the data is in the App Group.

- [ ] **Step 1: Failing test** — `PaperSnapshotTests`: encode/decode round-trip; `write(from:)` populates the App Group key (inject a test suite).
- [ ] **Step 2: Run → fail; implement; run → pass; build-verify.**
- [ ] **Step 3: Commit** — `feat(customization): paper-token App Group snapshot for widget`

---

## Task 8: Localization + final pass
- [ ] **Step 1:** Add every user-facing string (the Settings row, wizard titles "Paper"/"Ruling"/"Colour", tint/texture/ruling names, Back/Next/Done, the ✕-discard confirm dialog) to `Hibi/Localizable.xcstrings` for all 11 locales, translated naturally (per AGENTS.md). Grep the diff for hard-coded literals near `Text(`/buttons/dialogs.
- [ ] **Step 2:** Final `build-for-testing`.
- [ ] **Step 3: Commit** — `chore(customization): stage 3 localization + final pass`.

---

## Spec coverage self-check
| Stage 3 requirement (roadmap) | Task |
|---|---|
| `PaperSubstrate` primitive (texture+ruling+tint+chrome), DayView composes it | 2, 6 |
| `AdaptivePalette` tokens → (light,dark), depth ramp | 1 |
| Editor chrome kit (icon well, 4-seg pill, nav bar) | 4 |
| Settings "Customize calendar" → wizard; ✕→confirm→discard | 5, 6 |
| Pages 1–3 swipe carousel (texture/ruling/tint), name+dots, builds up | 5 |
| Global render dresses every day page (day-pages-only scope) | 6 |
| Craft: texture tilt shader + reduce-motion static fallback | 3 |
| Widget flow: paper tokens in App Group + reload | 7 |
| Tests: PaperStyle defaults/persistence; AdaptivePalette total+distinct; snapshot tokens; carousel mapping; reduce-motion fallback | 1,3,5,7 |
| Localize all strings (11 locales) | 8 |

## Handoff to user (on-device verification)
Build-green proves almost nothing for the Task 6 refactor — its risks are all visual/runtime. Specifically exercise:
1. **Change paper in the wizard → pop back → the day page updates LIVE** (no relaunch). This proves the `@Query` reactive read; a one-shot fetch fails here silently.
2. **Tear a page in DARK MODE** with a non-cream tint — the rip crossfade must stay correctly dark-adaptive (proves the fractional-depth-inside-the-trait-closure blend; a static-RGB lerp would look wrong only here).
3. **Default (cream/smooth/plain) day view looks byte-identical to before** — tear-off feel, parallax, progressive depth unchanged (refactor regression guard).
4. Tints adapt in dark mode generally (**vet the proposed dark-tint values**); texture **tilts under motion** and goes static under Reduce Motion / Low Power; appearance flip re-renders the texture.
5. Customized paper survives relaunch/sync. (Widget still shows the old render — that's Stage 10.)
