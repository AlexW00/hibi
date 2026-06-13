#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// === Paper tilt-specular ===
//
// A subtle tilt-reactive highlight applied OVER the baked paper-field image
// (PaperFieldBaker). This is the ONLY live (per-frame) term in the paper render —
// the formation fBm + grain are baked once to a cached image (research §H, §1.6),
// and this shader adds a single moving glint so the surface feels like coated stock
// catching the light as the device tilts.
//
// Generalizes StampShader.metal's specular term: a Gaussian hotspot whose centre is
// driven by device tilt. Unlike the stamp shader, this does NOT regenerate any
// texture — it samples the already-baked layer and adds a faint additive highlight.
//
// Applied as a `.layerEffect` to the baked paper Image. Reduce Motion / Low Power
// must OMIT this effect entirely (see paperTiltEnabled) — the baked texture still
// shows; only the moving highlight stops.
//
// Arguments after (position, layer):
//   float2 size      — view size in points
//   float2 tilt      — (tiltX, tiltY) from MotionStore, range ~-1..1
//   half4  tintColor — scheme-resolved tint (premultiplied); drives highlight warmth
//   float  strength  — overall highlight strength (0 = none)

[[stitchable]] half4 paperTiltSpecular(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float2 tilt,
    half4  tintColor,
    float  strength
) {
    half4 base = layer.sample(position);

    // Sampling outside the layer (rounded-corner transparent regions) → leave as-is.
    if (base.a < 0.01h) {
        return base;
    }

    float2 uv = position / size;

    // Tilt moves a broad, soft hotspot across the surface. The 0.5 multiplier keeps
    // the centre within roughly the card bounds (matches StampShader's specCenter).
    float2 specCenter = float2(0.5 + tilt.x * 0.5, 0.5 + tilt.y * 0.5);
    float d = distance(uv, specCenter);

    // Broad Gaussian falloff — a wide sheen, not a tight point (focus 2.2 is much
    // softer than the stamp's per-glyph hotspot). Resolution-independent in uv space.
    float hotspot = exp(-d * d * 2.2);

    // Highlight colour: a touch of the tint pushed toward white so the glint reads as
    // light on coated paper rather than a colour wash. Kept very faint via `strength`.
    half3 highlightColor = mix(tintColor.rgb, half3(1.0h), 0.6h);
    half glint = half(hotspot * strength);

    // Additive over the baked surface, clamped. Premultiplied output (base.a).
    half3 lit = clamp(base.rgb + highlightColor * glint * base.a, half3(0.0h), half3(1.0h));
    return half4(lit, base.a);
}
