# Hibi 3.0 "Customize" — High-Level Roadmap

> **Status:** high-level architecture & staging document. This is NOT an executable task plan —
> each stage below gets its own design doc (with the visual designs attached) and its own
> task-level implementation plan when we get there. Companion context: the customize-v3 spec
> scratchpad and the paper-feel rendering research report (noise stacks, ink models, TBDR
> bake strategy) live with the user; pull them into each stage's design phase.

**Goal:** Let users customize their Hibi calendar page (the Day-view paper): paper texture /
color / ruling, free drawing with ink-like rendering, and placeable widgets (date, weather,
sun, free text, stickers, hanko) — edited in a new in-place edit mode with undo/redo,
Instagram-Stories-style canvas feel.

---

## 1. Where we are vs. where this needs to go

| Aspect | Today | Needed |
|---|---|---|
| Page rendering | Hardcoded SwiftUI layout (`PageContent`), one fixed arrangement | Data-driven renderer over a per-page document (layout = data) |
| Paper surface | Flat `PaperTints` fill + `PaperChrome` edges | Procedural texture (noise stack), color, ruling; tilt-reactive finish |
| Metal usage | Stamp only: CPU-baked composite (coverage + SDF channels) → `[[stitchable]]` layer effect, tilt via `MotionStore` | Same architectural tier, generalized: baked paper texture + per-layer effects |
| Drawing | None | Stroke capture + ink-shader rendering coupled to the paper |
| Editing UI | None (page is read-only) | Edit mode: drawer panel, selection/manipulation, guides |
| Undo/redo | None anywhere in the app | Command-based, atomic, session-scoped |
| Persistence | `UserDefaults` + App Group snapshots only | Real document store (strokes, layouts, sticker images) |
| Day view structure | ~850-line `DayView.swift` monolith (stack, tear, collapse, parallax) | Page rendering extracted and reusable (day view, editor, widget snapshot) |

The single most load-bearing existing asset is the **stamp pipeline**: it already proves the
pattern we want everywhere — *rasterize/bake expensive content once on the CPU/GPU (with an
SDF channel), then apply a cheap live `[[stitchable]]` shader for ink noise + tilt specular*.
Hibi 3.0 generalizes that pattern; it does not need a new rendering paradigm.

## 2. Target architecture

### 2.1 Rendering: hybrid SwiftUI + Metal, not a full Metal canvas

Decision: **do not rebuild the page as an `MTKView` scene.** A monolithic Metal canvas would
mean reimplementing text layout, Dynamic Type, localization, accessibility, hit-testing, and
gesture handling that SwiftUI gives us free — and the tear-off animation, parallax, and
schedule collapse are already healthy SwiftUI. Instead the page is a **ZStack of three
independently rendered layers**, each using the cheapest technology that achieves its look:

1. **Paper layer (bottom)** — procedural texture **baked once** to a mipmapped texture
   (offscreen Metal render or compute pass at page resolution), per
   (texture preset × color × ruling × size-bucket × light/dark appearance). Displayed as an
   image fill; a *small live* layer effect samples a baked depth/normal map for the
   tilt-reactive specular (same `MotionStore` input as the stamp). Rationale: Apple GPUs are
   TBDR — per-fragment multi-octave noise every frame on a mostly-static background is wasted
   battery; bake-once converts it to cheap texture sampling (this is also the research
   report's core recommendation).
2. **Drawing layer (middle)** — committed strokes rendered into a cached raster; the
   in-progress stroke drawn live on top; an ink layer effect (noise-perturbed edges,
   absorbency darkening) reads the *paper's* baked fields so ink and paper stay coupled.
3. **Widget layer (top)** — placed widgets remain **SwiftUI views** (they need tap targets,
   text layout, live data). Widgets that want an "ink" look (free text, hanko) reuse the
   stamp recipe: rasterize via CoreText → bake SDF → live ink layer effect. While a widget is
   being dragged/scaled in edit mode, fall back to plain rendering and re-bake on commit.

This answers the open "typed text" question: **yes to ink-shader text, at moderate cost** —
`StampCompositor` already rasterizes arbitrary text with a baked SDF and the shader tier is
proven. The combination approach (plain text while editing, baked ink when committed) keeps
edit interactions cheap.

### 2.2 Document model

- **`PageDesign`** — the customization document: paper (texture, color, ruling) + an ordered
  list of widget instances (type, normalized position/size/rotation, per-type style payload).
- **Coordinate space:** widget positions and strokes are stored in a **normalized,
  fixed-aspect paper space**. This requires **fixing the paper aspect ratio** (today the page
  height is device/collapse-derived) — resolve early, in Stage 0, because every stored
  coordinate depends on it. Compact mode becomes a defined sub-rect of that space plus a
  continuous collapse-progress parameter (content outside the sub-rect fades/shifts as the
  paper resizes, matching today's `chromeFade` behavior but data-driven).
- **Scope split (recommendation, confirm in design):** the *design* (paper + widget layout)
  is **global** — "this is what my calendar looks like" — while *drawings* (and likely
  stickers placed in context, e.g. a birthday) are **per-day** overlays. Per-day design
  overrides can come later without schema breakage if the per-day record can optionally carry
  a design.
- **Default design = current layout.** The shipped hardcoded arrangement (weekday, numeral,
  month/year, weather + attribution, sunrise/sunset, stamp) is re-expressed as the built-in
  default `PageDesign`. Users who never customize see a pixel-identical app; migration is
  "no stored design → default design."

### 2.3 Persistence

`UserDefaults` cannot hold stroke data and sticker images. Add a small file-based store in
the **App Group container** (so the widget extension can read it): JSON documents for the
design and per-day ink records, an assets directory for sticker images, and a versioned
schema from day one (`v1` envelope) since this data outlives releases. No CoreData/SwiftData
needed at this scale; Codable files match the app's existing snapshot style.

### 2.4 Edit mode & undo/redo

A new `@Observable` **edit-session store**: copy-on-edit of the page document, a
command-based undo/redo stack (every panel action — place, move, restyle, stroke, paper
change — is one atomic command), dirty tracking for the cancel-confirmation popup, and
save = atomically persist + re-bake + write widget snapshot. Undo/redo is session-scoped
(cleared on save/cancel) — simplest model that satisfies the spec. While editing: tear
gesture, schedule collapse, and tab-driven day changes are disabled; leaving the day view
exits edit mode via the same confirmation path.

## 3. Hard problems & how we'll handle them

1. **Bake pipeline correctness across appearances.** Every texture/color must be designed
   *twice* — the dark theme is intentionally near-black (`#242424` front card), where cream
   textures and pastel paper colors behave completely differently. Bake per appearance and
   review both from the first texture onward; treat "texture invisible or muddy in dark
   mode" as a design blocker, not a bug to patch later.
2. **Aliasing of fine ruling/texture under resize.** Lines/grid/dots near pixel pitch will
   moiré, especially during the continuous compact-mode resize and on the small back cards.
   Mitigate with mipmapped bakes + band-limiting (fade ruling amplitude as on-screen pitch
   approaches a few pixels) — per the research report; this is the main reason ruling is
   baked into the texture rather than drawn as live vector lines.
3. **The stack has three cards and a tear animation.** Back cards must look like the same
   paper (reuse the same baked texture with the existing progressive tinting), and the bake
   must not stall the tear: bakes are async with the previous (or flat-color) paper as
   placeholder, and a small LRU cache of baked textures covers prev/next-day flips.
4. **WidgetKit parity (Today's Page widget).** SwiftUI shaders don't run in archived widget
   rendering. Options: (a) app pre-renders a flattened page image per appearance into the
   App Group, widget shows it; (b) widget renders a simplified vector version of the design
   (color/ruling/layout, no texture/ink effects). Recommend (a) for fidelity with (b) as the
   staleness fallback — decide in Stage 5's design pass. Either way the widget needs the
   design document readable from the App Group.
5. **Apple Weather attribution is a review requirement (5.2.5).** The weather widget must
   carry its attribution *as part of the widget* so it can't be deleted or cropped away
   while weather data is shown (the mock already draws it this way). Same class of issue:
   the date widget set must keep at least the day readable in compact mode — guard against
   designs that make the page meaningless (warn, don't block).
6. **Gesture arbitration in edit mode.** Selection, drag, pinch/rotate, draw, and panel
   scrubbing all live on a small canvas that *also* normally owns tear + collapse gestures.
   The edit-mode state machine must hard-disable the navigation gestures (spec requires it)
   and route by panel (Draw panel: canvas touches = strokes; Widgets panel: touches =
   select/manipulate). Budget real time for feel-tuning here — this is the "Instagram
   Stories" quality bar and it's interaction polish, not architecture.
7. **Drawing performance.** Never re-rasterize the whole drawing per touch sample: committed
   strokes live in a cached raster, only the live stroke renders per frame, smoothing
   (e.g. Catmull-Rom) applied on the fly. Custom stroke engine rather than PencilKit:
   we need shader-coupled ink, paper-field coupling, our own undo integration, and only
   "minimal" drawing per spec — PencilKit's canvas brings its own look, toolbar, and undo
   that all fight those goals.
8. **Ink shader + SDF/AA pitfalls.** Perturbing stroke/text edges with noise breaks naive
   `fwidth` antialiasing (shimmer). The stamp shader already navigates this — extract its
   conventions into shared MSL utilities rather than re-deriving (see `msl-techniques` /
   `stamp-ink-noise` skills).
9. **Hanko migration.** The Plus stamp is currently hard-placed by `HibiPlusView`/day view.
   It becomes a *placeable widget* (still Plus-gated, still seed-deterministic). The default
   design pins it where it lives today so existing Plus users see no change. Plus gating
   stays consistent across its (now) four checkpoints.
10. **Sticker background removal.** Use on-device Vision
    (`VNGenerateForegroundInstanceMaskRequest`) — no network, fits the no-backend posture.
    Sticker images need downscaling/compression on import so per-day documents stay small.
11. **Battery/thermals.** The live cost budget is: texture sampling + one small tilt effect +
    idle widget effects. Honor the existing Low Power Mode / Reduce Motion gates (stamp
    already degrades to static); verify on the oldest supported device per stage, not at the
    end.

## 4. Stages

Ordering rationale: foundation first (everything depends on the document model and the
extracted renderer); the edit-mode shell next so every later stage ships into a working
editor; paper before widgets because snapping depends on ruling and ink depends on paper
fields; widgets before drawing because they're the larger, riskier surface; stickers/hanko
and widget parity last as they're additive.

### Stage 0 — Foundation refactor (no visible change)
Extract page rendering out of the `DayView` monolith into a data-driven page renderer;
introduce `PageDesign` with the current layout as the built-in default; fix the paper aspect
ratio and define the normalized coordinate space + compact sub-rect; land the file-based
document store skeleton. **Exit criterion: pixel-parity with the shipping app** (screenshot
comparison), tear/parallax/collapse untouched.
*Risk focus: regression risk in the most-loved screen; aspect-ratio change is the one
user-visible tweak — get it approved on-device first.*

### Stage 1 — Edit mode shell + undo/redo
Edit button beside `+`; mode transitions (cog→Cancel, edit→Save, `+` hidden); drawer swaps
events for the customization panel with the custom pill toggle (Paper / Draw / Widgets);
edit-session store with command undo/redo + top undo/redo buttons; dirty-state cancel
confirmation; navigation-gesture lockdown; compact-boundary guide overlay. Ship the **Paper
panel with flat colors + ruling only** (no Metal yet) so the whole loop —
edit → change → undo → save → persist → re-render — is real end-to-end.
*Risk focus: gesture arbitration and the state machine; undo atomicity discipline starts here.*

### Stage 2 — Paper rendering engine (Metal)
The bake pipeline: offscreen render of the noise layer stack (per research report) into
mipmapped textures keyed by preset/color/ruling/size-bucket/appearance, with async bake +
caching; depth/normal map + tilt-specular layer effect; band-limited ruling; texture preset
catalog (Smooth, Linen, Kraft, News, Vellum per mock); integration with the three-card
stack, tear, and parallax; on-device perf/battery validation; dark-appearance variants of
every preset.
*Risk focus: this is the new-tech stage — budget for shader iteration and a device test
matrix; everything after it only consumes the pipeline.*

### Stage 3 — Widget layer
Placement engine: selection with handles + contextual actions (edit / duplicate / delete per
mock), drag/scale/rotate, z-order, snapping to the active ruling grid (no ruling = free),
compact-boundary highlight during drag, fade/shift behavior on collapse. Convert existing
content into widget types (date parts: numeral / weekday / month-year; weather + embedded
attribution; sunrise/sunset). Add **free text** (font choice + basic rich text), with the
ink-text bake (stamp-recipe) as its committed rendering. Hanko becomes a placeable Plus
widget (default-pinned for existing users).
*Risk focus: interaction feel + the per-type style-editor UI surface area; widget data
binding (live weather/date in a user-positioned layout, locale-safe).*

### Stage 4 — Drawing layer
Stroke capture + smoothing; committed-stroke raster cache; ink layer effect coupled to the
paper's absorbency/tooth fields; soft-edge fade for strokes crossing the compact bounds;
paper-type-dependent haptic feedback while drawing; color/width tools per mock (pen swatches
+ size slider + eraser); per-day persistence; stroke-level undo.
*Risk focus: ink feel (shader + haptics) is subjective — plan an explicit tuning pass with
the user on device; keep scope "minimal free drawing" per spec.*

### Stage 5 — Stickers, parity & release polish
Stickers: photo import, on-device background removal, asset storage/limits. Today's Page
widget parity (flattened-snapshot strategy). Performance/battery audit across stages;
accessibility pass over the editor; full localization sweep (11 locales — the editor adds a
lot of strings); migration + default-design verification for existing users; Plus marketing
surface update (hanko + any Plus-gated presets); What's New; release via `create-release`.
*Risk focus: review compliance (attribution, content), widget staleness, the long tail of
polish that defines whether 3.0 feels premium.*

### Explicitly out of scope (future)
AI daily quote widget; custom images as paper background; per-day design overrides;
cross-device sync of designs.

## 5. Open questions to settle in stage design phases

1. **Global design vs per-day** (recommendation in §2.2: global design + per-day ink/stickers) — Stage 0.
2. **Final fixed aspect ratio** and how it lands across device sizes — Stage 0.
3. **Widget rotation:** mock shows resize handles; is free rotation in scope (stories-style) or axis-aligned only? — Stage 3.
4. **What exactly is Plus-gated** in 3.0 beyond hanko (premium textures? sticker count?) — Stage 3/5.
5. **Widget-extension parity strategy** (flattened snapshot vs simplified vector) — Stage 5.
6. **Texture preset roster + per-preset haptic/ink parameters** — Stage 2/4, calibrated on device with the research report's noise stacks as starting points.
