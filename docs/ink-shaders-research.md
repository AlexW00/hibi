# Ink & Mark-Making on Paper, and the Noise Algorithms to Recreate It on Glyph Masks

## TL;DR

- **The look of any mark is governed by INSTRUMENT × PAPER**: a wet, liquid mark (fountain pen) feathers and bleeds on absorbent/unsized paper but stays crisp, pools, and develops sheen on sized/coated paper (Clairefontaine, Tomoe River); a typewriter leaves mechanically uneven, slightly ragged, filled-in characters with a faint impression; graphite is a dry mark that catches on paper "tooth," so it is granular and reveals the paper texture itself. These map cleanly onto distinct, layerable noise operations on a glyph mask.
- **The single most important implementation insight**: treat an "ink preset" exactly like the Part‑1 paper presets — a weighted stack of noise operations applied to the glyph's SDF/coverage mask, MODULATED by the paper preset underneath. The four core operations are (1) **SDF threshold perturbation** with fBm/value noise (edge roughening), (2) **domain‑warping the sample coordinates** (feathering/capillary tendrils, especially along a fiber‑direction field), (3) **threshold offset = dilate/erode** modulated by an absorbency map (bleed/spread vs. break‑up), and (4) **alpha/darkness modulation** by low‑frequency fBm and by SDF edge‑distance (pooling, shading, sheen, ribbon fade).
- **Concrete confirmed technique**: adding a noise value to the SDF distance _before_ the smoothstep (Chris Cummings' "Shader Fun" SDF series: `sdf.r += lerp(_EdgeNoiseA,_EdgeNoiseB,samplenoise(uv))`, "adjust distance by sampling noise texture") wobbles the contour; warping sample coordinates `f(p + h(p))` (Inigo Quilez, "Domain Warping") distorts edges; and `step(noiseCutoff, noise)` against an alpha mask (Mirza Beig dissolve tutorial) erodes/breaks up the fill. These are the building blocks for typewriter raggedness, wet‑ink feathering, and pencil grain respectively.

## Key Findings

1. **Sizing and absorbency are the master variables.** Surface sizing is a treatment that reduces a paper's tendency to absorb liquid so ink dries on the surface. Sized/coated papers (Clairefontaine, Rhodia, Tomoe River) hold ink on top → crisp edges, slow drying, pooling, shading, sheen, ghosting. Unsized/absorbent fibrous papers (cheap copy, washi, hanji) pull ink into the fiber network by capillary action → feathering (lateral spread) and bleed‑through (vertical soak). This single axis explains most instrument‑on‑paper differences.

2. **Feathering is capillary wicking along fibers, and it is directional (anisotropic).** Per the peer‑reviewed study by Aslannejad & Hassanizadeh ("Characterization of the Interface Between Coating and Fibrous Layers of Paper," _Transport in Porous Media_, 2018), "penetrating liquid in a fibrous layer first follows the direction of fibers and wets them. Then, the pore space between fibers is filled up with the liquid," and "the film flow along the fiber surface leads to wicking and a spider-leg like effect on the print." An MDPI study on lateral imbibition confirms fiber orientation significantly governs the direction of spread. This is why washi/hanji, with long visible kozo/dak fibers, channel ink directionally — a key cue to reproduce with anisotropic/flow noise aligned to a fiber field.

3. **Fountain‑pen shading and sheen come from uneven pooling on low‑absorbency paper.** Shading = darker where ink pools (starts/ends of strokes, intersections, lower edges of letters), lighter elsewhere. Sheen = a metallic rim that appears when dye concentrates on the surface because it has nowhere to soak; it appears at the heaviest‑ink regions and is best on resistant papers like Tomoe River. Both need smooth, low‑absorbency paper and more ink (broad/wet nibs). Within the Tomoe River range, the lighter 52gsm sheet is widely reported (e.g. by retailer Galen Leather) to "show off sheen better, meaning color variation and reflection may be more obvious," while the heavier 68gsm "shows bleed through less … and is more resistant to ghosting" — a useful preset distinction.

4. **Typewriter signature = mechanical‑but‑imperfect.** Cloth (cotton/nylon/silk) ribbons give a softer, slightly textured, sometimes blurry imprint with uneven inking and fade; enclosed counters (e, a, o, g) tend to fill in with ink; impression embossing from the typebar strike leaves a faint halo/dent; per‑character baseline/alignment jitter is inherent to the mechanism. Carbon‑film ribbons (one‑time use, used on daisy‑wheel/electric machines) give crisp, high‑contrast, archival‑sharp text by contrast — the crisp/soft toggle for the preset. Ribbon ink migrates back into used areas, so darkness recovers between strikes but fades over a ribbon's life; the Typewriter Wiki notes cotton is "ink‑heavy" but "can be blurry, especially on machines with smaller … typefaces," while silk gives "the crispest print."

5. **Graphite is a dry, granular mark that reveals the paper's tooth.** Per the Sibley Fine Art drawing blog, "It's the tooth (the pits and crests in the paper's surface) that causes the graphite to flake off the pencil's lead," and "if you use a soft grade (B to 8B) its minimal clay content means the individual graphite grains are large and won't fill the pits of the tooth entirely," leaving "flecks of white paper showing through." On rough/toothy paper, graphite catches on peaks and skips valleys → grainy, broken, flecked‑with‑white marks; on smooth paper → cleaner, more even, finer. Pressure and burnishing fill the tooth and create graphite sheen — a reflective, metallic shine from compacted, flattened graphite crystals (Vitruvian Studio: pressure "buffs‑up the surface of the graphite," making it "smooth and reflective, which produces glare"). This is the literal link back to the Part‑1 paper noise: pencil = glyph alpha × paper‑tooth noise.

6. **Letterpress/printing adds an ink‑squeeze halo.** Per Keesing Platform's serialization study, "A halo is a bead of ink around the contour of a letterpress impression that is formed when ink squeezes to the edges of the image area as the printing surface is pressed against the substrate," and an "internal halo" can form from "ink squeezing out not just around the numeral contour but also inside the image area." Heavy "bite" impressions deboss the paper and thicken counters (Letterpress Commons). Useful as an optional "printed" instrument mode (edge‑ring + emboss).

7. **The noise toolkit maps one‑to‑one onto these effects.** SDF/MSDF text rendering already thresholds a distance value with smoothstep to get a crisp anti‑aliased edge (Chlumský/msdfgen; Metal by Example); everything else is perturbing that pipeline. fBm (layered value/Perlin/simplex noise), domain warping (`f(p+h(p))`, Quilez), Worley/cellular noise (branching/cells, Worley 1996 via Book of Shaders), curl/flow noise (divergence‑free directional advection, Bridson et al. 2007), and per‑glyph hashing are the families needed.

## Details

### PART A — Ink / mark physics by instrument

**1. Fountain pen / wet ink.**

- _Edge_: Ranges from razor‑crisp (sized paper) to fuzzy/spidery (absorbent paper). Feathering produces fine tendrils radiating along fibers — "blurry, uneven lines instead of sharp ones," worse with wet, saturated inks and broad/wet nibs.
- _Fill_: Uneven — pooling produces shading (darker pools, lighter elsewhere). Wet inks shade most. On absorbent paper the fill is flatter (ink soaks evenly and dries fast, killing shading).
- _Tonal variation / artifacts_: Shading (light↔dark within a stroke), sheen (metallic surface rim at heavy‑ink regions), shimmer (glitter — physical particles), bleed‑through (soak to verso), ghosting/show‑through (faint shadow on reverse, normal on thin paper). Tomoe River (52/68 gsm) is the canonical extreme: minimal feathering, maximal shading/sheen (especially the 52gsm), heavy show‑through but little bleed.

**2. Typewriter.**

- _Edge_: Slightly ragged/imperfect; cloth ribbons can be blurry, especially at small sizes; carbon film is crisp.
- _Fill_: Uneven inking — some characters/areas darker than others; counters (e/a/o) fill in with ink; ribbon fade reduces density over life; double‑strike/ghosting from mechanical bounce or misalignment.
- _Artifacts_: Impression embossing/halo from the typebar strike; per‑character baseline jitter, vertical misalignment, slight rotation — the "mechanical but imperfect" fingerprint. Cloth vs. carbon‑film is the crisp/soft toggle.

**3. Pencil / graphite.**

- _Edge_: Soft, non‑feathered, slightly broken; no liquid spread.
- _Fill_: Granular/sparkly; darker on tooth peaks, lighter (white flecks) in valleys; reveals paper texture. Variable darkness with pressure and grade.
- _Artifacts_: Graphite sheen at high density/pressure (burnished, reflective); grain coarseness scales with paper tooth.

**4. Additional instrument modes (lighter coverage).**

- _Ballpoint_: Waxy oil paste, consistent, doesn't feather; can skip (gaps) and blob (surplus ink accumulating at the tip leaving a blotch). Crisp narrow line.
- _Gel pen_: Water‑based gel, smooth vivid line, slower drying, can smudge; minimal feather.
- _Felt‑tip/marker_: Dye soaks in; bleeds and feathers strongly on absorbent paper, broad soft edges, strong show/bleed‑through.
- _Letterpress/printing_: Ink‑squeeze halo bead at contours, optional debossing/emboss, possible internal halo and filled counters under heavy impression.

### PART B — Instrument × paper interaction (the 5 presets)

| Paper (Part 1)                                                    | Fountain pen / wet ink                                                                                                                                                                  | Typewriter                                                                                  | Pencil / graphite                                                                         |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **1. Standard office / wood‑pulp**                                | Unsized/lightly sized, absorbent → noticeable feathering and bleed‑through with wet inks; soft fuzzy edges; little shading/sheen                                                        | Reads cleanly but slightly absorbed; decent impression on harder platens; counters can fill | Medium‑fine grain; even mid‑tooth; the "default" pencil look                              |
| **2. Fine writing (Clairefontaine/Rhodia/Midori MD/Tomoe River)** | Crisp edges, strong pooling, pronounced shading + sheen, slow dry; thin Tomoe River shows heavy ghosting/show‑through but little bleed                                                  | Very crisp on smooth surface; clean counters; minimal absorption                            | Faint, even, low‑grain (little tooth); hard to build dark value; can burnish/sheen easily |
| **3. Hanji (Korean mulberry/dak)**                                | Unsized, absorbent, long criss‑cross bast fibers → directional feathering, ink "picks up" and spreads; soft, organic edges; bark specks interrupt the mark                              | Soft, partly absorbed imprint; impression cushioned by fibrous felt                         | Grain interrupted by long fibers and bark flecks; uneven catch                            |
| **4. Washi (Japanese kozo)**                                      | Highly absorbent (unsized "raw"), long kozo fibers + cloudy formation → strong, sometimes wild bleed and directional wicking; very soft edges; chiri flecks; translucent → show‑through | Soft, feathered imprint; cushioned impression                                               | Grain modulated by cloudy fiber formation and laid lines; flecks                          |
| **5. Laid / cotton‑rag (Fabriano)**                               | Cotton tooth + sizing varies; laid/chain lines create slight periodic texture in the line; moderate crispness                                                                           | Impression catches on the laid ridges; texture in the imprint                               | Coarse, granular, expressive grain; laid+chain grid shows through the shading strongly    |

Why fountain‑pen ink feathers on cheap copy paper and washi/hanji but not on Clairefontaine/Tomoe River: liquid water‑based ink is pulled into loosely woven, minimally sized fibers by capillary action, spreading laterally before it can dry; sized/coated papers keep ink on the surface so the line stays where it was laid. Long visible fibers (washi/hanji) channel that wicking directionally — feathering follows fiber lines (the "spider‑leg" wicking documented by Aslannejad & Hassanizadeh). Pencil grain is faint/even on smooth fine paper and coarse/granular on toothy laid/cotton paper because tooth is what flakes graphite off the lead. Typewriter impression and inking read sharper on smooth/hard surfaces and softer/cushioned on fibrous papers. Bleed‑through vs. show‑through: thin translucent papers (Tomoe River 52 gsm, washi) show the mark faintly from the back (ghosting) without ink fully penetrating (bleed) unless over‑inked.

### PART C — Noise algorithm mapping for glyph / SDF treatment

**Baseline pipeline.** SDF/MSDF text rendering samples a signed distance `d`, then `opacity = smoothstep(0.5 - w, 0.5 + w, d)` (or `clamp(screenPxDistance + 0.5, 0, 1)`, per msdfgen/Metal by Example), mixing background↔foreground. Every ink effect is a perturbation of (a) the distance value `d`, (b) the sample coordinates `uv`, (c) the resulting alpha, or (d) the output color. This keeps glyph shapes intact while changing how the mark "sits."

**Effect → technique mapping:**

- **Edge roughening / ragged edges (typewriter, rough‑paper edges):** Add high‑frequency value/Perlin/fBm noise to the distance before thresholding — the confirmed pattern from Chris Cummings' SDF series is `sdf.r += lerp(a, b, sampleNoise(uv))` ("adjust distance by sampling noise texture"), which wobbles the contour (and intentionally "breaks the field"). Equivalent: domain‑warp the sample coordinate slightly, `d(uv + n(uv))`. Frequency controls jaggedness; amplitude controls how far the edge wanders.

- **Feathering / spidery tendrils (wet ink on absorbent paper):** Domain‑warp the edge band by a **fiber‑direction field** so the contour extrudes along fibers — `f(p + h(p))` with `h` an anisotropic/flow field (Quilez's domain‑warping formulation). Use **curl/flow noise** (divergence‑free, advects coordinates along "currents," per Bridson et al.) or displace along the **gradient of the noise** ("flow noise," Perlin & Neyret, referenced in The Book of Shaders) to get directional, branching tendrils; **Worley/cellular noise** at the edge band adds branching/islands. Restrict the effect to a band near `d≈0.5` and bias it outward (only spread, don't erode) on high‑absorbency papers.

- **Ink bleed / spread (broad/wet nib, marker, absorbent paper):** Offset the SDF threshold outward (dilate) — lower the cutoff so more pixels count as "inside" — modulated by a per‑paper **absorbency map**; add a little fBm so the dilation is irregular. This is the SDF analog of a morphological dilate. Negative offset (erode) + thresholded noise (`step(noiseCutoff, noise)`, per Mirza Beig's dissolve setup) instead breaks the fill up (dry/sparse).

- **Pooling / shading / saturation variation (fountain pen on sized paper):** Modulate ink darkness inside the fill with **low‑frequency fBm** (large, soft blotches), and add **edge‑distance darkening**: use the SDF distance so the stroke edges and "lower" regions are darker (`darkness += k * (1 - d_inside)` plus a downward/gravity bias). Combine for the start/end/intersection pooling look.

- **Sheen (heavy‑ink regions):** Threshold the _highest_ pooling‑noise/darkness regions and add a colored/specular rim that shifts with view or light — sheen rides on top of where pooling is strongest, exactly as in reality (dye concentrated on the surface). A view‑angle term is optional in a flat 2D app; a static colored rim keyed to the pooling field reads convincingly. Drive this most strongly in the Tomoe‑River‑52gsm preset.

- **Typewriter uneven inking / ribbon fade:** Low‑frequency noise (or a 1D horizontal ramp) modulating per‑region ink density; **per‑glyph random darkness** via `hash(glyphID)`; filled counters via a slight inward SDF dilation that closes small interior gaps; impression halo via a thin band keyed off the SDF (a light‑then‑dark ring around `d≈0.5`).

- **Pencil grain (graphite on tooth):** Multiply glyph alpha by the **Part‑1 paper‑tooth noise itself**, so the tooth shows through; add high‑frequency value noise; **threshold by paper height/tooth** so graphite only "catches" on peaks (`alpha *= step(toothValley, paperHeight)` softened). This is the direct reuse of the paper preset's height/tooth layer as a multiplier on the mark — the literal embodiment of "tooth causes graphite to flake off the lead."

- **Per‑glyph jitter / misalignment (typewriter mechanics):** Small random per‑character baseline offset, horizontal shift, and sub‑degree rotation derived from `hash(glyphID)`; optional rare double‑strike (draw the glyph twice with a tiny offset and reduced alpha).

**Layering model.** Like the paper presets, each ink preset is a weighted combination of the above, with weights and even _which_ operations are active set by the paper underneath:

- **Wet ink (fountain pen):**
  - Tomoe River / fine paper: low edge‑roughness, strong pooling fBm + edge‑distance darkening, **sheen on**, ghosting layer, near‑zero feathering. _Crisp + pooled + sheen._
  - Washi / hanji: **strong directional feathering** (curl/flow warp along fiber field) + outward bleed dilation, soft edges, flecks interrupt fill, sheen off. _Wild, organic spread._
  - Office: moderate feathering + bleed‑through ghost on verso, fuzzy edges, weak shading.
  - Laid/cotton: moderate, with the laid‑line texture subtly modulating the edge.
- **Typewriter:** edge‑roughening (cloth) or near‑off (carbon film), per‑glyph hash darkness + baseline/rotation jitter, filled counters, impression halo, ribbon‑fade low‑freq density. On smooth paper crisper; on fibrous paper softer/feathered. _Mechanical but imperfect._
- **Pencil:** alpha × paper‑tooth noise + high‑freq grain + tooth‑peak thresholding; grain coarseness scales with the paper's tooth amplitude (faint on fine paper, coarse on laid/cotton); optional sheen patch at highest‑density regions. _Granular, reveals the paper._
- **Ballpoint/marker (optional):** ballpoint = crisp narrow, occasional skip (thresholded gaps) and blob (rare local dilation); marker = strong bleed dilation + feathering + show‑through, broad soft edges.

**Recipe sketches (operations on the SDF/mask):**

- _Wet‑ink‑on‑Tomoe‑River_ = `d` mostly unperturbed → smoothstep → fill color, then `darkness = base + poolFBM(low‑freq) + edgeDist(d)`, then `if darkness > t: add sheenRim`. Ghost layer on verso.
- _Wet‑ink‑on‑washi_ = warp `uv` by `curlNoise(fiberField)` near the edge band, dilate threshold outward by absorbency, soft smoothstep width up, sheen off, sprinkle chiri/fleck mask.
- _Typewriter‑on‑office_ = `d += valueNoise(highFreq)*amp` (ragged), inward micro‑dilate to fill counters, halo ring from `d`, `darkness *= hash(glyphID)` and ribbonFade ramp, per‑glyph baseline/rotation jitter.
- _Pencil‑on‑laid_ = `alpha = glyphCoverage * paperTooth * (0.6 + 0.4*valueNoise)` with `paperTooth` = Part‑1 laid+cotton height layer; threshold so valleys drop out; coarse grain.

## Recommendations

1. **Build the ink layer as a post‑process over your existing SDF/MSDF text pass.** Keep the crisp `median→smoothstep` pipeline as the base, then insert (in order): coordinate warp → distance perturbation/threshold offset → alpha modulation → color/sheen. This preserves font fidelity and matches your paper‑preset architecture.

2. **Start with the three "hero" presets** (wet ink, typewriter, pencil), each a weighted noise stack, and drive every weight from the active paper preset. Reuse the Part‑1 paper‑tooth/height texture directly as the pencil multiplier and as the absorbency/feather‑direction source — this is the cheapest, most authentic link and avoids new assets.

3. **Implement feathering with a fiber‑direction field, not isotropic noise.** For washi/hanji, derive a flow field from the paper's fiber layer and warp the glyph edge band along it (curl/flow noise or gradient‑displacement). Isotropic blur will read as "out of focus," not "wicked into fibers" — the physics (liquid follows fibers first) demands directional warp.

4. **Gate expensive operations by paper and by zoom.** Sheen, directional feathering, and per‑glyph double‑strike only matter at large sizes / specific presets. At small point sizes, collapse to: slight edge roughness + per‑glyph density jitter (typewriter), faint grain (pencil), or near‑crisp + subtle pooling (wet ink).

5. **Tune against real scans.** Photograph the same short text in each real instrument×paper combination and match histogram (fill darkness variance), edge spectrum (roughness frequency), and feather length. Thresholds to change the recipe: if edge‑roughness frequency reads as "buzzing"/aliased, lower frequency and raise smoothstep width; if feathering looks symmetric, increase anisotropy of the fiber field; if pencil looks painted, increase tooth‑threshold so more valleys drop to white.

6. **Expose a small parameter set per preset**: edge‑roughness amp/freq, bleed/dilate offset, feather strength + anisotropy, pooling amp + edge‑darkening, sheen threshold + tint, per‑glyph jitter + density variance, grain amp + tooth‑threshold. These are enough to span all instrument×paper combinations.

## Caveats

- **Community‑sourced ink behavior is qualitative.** Fountain‑pen, typewriter, and art‑pencil descriptions come largely from enthusiast/retailer/forum sources (JetPens, Goulet‑style educators, Fountain Pen Love, typewriter forums, art‑supply blogs). They are consistent and reliable for _visual signatures_ but are not metrologically precise; exact feather lengths, dry times, and sheen thresholds vary by specific ink/nib/humidity and should be calibrated empirically. The strongest physical claim (directional fiber wicking) is backed by peer‑reviewed work (Aslannejad & Hassanizadeh 2018; MDPI imbibition study).
- **The 52 vs 68 gsm Tomoe River and carbon‑vs‑cloth ribbon distinctions** are drawn from retailer/educator descriptions (Galen Leather, JetPens, Typewriter Wiki) rather than controlled measurement; treat them as reliable directional guidance, not exact specs.
- **Sheen and shimmer are partly view‑dependent and partly chemistry.** In a flat 2D app you are faking an angle‑dependent metallic effect; a static keyed rim is an approximation, not physically based.
- **"Breaking the field."** Perturbing the SDF distance with noise means the distorted field no longer represents true distance, which can interact badly with the screen‑px‑range anti‑aliasing math at extreme zooms; clamp amplitudes and re‑test at multiple scales (Cummings explicitly flags this side‑effect).
- **Some cited shader techniques are general, not text‑specific.** Domain warping (Quilez), Book‑of‑Shaders noise/fbm/cellular, curl‑noise (Bridson), and dissolve thresholding (Beig) are foundational references demonstrated on shapes/textures/terrain; applying them to glyph SDFs is a straightforward but author‑implemented step, not a turnkey recipe. The closest direct precedent for noise‑on‑glyph‑SDF edges is Cummings' "Shader Fun" series (demonstrated on a shape SDF, identical mechanism for font atlases).
- **Performance untested here.** Curl/flow‑noise warps and multi‑octave fBm per fragment over lots of text can be costly on mobile GPUs; the recommendation to gate by zoom/preset is a hypothesis to validate with profiling on target Apple Silicon devices.
- **Carbon‑film vs. cloth ribbon** is presented as a crisp/soft toggle; real machines vary widely, and the "filled counters" and impression effects depend heavily on machine condition, platen hardness, and ribbon age.
