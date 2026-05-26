#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// === Param indices — keep in sync with StampNoise.Param in StampNoise.swift ===
#define P_MASTER          0
#define P_SUPPLY_SCALE     1
#define P_SUPPLY_STRENGTH  2
#define P_SUPPLY_ERODE     3
#define P_CHIP_STRENGTH    4
#define P_CHIP_SCALE       5
#define P_EDGE_ROUGHNESS   6
#define P_EDGE_ROUGH_SCALE 7
#define P_RIM_WIDTH        8
#define P_RIM_DARKNESS     9
#define P_BLEED_WIDTH      10
#define P_BLEED_STRENGTH   11

// Normalized half-range used to encode the signed distance field into the
// composite's green channel. MUST match StampCompositor.sdfRange.
constant float SDF_RANGE = 0.06;

inline float param(device const float *p, int n, int i) {
    return (i < n) ? p[i] : 0.0;
}

// --- pcg3d hash (Jarzynski & Olano, JCGT 2020) ---

uint3 pcg3d(uint3 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> 16u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

// Large deterministic 2D offset so each seed samples a different region of
// the procedural noise fields.
float2 seedOffset(uint s) {
    uint3 h = pcg3d(uint3(s, 0x9E3779B9u, 0x85EBCA6Bu));
    return float2(h.xy) / float(0xFFFFFFFFu) * 1000.0;
}

// --- 2D simplex noise (Gustavson / webgl-noise port), output ~[-1, 1] ---

float3 mod289_3(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float3 permute289(float3 x) { return mod289_3((x * 34.0 + 1.0) * x); }

float snoise(float2 v) {
    const float4 C = float4(0.211324865405187, 0.366025403784439,
                           -0.577350269189626, 0.024390243902439);
    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = i - floor(i * (1.0 / 289.0)) * 289.0;
    float3 p = permute289(permute289(i.y + float3(0.0, i1.y, 1.0))
                                   + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy),
                                dot(x12.zw, x12.zw)), 0.0);
    m = m * m; m = m * m;
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x  = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// fBm built from simplex octaves, remapped to ~[0, 1].
float fbm(float2 p, int octaves, float2 off) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; ++i) {
        value += amplitude * snoise(p + off);
        p *= 2.02;
        amplitude *= 0.5;
        off = off * 1.7 + 19.1;
    }
    return clamp(value * 0.5 + 0.5, 0.0, 1.0);
}

// Worley / cellular noise — distance to nearest feature point.
float worley(float2 p, uint seedOffsetU) {
    float2 i = floor(p);
    float2 f = fract(p);
    float minDist = 1.0;
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            uint3 h = pcg3d(uint3(uint(i.x + float(x)),
                                  uint(i.y + float(y)), seedOffsetU));
            float2 pt = float2(h.xy) / float(0xFFFFFFFFu);
            float2 diff = float2(float(x), float(y)) + pt - f;
            minDist = min(minDist, dot(diff, diff));
        }
    }
    return sqrt(minDist);
}

// --- Stamp shader ---
//
// Applied as a layerEffect to the pre-composited mask+text image:
//   R = ink coverage (0 = paper, 1 = full ink)
//   G = signed distance field (0.5 = boundary, >0.5 inside; see SDF_RANGE)
//   A = 1 (opaque)
//
// Arguments after (position, layer):
//   float2 size       — view size in points
//   float  seed       — deterministic per-stamp seed (cast from UInt64)
//   float2 tilt       — (tiltX, tiltY) from MotionStore, range ~-1..1
//   half4  inkColor   — vermillion ink color (premultiplied)
//   floatArray params — StampNoise parameters (see P_* defines)

[[stitchable]] half4 stampEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float  seed,
    float2 tilt,
    half4  inkColor,
    device const float *params,
    int    paramCount
) {
    half4 raw = layer.sample(position);
    float coverage = float(raw.r);

    float2 uv = position / size;
    uint seedU = uint(seed);

    // --- Parameters (master scales every "strength" knob, 0 = clean) ---
    float m = clamp(param(params, paramCount, P_MASTER), 0.0, 1.0);

    float supplyScale     = param(params, paramCount, P_SUPPLY_SCALE);
    float supplyStrength  = param(params, paramCount, P_SUPPLY_STRENGTH) * m;
    float supplyErode     = param(params, paramCount, P_SUPPLY_ERODE) * m;
    float chipStrength    = param(params, paramCount, P_CHIP_STRENGTH) * m;
    float chipScale       = param(params, paramCount, P_CHIP_SCALE);
    float edgeRoughness   = param(params, paramCount, P_EDGE_ROUGHNESS) * m;
    float edgeRoughScale  = param(params, paramCount, P_EDGE_ROUGH_SCALE);
    float rimWidth        = param(params, paramCount, P_RIM_WIDTH);
    float rimDarkness     = param(params, paramCount, P_RIM_DARKNESS) * m;
    float bleedWidth      = param(params, paramCount, P_BLEED_WIDTH);
    float bleedStrength   = param(params, paramCount, P_BLEED_STRENGTH) * m;

    // --- Control field: slow macro pressure / ink-supply variation ---
    float supply = fbm(uv * supplyScale, 4, seedOffset(seedU + 11u));

    // --- Signed distance (in points), inside > 0 ---
    float sdN   = (float(raw.g) - 0.5) * 2.0 * SDF_RANGE;  // image fraction
    float sdPts = sdN * size.x;
    float aa    = max(fwidth(sdPts), 0.5);

    // --- Boundary erosion: low supply eats inward, hi-freq noise roughens ---
    float rough       = snoise(uv * edgeRoughScale + seedOffset(seedU + 211u)) * edgeRoughness;
    float pressErode  = (1.0 - supply) * supplyErode;
    float sdEff       = sdPts - pressErode + rough;
    float erodedAlpha = smoothstep(-aa, aa, sdEff);

    // Erosion only removes ink; never exceed the original coverage. Blend by
    // master so that at master = 0 the alpha is exactly the clean coverage.
    float alpha = mix(coverage, min(coverage, erodedAlpha), m);

    // --- Dry chips: larger irregular Worley voids ---
    float chip = 0.0;
    if (chipStrength > 0.001) {
        float wd = worley(uv * chipScale + 16.0, seedU + 701u);
        chip = (1.0 - smoothstep(0.05, 0.35, wd)) * chipStrength;
    }
    alpha *= (1.0 - chip);

    // --- Capillary bleed: faint ink just OUTSIDE the boundary ---
    if (bleedStrength > 0.001 && bleedWidth > 0.01) {
        float band = smoothstep(-bleedWidth, 0.0, sdPts)
                   * (1.0 - smoothstep(0.0, max(aa, 1.0), sdPts));
        // Directional (anisotropic) front — fakes paper-fiber wicking.
        float bdir = fbm(float2(uv.x * edgeRoughScale * 1.3,
                                uv.y * edgeRoughScale * 0.5)
                         + seedOffset(seedU + 907u), 3, float2(0.0));
        alpha = max(alpha, band * bleedStrength * bdir);
    }

    if (alpha < 0.01) {
        return half4(0.0h);
    }

    // --- Ink density (color brightness), centered on 1.0 ---
    float density = 1.0 + supplyStrength * (supply - 0.5) * 1.6;
    density = clamp(density, 0.15, 1.3);

    // --- Rim darkening (squeegee): band just INSIDE the boundary ---
    float rim = 0.0;
    if (rimDarkness > 0.001 && rimWidth > 0.01 && sdPts > 0.0) {
        rim = (1.0 - smoothstep(0.0, rimWidth, sdPts)) * rimDarkness;
    }

    half3 baseInk = inkColor.rgb * 0.85h;
    baseInk *= half(density);
    baseInk *= half(1.0 - rim * 0.6);

    // --- Specular highlight (gyro-driven) — unchanged ---
    float2 specCenter = float2(0.5 + tilt.x * 0.5, 0.5 + tilt.y * 0.5);
    float d = distance(uv, specCenter);
    float hotspot = exp(-d * d * 8.0);
    half3 specular = inkColor.rgb * half(hotspot * 0.45);

    // --- Bump / emboss — unchanged; uses RAW coverage on both sides ---
    float pressure = 0.5 + supply * 0.6;
    float rawCov = coverage * pressure;
    float right = float(layer.sample(position + float2(2.0, 0.0)).r) * pressure;
    float below = float(layer.sample(position + float2(0.0, 2.0)).r) * pressure;
    float dx = right - rawCov;
    float dy = below - rawCov;
    float2 lightDir = normalize(float2(-0.7 + tilt.x * 0.6, -0.7 + tilt.y * 0.6));
    float bumpLight = clamp(dx * lightDir.x + dy * lightDir.y, -1.0, 1.0);
    half bump = half(bumpLight);
    half positiveBump = max(bump, 0.0h);
    half negativeBump = min(bump, 0.0h);
    half3 bumpColor = inkColor.rgb * (positiveBump * 0.55h) + half3(negativeBump * 0.45h);

    // --- Final composite ---
    half3 finalColor = clamp(baseInk + specular + bumpColor, half3(0.0h), half3(1.0h));
    half outAlpha = half(alpha);
    return half4(finalColor * outAlpha, outAlpha);
}
