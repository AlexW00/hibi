# Transparent widget PNG extraction — design

## Problem

`scripts/screenshots.sh` (fastlane snapshot) captures App Store screenshots,
including two widget-gallery screens rendered against a **chroma-key green**
backdrop (`WidgetGalleryView`, green = pure sRGB `(0, 1, 0)`):

- `*-06-Widget-Schedule.png` — Schedule widget: medium (top) + large (bottom)
- `*-07-Widget-Today.png` — Today's Page widget: small (top) + large (bottom)

A device/simulator screen capture has no alpha channel, hence the green screen.
We want **transparent-background PNGs of each individual widget**, cropped tight,
for use as marketing cutouts. This must be a separate, re-runnable step that does
not require re-shooting.

## Solution

A standalone Python script, `scripts/remove_widget_backgrounds.py`
(Python 3 + Pillow + numpy — both already present on the dev machine), plus an
optional prompt wired into `scripts/screenshots.sh`.

### CLI

```
python3 scripts/remove_widget_backgrounds.py [options]
  --source DIR     input root (default: screenshots)
  --out DIR        output root (default: screenshots-widgets)
  --locales CSV    comma list (default: en-US,zh-Hans,zh-Hant,ja,ko)
  --no-preview     skip the _preview.png verification composites
```

Fully independent of fastlane; re-runnable any time against an existing
`screenshots/` tree.

### Per-locale algorithm

1. **Locate sources** by filename *suffix* (`-06-Widget-Schedule.png`,
   `-07-Widget-Today.png`) so the device prefix (`iPhone 16`, `iPhone 16 Pro
   Max`, …) is irrelevant. Skip + warn if a locale's sources are missing.

2. **Chroma key with feathered alpha + despill** (binary keying would leave a
   green halo or jagged edge on the `cornerRadius: 28` anti-aliased widget
   corners — the interior keys trivially, the rounded edges are beige↔green
   blends):
   - greenness `= g − max(r, b)`
   - alpha: opaque where `greenness ≤ lo` (lo ≈ 0), fully transparent where
     `greenness ≥ hi`, linearly feathered between
   - despill kept pixels by clamping `g → max(r, b)` to remove green fringe

3. **Band-split** by projecting alpha onto rows. The 26 pt VStack gap is a band
   of fully-transparent rows, so content rows form exactly two maximal runs
   (top widget, bottom widget). Tight-crop each band on both axes.

4. **Map bands → sizes** by source + VStack order, *verified* by aspect ratio
   (warn, don't mislabel, on mismatch):
   - Schedule: top ≈ 2.1 (wide) → `medium`, bottom ≈ 0.95 → `large`
   - Today:    top ≈ 1.0 → `small`, bottom ≈ 0.95 → `large`

5. **Write** tight transparent PNGs:
   - `Widget-Schedule-medium.png`, `Widget-Schedule-large.png`
   - `Widget-Today-small.png`, `Widget-Today-large.png`

### Output location

`screenshots-widgets/<locale>/` — a **sibling** of `screenshots/`, deliberately
*outside* the fastlane `output_directory`. The Snapfile sets
`clear_previous_screenshots(true)`, which wipes `./screenshots` at the start of
each run; a sibling folder cannot be silently deleted by a later run where the
user declines extraction.

### Verification (this is a visual task — do not declare done blind)

- The script writes `screenshots-widgets/<locale>/_preview.png`: the four
  cutouts composited over a magenta/checkerboard background so any residual
  green fringe is glaring. `--no-preview` opts out.
- Structural asserts per output: image has an alpha channel; the four corners
  are alpha 0; the centre pixel is opaque.
- During implementation: Read one `_preview.png`, zoom a rounded corner, confirm
  no halo before claiming completion.

### Integration into `scripts/screenshots.sh`

After `fastlane snapshot` completes, prompt:
`Extract transparent widget PNGs now? [Y/n]`.

- Honors `EXTRACT_WIDGETS=1|0` for non-interactive runs (skips the prompt).
- Calls `python3 scripts/remove_widget_backgrounds.py` on yes.
- The Python script stays standalone so extraction can be re-run without
  re-shooting.

### Out of scope

- `screenshots/screenshots.html` is standard fastlane output — left untouched.
- No new HTML gallery is built (the `_preview.png` composites cover review).

## Files touched

- **new** `scripts/remove_widget_backgrounds.py`
- **edit** `scripts/screenshots.sh` — post-snapshot extraction prompt
- **edit** `docs/screenshots.md` — short section documenting the new step
