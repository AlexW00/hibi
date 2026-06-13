# Procedural "Paper-Feel" Rendering in Swift + Metal — Consolidated, Validated Research Basis

## TL;DR

- Both prior reports are largely correct on physical and graphics facts; the most material correction is that **Ken Perlin began developing noise while working on Tron at MAGI in 1981** — in his own words, "I first started to think seriously about procedural textures when I was working on TRON at MAGI in Elmsford, NY, in 1981… on some level I was frustrated by the fact that everything looked machine-like" — not "post-Tron." Several craft "facts" (Fabriano's three innovations, washi/hanji line spacings) are real but rest on **marketing or qualitative sources, not metrology** — calibrate against real scans.
- The architecture holds: build one **shared weighted noise-layer stack** evaluated in canvas space, **bake to a texture** on Apple's TBDR GPUs rather than re-evaluating multi-octave noise per fragment per frame, and **link the paper and ink stacks** (pencil reuses the paper tooth/height field; ink feathering anisotropy is driven by the paper's fiber-direction field).
- Keep contrast **extremely low** (luminance modulation in the low single-digit percent range) and tones **warm/cream** — this matches the "affordable luxury via craft" register and also sidesteps the worst moiré/aliasing of fine ~1 mm laid lines on Retina displays.

## Key Findings

1. **Formation/flocculation is solidly grounded.** Per Dr. Martin A. Hubbe (NC State Dept. of Wood and Paper Science), "Nonuniformity of paper within a length scale of 2-20 mm is most frequently associated with a tendency of fibers to form flocs… papermaking fibers have length-to-thickness ratios between about 50 and 100." fBm is the correct primitive for formation cloudiness.
2. **Fiber and craft facts are mostly confirmed**, with caveats: kozo ~1 cm fiber length (IFLA conservation literature); hanji two-layer lamination and dochim burnishing (conservation bodies); washi su-no-me and ~1 mm bamboo splints. But **precise laid/chain-line spacings for washi and hanji are essentially absent from the metrology literature** — only European laid paper has good published numbers.
3. **Graphics lineage is accurate.** Perlin 1985 "An Image Synthesizer," 1997 Academy Award; Worley 1996 cellular; Lagae et al. 2009 Gabor + 2010 survey; Quilez domain warping f(p+h(p)); Bridson 2007 curl noise; Goldberg/Zwicker/Durand 2008 anisotropic noise; Chlumský msdfgen median-of-three — all verified against primary sources.
4. **Gabor noise is real but expensive**; for subtle paper fibers/flecks the literature and practice favor cheaper alternatives (thresholded value noise, pre-baked point splatting, texture-based anisotropic noise). On mobile this matters.
5. **Ink-on-paper has a real academic foundation** (Curtis et al. 1997 computer-generated watercolor; Chu & Tai 2005 MoXi real-time ink dispersion) that validates and can improve the glyph-mask noise approach, but the prior reports' lightweight SDF-perturbation approach is the right complexity tier for a UI background.

## Details

### A. Validation Ledger

#### Confirmed

- **Formation, flocculation, look-through.** Per Hubbe's "Formation Uniformity" troubleshooting guide: "Nonuniformity of paper within a length scale of 2-20 mm is most frequently associated with a tendency of fibers to form flocs… papermaking fibers have length-to-thickness ratios between about 50 and 100." The refined mechanism (Hubbe & Rojas, "The Dispersion Science of Papermaking"): "As the length-to-thickness ratio increases above a value of 50 there is increased tendency for entanglement and floc formation," producing "about 20-50 crossing points with adjacent fibers after formation of the sheet." "Look-through" by holding to a light, with wild/curdled vs. even/ground-glass appearance, is standard. **Verdict: confirmed.** Nuance to carry forward: look-through is an _optical_ proxy, not a direct measure of mass distribution — it conflates real grammage variation with color/opacity. That's fine for us; we are faking the optical result anyway.
- **npj Heritage Science 2021 hanji study.** Han et al., _Heritage Science_ 9:96 (2021). Color gamut L* 69.9–95.9, a* −3 to 3, b\* 0–20; neutral/alkaline pH; Heullimtteugi (single mould, "webal") gives dense crisscrossed multi-directional fiber orientation vs. Gadumtteugi/ssangbal aligned orientation; dochim (calendering) improves tensile/folding. **Verdict: confirmed, values exact.**
- **Hanji webal/heullim multi-directional formation, two-layer lamination, dochim, shifting chain lines.** Confirmed by conservation bodies. Traditional hanji is laminated from two pulls of the screen, and chain lines are offset/flipped so they "do not 'double up' and create weak areas of the sheet" (AICCM Hanji workshop review). Dochim = dampened sheets pounded by hand around a cylinder or via heavy stamping between stone plates, yielding a smooth, "almost silken, writing surface" (AICCM). **Verdict: confirmed.**
- **Washi nagashizuki / neri / su / su-no-me / chiri / unryu / UNESCO 2014.** Nagashizuki uses neri (mucilage from tororo-aoi, _Abelmoschus manihot_) to slow drainage; the flexible bamboo su leaves horizontal su-no-me marks; bamboo screens produce narrower chain-line distances, periodic "double chain lines" at the splint lap-joins, and finer laid lines (Prestowitz & Katayama, _Book and Paper Group Annual_ 37, 2018: "those made with a bamboo screen will have narrower distances between chain lines, sets of narrow double chain lines at intervals, and the laid lines are much finer"). UNESCO 2014 inscription "Washi: Craftsmanship of Traditional Japanese Hand-Made Paper" covers sekishū-banshi (Shimane), hon-minoshi (Gifu), hosokawashi (Saitama). **Verdict: confirmed.**
- **Kozo ~1 cm fiber length.** "Kozo fibres are about 1 cm in length, which makes washi strong and flexible" (IFLA). **Verdict: confirmed.** Dak (Korean paper mulberry, _Broussonetia_) is the hanji equivalent.
- **Fabriano 1264 Matelica document; gelatin sizing, watermark, hammer mill; Artistico 100% cotton no-OBA.** A parchment document of 1264 held at Matelica records the municipality buying paper (Library of Congress / Handpapermaking; Fabriano corporate). Fabriano's three claimed innovations — animal-gelatin sizing, the watermark (filigrana), and the water-powered multiple hammer/stamper mill — are widely repeated. **Verdict: confirmed as historical attribution, but flagged** — these are substantially Fabriano's own and trade sources; "first/invented" claims are corporate heritage framing. The 1264 Matelica document evidences paper _purchase/use_; the oldest known watermark is dated 1271 (Cremona), per the Handpapermaking history.
- **Clairefontaine 1858, Jean-Baptiste Bichelberger, Étival-Clairefontaine.** Confirmed by the company's own history page and Wikipedia: founded 1858 on the Meurthe; the mill site traces to a 1512 Abbey of Étival paper mill. **Verdict: confirmed.**
- **Tomoe River production transfer Tomoegawa→Sanzen, 2021; Sanzen toothier.** Confirmed exact: "Sanzen Paper Manufacturing acquired business rights from Tomoegawa for JPY300 million (US$2.64 million)" (Pen Noob, 28 Oct 2021); per Tomoegawa's official notice the "product sales contract, trademark rights and inventory will be transferred to Sanzen Paper Manufacturing Co., Ltd." (Kanazawa, Ishikawa; Sanzen is owned by Chuetsu Pulp, affiliated with Oji Paper), with Sanzen shipping from 29 Nov 2021. Reviewers consistently report the Sanzen paper has **more tooth/texture, slightly rougher line edges, darker ink with less shading/sheen, and less show-through** than original Tomoegawa (fudefan; The Gentleman Stationer). **Verdict: confirmed.** Refinement: original Machine #7 (until ~2019), "new" Machine #9 (2020–21), then Sanzen; later Sanzen batches (2024–25) were re-refined, and some 2025 batches reported as problematic.
- **Aslannejad & Hassanizadeh 2018, _Transport in Porous Media_ 127(1):143–155.** "The main detrimental effect of ink penetrating the fibrous layer is that the film flow along the fiber surface leads to wicking and a spider-leg like effect on the print." **Verdict: confirmed verbatim.** This is the load-bearing citation for fiber-direction feathering.
- **Perlin noise lineage.** 1985 SIGGRAPH "An Image Synthesizer"; 1997 Technical Achievement Academy Award. **Verdict: confirmed.**
- **Worley 1996; Lagae et al. 2009 Gabor + 2010 survey; Quilez domain warping; Bridson et al. 2007 curl noise; Perlin & Neyret flow noise; Goldberg/Zwicker/Durand 2008 anisotropic noise.** All confirmed against primary sources (SIGGRAPH/ACM/Computer Graphics Forum). Quilez's formulation is exactly g(p)=p+h(p), evaluating f(p+h(p)), explicitly traced to Perlin's 1984 marble. **Verdict: confirmed.**
- **msdfgen / Chlumský median-of-three.** The fragment-shader step is `median(r,g,b)` then a smoothstep/`screenPxRange` ramp to opacity (Chlumský msdfgen; "Improved Corners with Multi-Channel SDFs," CGF 2018). **Verdict: confirmed.**

#### Corrected / Refined

- **Perlin "post-Tron, 1983" framing is wrong.** Perlin began the work _on the Tron production itself_, at MAGI (Mathematical Applications Group, Inc.) in 1981 — his own account: "I first started to think seriously about procedural textures when I was working on TRON at MAGI in Elmsford, NY, in 1981… everything looked machine-like." The algorithm is commonly dated to 1983 and was formally published in the 1985 SIGGRAPH paper "An Image Synthesizer"; the Academy Technical Achievement Award was granted in 1997. Use 1981 origin / 1985 publication / 1997 award.
- **"~1 mm laid-line pitch" for washi is an over-precise generalization.** Washi laid-line density is _deliberately variable_ by paper type ("the number of bamboo strips per centimeter varies according to the kind of paper"). The ~1 mm figure is confirmed for splint _diameter_, but treat washi su-no-me pitch as a tunable range, not a fixed 1 mm.
- **Fabriano "invented the watermark in 1264."** The 1264 Matelica document attests cotton paper with gelatin sizing; the earliest _dated watermark_ is 1271 (Cremona). Keep 1264 as the anchor date for Fabriano paper, not specifically for the watermark.

#### Uncertain / Unresolved

- **Precise washi su-no-me laid-line pitch and chain-line (ito) spacing.** Not found as a clean metric in conservation literature; bamboo splints ~1 mm diameter (practitioner source); imitation molds cited at 1.5–3.0 cm chain spacing (AIC wiki, ambiguous). Authentic washi chain-line cm pitch unconfirmed.
- **Hanji laid-lines-per-cm / chain-line interval in cm.** No published numeric found, even in the 309-sample npj study. Nearest East-Asian analogue: Chinese handmade papers ~6–15 laid lines/cm with irregular chain spacing. **Treat hanji line spacing as a tunable parameter, calibrated to scans, and stated as unmeasured.**
- **Shoji "roughly half" light transmission** and **Tomoe River 52 vs 68 gsm** exact sheen/ghosting deltas — directionally reported by enthusiasts/sellers, not metrology.

### B. Measured Line Spacings (the one well-quantified family)

European laid paper is the only family with reliable published numbers, and they converge:

- **Laid lines: "There are typically 25 lines per inch (10 lines per cm.)"** (Malta Map Society glossary); medieval range **5–15 lines/cm**, with npj Heritage Science 2023 measuring sample patches at **8–11 laid lines/cm**.
- **Laid-line impressions ~0.5–1 mm wide, spaced ~0.7–2 mm apart** (secondary).
- **Chain lines: "commonly 25mm apart"** (Fenner Paper), with a medieval range of ~15–50 mm; antique-laid chain lines often show a thicker pulp ridge from rib suction. Machine-made laid uses a **dandy roll**; chain lines run in machine direction.

**Implication for the preset:** model Western laid as a near-periodic sine grid at **~10 laid lines/cm** crossed by **~25 mm chain lines**, then break it with low-amplitude domain warp so it never reads as a perfect screen. For washi/hanji, do _not_ hard-code a pitch — expose it and tune to scans.

### C. Gabor Noise Cost and Cheaper Alternatives

Gabor noise (Lagae et al. 2009) is sparse-convolution noise: a sum of Gabor kernels (Gaussian × cosine harmonic) at random impulse points, giving precise frequency/orientation control — ideal in principle for oriented fibers and flecks. **But it is acknowledged as expensive**: "evaluating a potentially large number of Gabor noises is inefficient" (Galerne et al., "Gabor Noise by Example"). For a subtle, baked UI background on a mobile GPU, full per-fragment Gabor evaluation is overkill. Established cheaper substitutes for sparse oriented features:

- **Thresholded value/gradient noise** — step or smoothstep a cheap fBm to isolate sparse high spots as "flecks."
- **Pre-baked point splatting** — scatter fiber/chiri sprites (Poisson-distributed) into the baked texture offline; this is effectively the sparse-convolution idea done once on the CPU.
- **Texture-based anisotropic noise** (Goldberg/Zwicker/Durand 2008) — store oriented sub-band noise in textures and sample, "achieving similar rendering performance as state-of-the-art procedural noise" without per-fragment kernel sums.
- **Anisotropic/stretched fBm** — sample fBm with a directionally scaled coordinate transform for cheap grain direction.

Because we bake once, the cost objection mostly dissolves — but point-splatting and stretched-fBm are simpler to author/tune than Gabor and are the recommended default.

### D. Constructing a Fiber-Direction / Flow Field

The paper's anisotropy field that drives ink feathering can be built procedurally without a fluid sim:

- **Noise gradient → orientation.** Take a smooth fBm height field; its gradient (or its perpendicular) gives a continuous direction field — the Perlin & Neyret "flow noise" idea, and the basis of Quilez derivative-based warping.
- **Curl noise** (Bridson et al. 2007) gives a divergence-free vector field — visually "swirly," good for organic, non-converging fiber flow; it's the 90° rotation of a potential's gradient.
- **Line-integral-convolution-like smearing** along that field, or anisotropic noise oriented by it, produces directional streaks. For hanji's multi-directional webal formation, blend two or more orientation fields; for machine papers, bias the field toward machine direction.

Use this same field as the input to ink feathering anisotropy (the "spider-leg" direction) — the paper field is a shared resource, not re-derived per ink.

### E. fBm Parameter Conventions

Standard fBm: sum octaves with **lacunarity ≈ 2.0** (frequency doubling) and **gain ≈ 0.5** (amplitude halving), corresponding to H≈1 / "yellow noise" that Quilez shows matches natural fractal terrain. Conventions confirmed across Quilez, The Book of Shaders, and standard implementations:

- **Octaves:** 4–6 typical; for _subtle_ material texture, **3–5 is plenty** — extra octaves add fine detail that aliases on Retina and is invisible at UI contrast.
- **Detune octave frequencies** (×2.01, ×2.03, …) and **rotate the domain** between octaves (a fixed 2×2 rotation matrix) to break axial bias and avoid superimposed peaks creating regular artifacts.
- For background paper, weight the **low octaves** (formation cloudiness) heavily and the **high octaves** (grain) lightly.

### F. Seamless Tiling vs. Canvas-Space Evaluation

- **Evaluate in world/canvas space** (continuous coordinates) — no visible repetition, correct under pan/zoom, but no small-tile cache.
- **Periodic/tileable noise** — use periodic variants (domain wrapped on a lattice period, or tiling value-noise) to bake a single seamless tile and repeat it. Cheaper memory, but risks visible repetition on large canvases and phase artifacts where the tile meets ink features.

**Recommendation:** bake a **moderately large seamless tile** (periodic noise) for the fine grain, but compute **formation cloudiness and laid lines in canvas space** (or bake at canvas scale) so large-scale structure never visibly repeats. This hybrid keeps memory bounded while hiding tiling.

### G. Perceptual Contrast Calibration for UI Backgrounds

Report 1's "2–5% opacity" guidance is reasonable and in the right spirit, though it's a design heuristic rather than a measured standard. Frame it as **luminance modulation of only a few percent around a warm cream base**, with refinements:

- Push most energy into **low-frequency formation** (large, soft) rather than high-frequency grain, which reads as noise/dirt at any visible contrast.
- **Warm/cream base, never sterile white**; OBA-driven "blue-white" office paper is the _anti-pattern_ for the luxury register.
- Gate texture **down further at small zoom / small type** to protect legibility; allow slightly more at large zoom where the surface is the subject.
- Calibrate on-device under both light and dark appearance; cream textures behave very differently on a dark canvas.

### H. Apple-Silicon / TBDR Performance Architecture

Apple GPUs are **Tile-Based Deferred Rendering**: geometry is binned into tiles, fragments shaded from fast on-chip tile memory, with hidden-surface removal before shading. Consequences for procedural paper:

- **Per-fragment multi-octave fBm every frame is the wrong default.** It's ALU-heavy and runs for every visible pixel each frame — wasted power/thermal budget on a mostly-static notes/calendar background.
- **Bake once to an offscreen texture** (render-to-texture on launch / on theme or zoom-bucket change), then sample during normal compositing. This converts per-frame ALU cost into a one-time cost plus cheap bandwidth-bound sampling — exactly what TBDR rewards.
- Keep intermediate passes in **tile memory / memoryless attachments** where you composite procedurally; avoid round-tripping large textures through system memory.
- If you must evaluate live (infinite-zoom canvas), **evaluate at a capped resolution and upscale**, and drop octaves as zoom shrinks.

### I. Bake-vs-Live, Mipmapping, and Aliasing of ~1 mm Laid Lines

- **Fine periodic patterns (~1 mm laid lines) are the main aliasing risk.** At Retina densities and arbitrary zoom, a near-Nyquist periodic grid will moiré. Mitigations: (1) **mipmap the baked paper texture**, sample with trilinear/anisotropic filtering; (2) **band-limit** — fade laid-line amplitude toward zero as the on-screen pitch approaches a few pixels (the standard "omit high-frequency bands near Nyquist" approach noted by Goldberg/Zwicker/Durand for procedural noise); (3) **break periodicity** with low-amplitude domain warp so energy isn't concentrated at one frequency.
- **Bake tradeoff:** baking gives free mip generation and stable AA but fixes resolution; live gives infinite zoom but you must implement band-limiting yourself. For a notes/calendar app, **bake per zoom-bucket** is the pragmatic sweet spot.

### J. Academic Ink-on-Paper Literature

- **Curtis, Anderson, Seims, Fleischer, Salesin, "Computer-Generated Watercolor," SIGGRAPH 1997** (DOI 10.1145/258734.258896). From the abstract: "Our watercolor model is based on an ordered set of translucent glazes, which are created independently using a shallow-water fluid simulation. We use a Kubelka-Munk compositing model for simulating the optical effect of the superimposed glazes." Fig. 1 enumerates the effects it reproduces: "drybrush (a), edge darkening (b), backruns (c), granulation (d), flow effects (e), and glazing (f)." This is the canonical reference; it validates modeling ink as an absorbed/diffused layer with edge effects and specifically justifies the fountain-pen **edge-darkening pool** as a real phenomenon — achievable cheaply via SDF distance bands rather than a full fluid sim.
- **Chu & Tai, "MoXi: real-time ink dispersion in absorbent paper," SIGGRAPH 2005.** Real-time Eastern ink diffusion — directly relevant to washi/hanji ink behavior and confirms a real-time tier exists between "static mask" and "offline fluid sim."
- **Aslannejad & Hassanizadeh 2018** supplies the physical mechanism (film flow along fibers → spider-leg wicking) that motivates anisotropic, fiber-aligned feathering rather than isotropic blur.

**Takeaway:** the prior reports' glyph-mask + SDF-perturbation approach is the correct _complexity tier_ for a UI; borrow _qualitative results_ from Curtis (edge darkening, granulation in valleys) without importing the fluid sim.

### K. Show-Through / Ghosting (verso text)

Thin papers (Tomoe River especially) show verso text. To render: composite a **blurred, low-opacity, mirrored copy of the verso content** beneath the recto, modulated by a paper-opacity/thickness field (thinner formation spots show through more). This couples naturally to the formation fBm — show-through is locally stronger where grammage is lower, reinforcing realism. Keep opacity very low; ghosting should be subliminal in the luxury register.

### L. The Layer-Stack Spine

#### Paper presets (weighted noise-layer stacks)

| Layer (feature)                 | Noise family                         | Office wood-pulp           | Fine writing (Clairefontaine reg.) | Hanji                                       | Washi                                | Western laid (cotton/rag)      |
| ------------------------------- | ------------------------------------ | -------------------------- | ---------------------------------- | ------------------------------------------- | ------------------------------------ | ------------------------------ |
| Base tone                       | flat                                 | neutral-cool cream         | warm cream                         | warm ivory                                  | warm natural                         | cool/neutral cream             |
| Formation cloudiness (2–20 mm)  | fBm (low oct., heavy low-freq)       | very low (even)            | low                                | **high, multi-directional**                 | medium-high                          | medium                         |
| Fine grain / tooth              | value/white noise (hi-freq, low amp) | very low (calendered)      | low (satin)                        | medium                                      | medium-high                          | medium                         |
| Fiber clumps                    | Worley / thresholded value           | none                       | none                               | medium (long dak)                           | medium (long kozo)                   | low                            |
| Grain direction field           | anisotropic / stretched fBm          | machine dir. (weak)        | weak                               | **multi-dir blend**                         | perpendicular to splints             | mould dir.                     |
| Laid + chain lines              | sine grid + domain warp              | none                       | none (or faint)                    | faint, offset chain lines, shift at midline | su-no-me + double chain at lap-joins | **~10 laid/cm + ~25 mm chain** |
| Sparse flecks                   | point-splat (baked) / Gabor          | none                       | none                               | low                                         | **chiri bark flecks**                | low (rag specks)               |
| Organic warp (applied to above) | domain warp f(p+h(p))                | minimal                    | minimal                            | strong                                      | strong                               | low–medium                     |
| Show-through field              | derived from formation               | low                        | low–med (thin)                     | med                                         | **high (thin)**                      | low                            |
| Surface finish                  | global contrast/whiteness            | OBA blue-white, calendered | satin, no/low OBA                  | dochim-smoothed                             | varies                               | ribbed, sized                  |

Relative weights are starting points; **the formation layer dominates for hanji/washi, the laid-line layer dominates for Western laid, and office/fine-writing are nearly flat** (their character is _smoothness and tone_, not texture).

#### Ink presets (weighted operation stacks over a glyph SDF/mask)

Four core SDF/mask operations (validated against the cited techniques):

1. **Threshold perturbation** — perturb the SDF cutoff with noise before the smoothstep (Chris Cummings "Shader Fun" SDF-noise series); breaks the clean edge into a fibrous one. AA interaction caveat: perturbing the field changes the effective gradient, so the `screenPxRange`/`fwidth` smoothing must be recomputed or the edge aliases ("breaking the field").
2. **Domain warp** — displace mask coordinates with f(p+h(p)) (Quilez) for organic stroke wobble.
3. **Dilate / erode via absorbency** — offset the SDF threshold by a per-pixel absorbency map (Mirza Beig dissolve = `step(noiseCutoff, noise)`), so wet ink spreads where the paper is more absorbent.
4. **Alpha / darkness modulation** — multiply ink alpha/value by paper fields (tooth, formation) and by SDF distance bands (edge darkening per Curtis).

| Instrument                 | Threshold perturb      | Domain warp | Dilate/erode (absorbency)                          | Alpha/darkness mod                                                                                                    | Paper coupling                                                                                       |
| -------------------------- | ---------------------- | ----------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Fountain pen / wet ink** | low (clean core)       | low–med     | **high** (feathering, anisotropic via fiber field) | edge-darkening pools (shading); sheen as surface-dye concentration highlight                                          | feathers more on absorbent/unsized paper; shading/sheen strongest on coated low-absorb (Tomoe River) |
| **Typewriter**             | med (ribbon texture)   | low         | low                                                | **cloth ribbon = mottled/low-ink; carbon-film = dense/sharp**; filled counters; impression halo; baseline jitter      | impression halo deeper on soft/thick paper                                                           |
| **Pencil / graphite**      | **high** (tooth-catch) | low         | none                                               | **alpha multiplied directly by paper tooth/height field**; white flecks in valleys; burnishing sheen at high pressure | _directly reuses paper tooth layer_                                                                  |
| Ballpoint (opt.)           | low                    | low         | low                                                | skip/blob starvation; very dark thin line                                                                             | minimal coupling                                                                                     |
| Marker (opt.)              | low                    | med         | high (bleed)                                       | overlap darkening; streak                                                                                             | bleeds heavily on absorbent paper                                                                    |
| Letterpress (opt.)         | low                    | low         | med                                                | **ink-squeeze halo** (darker rim, lighter center — Keesing platform)                                                  | halo/impression deeper on soft cotton/rag                                                            |

### M. The Architectural Through-Line (must preserve)

- **Pencil ink preset reuses the paper preset's tooth/height noise layer as an alpha multiplier** — graphite deposits on the peaks the tooth field exposes and skips the valleys (white flecks). This is not a separate noise; it is a _read_ of the paper field.
- **The paper's fiber-direction field drives ink feathering anisotropy** — the "spider-leg" wicking direction (Aslannejad & Hassanizadeh) follows the paper field, not an ink-local random direction.
- Therefore **paper and ink stacks are linked, not independent.** Implement the paper field set (height/tooth, formation, fiber-direction, absorbency, show-through) as a shared resource consumed by both the paper render and every ink instrument.

## Recommendations

1. **Build the shared layer-stack engine first**, parameterized as the spine table above, evaluated in canvas space and **baked to a mipmapped texture per zoom-bucket**. Benchmark on the oldest target device before adding octaves. Threshold to change course: if a baked-texture frame costs more than a few percent of frame budget, you've over-baked resolution — cap it.
2. **Stage by visual payoff:** (a) warm base + formation fBm (biggest perceptual win, lowest risk); (b) fine grain/tooth + pencil coupling; (c) laid/chain lines for the Western-laid preset (highest aliasing risk — do last, with band-limiting); (d) chiri flecks and fiber clumps via baked point-splatting; (e) fountain-pen feathering/shading using the fiber field.
3. **Default to cheap noise** (stretched/rotated fBm, thresholded value noise, baked point-splats). Only reach for Gabor/anisotropic-texture noise if a specific oriented feature can't be faked — and bake it if you do.
4. **Calibrate against real scans.** Acquire flatbed scans (and raking-light photos) of each target paper; match formation scale, laid-line pitch, and tone by eye and by FFT power spectrum. This is the only way to fix the unmeasured washi/hanji spacings.
5. **Keep contrast in the low single-digit percent** and re-check on-device in light and dark appearance. If texture is ever consciously noticeable on a calendar grid at default zoom, it's too strong.
6. **Ghosting and sheen are optional polish**, gated to large zoom and specific presets (Tomoe River show-through; fountain-pen sheen). View-dependent sheen is the most likely thing to look "gimmicky," so ship it last and conservatively.

## Caveats

- **Craft "facts" lean on marketing and qualitative sources.** Fabriano's innovation claims, shoji "half" transmission, Tomoe River 52-vs-68 deltas, and washi/hanji line spacings are not metrology. Use them as _direction_; calibrate to scans for _magnitude_.
- **Washi and hanji line spacings are genuinely unmeasured** in accessible literature — expose them as parameters, don't hard-code.
- **Sheen is view-dependent** (a function of surface dye concentration and grazing angle); a flat UI can only fake it, and it can read as artifact.
- **SDF field-breaking + AA interaction** is the main ink-rendering pitfall: perturbing the distance field invalidates naive `fwidth` smoothing and causes shimmer; recompute the smoothing footprint from the perturbed field.
- **Mobile GPU performance is still unbenchmarked for your specific stack** — the bake-once recommendation is precisely to de-risk this, but verify on-device.
- **OBA tone is a trap for the luxury register**: matching real office paper means a cool blue-white that fights the cream aesthetic. Render office paper _honestly cool_ only if you want the "cheap paper" contrast; otherwise warm it deliberately.
