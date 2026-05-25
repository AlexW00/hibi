import CoreGraphics
import CoreText
import UIKit

enum StampCompositor {
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

        // Push ctx onto UIKit's stack so UIImage.draw can find it.
        // UIImage.draw is CTM-aware and renders right-side-up in our y-flipped context.
        // Raw CGContext.draw would flip the mask (CG's bottom-left-origin convention).
        UIGraphicsPushContext(ctx)
        UIImage(cgImage: maskImage).draw(in: CGRect(x: 0, y: 0, width: px, height: px))
        UIGraphicsPopContext()

        // Draw date text on top
        drawDateText(
            in: ctx,
            definition: definition,
            date: date,
            imageSize: CGFloat(px)
        )

        // Apply fine grain to all inked pixels.
        // Mask PNGs already have some texture; this adds matching grain to
        // the clean CoreText-rendered date text.
        applyGrain(ctx: ctx, width: px, height: px)

        return ctx.makeImage()
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

    private static func applyGrain(ctx: CGContext, width: Int, height: Int) {
        guard let data = ctx.data else { return }
        let buf = data.assumingMemoryBound(to: UInt8.self)
        let rowBytes = ctx.bytesPerRow

        for y in 0..<height {
            for x in 0..<width {
                let i = y * rowBytes + x * 4
                let r = buf[i]
                guard r > 10 else { continue }

                var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263)
                h = (h ^ (h >> 13)) &* 1274126177
                h = h ^ (h >> 16)
                let t = Float(h & 0xFFFF) / 65535.0

                let v = UInt8(Float(r) * (0.82 + t * 0.18))
                buf[i] = v
                buf[i + 1] = v
                buf[i + 2] = v
            }
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
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
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
