import CoreGraphics
import CoreText
import Foundation
import ImageIO

nonisolated enum StampCompositor {
    // MARK: - Cache

    private static let memoryCache = NSCache<NSString, CGImageWrapper>()

    private final class CGImageWrapper {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private static func cacheKey(stampId: String, date: Date, px: Int) -> NSString {
        NSString(string: "\(stampId)-\(Int(date.timeIntervalSince1970))-\(px)")
    }

    private static var diskCacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("StampComposites", isDirectory: true)
    }

    private static func diskURL(stampId: String, date: Date, px: Int) -> URL? {
        guard let dir = diskCacheDirectory else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(stampId)-\(Int(date.timeIntervalSince1970))-\(px).png")
    }

    /// Fast synchronous lookup: memory cache → disk cache. Returns nil on miss.
    static func cachedComposite(
        definition: StampDefinition,
        date: Date,
        outputSize: CGFloat,
        scale: CGFloat
    ) -> CGImage? {
        let px = Int(outputSize * scale)
        guard px > 0 else { return nil }

        let key = cacheKey(stampId: definition.stampId, date: date, px: px)
        if let hit = memoryCache.object(forKey: key) { return hit.image }

        guard let url = diskURL(stampId: definition.stampId, date: date, px: px),
              let provider = CGDataProvider(url: url as CFURL),
              let image = CGImage(pngDataProviderSource: provider,
                                  decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent)
        else { return nil }

        memoryCache.setObject(CGImageWrapper(image), forKey: key)
        return image
    }

    private static func persistToDisk(_ image: CGImage, stampId: String, date: Date, px: Int) {
        guard let url = diskURL(stampId: stampId, date: date, px: px),
              let dest = CGImageDestinationCreateWithURL(
                  url as CFURL, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    // MARK: - Composite

    /// Rasterizes a stamp's mask + date text into a single composite CGImage.
    /// The image is grayscale ink-coverage: 0 = no ink (paper), 1 = full ink.
    /// Output dimensions = `outputSize` in points × `scale`.
    ///
    /// Returns nil if the mask PNG or font can't be loaded.
    static func composite(
        definition: StampDefinition,
        date: Date,
        outputSize: CGFloat,
        scale: CGFloat
    ) -> CGImage? {
        let px = Int(outputSize * scale)
        guard px > 0 else { return nil }

        let key = cacheKey(stampId: definition.stampId, date: date, px: px)
        if let cached = memoryCache.object(forKey: key) { return cached.image }

        // Load mask PNG
        guard let maskImage = loadMask(stampId: definition.stampId) else { return nil }

        // Create RGBA context (we write grayscale values into RGB channels)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: px, height: px,
            bitsPerComponent: 8,
            bytesPerRow: px * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Flip to y-down (UIKit/CoreText convention, matches stamps.json origin=top-left)
        ctx.translateBy(x: 0, y: CGFloat(px))
        ctx.scaleBy(x: 1, y: -1)

        // Draw mask using pure CoreGraphics (safe for background threads,
        // unlike UIGraphicsPushContext / UIImage.draw which require the main
        // thread). Temporarily undo the y-flip so CGContext.draw renders the
        // mask right-side-up (CG.draw assumes a y-up coordinate system).
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(px))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(maskImage, in: CGRect(x: 0, y: 0, width: px, height: px))
        ctx.restoreGState()

        // Draw date text on top
        drawDateText(
            in: ctx,
            definition: definition,
            date: date,
            imageSize: CGFloat(px)
        )

        // Bake a signed distance field into the green channel. The stamp
        // shader reads it to drive edge effects (rim darkening, bleed,
        // boundary roughness). R stays raw coverage; the SDF is computed from
        // the final mask+text coverage so text edges get stamped too.
        bakeSDF(ctx: ctx, width: px, height: px)

        guard let image = ctx.makeImage() else { return nil }
        memoryCache.setObject(CGImageWrapper(image), forKey: key)
        persistToDisk(image, stampId: definition.stampId, date: date, px: px)
        return image
    }

    private static func loadMask(stampId: String) -> CGImage? {
        let url = Bundle.main.url(forResource: stampId, withExtension: "png", subdirectory: "StampMasks")
                ?? Bundle.main.url(forResource: stampId, withExtension: "png")
        guard let url, let provider = CGDataProvider(url: url as CFURL) else { return nil }
        return CGImage(
            pngDataProviderSource: provider,
            decode: nil, shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func drawDateText(
        in ctx: CGContext,
        definition: StampDefinition,
        date: Date,
        imageSize: CGFloat
    ) {
        let region = definition.dateRegion

        // Resolve pixel-space values per EDITOR.md §7.1
        let fontPx = region.fontSize * imageSize
        let letterSpacingPx = region.resolvedLetterSpacing * imageSize
        let lineSpacingPx = region.resolvedLineSpacing * imageSize
        let lineAdvance = fontPx + lineSpacingPx
        let cx = region.centerX * imageSize
        let cy = region.centerY * imageSize

        // Create CTFont — weight 900 = NotoSerifJP-Black
        let fontName: String
        switch region.resolvedFontWeight {
        case 900: fontName = AppFont.serifJPBlack
        default:  fontName = AppFont.serifJP
        }
        guard let ctFont = CTFontCreateWithName(fontName as CFString, fontPx, nil) as CTFont? else { return }

        // Format the date string and split into lines
        let formatted = StampConfig.formatDate(date, format: region.format)
        let lines = formatted.components(separatedBy: "\n")

        // White color for ink-coverage drawing (mask is grayscale;
        // white = full coverage, drawn on top of the mask)
        let inkColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        // Apply rotation around center per EDITOR.md §7.6
        let rotRad = region.rotation * .pi / 180
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: -rotRad) // negated because context is y-flipped

        // Vertically center the multi-line block around (0, 0)
        // per EDITOR.md §7.3
        let blockHeight = CGFloat(lines.count - 1) * lineAdvance
        let firstLineCY = -blockHeight / 2

        for (i, line) in lines.enumerated() {
            let lineCY = firstLineCY + CGFloat(i) * lineAdvance
            drawLine(
                line,
                in: ctx,
                font: ctFont,
                centerX: 0,
                centerY: lineCY,
                letterSpacingPx: letterSpacingPx,
                color: inkColor
            )
        }

        ctx.restoreGState()
    }

    /// Normalized half-range used to encode the SDF into the green channel.
    /// MUST match `SDF_RANGE` in StampShader.metal. The shader decodes
    /// `sd = (g - 0.5) * 2 * sdfRange` as a fraction of the image dimension.
    static let sdfRange: Float = 0.06

    /// Computes a signed distance field from the R-channel coverage and writes
    /// it into the G channel (inside > 0.5, boundary = 0.5, outside < 0.5).
    private static func bakeSDF(ctx: CGContext, width: Int, height: Int) {
        guard let data = ctx.data else { return }
        let buf = data.assumingMemoryBound(to: UInt8.self)
        let rowBytes = ctx.bytesPerRow
        let n = width * height

        var inside = [Bool](repeating: false, count: n)
        for y in 0..<height {
            for x in 0..<width {
                inside[y * width + x] = buf[y * rowBytes + x * 4] >= 128
            }
        }

        let distToPaper = edt2d(mask: inside, width: width, height: height, target: false)
        let distToInk = edt2d(mask: inside, width: width, height: height, target: true)

        let maxDim = Float(max(width, height))
        let denom = 2.0 * sdfRange
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let sdPx = inside[idx] ? distToPaper[idx] : -distToInk[idx]
                let g = max(0.0, min(1.0, 0.5 + (sdPx / maxDim) / denom))
                buf[y * rowBytes + x * 4 + 1] = UInt8(g * 255.0)
            }
        }
    }

    /// Exact Euclidean distance (in pixels) to the nearest pixel whose
    /// `inside` flag equals `target`, via separable Felzenszwalb–Huttenlocher.
    private static func edt2d(mask: [Bool], width w: Int, height h: Int, target: Bool) -> [Float] {
        let inf: Float = 1e20
        var f = [Float](repeating: 0, count: w * h)
        for i in f.indices { f[i] = (mask[i] == target) ? 0 : inf }

        let maxLen = max(w, h)
        var line = [Float](repeating: 0, count: maxLen)
        var d = [Float](repeating: 0, count: maxLen)
        var v = [Int](repeating: 0, count: maxLen)
        var z = [Float](repeating: 0, count: maxLen + 1)

        for x in 0..<w {
            for y in 0..<h { line[y] = f[y * w + x] }
            dt1d(line, h, &d, &v, &z)
            for y in 0..<h { f[y * w + x] = d[y] }
        }
        for y in 0..<h {
            let base = y * w
            for x in 0..<w { line[x] = f[base + x] }
            dt1d(line, w, &d, &v, &z)
            for x in 0..<w { f[base + x] = d[x] }
        }
        for i in f.indices { f[i] = f[i].squareRoot() }
        return f
    }

    /// 1D squared-distance transform of `f[0..<n]`, result written to `d`.
    /// `v` and `z` are reusable scratch buffers.
    private static func dt1d(_ f: [Float], _ n: Int,
                             _ d: inout [Float], _ v: inout [Int], _ z: inout [Float]) {
        let inf: Float = 1e20
        var k = 0
        v[0] = 0
        z[0] = -inf
        z[1] = inf
        for q in 1..<n {
            var s = ((f[q] + Float(q * q)) - (f[v[k]] + Float(v[k] * v[k]))) / Float(2 * q - 2 * v[k])
            while s <= z[k] {
                k -= 1
                s = ((f[q] + Float(q * q)) - (f[v[k]] + Float(v[k] * v[k]))) / Float(2 * q - 2 * v[k])
            }
            k += 1
            v[k] = q
            z[k] = s
            z[k + 1] = inf
        }
        k = 0
        for q in 0..<n {
            while z[k + 1] < Float(q) { k += 1 }
            let dq = Float(q - v[k])
            d[q] = dq * dq + f[v[k]]
        }
    }

    /// Draws a single line of text centered horizontally at (centerX, centerY),
    /// using per-glyph layout with letter spacing per EDITOR.md §7.4-7.5.
    private static func drawLine(
        _ text: String,
        in ctx: CGContext,
        font: CTFont,
        centerX: CGFloat,
        centerY: CGFloat,
        letterSpacingPx: CGFloat,
        color: CGColor
    ) {
        let chars = Array(text)
        guard !chars.isEmpty else { return }

        // Measure each character's advance width using CTLine
        // Use CoreText attribute keys directly (not UIKit's .font/.foregroundColor)
        // so this code runs safely on background threads without UIKit.
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]

        var advances: [CGFloat] = []
        var ctLines: [CTLine] = []
        for ch in chars {
            let attrStr = NSAttributedString(string: String(ch), attributes: attrs)
            let ctLine = CTLineCreateWithAttributedString(attrStr)
            let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
            advances.append(CGFloat(width))
            ctLines.append(ctLine)
        }

        // Total line width including letter spacing
        let totalWidth = advances.reduce(0, +) + letterSpacingPx * CGFloat(chars.count - 1)
        var x = centerX - totalWidth / 2

        // Baseline: emCenterAboveBaseline = (ascender + descender) / 2
        // Per EDITOR.md §7.5
        let ascender = CTFontGetAscent(font)
        let descender = CTFontGetDescent(font)
        let emCenterAboveBaseline = (ascender - descender) / 2
        let baselineY = centerY + emCenterAboveBaseline // + because y is flipped

        // CoreText renders relative to ctx.textMatrix. In a y-flipped context
        // (translateBy + scaleBy) the default identity matrix would mirror glyphs.
        // Set textMatrix to counter the flip so glyphs render right-side-up.
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)

        for (i, ctLine) in ctLines.enumerated() {
            ctx.saveGState()
            ctx.textPosition = CGPoint(x: x, y: baselineY)
            CTLineDraw(ctLine, ctx)
            ctx.restoreGState()
            x += advances[i] + letterSpacingPx
        }
    }
}
