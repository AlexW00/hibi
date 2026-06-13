import SwiftUI

extension PaperFieldBaker {

    /// Returns the baked paper field as a SwiftUI `Image` (decorative), generating +
    /// caching on a miss. `nil` only if `px <= 0` or the CoreGraphics bake fails.
    ///
    /// `scale` should be the caller's display scale so 1 image point maps to `scale`
    /// device pixels; `px` is `pointSide × scale` already bucketed by `sizeBucket`.
    static func bakedImage(
        texture: PaperTexture,
        tint: PaperTint,
        scheme: Scheme,
        px: Int,
        displayScale: CGFloat
    ) -> Image? {
        guard let cg = bakedField(texture: texture, tint: tint, scheme: scheme, px: px)
        else { return nil }
        return Image(decorative: cg, scale: displayScale)
    }

    /// Buckets a point dimension to a coarse pixel side so small layout jitter doesn't
    /// thrash the cache (mirrors the spirit of StampCompositor's fixed composite size).
    /// Rounds the *point* side up to the nearest 32pt, then multiplies by scale.
    static func sizeBucket(pointSide: CGFloat, displayScale: CGFloat) -> Int {
        let bucketPt = (ceil(max(pointSide, 1) / 32.0) * 32.0)
        // Cap so a huge layout doesn't bake an enormous bitmap; the field is low-freq,
        // so a moderate cap upsamples cleanly.
        let cappedPt = min(bucketPt, 512)
        return Int(cappedPt * max(displayScale, 1))
    }

    /// Maps a SwiftUI `ColorScheme` to the baker's scheme key.
    static func scheme(for colorScheme: ColorScheme) -> Scheme {
        colorScheme == .dark ? .dark : .light
    }
}
