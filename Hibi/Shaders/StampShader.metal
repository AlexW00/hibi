#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

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

float hash01(uint3 seed) {
    return float(pcg3d(seed).x) / float(0xFFFFFFFFu);
}

// --- Simplex-like value noise for fBm ---

float valueNoise(float2 p, uint seedOffset) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f); // smoothstep

    uint ix = uint(i.x);
    uint iy = uint(i.y);

    float a = hash01(uint3(ix,     iy,     seedOffset));
    float b = hash01(uint3(ix + 1, iy,     seedOffset));
    float c = hash01(uint3(ix,     iy + 1, seedOffset));
    float d = hash01(uint3(ix + 1, iy + 1, seedOffset));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(float2 p, int octaves, uint seedOffset) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; ++i) {
        value += amplitude * valueNoise(p, seedOffset + uint(i) * 37u);
        p *= 2.02;
        amplitude *= 0.5;
    }
    return value;
}

float worley(float2 p, uint seedOffset) {
    float2 i = floor(p);
    float2 f = fract(p);
    float minDist = 1.0;

    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            float2 neighbor = float2(float(x), float(y));
            uint3 cellSeed = uint3(uint(i.x + float(x)),
                                   uint(i.y + float(y)),
                                   seedOffset);
            uint3 h = pcg3d(cellSeed);
            float2 point = float2(float(h.x), float(h.y)) / float(0xFFFFFFFFu);
            float2 diff = neighbor + point - f;
            float d = dot(diff, diff);
            minDist = min(minDist, d);
        }
    }
    return sqrt(minDist);
}

// --- Stamp shader ---
//
// Applied as a layerEffect to the pre-composited mask+text image.
// The layer contains grayscale ink coverage (R=G=B=coverage, A=1).
//
// Arguments after (position, layer):
//   float2 size       — view size in points
//   float  seed       — deterministic seed for noise (cast from UInt64)
//   float2 tilt       — (tiltX, tiltY) from MotionStore, range ~-1..1
//   half4  inkColor   — the vermillion ink color (premultiplied)

[[stitchable]] half4 stampEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float  seed,
    float2 tilt,
    half4  inkColor
) {
    // Sample the composite (grayscale coverage)
    half4 raw = layer.sample(position);
    float coverage = float(raw.r);

    // UV in 0..1
    float2 uv = position / size;

    // --- Ink-transfer imperfections ---
    // fBm shapes WHERE ink drops out (organic contours).
    // Fine hash perturbs the threshold so edges are grainy, not smooth.
    uint seedU = uint(seed);

    // Broad pressure — large-scale ink density.
    float broad = fbm(uv * 2.5, 3, seedU);
    float pressureMap = smoothstep(0.05, 0.40, broad);

    // Ink strength: pressure + coverage.
    float inkStrength = pressureMap * 0.65 + coverage * 0.35;

    // Medium-scale organic wobble — makes boundary shape irregular.
    float wobble = (fbm(uv * 15.0, 2, seedU + 100u) - 0.4) * 0.18;

    // Fine grain — near-pixel hash (~2px cells) roughens the boundary edge.
    // Only affects pixels near the threshold; solid/empty areas are unchanged.
    float2 grainCell = floor(uv * 300.0);
    float grain = (hash01(uint3(uint(grainCell.x), uint(grainCell.y), seedU + 200u)) - 0.5) * 0.10;

    float inkSurvival = step(0.45, inkStrength + wobble + grain);

    coverage *= inkSurvival;

    float pressure = 0.4 + broad * 0.7;

    if (coverage < 0.01) {
        return half4(0.0h);
    }

    // --- Ink color ---
    half3 currentInk = inkColor.rgb * 0.82h;

    // --- Specular highlight (gyro-driven) ---
    float2 specCenter = float2(0.5 + tilt.x * 0.5, 0.5 + tilt.y * 0.5);
    float d = distance(uv, specCenter);
    float hotspot = exp(-d * d * 8.0);
    float specStrength = hotspot * 0.45;
    half3 specular = inkColor.rgb * half(specStrength);

    // --- Bump effect ---
    // Use raw coverage for both sides so dropout doesn't break the gradient.
    float rawCov = float(raw.r) * pressure;
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
    half3 finalColor = clamp(currentInk + specular + bumpColor, half3(0.0h), half3(1.0h));
    half  alpha = half(coverage);

    // Premultiply
    return half4(finalColor * alpha, alpha);
}
