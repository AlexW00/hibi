---
name: stamp-ink-noise
description: How to create realistic rubber-stamp ink-transfer imperfections in Metal shaders. Covers noise technique selection, the perturbation threshold approach, text grain in StampCompositor, and the stamp pipeline (StampConfig seed, StampCompositor composite, StampShader.metal effect). Use when modifying stamp visuals, tuning noise parameters, or adding new stamp-related features.
---

# Stamp Ink Noise & Pipeline

## Architecture

The stamp rendering pipeline has three stages:

1. **StampConfig** (`Hibi/Models/StampConfig.swift`) — Deterministic seed from purchase date (Wang hash, 24-bit for Float safety). Selects which stamp definition to use via `seed % definitions.count`. The `stamps.json` file maps stampIds to date region configs.

2. **StampCompositor** (`Hibi/Models/StampCompositor.swift`) — Rasterizes mask PNG + date text into a single grayscale CGImage (R=G=B=coverage, A=opaque). Mask PNGs live in `Hibi/Resources/StampMasks/`. Text grain is applied here (see below).

3. **StampShader** (`Hibi/Shaders/StampShader.metal`) — `[[stitchable]]` SwiftUI layer effect. Receives the composite, adds ink-transfer noise, specular highlight, and bump/emboss. All noise is seed-deterministic; only tilt varies per frame.

## Noise Technique: What Works and What Doesn't

### Failed approaches

| Technique | Problem |
|-----------|---------|
| fBm as a multiplier (e.g., `coverage *= 0.55 + fbm * 0.45`) | Creates smooth gradients. Looks "cloudy." A floor above zero means pixels never drop out. |
| Worley (cellular) noise with smoothstep | Smooth circular distance fields. Even with narrow smoothstep, boundaries are smooth curves, not jagged. |
| Worley + fBm warping | Still fundamentally smooth. Distorted circles are still circles. |
| Non-interpolated hash at coarse scale (30-150 cells) | Creates visible rectangular grid. Looks pixelated, not natural. |
| fBm thresholded with narrow smoothstep at multiple scales | Shapes are organic but edges are still smooth fBm isolines. User described as "round noise patterns with smooth gradients." |

### What works: perturbation threshold

The correct approach separates **shape** (where ink drops out) from **texture** (how the edge looks):

1. **Smooth fBm** controls the broad pressure field — determines which regions have ink and which don't. Organic contour shapes.
2. **Near-pixel hash** perturbs the threshold at the boundary — creates jagged, grain-like edges without visible grid artifacts.

Key insight: the hash doesn't determine ink/no-ink directly (that looks pixelated). It only nudges the threshold by a small amount. In solid areas the nudge can't change the outcome. In empty areas, same. Only at the boundary does per-cell randomness create rough texture.

```metal
// Broad pressure — smooth fBm
float broad = fbm(uv * 2.5, 3, seedU);
float pressureMap = smoothstep(0.05, 0.40, broad);
float inkStrength = pressureMap * 0.65 + coverage * 0.35;

// Organic wobble — medium-scale shape variation
float wobble = (fbm(uv * 15.0, 2, seedU + 100u) - 0.4) * 0.18;

// Fine grain — near-pixel hash (~2px cells), roughens boundary only
float2 grainCell = floor(uv * 300.0);
float grain = (hash01(uint3(uint(grainCell.x), uint(grainCell.y),
              seedU + 200u)) - 0.5) * 0.10;

float inkSurvival = step(0.45, inkStrength + wobble + grain);
coverage *= inkSurvival;
```

### Tuning knobs

| Parameter | Effect | Current |
|-----------|--------|---------|
| `uv * 2.5` (broad freq) | Size of large missing areas | 2.5 |
| `smoothstep(0.05, 0.40)` | How much of stamp is affected | 0.05–0.40 |
| `pressureMap * 0.65 + coverage * 0.35` | Weight of pressure vs edge erosion | 65/35 |
| `uv * 15.0` (wobble freq) | Scale of boundary irregularity | 15.0 |
| `* 0.18` (wobble amplitude) | How much boundary shape varies | 0.18 |
| `uv * 300.0` (grain freq) | Grain cell size (~2px at 3x retina) | 300 |
| `* 0.10` (grain amplitude) | How rough the boundary edge is | 0.10 |
| `step(0.45, ...)` threshold | Overall ink retention | 0.45 |

## Text Grain in StampCompositor

Mask PNGs have baked-in fine texture. Text rendered by CoreText is perfectly smooth and looks too clean by comparison. The compositor applies per-pixel multiplicative grain (82–100%) to text pixels only:

1. Snapshot pixel buffer before drawing text
2. Draw text normally (solid white)
3. Compare before/after per pixel — where coverage increased, text was drawn
4. Apply deterministic hash grain only to the text contribution

This keeps mask texture unchanged while making text match.

## Bump/Emboss Calculation

The bump effect compares neighbor coverage to center coverage. After ink dropout modifies `coverage`, the bump must use **raw** coverage for both sides:

```metal
float rawCov = float(raw.r) * pressure;  // raw = original layer sample
float right = float(layer.sample(pos + float2(2,0)).r) * pressure;
float dx = right - rawCov;  // NOT: right - coverage (post-dropout)
```

Using post-dropout coverage mixes different scales and kills the bump visibility.

## Constraints

- `maxSampleOffset` is `CGSize(width: 2, height: 2)` in HibiPlusView.swift. Neighbor sampling limited to offset 2.
- Shader is `[[stitchable]]` — no external textures, all noise must be procedural.
- `half` for colors/intermediates, `float` for positions/accumulators.
- Seed is constant per stamp. Noise must be stable across frames (only `tilt` varies).
- All stamp mask PNGs (2–8) are in `Hibi/Resources/StampMasks/`. Source files are at `~/Desktop/hibi-stamps/hibi-stamps/`.
