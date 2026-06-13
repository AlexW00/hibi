# Hibi — Customize Update v3

Users customize their calendar at **two levels**. Three stacked layers throughout:

| Layer | What | Stack |
|---|---|---|
| Widgets | placed objects (tappable, movable) | top |
| Drawing | free ink (decoration, not widgets) | middle |
| Paper | background substrate | bottom |

## Two editors — the core split

- **Calendar structure (global, set-once)** — Settings → one row **"Customize calendar"**.
  Dresses EVERY page. A 4-page wizard: Paper texture → Ruling → Colour → Widgets.
- **Today (daily)** — a **pencil button** beside ＋ on the day view. Decorates only this day.
  Opens a home of three objects: Text · Draw · Stickers.

The split is what answers "does Save dress every page or just today?" — **structure = every
page, today = this day.**

The editor reuses the calendar's **standard draggable schedule separator** (NOT a drawer) —
tools sit flat below it where the schedule list normally is.
There is **no Paper/Draw/Widgets pill** anywhere — the split lives in Settings vs. the day view.

### Top bars & commit model (NOT uniform — by design, but verify)

The three screens deliberately carry different chrome:

| Screen | Top bar | Commit |
|---|---|---|
| Paper wizard (pages 1–3) | **✕ cancel only** (no undo/redo) | bottom **Next** → flows forward |
| Widgets (page 4) | ✕ · ↶ undo · ↷ redo (**no save ✓**) | bottom **Done** |
| Today | ✕ · ↶ undo · ↷ redo · ● **save** | top-bar save ✓ |

- **Undo/redo scope (resolved):** undo applies **only to placing / moving / adding / removing
  things on the calendar stack** (widgets, stickers, ink). **Paper swipes (texture / ruling /
  colour) are intentionally NOT undoable** — that's why pages 1–3 have no undo/redo.
- **✕ on a wizard page (resolved):** shows a **confirm dialog**; confirming **discards changes**.

## Paper (global, wizard pages 1–3)

Swipe the centered paper stack to change each property:
1. **Texture** — Smooth / Linen / Kraft / News / Vellum.
2. **Ruling** — Plain / Lines / Grid / Dots.
3. **Colour (tint)** — Cream(default) / Blush / Sky / Sage / Butter / Lilac.

- _[impl, not depicted]_ Texture should have tilt effects (depthmap + slight specular).

## Widgets — structural (global, wizard page 4)

Page goes full size (like Today edit), carrying the chosen texture/ruling/colour.
A drawer of widgets to pull onto the page. Bare ink, no containers.

- **Date — atomic widgets** (no combined "full date" widget). Offer **multiple format variants per
  field** so users can cover most cases:
  - **Day number** — `5` (and `05` padded)
  - **Weekday** — `Monday` (long) · `Mon` (short)
  - **Month** — `June` (name) · `Jun` (short) · `06` (number)
  - **Year** — `2026` (full) · `'26` (short)
- **Weather** — temperature; MUST show "Apple Weather" credit.
- **Sun** — Sunrise / Sunset.
- **Behavior:** snap to the page's ruling (dots/grid); no ruling = no snapping. No extra snap UI.
- Compact core marked by **corner brackets**; collapsing **scales the WHOLE stack down**
  (not a single boundary line). Content outside the core scales/fades with it.
  - **Brackets show in BOTH editors** — the page-4 Widgets editor **and** the Today/daily editor —
    so structural widgets *and* daily ink/stickers both have the compact-core guide. (Currently
    missing from both in the mocks → add back.)
- ⚠️ **GAP:** placed-widget **manipulation chrome** (select → move / resize / delete) is **not
  designed** anywhere in the final flow. The earlier "Selecting a widget" mock (monochrome frame +
  handles + floating bar) didn't survive consolidation. Needs a dedicated design pass.

## Today (daily) — three modes

Tapping the pencil swaps the schedule for a home of three skeuomorphic objects; back-arrow returns home.

- **Text** — style editor only (no keyboard here; you type on the page). Font · B/I/U ·
  effect (none / background / outline) · colour. Colour = dynamic **"primary"** (no black+white
  pair) plus tints. Instagram-stories feel.
  - _[impl, not depicted]_ noise shaders to make the font look like real ink.
- **Draw** — **one marker only** (for now): a single marker type with ink colours + eraser
  (a rubber-topped pencil object) + size slider. Draw directly on the paper.
  - _[impl, not depicted]_ ink-simulation shader; haptic feedback by paper type;
    strokes past the compact core handled in-app.
- **Stickers** — a gallery grid; add (＋) and remove (×). See sticker flow below.

## Stickers

- **＋ opens a "Camera or Gallery" menu** first, then the chosen source.
- Photo opens straight as a **sticker preview** — subject auto-extracted (OS / Vision),
  permanent white die-cut **border** added (border non-removable; lighter edge in dark mode).
- **Swipe ←/→ changes the finish**: None · Shiny · Holographic · Glitter.
  - _[impl]_ Metal-shader finishes (ref: signerlabs/ShipSwift → SWPackage/SWAnimation/SWMetal).
    Degrade to a static gradient under Reduce Motion.
- Buttons: **Re-select subject** and **Create sticker**.
- **Re-select subject** screen: full-screen photo + marching-ants mask; tap to auto-select a new
  subject (no add/subtract); "Use as sticker" → preview.
- After creating, the sticker lands in the drawer grid.
- **Long-press** → context menu with **Edit** (re-opens preview, finish only; mask locked) and **Delete**.
- **Library cap:** a user can keep at most **500 stickers**. At the cap, ＋ is blocked /
  prompts the user to delete some first.
- **Storage:** sticker images are **compressed** to save space (the extracted cut-out is stored,
  not the full original photo).

## Hanko

**Removed from customization for now** — it's already handled in-app. Each Plus user gets an
individual stamp there. Not placed via these editors.

## Edit-mode behavior (not depicted in mocks, still required)

- Disable swipe-to-navigate-days while editing.
- Cancel → confirmation popup if there are unsaved changes.
- Leaving the day view while editing → exit edit mode (+ popup).
- **Hide the bottom tab bar in place** when entering Today edit — same screen, no navigation push,
  animated. Use `.toolbar(isEditing ? .hidden : .visible, for: .tabBar)` inside `withAnimation`
  (works iOS 16+, fine on iOS 26). Keeps the whole edit-mode entrance one coordinated transition.

## Open questions

- **Manipulation chrome** (see Widgets GAP): how does a placed widget/sticker get selected,
  moved, resized, deleted? No design exists — needs its own pass. (Select = monochrome frame +
  handles; supports move / resize / delete; undoable.)
- Is the aspect ratio fixed? If not, fix it.

### Resolved

- **Sticker library scope:** a created sticker is **reusable on every day** — it's a global
  library asset. *Placing* it is per-day.
- **Daily content vs compact core:** the Today editor shows the **compact corner brackets** as the
  guide, same as the Widgets editor, so daily ink/stickers know what survives collapse.
- **Undo scope & wizard ✕:** see Top bars & commit model above.
- **Date format variants:** multiple formats per field (see Widgets above).
- **Camera path:** post-capture, the photo feeds the **same auto-extract sticker preview** as the
  gallery path — one merged flow.

## Persistence & iCloud sync

Customizations and settings **must survive uninstall/reinstall and sync across the user's
devices** — they can't just live on one device. Hibi has no database today (state is in
`@Observable` stores backed by `UserDefaults` + the App Group), so this is a **new sync
layer**. Three data kinds map to three Apple stores:

| Data kind | Store | Schema to deploy? |
|---|---|---|
| **Settings** (units, time format, appearance, hidden calendars) | `NSUbiquitousKeyValueStore` | ❌ None |
| **Calendar customizations** (paper style, structural widgets, per-day ink/text/stickers) | **SwiftData + CloudKit** | ✅ Yes — and **additive-only forever** |
| **Sticker library** (≤500 cut-outs + style payload) | Same SwiftData store; image via `.externalStorage` → CKAsset | ✅ Same container |

Key consequences for design:
- **No `@Attribute(.unique)`** under CloudKit → per-day records (keyed by date) and stickers
  dedupe at the app layer, not via a uniqueness constraint.
- **Every property optional/defaulted; relationships optional + inverse + not ordered** →
  store an explicit `zIndex` for z-order (CloudKit relationships aren't ordered).
- **Derived caches don't sync** — the sticker SDF composite / baked finishes are rebuilt on
  device (same as `StampCompositor`); only the compressed cut-out + style payload sync.
- **Operational gotcha:** the CloudKit schema must be **manually deployed to Production
  before every release** (add to the release checklist) or data silently fails to sync.

**→ Full plan, model sketch, model constraints, deployment workflow, entitlements, and open
decisions: [customize-v3-sync.md](customize-v3-sync.md).**

## Future

- Custom images as paper background.
- Daily quote tailored to the day + tone (AI).

---

## Appendix A — Sticker borders & finishes (rendering / craft)

Identity: physical objects stuck on cream paper, not Instagram glass. Built on the SDF +
layer-effect pipeline (the stamp shader's specular term + edge-roughness + MotionStore).

### Border
- **Die-cut white**, permanent and non-removable. Classic vinyl-sheet band: tint **warm** white
  (pure `#FFF` fights the cream), with a hairline darker outer edge so it reads as a *cut*, not a
  glow. Different treatment in dark mode.

### Finishes — None · Shiny · Holographic · Glitter (swipe to change)
- **None (default)** — restraint is the luxury register; finish is opt-in.
- **Shiny** — single-hue tilt-driven glint (gold/silver foil), masked to the SDF border band; reuses
  the stamp's specular term + MotionStore.
- **Holographic** — tilt-driven iridescent hue sweep; masked-to-band, with a louder "whole sticker"
  variant (gradient × image luminance). Cap the intensity.
- **Glitter** — hash-based sparkle; keep it tasteful.

### Cross-cutting (applies to every sticker)
- **Contact shadow + paper-grain overlay**: a soft, tight drop shadow (stuck on, not floating) plus
  paper grain multiplied at low opacity. Welds the sticker into the page; grain read is free (shared
  paper field).
- **Reduce Motion / Low Power fallback** — Shiny / Holographic / Glitter degrade to a fixed-angle
  static gradient, so finishes never vanish, just stop moving.

## Appendix B — Sticker pipeline (implementation)

No single iOS "sticker" framework — assembled from four pieces, and the hardest (SDF bake +
layer effect) already exists in the hanko/stamp pipeline.

### 1. Pick — PhotosUI / Camera
- **Gallery:** `PhotosPicker` runs out-of-process → **no photo-library permission prompt** (fits the
  no-backend privacy posture). Load the `PhotosPickerItem` as `Data`.
- **Camera:** native capture — this path **does** need `NSCameraUsageDescription` + a permission
  prompt (the only sticker source that does).
- Either way, **downscale immediately to ~1024px** working size (Vision cost scales with input).

### 2. Subject mask — Vision
- Use **`GenerateForegroundInstanceMaskRequest`** (modern Vision; legacy
  `VNGenerateForegroundInstanceMaskRequest` also fine) — on-device, async, off the main actor.
  Returns an instance mask + `generateMaskedImage(...)` (subject with alpha).
- **Auto-run on import** (not VisionKit's long-press lift — that's UIKit and surrenders gesture
  control, awkward inside the wizard). The photo opens already a sticker.
- **Multiple instances** are supported → hit-test the user's tap against the instance mask to drive
  the **Re-select subject** screen.
- Clean/feather rough edges with a couple of Core Image morphology passes.
- **No subject found → fall back to the full rectangular photo** (still gets the border).

### 3. Border + finish — reuse the stamp architecture
- On import / mask change, **bake a composite**: colour image + alpha, with an **SDF of the alpha
  channel** baked alongside. Generalize `StampCompositor`'s Felzenszwalb–Huttenlocher SDF bake +
  disk/memory cache — don't write a second baker.
- **Border** = SDF distance band (`0 < d < r`) filled under the image. Resolution-independent,
  naturally rounded, scales without re-running Vision. The band width is a fixed style constant —
  the border is permanent and has **no user knobs**.
- **Finish** = the stamp's specular trick: tilt-driven (`MotionStore`) highlight in the
  `[[stitchable]]` layer effect, masked to the band or whole sticker, hue-shifted by position + tilt.
  Gate behind Reduce Motion / Low Power.
- Finish style/intensity are shader parameters in the sticker's **style payload** → instant preview,
  only the SDF is baked.

### 4. Persistence
- Store the final **masked image with alpha** (compressed — HEIC-with-alpha or quality-compressed,
  **not** raw PNG; matters across the 500-sticker cap) + the style payload, in the sticker asset store.
- The SDF composite is a **derived cache** (like stamp composites) — rebuilt on demand.
- The mask is **not** re-run or re-stored after creation — the saved alpha image *is* the result.
  (So **Re-select subject works only during the creation session**, while the original photo is in
  hand; after that, Edit changes finish only.)

### Stack summary
PhotosUI / Camera (pick) → Vision (subject mask) → Core Image (downscale / feather)
→ generalized SDF-bake + layer-effect pipeline (border, finish, render). No new frameworks beyond
Vision / PhotosUI; effects land on the proven hanko infrastructure.
