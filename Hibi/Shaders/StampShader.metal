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

    // --- Pressure noise ---
    // Low-frequency fBm driven by seed. Modulates ink density to simulate
    // uneven rubber-stamp pressure. The masks already have high-frequency
    // distress baked in, so we only add low-frequency unevenness.
    uint seedU = uint(seed);
    float pressure = fbm(uv * 4.0, 3, seedU);
    pressure = 0.55 + pressure * 0.45;
    coverage *= pressure;

    // Threshold: below a certain coverage, treat as transparent
    if (coverage < 0.01) {
        return half4(0.0h);
    }

    // --- Ink color ---
    half3 currentInk = inkColor.rgb * 0.70h;

    // --- Specular highlight (gyro-driven) ---
    float2 specCenter = float2(0.5 + tilt.x * 0.3, 0.5 + tilt.y * 0.3);
    float d = distance(uv, specCenter);
    float hotspot = exp(-d * d * 6.0);
    float specStrength = hotspot * 0.45;
    half3 specular = half3(1.0h) * half(specStrength);

    // --- Bump effect ---
    // Sample neighbors with a wider offset to smooth across text edges.
    float right = float(layer.sample(position + float2(2.0, 0.0)).r) * pressure;
    float below = float(layer.sample(position + float2(0.0, 2.0)).r) * pressure;
    float dx = right - coverage;
    float dy = below - coverage;
    float2 lightDir = normalize(float2(-0.7 + tilt.x * 0.3, -0.7 + tilt.y * 0.3));
    float bumpLight = clamp(dx * lightDir.x + dy * lightDir.y, -1.0, 1.0);
    half bumpAmount = half(bumpLight * 0.30);

    // --- Final composite ---
    half3 finalColor = currentInk + specular + bumpAmount;
    half  alpha = half(coverage);

    // Premultiply
    return half4(finalColor * alpha, alpha);
}
