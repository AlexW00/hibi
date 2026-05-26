---
name: stamp-ink-noise
description: How to create realistic rubber-stamp ink-transfer imperfections in Metal shaders. Covers the baked-SDF channel contract, the role-separated noise model (supply, mottle, dropout, chips, rim, bleed, roughness), the StampNoise parameter/preset system and DEBUG tuning menu, and the stamp pipeline (StampConfig seed, StampCompositor composite + SDF, StampShader.metal effect). Use when modifying stamp visuals, tuning noise parameters, or adding new stamp-related features.
---

# Stamp Ink Noise & Pipeline

## Architecture

The stamp rendering pipeline has three stages:

1. **StampConfig** (`Hibi/Models/StampConfig.swift`) — Deterministic seed from purchase date (Wang hash, 24-bit for Float safety). Selects which stamp definition to use via `seed % definitions.count`. The `stamps.json` file maps stampIds to date region configs.

2. **StampCompositor** (`Hibi/Models/StampCompositor.swift`) — Rasterizes mask PNG + date text into a single grayscale CGImage. Mask PNGs (256×256, 8-bit grayscale, **bright = ink**, dark = paper) live in `Hibi/Resources/StampMasks/`. **Channel contract:** R = ink coverage, **G = baked signed distance field**, B = coverage (unused), A = opaque. The SDF is computed from the final mask+text coverage (so text edges get edge effects too) via a separable Felzenszwalb–Huttenlocher Euclidean distance transform, then encoded into G.

3. **StampShader** (`Hibi/Shaders/StampShader.metal`) — `[[stitchable]]` SwiftUI layer effect. Receives the composite, applies role-separated procedural ink noise, specular highlight, and bump/emboss. All noise is seed-deterministic; only `tilt` varies per frame. Noise parameters arrive as a `.floatArray`.

## SDF encoding (compositor ↔ shader contract)

`StampCompositor.sdfRange` (Swift) and `SDF_RANGE` (Metal) **must stay equal** (currently `0.06`). Encoding/decoding:

```
// compositor: sdPx = signed distance in pixels (inside > 0)
g = clamp(0.5 + (sdPx / maxImageDim) / (2 * sdfRange), 0, 1)   // → green channel

// shader: recover a signed distance, then convert to view points
sdN   = (raw.g - 0.5) * 2 * SDF_RANGE      // fraction of image dimension
sdPts = sdN * size.x                       // points, resolution-independent
```

Storing distance as an image fraction (not raw pixels) keeps edge bands (rim, bleed) a fixed size in **points** regardless of display size or composite resolution. SDFs interpolate cleanly under bilinear filtering — that's why baking distance beats sampling the binary mask.

## Noise pipeline: role separation

Convincing stamp noise is **never one function**. Real impressions combine ink-supply variation, edge meniscus (squeegee), capillary wicking, and broken coverage — each at a different scale. The shader separates these into independent mechanisms, all gated by a single `master` strength (0 = perfectly clean composite):

| Mechanism | Noise | Affects | Physical analogue |
|-----------|-------|---------|-------------------|
| `supply`  | low-freq simplex fBm | ink darkness + inward erosion | uneven pad/pressure |
| `mottle`  | mid-freq fBm | interior ink darkness | patchy transfer |
| `dropout` | interleaved-gradient (blue-noise-ish) dither, clustered by low supply | sparse alpha holes | under-inking |
| `chips`   | Worley cells | larger alpha voids | dry / relief wear |
| `rough`   | high-freq simplex on the SDF boundary | boundary jaggedness | torn edge |
| `rim`     | inner SDF band | darkens ink | squeegee / edge concentration |
| `bleed`   | outer SDF band × anisotropic fBm | adds faint ink outside | capillary feathering |

Key principles learned the hard way:
- **Density (color) and coverage (alpha) are separate.** `supply`/`mottle` modulate ink *brightness* centered on 1.0; they do not on their own punch holes. Holes come from `dropout`/`chips` (multiplicative alpha) and boundary erosion.
- **Edge effects need a real distance field.** Rim darkening and outward bleed operate in bands several points wide — impossible from a 1px coverage ramp or a 2px neighbourhood. Hence the baked SDF.
- **Erosion only removes ink** (`min(coverage, erodedAlpha)`); bleed is the only thing that adds outside the shape.
- **`master = 0` must be exactly the clean composite** — `alpha = mix(coverage, eroded, master)` and every strength knob is pre-multiplied by `master`.

### Why the old approach was replaced

The previous shader used a single fBm field as a coverage multiplier plus a near-pixel hash "perturbation threshold." It looked cloudy/digital because one isotropic field can't represent supply, edge, and dropout simultaneously, and it had no notion of distance-to-boundary (no rim, no directional bleed). The redesign deletes all of that (and the compositor's CPU text-grain pass) in favour of the SDF + role-separated model above.

Approaches that did **not** work and should not be reintroduced as the *primary* texture: fBm-as-multiplier with a floor, Worley+smoothstep alone (smooth circles), coarse non-interpolated hash (visible grid), single cloudy field for everything.

## Parameters, presets, and the debug menu

`Hibi/Models/StampNoise.swift` is the single source of truth:
- `Param` enum — ordered list of 16 floats. **Index order MUST match the `P_*` `#define`s in StampShader.metal.**
- `Preset` enum — `clean` / `balanced` / `dry` / `wet`. `balanced` ships in release.
- `encode`/`decode` — flat `[Float]` ⇄ comma-joined String for `@AppStorage`.

`HibiStamp` (in `HibiPlusView.swift`) reads the values and passes them as `.floatArray(noiseValues)`. **Release always uses `StampNoise.defaultValues`**; only DEBUG builds read the persisted, tunable values (`#if DEBUG` around the `@AppStorage`).

The DEBUG-only **Settings → Debug → Stamp Noise** page (`StampNoiseDebugView` in `SettingsView.swift`) shows a live `HibiStamp` preview, a preset segmented picker, and a slider per parameter. Editing a slider switches the preset to a `custom` sentinel. Because the SDF is param-independent, tuning never rebuilds the composite — it's a cheap shader re-render.

When adding/removing a parameter, update **all** of: `Param` enum (+ `label`, `range`), every `Preset.values` array, and the `P_*` defines + reads in the shader. Keep the count in sync (`StampNoise.count`).

## Bump / Emboss Calculation

Unchanged by the redesign and still required: the bump compares neighbour coverage to centre coverage using **raw** R-channel coverage on both sides (never post-dropout alpha), so the gradient stays on one scale.

```metal
float rawCov = coverage * pressure;                                   // raw = layer R sample
float right  = float(layer.sample(pos + float2(2,0)).r) * pressure;
float dx = right - rawCov;                                            // NOT post-alpha coverage
```

## Constraints

- `maxSampleOffset` is `CGSize(width: 2, height: 2)` in HibiPlusView.swift. Neighbor sampling limited to offset 2 (bump only — edge geometry comes from the baked SDF, not neighbour sampling).
- Shader is `[[stitchable]]` — no external textures; the only data input besides the layer is the `.floatArray` of params. All noise is procedural.
- `half` for colors/intermediates, `float` for positions/accumulators/distances.
- Seed is constant per stamp. Noise must be stable across frames (only `tilt` varies).
- Stamp mask PNGs are in `Hibi/Resources/StampMasks/`. Source files are at `~/Desktop/hibi-stamps/hibi-stamps/`.
- **Channel-value gamma:** the shader assumes `raw.r`/`raw.g` come through ≈ the stored 8-bit values (sRGB-encoded, not linearized). If the SDF ever reads inverted/offset on device, this is the first thing to verify — a colour-management linearization of the green channel would break the distance metric.
- The SDF distance transform runs on the main thread inside `buildComposite` (one-time per stamp/date). It's O(n) but touches the full ~930² buffer; if it ever hitches, move compositing off-main or compute the SDF at reduced resolution.
