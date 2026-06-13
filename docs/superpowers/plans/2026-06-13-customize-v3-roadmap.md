# Customize v3 — Implementation Roadmap

A staged plan to implement **all** of [customize-v3-plan.md](../../customize-v3-plan.md)
and its sync companion [customize-v3-sync.md](../../customize-v3-sync.md).

This is a **master roadmap at mid-level altitude**, not nine detailed plans. Each stage
names its goal, dependencies, scope, the shared pieces it introduces or reuses, the craft
(shader) work, the widget data-flow obligation, the high-value tests, and a done-bar.
**Stage 1–2 (the foundation) are specified in more depth** because they are first and the
schema decision is irreversible; later stages each get their own `brainstorming → writing-plans`
pass when they're actually built, against the contracts fixed here.

**Design source of truth:** the visual design lives in the Claude Code design project at
`/Users/alexweichart/Developer/designs/Hibi-customize-2`. Open `Design.html` (mounts the
`twoeditors` canvas) for the **resolved** flow; the source is `design-system/build-canvas.jsx`
+ `build-parts.jsx` (with `paper-editor.jsx`, `today-editor.jsx`, `sticker-flow.jsx`,
`camera-flow.jsx`, `edit-widgets.jsx`). Its `CLAUDE.md` records the resolved decisions (the
always-circular icon-button recipe, the dots-only widget drawer, the `InkSelection` chrome). The
other `*-frames.jsx` / `explorations.jsx` files are **earlier A/B/C explorations — not the final
design**; defer to `build-canvas.jsx` and, where they differ, to `customize-v3-plan.md`. Each stage
should pull its exact layout/chrome from the matching artboard in that project.

---

## 0. Locked decisions (answered) & stated defaults

**Answered by the product owner (2026-06-13):**

| Decision | Answer | Consequence |
|---|---|---|
| Plus gating | **All free** | Store + editors load unconditionally. No `isPlus` branching in the customize path. |
| Placed-sticker transform | **Pinch + two-finger rotate** (no frame handles) | Placement stage builds direct manipulation gestures; `scale`/`rotation` are user-driven. Selection chrome stays move + delete. |
| Craft / shader timing | **Craft-complete each stage** | Every feature stage carries its Metal work inline (no deferred "polish" stage). Lean on the existing stamp pipeline + ShipSwift `SWMetal` reference (MIT) at `/Users/alexweichart/Developer/ShipSwift/ShipSwift/SWPackage/SWAnimation/SWMetal` — notably `SWFoil` (holographic), `SWGlitter`, `SWGrainGradient` (paper grain), `SWChromaticGlass`. |

**Stated defaults (from the docs; not worth a question — flagged so they can be vetoed):**

- **Conflict policy:** last-writer-wins (SwiftData+CloudKit default). Acceptable for decoration.
- **First-launch / reinstall latency:** sync is eventual — show a quiet "syncing…" / graceful
  empty state, never a blank-looking regression.
- **iCloud-off / not-signed-in:** **offline-first**. Local SwiftData is the source of truth;
  CloudKit is additive. The container must degrade gracefully with no iCloud account.
- **Aspect ratio:** **fixed** to the paper page's ratio (the plan's open question leaned this way).
- **Hanko:** out of scope for customization (handled in-app already). Not placed via these editors.

**The manipulation-chrome GAP from the plan doc is resolved by the design project** (`build-canvas.jsx`):
one monochrome **ink selection** language for both editors — a hairline rect with white corner
dots (bounds only, **no resize/rotate handles**), the body drags to move, and a small ink pill
above with **delete** + (date widgets only) **switch-format ←→**. Stickers scale/rotate by direct
gesture, not handles.

---

## 1. Cross-cutting architecture (read before any stage)

### 1.1 Three-store sync layer

Per the sync doc, three data kinds → three Apple mechanisms. **Do not unify them.**

| Data | Store | Capability | Schema deploy |
|---|---|---|---|
| Settings (units, time format, appearance, hidden calendars/lists) | `NSUbiquitousKeyValueStore` | iCloud Key-value storage | None |
| Customizations (paper, structural widgets, per-day ink/text/placed-stickers) | SwiftData + CloudKit (private DB) | iCloud CloudKit | Yes — **once, up front** |
| Sticker library (≤500 cut-outs + style payload) | Same SwiftData store; image via `@Attribute(.externalStorage)` → CKAsset | Same container | Same |

The **App Group stays the only app↔widget channel** (it is *not* the sync store). KVS and
SwiftData are sync stores the widget can't read; the app **mirrors** what the widget needs into
`group.com.weichart.hibi`, exactly as `PlusStore → PlusEntitlementStore` already does. See §1.5.

### 1.2 The complete SwiftData model graph — front-loaded in Stage 2

Production CloudKit schema is **additive-only forever** (no delete / rename / type-change). So we
design **every** model up front and deploy the schema **once**, even though the editors that write
them ship across Stages 3–9. Unused record types sitting in Production are harmless; a forbidden
type-change discovered mid-program is not. This also collapses the sync doc's "deploy per release
that adds a type" into a single up-front deploy.

CloudKit constraints baked in from line one (verified, stable since iOS 14):
**no `@Attribute(.unique)`**; every property **optional or defaulted**; every relationship
**optional + inverse + not `.deny` + not ordered**; z-order via an explicit `zIndex: Int`;
volatile/evolving fields live inside an **opaque `stylePayload` `Data` blob** so their contents can
change without a schema change; **colours stored as semantic tokens (enum raw value / index), never
baked RGB** — so they resolve to the right light/dark value per device at render time (see §1.4).

```
ModelContainer(cloudKitDatabase: .automatic)   // private DB, offline-first
├─ PaperStyle        global (one logical row): texture, ruling, tint — all defaulted
│                    (Smooth / Plain / Cream). app-dedup, NOT .unique.
├─ StructuralWidget  global page-4 widgets: kind, formatVariant, x, y, zIndex
│                    kinds: dayNumber · weekday · month · year · weather · sunrise · sunset
├─ DayCustomization  keyed by date (app-level dedup by date key, NOT .unique)
│   ├─ placedStickers → [PlacedSticker]   (ref → Sticker, x, y, scale, rotation, zIndex)
│   ├─ inkStrokes     → ink data (.externalStorage)  — see Stage 7 capture decision
│   └─ textObjects    → [TextObject]       (string, stylePayload, x, y, scale, rotation, zIndex)
└─ Sticker            library asset: maskedImage Data (.externalStorage → CKAsset)
                      + stylePayload (finish, intensity). SDF composite NOT stored (derived).
```

Because there is no uniqueness constraint, **app-level dedup** (one `DayCustomization` per date;
sticker identity) is correctness-critical and is its own tested unit (§1.7).

### 1.3 Shared components — built once, reused everywhere

The #1 way this program stays small. Each piece is born in one stage and consumed by later ones;
**do not build any of these twice.**

| Shared piece | Born in | Reused by | Note |
|---|---|---|---|
| **`PaperSubstrate`** — the single reusable paper-card primitive: texture (shader) + ruling (dots/grid/lines) + tint + card chrome (edges/shadow/binding holes/perforation), driven by a `PaperStyle` | **Stage 3** | DayView stack, paper wizard, `PageEditorCanvas` (4), widget (10) | **The primitive the whole feature rests on — must not be duplicated.** See the layering note below. |
| **`AdaptivePalette`** — semantic color tokens → light/dark-resolving `Color`s, extending the existing `PaperTints.dynamic(light:dark:)` mechanism | Stage 3 | every color in every stage + widget | The single source of truth for "what colour is Sky / Blush / primary / ink-blue, in light and dark." See §1.4. |
| **Editor chrome kit** — circular icon "well" buttons (✕ / undo / redo / back / save), 4-segment progress pill, Back/Next/Done/Save bar | Stage 3 (wizard) | Stages 4, 5 | Recipe is fixed by the design project's `CLAUDE.md` (always-circular icon buttons). |
| **`PageEditorCanvas`** — `PaperSubstrate` + `PageContent` + placeable-object layer + compact-core corner brackets + ruling-snap + drag-to-move | **Stage 4** | Stage 5 (Today), 9 (sticker placement) | The editor spine. Page-4 widgets and the Today editor are the *same* canvas, differing only in what they place (global structural widgets vs per-day ink/text/stickers). |
| **Ink selection chrome** (`InkSelection`) — corner dots, move, delete, optional switch-format | Stage 4 | Stages 5, 9 | One language for widgets + stickers. No resize/rotate handles. |
| **Undo/redo command stack** — scope: place / move / add / remove / switch-format on the calendar stack | Stage 4 | Stage 5 (Today) | Paper swipes are intentionally **not** undoable (why pages 1–3 have no undo). |
| **Generalized SDF-bake pipeline** — extend `StampCompositor`'s Felzenszwalb–Huttenlocher bake + disk/memory cache | Stage 8 | hanko (existing) + sticker border/finish | "Don't write a second baker." |
| **`MotionStore` specular term** (existing) | already exists | paper texture tilt (3), sticker finishes (9), font ink (6) | Tilt-reactive highlight, Reduce-Motion/Low-Power gated. |
| **`PageContent`** (existing) | already exists | every page render + widget | The date/weather/sun **content** layer that sits *on* the substrate. Extend to honor structural widgets. |

**Paper rendering layering (keep these three distinct — this is what stops duplication):**
1. **`PaperSubstrate`** — the paper *background* (texture + ruling + tint + chrome) for **one** card.
   The reusable primitive. DayView composes a *stack* of these for the tear-off pad; the wizard shows
   one centred; the editor and widget each show one.
2. **`PageContent`** (existing) — the *content* drawn on the substrate (numeral, weekday, weather, sun).
3. **`PageEditorCanvas`** (Stage 4) — substrate + content + the *editable* placeable-object layer,
   selection chrome, and brackets. Only the editors use this; DayView/wizard/widget use 1 (+2).

> Naming caution: the existing `WidgetGalleryView.swift` is a **screenshot-only** screen, unrelated
> to the v3 widget drawer. Name the new structural-widget drawer something distinct
> (e.g. `StructuralWidgetDrawer`) to avoid collision.

### 1.4 Color & light/dark mode (cross-cutting — no holes allowed)

The user can't pick arbitrary colours — they pick from a **fixed, curated set** (paper tints
Cream/Blush/Sky/Sage/Butter/Lilac; text/ink "primary" + tints). That fixed-set constraint is exactly
what makes correct dark mode tractable, and it dictates a hard rule:

- **Store the colour *token*, never a baked RGB value.** `tint = .sky`, `ink = .primary`,
  `inkColour = .blue` — an enum/index, not `#A9C4DE`. A device resolves the token to the right P3
  colour for *its current appearance* at render time. This (a) makes dark mode automatic, (b) keeps
  the same stored value valid as we re-tune palettes later, and (c) honours the existing rule "pastel
  tints are dynamic `Color`s — don't snapshot them to static hex." It also makes sync trivially
  correct: the token syncs, each device renders its own light/dark.
- **`AdaptivePalette` is the single resolver**, extending the existing
  `PaperTints.dynamic(light:dark:)` pattern (a `UIColor { trait in … }` closure already used for the
  paper stack and `Color.pastelized`). Every token gets a **hand-tuned dark variant — a genuinely
  different, darker colour, not the light value dimmed** (matching Hibi's "high-contrast dark"
  convention: front paper `#242424`, back pure black). "Primary" ink is the adaptive black↔near-white
  pair; each paper tint and each text/draw ink colour gets its own (light, dark) pair chosen to read
  well on the dark canvas.
- **Shaders need the resolved colour, and must re-render on appearance change.** Metal shaders take
  raw colour values, not dynamic `Color`s — so texture tilt (3), font ink (6), draw ink (7), and
  sticker finishes (9) must be fed the scheme-resolved colour and re-render when `\.colorScheme`
  flips. Follow the stamp pattern: **bake luminance/alpha/SDF (scheme-independent), apply the
  adaptive colour at shade time** — so the cached composite is reused across both appearances and only
  the colour input changes. Where a baked bitmap *must* carry colour, cache a light **and** a dark
  variant.
- **Stickers:** the photo content is fixed (it's a photo), but the **die-cut border + finish adapt** —
  warm-white border in light, the lighter/different treatment in dark the plan calls for. This is part
  of the sticker render, not a separate path.
- **Widget:** must resolve tokens for *its own* `colorScheme` too — see §1.5 and Stage 10. Never ship
  the widget a single-appearance baked image.

**Tested as pure logic:** token → (light, dark) resolution table is exhaustive and deterministic →
a high-value unit test (every token resolves to a defined, distinct pair; no token falls back to a
default). Born in Stage 3, asserted there.

### 1.5 Widget data-flow obligation (what each stage feeds; rendering is Stage 10)

The Today's Page home-screen widget shows today's page, so **anything that changes how a page
looks must reach the widget**: paper style (3), structural widgets (4), and today's per-day
ink/text/stickers (5–9). Each of those stages has one obligation here: **serialize its data/tokens
into the App Group snapshot** (paper style tokens, structural-widget layout, today's decoration) and
call `WidgetCenter.reload…`, same as events/weather do today.

**The widget's actual *rendering* of the customized page is its own stage (Stage 10).** WidgetKit
can't run the tilt/specular Metal shaders or `MotionStore` the way the app does (no continuous
animation, tight memory/time budget, single static snapshot per timeline entry), so *how* the widget
reproduces the customized substrate — re-render from synced tokens with a static, shader-light path,
or have the app bake a snapshot bitmap (light **and** dark) into the App Group and just display it —
is a real design decision deferred to Stage 10. Stages 3–9 only guarantee the **data is there**; they
do not try to make the widget pixel-match.

### 1.6 Craft / shader foundation

Craft-complete means Stages 3, 4, 6, 7, 8, 9 each carry Metal work. The foundation already exists
and must be **generalized, not duplicated**:

- Pipeline: `StampConfig` (seed) → `StampCompositor` (composite + baked SDF, disk/mem cache) →
  `StampShader.metal` (`[[stitchable]]` layer effect, role-separated noise + specular, tilt-reactive).
- Skills to invoke per craft stage: `stamp-ink-noise`, `swiftui-metal-shaders`, `msl-techniques`,
  `metal-motion-effects`.
- Reference shaders (MIT, copyable) in `SWMetal`: `SWFoil` → holographic; `SWGlitter` → glitter;
  `SWChromaticGlass`/`SWGlass` → shiny; `SWGrainGradient` → paper grain overlay.
- Every animated shader needs a **Reduce Motion / Low Power** fallback to a fixed-angle static
  gradient (finishes never vanish, just stop moving).

**Validated research basis for paper & ink shaders (read before the relevant craft stage):**
- [`docs/paper-shaders-research.md`](../../paper-shaders-research.md) — paper-texture stack (Stages 3, 10). Authoritative for fBm formation/grain/tooth, the per-texture preset table (§L), fBm conventions (lacunarity≈2, gain≈0.5, 3–5 octaves, detune+rotate — §E), laid-line aliasing/band-limiting (§I), and contrast calibration (low single-digit % luminance, warm cream — §G).
- [`docs/ink-shaders-research.md`](../../ink-shaders-research.md) — ink/mark stack over glyph SDFs (Stages 6 text, 7 draw, possibly 10). The 4 core ops (threshold-perturb, domain-warp, dilate/erode by absorbency, alpha/darkness mod), per-instrument presets, and the SDF "field-breaking" AA caveat.

**Two cross-cutting mandates from that research (apply in every craft stage):**
1. **BAKE, don't evaluate-per-frame.** Apple GPUs are TBDR; per-fragment multi-octave fBm every frame is the wrong default for a mostly-static calendar surface. Bake the noise to a **mipmapped offscreen texture** (per style / per zoom-bucket), disk/mem-cached exactly like `StampCompositor`, then sample cheaply; keep only small genuinely-dynamic terms (tilt specular) live. This is also what lets the **widget** (Stage 10, no live shaders) reuse the same baked surface.
2. **Paper and ink stacks are LINKED — one shared paper-field set.** Build the paper field (formation, tooth/height, fiber-direction, absorbency, show-through) **once in Stage 3** as a shared, baked resource; ink stages **read** it (pencil/marker grain = glyph alpha × paper tooth; wet-ink feathering follows the paper fiber-direction field — the Aslannejad & Hassanizadeh "spider-leg" wicking). Do **not** re-derive paper noise inside the ink shaders.

### 1.7 Test strategy (high-value, low-complexity — no UI/E2E)

Mirror the existing pattern: pure-logic unit tests on formatters / caches / seeds / state machines
(`TemperatureUnitTests`, `StampConfigFormatDateTests`, `StampCompositorCacheTests`, `StampSeedTests`).
**The test target is compile-checked here and run on-device by the user** (per AGENTS.md / CLAUDE.md;
no simulator). The strategy *drives architecture*: push logic out of views into testable types.

Cross-stage high-value targets (each assigned to its stage below):
KVS↔AppGroup mirror round-trip + remote-change handling · app-level dedup (date key + sticker id) ·
zIndex ordering resolver · date-format variants (`5`/`05`/`Mon`/`Monday`/`Jun`/`June`/`06`/`2026`/`'26`) ·
undo/redo command-stack invariants · ruling-snap math · 500-sticker cap · SDF-bake cache ·
image compression round-trip · "no subject → full-rect" fallback · edit-mode state machine ·
style-payload encode/decode · Reduce-Motion fallback selection.

### 1.8 Conventions (all stages)

- **Localize every user-facing string** → all 11 locales in `Localizable.xcstrings` /
  `InfoPlist.xcstrings` (incl. widget strings, usage descriptions). Translate naturally. (AGENTS.md.)
- **Edit-mode behavior (Stages 4–9):** disable swipe-to-navigate-days while editing; cancel →
  confirm if unsaved changes; leaving the day view while editing → exit edit mode (+ popup); hide
  the tab bar **in place** with `.toolbar(isEditing ? .hidden : .visible, for: .tabBar)` inside
  `withAnimation`.
- **Build-only verification** (no simulator). State clearly when runtime/visual checks are left to
  the user.

---

## 2. Stages

### Stage 1 — Settings sync via iCloud KVS (+ migrate existing settings)

**Goal:** existing settings stop being lost on reinstall and sync across devices; proves the iCloud
entitlement plumbing. (Lowest risk, immediately useful.)

**Depends on:** nothing.

**Scope:**
- Add capabilities to the **app** target now (front-loaded): iCloud **Key-value storage**, iCloud
  **CloudKit** + create/select container `iCloud.com.weichart.hibi`, **Background Modes → Remote
  notifications**. (CloudKit/remote-notifications are unused until Stage 2 but added once.)
- A `SyncedSettingsStore` that owns the mirror: KVS = source of truth for **sync**; App Group
  `UserDefaults` = source of truth for the **widget**. On local change → write both. On
  `NSUbiquitousKeyValueStore.didChangeExternallyNotification` → update in-memory store + App Group +
  `WidgetCenter.reloadAllTimelines()`. Last-writer-wins.
- Migrate the existing settings currently in App Group / standard `UserDefaults` (`TemperatureUnit`,
  `TimeFormat`, appearance override, hidden calendars/lists in `EventStore`) to write-through KVS;
  seed KVS from existing App-Group values on first run (one-time, idempotent).
- Budget check: settings are a few enums + an ID set → <1% of the 1 MB / 1024-key KVS limit.

**Widget flow:** unchanged — widgets keep reading App Group; the mirror keeps it fresh.

**Tests:** mirror round-trip (write → KVS+AppGroup both updated); remote-change handler updates
in-memory + AppGroup + triggers reload; one-time migration seeds correctly and is idempotent;
last-writer-wins resolution.

**Done:** toggling a setting on device A appears on device B; settings survive delete+reinstall;
widgets still honor units/time format.

---

### Stage 2 — Customization persistence foundation (SwiftData + CloudKit, full graph, one deploy)

**Goal:** a synced, offline-first store with the **entire** v3 model graph and the Production schema
deployed once. No customization UI yet (a tiny DEBUG harness is fine).

**Depends on:** Stage 1 (capabilities).

**Scope (ordered substeps):**
1. **Local-first:** define all `@Model` types from §1.2 against the CloudKit constraints; validate
   the shape (no `.unique`; all optional/defaulted; relationships optional+inverse+unordered;
   `zIndex`; `stylePayload` blobs; `.externalStorage` on image/ink data). Wire
   `ModelContainer` into the app via `.environment`/`.modelContainer`. Verify it builds and persists
   with **no iCloud account** (offline-first).
2. **App-level dedup helpers:** "fetch-or-create `DayCustomization` for date" and sticker-identity
   dedup (persistent-history-driven), since there's no uniqueness constraint.
3. **Turn on CloudKit** (`cloudKitDatabase: .automatic`, private DB).
4. **Schema deploy (once):** DEBUG-only bring-up that builds an `NSManagedObjectModel` from the
   `@Model` types, wraps it in `NSPersistentCloudKitContainer`, calls `initializeCloudKitSchema()`
   (so the schema includes *every* field, not just JIT-exercised ones), then **Deploy to Production**
   in CloudKit Console. Add "Deploy CloudKit schema" to the `create-release` checklist for any future
   additive change.

**Widget flow:** none yet (no visible customization).

**Tests:** dedup-by-date resolver (same date → same record); sticker dedup; zIndex ordering resolver
(reconstruct visual order from unordered relationship + `zIndex`); `stylePayload` encode/decode
round-trip; container initializes with no account (offline-first).

**Done:** writing a model on device A appears on device B after sync; schema is in Production;
store works fully offline; release checklist updated.

> Use the `swiftdata-pro` and `axiom-data` skills here; the repo already added `swiftdata-pro`
> references including `cloudkit.md`.

---

### Stage 3 — Paper customization (wizard pages 1–3) + global paper rendering + editor chrome

**Goal:** a "Customize calendar" Settings row opens the wizard; swiping the centered paper stack
sets texture / ruling / colour; the choice dresses **every** page and the widget.

**Depends on:** Stage 2 (`PaperStyle`).

**Scope:**
- **`PaperSubstrate` primitive (born here — the load-bearing piece):** the single reusable paper-card
  view that takes a `PaperStyle` and renders texture + ruling + tint + chrome. **Refactor DayView's
  current card rendering to compose `PaperSubstrate`** rather than leaving the substrate logic inline,
  so there is exactly one implementation from day one. The wizard preview, Stage 4 canvas, and the
  widget (Stage 10) all consume this same primitive. (Existing `PageContent` / `PaperChrome` /
  `BindingHoles` / `PerforationEdge` become its content/chrome parts.)
- **`AdaptivePalette` (born here):** the curated tint + ink colour set as semantic tokens, each with a
  hand-tuned **(light, dark)** pair via the existing `PaperTints.dynamic(light:dark:)` mechanism. The
  six paper tints (Cream/Blush/Sky/Sage/Butter/Lilac) get dark variants that read on the dark canvas
  (darker, not dimmed — see §1.4), and "primary" ink is the adaptive black↔near-white pair.
- **Editor chrome kit (born here):** circular icon-well buttons (✕), the 4-segment progress pill,
  Back/Next/Done nav bar — the shared chrome reused by Stage 4/5.
- Settings → **"Customize calendar"** row (Appearance section) → wizard container (4 pages; pages
  1–3 here, page 4 in Stage 4). Top bar pages 1–3: **✕ cancel only, no undo/redo** (paper swipes are
  intentionally not undoable). ✕ → **confirm dialog → discard**.
- Pages 1–3: centered `PaperSubstrate` + horizontal **swipe carousel** cycling the value (name label +
  position dots): Texture (Smooth/Linen/Kraft/News/Vellum) · Ruling (Plain/Lines/Grid/Dots) ·
  Colour/tint (Cream/Blush/Sky/Sage/Butter/Lilac). Page builds up as you go.
- **Global render:** the chosen `PaperStyle` dresses the **day pages** (the tear-off pad — every day
  page, which is what "dresses EVERY page" means and what Stage 4's full-size page assumes).
  - **⚠️ Decision to confirm (scope):** does paper apply to **day pages only**, or also the
    **Month grid / Week stream** and/or the **app background**? Texture (linen/kraft) and ruling
    (dots/grid) are day-pad concepts that don't obviously belong on a month grid; a global **tint**
    might reasonably extend to the app background. Default assumed here: **day pages only** (texture
    + ruling + tint), Month/Week unchanged. Resize this stage if that's wrong.
- **Craft (per [`paper-shaders-research.md`](../../paper-shaders-research.md)):** **bake** the paper
  field (warm base + formation fBm + per-texture grain/tooth) to a **mipmapped, disk/mem-cached texture**
  (like `StampCompositor`) — the §1.6 "bake, don't evaluate-per-frame" mandate — and build it as the
  **shared paper-field set** Stages 6/7/10 reuse (expose the tooth/height channel now; fiber-direction/
  absorbency are additive in Stage 7). Map textures to the research preset table (§L); fBm conventions
  per §E; contrast in the low single-digit % around warm cream (§G); band-limit/mipmap to avoid laid-line
  moiré (§I). A small **tilt specular** term stays live (`MotionStore`, generalizing the stamp specular);
  the shader receives the scheme-resolved tint (§1.4) and re-renders on appearance change.
  Reduce-Motion / Low Power → tilt off (baked texture still shows).

**Widget flow:** serialize the chosen texture/ruling/tint **tokens** into the App Group snapshot;
`WidgetCenter` reload on commit. (How the widget *renders* the substrate — and resolves tokens for its
own colour scheme — is Stage 10; this stage only guarantees the tokens are in the snapshot.)

**Tests:** `PaperStyle` defaults (Smooth/Plain/Cream); texture/ruling/tint token persistence;
**`AdaptivePalette` token → (light, dark) resolution is total and distinct** (every token maps to a
defined pair, no default fallback); widget snapshot carries the paper-style tokens; carousel
index↔value mapping.

**Done:** changing paper in the wizard re-dresses every day page; survives reinstall/sync; tints adapt
correctly in dark mode; texture tilts under motion in-app; the substrate is a single reusable
primitive (DayView now composes it).

---

### Stage 4 — Shared `PageEditorCanvas` + structural widgets (wizard page 4)

**Goal:** the reusable editor spine, plus the page-4 widget editor that places global date/weather/sun
widgets onto every page.

**Depends on:** Stage 2 (`StructuralWidget`), Stage 3 (paper render + chrome).

**Scope:**
- **`PageEditorCanvas` (born here, the spine):** full-size `PaperSubstrate` + `PageContent` + a
  placeable-object layer + **compact-core corner brackets** (collapsing scales the *whole stack* down;
  content outside the core scales/fades) + **ruling-snap** (snap to dots/grid; no ruling = no snap; no
  extra snap UI) + drag-to-move.
- **`InkSelection` chrome (born here):** corner dots (bounds, no handles), move, delete, and for date
  widgets a **switch-format ←→** pill; tapping the placed widget cycles its format.
- **Undo/redo command stack (born here):** place / move / add / remove / switch-format. Top bar
  page 4: **✕ · undo · redo (no save ✓)**; commit = **Done**.
- **Structural widget drawer** (`StructuralWidgetDrawer`, dots-only, no labels; date widgets show
  variant dots): Date atomic widgets — **Day** (`5`/`05`), **Weekday** (`Monday`/`Mon`),
  **Month** (`June`/`Jun`/`06`), **Year** (`2026`/`'26`); **Weather** (temp, **must** show Apple
  Weather credit — reuse `AppleWeatherAttribution`); **Sun** (sunrise/sunset). Placed widgets grey
  out in the drawer.
- Structural widgets are **global** (every page) → persist to `StructuralWidget`; render on every
  DayView page via the canvas/`PageContent`.

**Widget flow:** serialize the placed structural-widget layout into the App Group snapshot +
`WidgetCenter` reload. (Widget *rendering* of that layout = Stage 10.)

**Tests:** **date-format variant strings** (all 9 variants); zIndex ordering; **undo/redo invariants**
(apply→undo→redo returns to identical state; bounds at stack ends); **ruling-snap math**; drawer
grey-out logic (placed kind → disabled).

**Done:** structural widgets dress every day page; undo/redo works on page 4; brackets show;
format cycling works.

---

### Stage 5 — Today (daily) editor: entry + shell, reusing the canvas

**Goal:** the pencil opens a daily editor that reuses `PageEditorCanvas` to place **per-day**
objects; full edit-mode entry choreography.

**Depends on:** Stage 4 (canvas, selection chrome, undo stack).

**Scope:**
- **Pencil button** beside ＋ on the Day tab (lives on `ContentView`'s toolbar, Day tab only).
- **Edit-mode entry (one coordinated transition):** hide tab bar in place
  (`.toolbar(.hidden, for: .tabBar)` in `withAnimation`); disable swipe-to-navigate-days; reuse the
  **standard draggable schedule separator** (NOT a drawer) — tools sit flat below it where the
  schedule list normally is.
- Top bar Today: **✕ · undo · redo · ● save** (top-bar save ✓). Cancel/leave → confirm if unsaved.
- **Tool home:** three skeuomorphic objects — **Text · Draw · Stickers**; back-arrow returns home.
  (Each mode's body is Stages 6/7/8–9.)
- Reuse the canvas to place per-day objects → `DayCustomization` (fetch-or-create by date). Compact
  brackets show here too.

**Widget flow:** saving today's customization → App Group + reload. (The Today's Page widget reflects
the per-day decoration via Stage 10.)

**Tests:** **edit-mode state machine** (enter / save / cancel-with-changes / leave-while-editing);
`DayCustomization` dedup-by-date on save; undo-stack reset per editing session.

**Done:** pencil opens the editor, tab bar animates away, save/cancel works, per-day persistence +
sync.

---

### Stage 6 — Today: Text mode (craft-complete)

**Goal:** Instagram-stories-style text styling; you type on the page, not in a panel.

**Depends on:** Stage 5.

**Scope:** style editor only (no keyboard in the tray) — Font · B/I/U · effect (none / background /
outline) · colour = dynamic **"primary"** (no black+white pair) plus tints. Type-on-page interaction.
Persist `TextObject` (string + `stylePayload` + transform + zIndex). **Craft (per
[`ink-shaders-research.md`](../../ink-shaders-research.md)):** make the font read like real ink via
the ink ops over the glyph SDF/mask — primarily SDF **threshold perturbation** + low-freq **pooling**/
edge-distance darkening — **modulated by the active paper** and reusing the Stage 3 shared paper-field
(don't re-derive paper noise). Mind the SDF "field-breaking" AA caveat (recompute the smoothing
footprint). Reduce-Motion fallback.

**Widget flow:** text objects are already in the day's `DayCustomization` → reach the App Group via
Stage 5; widget rendering = Stage 10 (static, no ink-noise animation).

**Tests:** style-payload encode/decode; effect/colour model; transform persistence.

**Done:** styled text on the page survives save/sync; ink-noise renders in-app.

---

### Stage 7 — Today: Draw mode (craft-complete)

**Goal:** draw directly on the paper with one marker + eraser + size.

**Depends on:** Stage 5. (Parallelizable with Stage 6.)

**Scope:** **one marker** (single type) with ink colours + **eraser** (rubber-topped-pencil object) +
**size slider**. **Craft (per [`ink-shaders-research.md`](../../ink-shaders-research.md)):** the marker
is the wet-ink preset — feathering (domain-warp along the paper **fiber-direction field** from Stage 3),
bleed/dilation by **absorbency**, and pooling/edge-darkening — all modulated by the active paper and
**reading the Stage 3 shared paper-field** (this is where fiber-direction/absorbency fields get added to
that shared engine). **Haptic feedback by paper type**; strokes past the compact core handled in-app.
Reduce-Motion fallback.

> **Stage-level decision to make at brainstorming time:** ink capture/storage. Default lean — capture
> strokes as Codable point arrays (`.externalStorage`) and render via the Metal ink shader, since
> `PKDrawing.dataRepresentation()` is opaque and hard to re-shade for the ink-simulation look. Fall
> back to PencilKit only if the custom shader route proves too costly. (Sync doc sketch lists
> `PKDrawing`; revisit against the craft requirement.)

**Widget flow:** strokes reach the App Group via Stage 5; widget rendering = Stage 10 (static).

**Tests:** stroke-data round-trip; eraser hit logic; size→width mapping.

**Done:** marker + eraser draw and persist; ink shader in-app; haptics vary by paper.

---

### Stage 8 — Stickers: creation pipeline + library (craft-complete border + custom camera)

**Goal:** create stickers from photo or camera, auto-extract the subject, add the permanent die-cut
border, manage a ≤500 library. (Placement is Stage 9.)

**Depends on:** Stage 2 (`Sticker`). Library work is largely independent of the editor and can be
developed in parallel after Stage 2.

**Scope:**
- **＋ → source menu** (liquid-glass popover: Camera / Photo Library; tap-outside dismisses).
- **Photo Library:** `PhotosPicker` (out-of-process → no library permission prompt); load as `Data`;
  **downscale to ~1024px** working size.
- **Camera:** **custom `AVCaptureSession` viewfinder** (per design — not the system camera): dark
  lens, static white SF corner brackets (a fixed frame, not a tracking reticle), all-caps hint,
  circular ✕, single shutter. Needs `NSCameraUsageDescription`. Capture → die-cut **pop + slide
  transition** to the customize screen (sticker pinned centre as backgrounds pass).
- **Subject mask (Vision):** `GenerateForegroundInstanceMaskRequest`, **auto-run on import**, off the
  main actor; `generateMaskedImage`. Multiple instances supported (drives Re-select). **No subject →
  full rectangular photo** (still bordered). Core Image morphology feather.
- **Border (craft):** generalize `StampCompositor`'s SDF bake → die-cut white border as an SDF
  distance band (`0<d<r`) under the image — resolution-independent, fixed width, **no user knobs**.
  Warm-white tint + hairline darker outer edge; dark-mode variant. SDF composite is a **derived
  cache** (disk/mem), never synced.
- **Preview screen:** finish carousel (**None** default; Shiny/Holographic/Glitter wired in Stage 9)
  + **Re-select subject** + **Create sticker**. **Re-select:** full-screen photo + marching-ants
  contour; tap to auto-pick a different subject (no add/subtract) → "Use as sticker". (Re-select works
  **only during the creation session** — the saved alpha image *is* the result afterwards.)
- **Library:** persist `Sticker` — **compressed** masked image (HEIC-with-alpha / quality-compressed,
  **not** raw PNG) `.externalStorage` → CKAsset + style payload. **≤500 cap** (＋ blocked / prompts to
  delete at cap). **Long-press** placed/library sticker → **Edit** (re-opens finish carousel, mask
  locked) · **Delete**. Border never in the menu (permanent).

**Widget flow:** none yet (creation only; placement is Stage 9).

**Tests:** **500-cap enforcement** (block at cap); **SDF-bake cache** (mirror
`StampCompositorCacheTests`); **compression round-trip** (alpha preserved, size bounded);
**"no subject → full-rect" fallback** selection; sticker dedup.

**Done:** both sources produce a bordered die-cut sticker that lands in the library; cap enforced;
re-select works in-session; Edit/Delete work; images compressed + synced.

---

### Stage 9 — Stickers: placement + finishes (craft-complete shaders)

**Goal:** place library stickers per-day with direct manipulation, and the Metal finishes.

**Depends on:** Stage 5 (canvas in Today) + Stage 8 (library).

**Scope:**
- Place stickers on `PageEditorCanvas` (Today); **pinch-to-scale + two-finger rotate** (per the
  product answer — no frame handles); selection chrome = move + delete (stickers have no formats).
  Persist `PlacedSticker` (ref + x/y/scale/rotation/zIndex).
- **Finishes (craft):** **Shiny** (single-hue tilt glint, masked to the SDF band — `SWChromaticGlass`/
  `SWGlass` reference), **Holographic** (tilt-driven iridescent hue sweep, masked-to-band + a louder
  whole-sticker variant, capped — `SWFoil`), **Glitter** (hash-based sparkle, tasteful — `SWGlitter`).
  Reuse the stamp specular term + `MotionStore`. Finish = shader params in the **style payload**
  (instant preview; only the SDF is baked). **Contact shadow + paper-grain overlay** weld every
  sticker to the page. **Reduce Motion / Low Power → fixed-angle static gradient.**

**Widget flow:** placed stickers reach the App Group via Stage 5's save path; widget rendering
(static border + static finish gradient, resolved for the widget's colour scheme) = Stage 10.

**Tests:** finish-param payload encode/decode; placement transform persistence; **Reduce-Motion
fallback** selection logic (animated vs static path chosen correctly).

**Done:** stickers place + scale + rotate + delete on today's page; finishes animate under tilt
in-app with static fallback; placed stickers sync.

---

### Stage 10 — Widget renders the customized page (the WidgetKit-limits stage)

**Goal:** make the Today's Page home-screen widget actually *reflect* the customized page — paper
substrate (texture/ruling/tint), structural-widget layout, and today's per-day ink/text/stickers —
within WidgetKit's constraints. Stages 3–9 put all the data in the App Group; this stage is where it
becomes pixels in the widget.

**Depends on:** Stage 3 (substrate + tokens in snapshot), 4 (structural layout), 5–9 (daily decoration
in snapshot). Last stage — everything it renders must exist and be synced first.

**Why it's its own stage — the WidgetKit limits:** the widget extension can't run the app's live
craft path: no `MotionStore`/CoreMotion tilt, no continuous `TimelineView` animation (one static
snapshot render per timeline entry), and a tight memory/time budget. So the rich in-app render
(animated finishes, tilt-reactive texture, ink shaders) does **not** transfer directly.

**The core decision this stage must settle (two viable approaches — pick during its brainstorming):**
- **A — Re-render from tokens in the widget.** The widget rebuilds `PaperSubstrate` + `PageContent` +
  the placed objects from the synced tokens/layout, using a **static, shader-light** path (flat or
  cheaply-shaded texture, static finish gradient, no motion). Pro: small App Group payload, always
  fresh, resolves light/dark natively via `\.colorScheme`. Con: the substrate/finish render paths must
  have a widget-safe static variant, and parity with the app is approximate.
- **B — App bakes a snapshot bitmap.** The app renders the customized page to an image (using
  `ImageRenderer`) and writes it to the App Group; the widget just displays it. Pro: pixel-parity,
  zero widget render cost. Con: must bake **light *and* dark** variants at the needed sizes, regenerate
  on every customization/appearance change, and watch the App Group size budget; can look stale if a
  bake is missed.
- Likely answer: **A for the substrate + structural widgets** (cheap, token-driven, scheme-native) and
  consider **B only if** the daily sticker finishes prove too expensive to even statically render in
  the extension. Decide with a memory/perf check.
- **Lever from [`paper-shaders-research.md`](../../paper-shaders-research.md) §H/§I:** the Stage-3 paper
  texture is **already baked to a (mipmapped) texture**, and the bake is shader-light + motion-free —
  exactly what the widget needs. So "A" for the substrate can **reuse the baked paper field** (sample
  the same cached texture, or re-bake at widget size) rather than inventing a separate widget texture
  path. This is a third, cheaper option the bake architecture unlocks: **A′ — widget samples the baked
  paper surface** (tilt specular simply omitted). Resolve light/dark by baking/sampling per
  `\.colorScheme`.

**Scope:** implement the chosen render path in `TodaysPageWidget` / `SmallPaperView` / `LargePaperView`;
ensure **light/dark token resolution in the widget process**; make `PaperSubstrate` (and any finish
render it needs) **widget-safe** (no `MotionStore` dependency — motion is an app-only enhancement);
extend the `TodaysPageEntry` / App Group snapshot to carry the paper tokens + structural layout +
today's decoration; reload timelines on any customization change.

**Tests:** snapshot serialization round-trip (tokens + layout + decoration encode/decode); widget-side
token → light/dark resolution; "missing customization → falls back to default page" (graceful, no
crash). Visual parity is left to on-device verification (no simulator).

**Done:** customizing paper / widgets / today in the app is reflected on the home-screen widget in both
light and dark mode, within the widget's budget, without animation.

---

## 3. Sequencing & dependency graph

```
Stage 1 (KVS settings) ─┐
                        ├─► Stage 2 (SwiftData+CloudKit foundation, full graph, deploy once)
                        │        │
                        │        ├─► Stage 3 (paper wizard + PaperSubstrate + AdaptivePalette + chrome)
                        │        │        │
                        │        │        └─► Stage 4 (PageEditorCanvas + structural widgets)  ◄── the spine
                        │        │                 │
                        │        │                 └─► Stage 5 (Today shell, reuses canvas)
                        │        │                          ├─► Stage 6 (Text)   ┐ parallel
                        │        │                          ├─► Stage 7 (Draw)   ┘
                        │        │                          └─► Stage 9 (sticker placement + finishes)
                        │        └─► Stage 8 (sticker creation + library) ───────────────┘ (parallel after 2; placement needs 5)

   Stage 10 (widget renders the customized page) ◄── LAST: depends on 3,4,5–9 (data must exist + sync first)
```

Critical path: **1 → 2 → 3 → 4 → 5 → 9 → 10**. Stages 6, 7, 8 hang off the path and can overlap. Two
ordering rules matter most: **Stage 4 builds the shared canvas before any daily mode** (page editor
implemented once), and **Stage 10 is last** because it can only render customizations that already
exist and sync.

This matches the sync doc's suggested build order (KVS → SwiftData local → CloudKit → stickers last),
with the schema **front-loaded** into one deploy in Stage 2.

---

## 4. Operational / release additions

- **CloudKit schema deploy** to Production — done once in Stage 2; add to the `create-release`
  checklist for any *future* additive change (never delete/rename/retype an existing field).
- New **capabilities** on the app target: iCloud Key-value storage, iCloud CloudKit (+ container),
  Background Modes → Remote notifications. Widget target unchanged (App Group only).
- New **Info.plist usage string**: `NSCameraUsageDescription` (Stage 8) — localized in all 11 locales.
- Each craft stage: verify **Reduce Motion / Low Power** fallbacks; build-only verification, runtime
  left to the user (no simulator).

---

## 5. Out of scope / future

- **Hanko** — handled in-app; not part of customization.
- **Custom images as paper background**; **AI daily quote** — future, not v3.

---

## 6. How to execute this roadmap

Per stage, when you start it: run `brainstorming` (to settle that stage's open detail —
e.g. the Stage 7 ink-capture decision) → `writing-plans` for the stage's detailed plan → implement
test-first (`test-driven-development`) → `requesting-code-review` → `verification-before-completion`.
Foundation Stages 1–2 are specified deeply enough here to go almost straight to `writing-plans`.
