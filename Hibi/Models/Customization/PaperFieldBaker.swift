import CoreGraphics
import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit
#endif

/// Bakes the procedural **paper field** to a cached `CGImage` and exposes it as a
/// SwiftUI `Image` (see `PaperFieldBaker+Image`).
///
/// ## Why bake (research §H / §1.6 "bake, don't evaluate-per-frame")
/// Apple GPUs are tile-based deferred renderers; evaluating multi-octave fBm per
/// fragment every frame on a mostly-static notes background wastes power/thermal
/// budget. The field is therefore evaluated **once** in canvas space and baked to
/// an image, then cached disk + memory keyed by `(texture, tint, scheme, size)`.
/// Normal compositing samples the cheap bitmap; the only LIVE term is the tilt
/// specular `.layerEffect` (`PaperTexture.metal`).
///
/// ## Bake mechanism: CPU fBm bitmap (chosen — see report)
/// The candidate GPU mechanisms (ImageRenderer-over-`.colorEffect`; offscreen
/// `MTLTexture` → `CGImage`) cannot be **verified headless** (no simulator in this
/// environment) and carry the exact silent-failure surface — sRGB/linear,
/// premultiply, Y-flip, channel gamma — that the project's shader notes warn about.
/// A CPU bake is the only path that (a) mirrors `StampCompositor` exactly (a
/// `nonisolated` CoreGraphics rasterizer → `CGImage` → disk+mem cache, no second
/// cache), and (b) is **provably correct without a device**: the unit test asserts
/// the baked bitmap actually carries noise variance. The one-time cost is amortized
/// by the disk+memory cache, so the TBDR win (no per-frame ALU) is preserved.
///
/// ## Shared paper-field set (research §1.6 / §M)
/// The baked luminance **is** the tooth/height field a later stage (Stage 7 ink)
/// will sample: pencil/marker grain = glyph alpha × paper tooth. `paperField(...)`
/// returns the raw `[Float]` field so that stage can request it without re-deriving
/// the noise; `bakedImage(...)` is the rendered consumer of the same field. Fiber-
/// direction / absorbency are additive later — the API is kept extensible (more
/// channels) rather than collapsed into the single rendered image.
nonisolated enum PaperFieldBaker {

    // MARK: - Public key inputs

    /// Light vs dark — folded into the cache key so an appearance flip re-bakes and
    /// both variants coexist in the cache.
    enum Scheme: Int { case light = 0, dark = 1 }

    /// The baked field's input parameters. All members are value-typed integers /
    /// resolved RGB so the key is stable (no float-fragile color identity).
    struct Key: Hashable {
        var textureRaw: Int
        var tintRaw: Int
        var scheme: Int
        /// Pixel side length (square), already bucketed by the caller.
        var px: Int
    }

    // MARK: - Cache (mirrors StampCompositor exactly)

    private static let memoryCache = NSCache<NSString, CGImageWrapper>()

    private final class CGImageWrapper {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private static func cacheKey(_ key: Key) -> NSString {
        NSString(string: "paper-\(key.textureRaw)-\(key.tintRaw)-\(key.scheme)-\(key.px)")
    }

    private static var diskCacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PaperFields", isDirectory: true)
    }

    private static func diskURL(_ key: Key) -> URL? {
        guard let dir = diskCacheDirectory else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(
            "paper-\(key.textureRaw)-\(key.tintRaw)-\(key.scheme)-\(key.px).png")
    }

    #if DEBUG
    static func _test_clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    #endif

    // MARK: - Lookup / bake

    /// Fast synchronous lookup: memory cache → disk cache. Returns nil on miss.
    static func cachedField(_ key: Key) -> CGImage? {
        guard key.px > 0 else { return nil }

        let cacheKeyString = cacheKey(key)
        if let hit = memoryCache.object(forKey: cacheKeyString) { return hit.image }

        guard let url = diskURL(key),
              let provider = CGDataProvider(url: url as CFURL),
              let image = CGImage(pngDataProviderSource: provider,
                                  decode: nil, shouldInterpolate: true,
                                  intent: .defaultIntent)
        else { return nil }

        memoryCache.setObject(CGImageWrapper(image), forKey: cacheKeyString)
        return image
    }

    /// Returns the baked paper-field image for `key`, generating + caching (memory
    /// and disk) on a miss. Pure CoreGraphics — safe on any thread (`nonisolated`).
    static func bakedField(
        texture: PaperTexture,
        tint: PaperTint,
        scheme: Scheme,
        px: Int
    ) -> CGImage? {
        let key = Key(textureRaw: texture.rawValue, tintRaw: tint.rawValue,
                      scheme: scheme.rawValue, px: px)
        guard key.px > 0 else { return nil }

        let cacheKeyString = cacheKey(key)
        if let cached = memoryCache.object(forKey: cacheKeyString) { return cached.image }
        if let onDisk = cachedField(key) { return onDisk }

        guard let image = render(texture: texture, tint: tint, scheme: scheme, px: key.px)
        else { return nil }

        memoryCache.setObject(CGImageWrapper(image), forKey: cacheKeyString)
        persistToDisk(image, key: key)
        return image
    }

    private static func persistToDisk(_ image: CGImage, key: Key) {
        guard let url = diskURL(key) else { return }
        let tmpURL = url.appendingPathExtension("tmp")
        guard let dest = CGImageDestinationCreateWithURL(
                  tmpURL as CFURL, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tmpURL)
            return
        }
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    // MARK: - Render

    /// Rasterizes the paper field into an RGBA `CGImage` of `px × px`.
    ///
    /// The base is the **resolved tint** (warm cream / tinted, never sterile white);
    /// the formation fBm + grain modulate **luminance by a low single-digit percent**
    /// around that base (research §G). The result is intentionally subtle — if the
    /// texture is consciously visible at default zoom it is too strong (on-device
    /// tuning knob: `Weights.formationStrength` / `.grainStrength`).
    private static func render(
        texture: PaperTexture,
        tint: PaperTint,
        scheme: Scheme,
        px: Int
    ) -> CGImage? {
        let field = paperField(texture: texture, px: px)
        let weights = Weights.forTexture(texture)
        let base = baseColor(tint: tint, scheme: scheme)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bytes = [UInt8](repeating: 0, count: px * px * 4)

        // Per-channel luminance modulation. Field is ~[0,1] (0.5 = neutral); we map
        // (field − 0.5) → a small +/- luminance delta, scaled per scheme so the dark
        // variant doesn't crush to black.
        let amp = weights.luminanceAmplitude * (scheme == .dark ? 0.7 : 1.0)

        for i in 0 ..< (px * px) {
            let f = Double(field[i])               // ~[0,1]
            let delta = (f - 0.5) * 2.0 * amp      // ~[-amp, +amp]
            let factor = 1.0 + delta               // luminance scale around base

            let r = clamp01(base.r * factor)
            let g = clamp01(base.g * factor)
            let b = clamp01(base.b * factor)

            let o = i * 4
            bytes[o + 0] = UInt8(r * 255.0)
            bytes[o + 1] = UInt8(g * 255.0)
            bytes[o + 2] = UInt8(b * 255.0)
            bytes[o + 3] = 255
        }

        return bytes.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: px, height: px,
                bitsPerComponent: 8,
                bytesPerRow: px * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
    }

    // MARK: - Shared field (tooth/height — Stage 7 will sample this)

    /// Generates the procedural paper field as a `px × px` array of `Float` in ~[0,1]
    /// (0.5 ≈ neutral). **This luminance IS the tooth/height field** the ink stage
    /// reuses (research §M): the rendered image is `base × (1 ± k·(field−0.5))`, and a
    /// pencil/marker can read the same `field` as a grain mask. Exposed `static` so a
    /// later stage requests the field directly rather than re-deriving the noise.
    ///
    /// - Hero layer: **low-octave formation fBm** (research §E, the biggest perceptual
    ///   win) — 4 octaves, lacunarity ≈2.0, gain ≈0.5, detuned frequencies + domain
    ///   rotation between octaves to break axial bias.
    /// - Plus a **light, band-limited high-frequency grain** (the tooth), weighted per
    ///   texture (§L: smooth ≈ flat; linen/kraft = fiber grain; news = halftone-ish;
    ///   vellum = soft veil).
    static func paperField(texture: PaperTexture, px: Int) -> [Float] {
        let weights = Weights.forTexture(texture)
        let n = px * px
        var out = [Float](repeating: 0.5, count: n)

        // Canvas-space coordinate scale: low frequency so formation reads as large
        // soft 2–20 mm blobs, not high-freq dirt. Resolution-independent.
        let formationScale = Float(5.0)
        let grainScale = weights.grainScale
        let invPx = 1.0 / Float(max(px, 1))

        for y in 0 ..< px {
            for x in 0 ..< px {
                let u = Float(x) * invPx
                let v = Float(y) * invPx

                // Hero: low-octave formation fBm in ~[0,1].
                let formation = fbm(SIMDPoint(u * formationScale, v * formationScale),
                                    octaves: 4, seed: 11)

                // Light high-freq grain/tooth, also ~[0,1].
                let grain = weights.grainStrength > 0
                    ? fbm(SIMDPoint(u * grainScale, v * grainScale), octaves: 2, seed: 207)
                    : 0.5

                // Halftone-ish dot character for newsprint: a cheap periodic dot grid,
                // band-limited (kept faint) so it reads as coarse pulp, not moiré.
                let halftone = weights.halftoneStrength > 0
                    ? halftoneDots(u: u, v: v, px: px, cellPx: 6.0)
                    : 0.5

                // Weighted blend around neutral 0.5.
                var value: Float = 0.5
                value += (formation - 0.5) * weights.formationStrength
                value += (grain - 0.5) * weights.grainStrength
                value += (halftone - 0.5) * weights.halftoneStrength

                out[y * px + x] = clampF(value, 0.0, 1.0)
            }
        }
        return out
    }

    // MARK: - Per-texture weights (research §L preset table)

    /// Relative layer weights per `PaperTexture`. Smooth is nearly flat (its character
    /// is tone + smoothness, not texture); linen/kraft lean on fiber grain; news adds a
    /// faint halftone; vellum is a soft low-freq veil. `luminanceAmplitude` is the
    /// low-single-digit-% luminance modulation envelope (§G).
    struct Weights {
        var formationStrength: Float
        var grainStrength: Float
        var grainScale: Float
        var halftoneStrength: Float
        /// Max ± luminance modulation as a fraction (e.g. 0.03 = ±3%).
        var luminanceAmplitude: Double

        static func forTexture(_ texture: PaperTexture) -> Weights {
            switch texture {
            case .smooth:
                // Nearly flat — a whisper of formation only.
                return Weights(formationStrength: 0.25, grainStrength: 0.05,
                               grainScale: 90, halftoneStrength: 0,
                               luminanceAmplitude: 0.015)
            case .linen:
                // Woven fiber grain over medium formation.
                return Weights(formationStrength: 0.55, grainStrength: 0.45,
                               grainScale: 70, halftoneStrength: 0,
                               luminanceAmplitude: 0.030)
            case .kraft:
                // Pressed-pulp fiber: strong formation + coarse grain.
                return Weights(formationStrength: 0.70, grainStrength: 0.40,
                               grainScale: 55, halftoneStrength: 0,
                               luminanceAmplitude: 0.035)
            case .news:
                // Coarse pulp + faint halftone dot character.
                return Weights(formationStrength: 0.50, grainStrength: 0.25,
                               grainScale: 80, halftoneStrength: 0.30,
                               luminanceAmplitude: 0.030)
            case .vellum:
                // Soft translucent veil — formation only, very low grain.
                return Weights(formationStrength: 0.45, grainStrength: 0.08,
                               grainScale: 100, halftoneStrength: 0,
                               luminanceAmplitude: 0.020)
            }
        }
    }

    // MARK: - Base tint colour (resolved per scheme)

    private struct RGB { var r: Double; var g: Double; var b: Double }

    /// Resolved RGB base for the field, mirroring `AdaptivePalette.paperFill` depth-0
    /// values so the baked texture sits over the same tint the substrate fills with.
    private static func baseColor(tint: PaperTint, scheme: Scheme) -> RGB {
        switch (tint, scheme) {
        case (.cream, .light):  return RGB(r: 0.984, g: 0.980, b: 0.969)
        case (.cream, .dark):   return RGB(r: 0.141, g: 0.141, b: 0.141)
        case (.blush, .light):  return RGB(r: 0.965, g: 0.910, b: 0.898)
        case (.blush, .dark):   return RGB(r: 0.165, g: 0.141, b: 0.133)
        case (.sky, .light):    return RGB(r: 0.894, g: 0.925, b: 0.953)
        case (.sky, .dark):     return RGB(r: 0.125, g: 0.137, b: 0.153)
        case (.sage, .light):   return RGB(r: 0.906, g: 0.925, b: 0.882)
        case (.sage, .dark):    return RGB(r: 0.137, g: 0.153, b: 0.133)
        case (.butter, .light): return RGB(r: 0.961, g: 0.933, b: 0.843)
        case (.butter, .dark):  return RGB(r: 0.153, g: 0.141, b: 0.125)
        case (.lilac, .light):  return RGB(r: 0.925, g: 0.898, b: 0.945)
        case (.lilac, .dark):   return RGB(r: 0.145, g: 0.129, b: 0.157)
        }
    }

    // MARK: - Noise primitives (CPU ports of StampShader.metal's snoise / fbm)

    /// Lightweight 2D float point (avoids pulling in SIMD types for clarity).
    private struct SIMDPoint { var x: Float; var y: Float
        init(_ x: Float, _ y: Float) { self.x = x; self.y = y }
    }

    /// fBm built from simplex octaves, remapped to ~[0,1]. Conventions per research §E:
    /// lacunarity ≈2.0 (detuned 2.02 to break grid alignment), gain ≈0.5, a fixed 2×2
    /// domain rotation between octaves, and a per-call seed offset so layers decorrelate.
    private static func fbm(_ p0: SIMDPoint, octaves: Int, seed: Int) -> Float {
        var p = p0
        // Decorrelate this fBm call's domain.
        let off = Float(seed) * 13.37
        p.x += off
        p.y += off * 0.7

        var value: Float = 0
        var amplitude: Float = 0.5
        // Fixed rotation (~0.5 rad) applied between octaves to break axial bias.
        let cosR: Float = 0.8775826
        let sinR: Float = 0.4794255
        for _ in 0 ..< octaves {
            value += amplitude * snoise(p)
            // Detuned lacunarity + domain rotation.
            let rx = p.x * cosR - p.y * sinR
            let ry = p.x * sinR + p.y * cosR
            p.x = rx * 2.02
            p.y = ry * 2.02
            amplitude *= 0.5
        }
        return clampF(value * 0.5 + 0.5, 0.0, 1.0)
    }

    /// 2D simplex noise (Gustavson / webgl-noise port), output ~[-1, 1].
    /// CPU mirror of `snoise` in StampShader.metal.
    private static func snoise(_ v: SIMDPoint) -> Float {
        let C = (x: Float(0.211324865405187),
                 y: Float(0.366025403784439),
                 z: Float(-0.577350269189626),
                 w: Float(0.024390243902439))

        // First corner.
        let s = (v.x + v.y) * C.y
        var ix = (v.x + s).rounded(.down)
        var iy = (v.y + s).rounded(.down)

        let t = (ix + iy) * C.x
        let x0x = v.x - ix + t
        let x0y = v.y - iy + t

        // Other corners.
        let (i1x, i1y): (Float, Float) = (x0x > x0y) ? (1, 0) : (0, 1)

        // x12 = x0.xyxy + C.xxzz - (i1.x, i1.y, 0, 0)
        let x12x = x0x + C.x - i1x
        let x12y = x0y + C.x - i1y
        let x12z = x0x + C.z
        let x12w = x0y + C.z

        ix = mod289(ix)
        iy = mod289(iy)

        let p0 = permute(permute(iy + 0.0) + ix + 0.0)
        let p1 = permute(permute(iy + i1y) + ix + i1x)
        let p2 = permute(permute(iy + 1.0) + ix + 1.0)

        var m0 = max(0.5 - (x0x * x0x + x0y * x0y), 0.0)
        var m1 = max(0.5 - (x12x * x12x + x12y * x12y), 0.0)
        var m2 = max(0.5 - (x12z * x12z + x12w * x12w), 0.0)
        m0 *= m0; m0 *= m0
        m1 *= m1; m1 *= m1
        m2 *= m2; m2 *= m2

        // Gradients.
        let x_0 = 2.0 * fractF(p0 * C.w) - 1.0
        let x_1 = 2.0 * fractF(p1 * C.w) - 1.0
        let x_2 = 2.0 * fractF(p2 * C.w) - 1.0
        let h0 = abs(x_0) - 0.5
        let h1 = abs(x_1) - 0.5
        let h2 = abs(x_2) - 0.5
        let ox0 = (x_0 + 0.5).rounded(.down)
        let ox1 = (x_1 + 0.5).rounded(.down)
        let ox2 = (x_2 + 0.5).rounded(.down)
        let a0_0 = x_0 - ox0
        let a0_1 = x_1 - ox1
        let a0_2 = x_2 - ox2

        let norm = Float(1.79284291400159)
        m0 *= norm - 0.85373472095314 * (a0_0 * a0_0 + h0 * h0)
        m1 *= norm - 0.85373472095314 * (a0_1 * a0_1 + h1 * h1)
        m2 *= norm - 0.85373472095314 * (a0_2 * a0_2 + h2 * h2)

        let g0 = a0_0 * x0x + h0 * x0y
        let g1 = a0_1 * x12x + h1 * x12y
        let g2 = a0_2 * x12z + h2 * x12w

        return 130.0 * (m0 * g0 + m1 * g1 + m2 * g2)
    }

    private static func mod289(_ x: Float) -> Float {
        x - (x * (1.0 / 289.0)).rounded(.down) * 289.0
    }

    private static func permute(_ x: Float) -> Float {
        mod289((x * 34.0 + 1.0) * x)
    }

    /// A faint periodic halftone dot field (newsprint), band-limited to read as coarse
    /// pulp rather than a high-frequency moiré screen. Returns ~[0,1].
    private static func halftoneDots(u: Float, v: Float, px: Int, cellPx: Float) -> Float {
        let cell = cellPx / Float(max(px, 1))
        let cu = fractF(u / cell) - 0.5
        let cv = fractF(v / cell) - 0.5
        let d = (cu * cu + cv * cv).squareRoot()
        // Soft dot: dark center, light surround — kept subtle by the weight.
        let dot = 1.0 - smoothstepF(0.1, 0.4, d)
        return 0.5 + (dot - 0.5) * 0.5
    }

    // MARK: - Scalar helpers

    private static func fractF(_ x: Float) -> Float { x - x.rounded(.down) }
    private static func clampF(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(x, lo), hi)
    }
    private static func clamp01(_ x: Double) -> Double { min(max(x, 0.0), 1.0) }
    private static func smoothstepF(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
        let t = clampF((x - e0) / (e1 - e0), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    }
}
