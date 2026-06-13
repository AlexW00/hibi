import CoreGraphics
import Testing
@testable import Hibi

/// Bake-cache tests for `PaperFieldBaker`, mirroring `StampCompositorCacheTests`'s
/// disk-round-trip pattern and adding the distinct-key and noise-presence guarantees.
///
/// Because the bake is pure CoreGraphics (CPU fBm), it runs headless — so these test
/// the **real** bake, not a key-lookup stub. The variance assertion is the headless
/// "the texture actually carries noise, not a flat fill" guarantee.
///
/// `.serialized`: tests share the static memory cache and one test calls
/// `_test_clearMemoryCache()`; running them in parallel could clear the cache between
/// the two `bakedField` calls in `sameKeyReturnsCachedHit` and flake the `===` check.
@Suite(.serialized)
struct PaperFieldBakerCacheTests {

    // MARK: - Helpers

    /// Mean and variance of the red channel of a baked field (proxy for luminance
    /// modulation). Returns (mean01, variance) with channel values normalized to 0…1.
    private func redStats(_ image: CGImage) -> (mean: Double, variance: Double) {
        let w = image.width, h = image.height
        let bytesPerRow = w * 4
        var bytes = [UInt8](repeating: 0, count: h * bytesPerRow)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var sum = 0.0
        let n = w * h
        for i in 0 ..< n { sum += Double(bytes[i * 4]) / 255.0 }
        let mean = sum / Double(n)
        var varSum = 0.0
        for i in 0 ..< n {
            let v = Double(bytes[i * 4]) / 255.0
            varSum += (v - mean) * (v - mean)
        }
        return (mean, varSum / Double(n))
    }

    // MARK: - Tests

    @Test func bakedFieldIsCachedAndReadableFromDisk() {
        let px = 96
        guard let image = PaperFieldBaker.bakedField(
            texture: .linen, tint: .cream, scheme: .light, px: px
        ) else {
            Issue.record("Bake returned nil")
            return
        }
        #expect(image.width == px)
        #expect(image.height == px)

        // Clear memory so the next lookup must hit disk — a torn write would nil here.
        PaperFieldBaker._test_clearMemoryCache()

        let key = PaperFieldBaker.Key(textureRaw: PaperTexture.linen.rawValue,
                                      tintRaw: PaperTint.cream.rawValue,
                                      scheme: PaperFieldBaker.Scheme.light.rawValue, px: px)
        let cached = PaperFieldBaker.cachedField(key)
        #expect(cached != nil, "Disk-cached field must be readable")
        #expect(cached?.width == image.width)
        #expect(cached?.height == image.height)
    }

    @Test func sameKeyReturnsCachedHit() {
        let px = 64
        let first = PaperFieldBaker.bakedField(texture: .kraft, tint: .sage, scheme: .dark, px: px)
        let second = PaperFieldBaker.bakedField(texture: .kraft, tint: .sage, scheme: .dark, px: px)
        #expect(first != nil && second != nil)
        // Identity: a memory-cache hit returns the *same* CGImage instance.
        #expect(first === second)
    }

    @Test func differentTextureTintSchemeProduceDistinctEntries() {
        let px = 64
        let base   = PaperFieldBaker.bakedField(texture: .linen, tint: .cream, scheme: .light, px: px)
        let altTex = PaperFieldBaker.bakedField(texture: .kraft, tint: .cream, scheme: .light, px: px)
        let altTint = PaperFieldBaker.bakedField(texture: .linen, tint: .blush, scheme: .light, px: px)
        let altScheme = PaperFieldBaker.bakedField(texture: .linen, tint: .cream, scheme: .dark, px: px)

        #expect(base != nil && altTex != nil && altTint != nil && altScheme != nil)
        // Distinct keys → distinct cached instances.
        #expect(base !== altTex)
        #expect(base !== altTint)
        #expect(base !== altScheme)
    }

    @Test func differentTintProducesDifferentBaseTone() {
        let px = 64
        guard let cream = PaperFieldBaker.bakedField(texture: .smooth, tint: .cream, scheme: .light, px: px),
              let sky = PaperFieldBaker.bakedField(texture: .smooth, tint: .sky, scheme: .light, px: px)
        else { Issue.record("Bake returned nil"); return }
        // Cream and Sky differ in base tone → mean red channel should differ.
        let creamMean = redStats(cream).mean
        let skyMean = redStats(sky).mean
        #expect(abs(creamMean - skyMean) > 0.01)
    }

    @Test func bakedFieldCarriesNoiseVariance() {
        // The load-bearing "not a flat placeholder" guarantee: a textured paper (linen)
        // must have measurable luminance variance — i.e. the fBm is actually present.
        let px = 128
        guard let linen = PaperFieldBaker.bakedField(
            texture: .linen, tint: .cream, scheme: .light, px: px
        ) else { Issue.record("Bake returned nil"); return }

        let variance = redStats(linen).variance
        // Low single-digit % luminance modulation → small but strictly positive variance.
        #expect(variance > 1e-6, "Baked texture must carry noise, not be a flat fill")
        // Sanity ceiling: contrast must stay subtle (not a loud high-contrast pattern).
        #expect(variance < 0.02, "Baked texture contrast must stay low (subtle, not loud)")
    }

    @Test func zeroSizeReturnsNil() {
        #expect(PaperFieldBaker.bakedField(texture: .smooth, tint: .cream, scheme: .light, px: 0) == nil)
    }
}
