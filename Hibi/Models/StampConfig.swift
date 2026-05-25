import CoreGraphics
import Foundation

struct StampDateRegion: Codable {
    let center: [CGFloat]       // [x, y] normalized 0..1
    let size: [CGFloat]         // [w, h] normalized 0..1
    let rotation: CGFloat       // degrees, positive = clockwise
    let fontStyle: String       // "noto-serif" | "noto-sans"
    let fontSize: CGFloat       // normalized to image height
    let format: String          // e.g. "{era}{year}年{month}月{day}日"

    // Optional with defaults per EDITOR.md §2 backward-compat
    let fontWeight: Int?
    let letterSpacing: CGFloat?
    let lineSpacing: CGFloat?

    var resolvedFontWeight: Int { fontWeight ?? 900 }
    var resolvedLetterSpacing: CGFloat { letterSpacing ?? 0 }
    var resolvedLineSpacing: CGFloat { lineSpacing ?? 0 }

    var centerX: CGFloat { center[0] }
    var centerY: CGFloat { center[1] }
}

struct StampDefinition: Codable {
    let stampId: String
    let dateRegion: StampDateRegion
}

enum StampConfig {
    private static let definitions: [StampDefinition] = {
        guard let url = Bundle.main.url(forResource: "stamps", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let defs = try? JSONDecoder().decode([StampDefinition].self, from: data)
        else { return [] }
        return defs
    }()

    static func definition(for seed: UInt64) -> StampDefinition? {
        guard !definitions.isEmpty else { return nil }
        let index = Int(seed % UInt64(definitions.count))
        return definitions[index]
    }

    // MARK: - Japanese era date

    private static let japaneseCalendar: Calendar = {
        var cal = Calendar(identifier: .japanese)
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }()

    static func formatDate(_ date: Date, format: String) -> String {
        let comps = japaneseCalendar.dateComponents([.era, .year, .month, .day], from: date)
        let eraSymbols = japaneseCalendar.eraSymbols
        let eraName = (comps.era.flatMap { $0 < eraSymbols.count ? eraSymbols[$0] : nil }) ?? "令和"
        let year = comps.year ?? 1
        let month = comps.month ?? 1
        let day = comps.day ?? 1

        return format
            .replacingOccurrences(of: "{era}", with: eraName)
            .replacingOccurrences(of: "{year}", with: "\(year)")
            .replacingOccurrences(of: "{month}", with: "\(month)")
            .replacingOccurrences(of: "{day}", with: "\(day)")
    }

    // MARK: - Seed

    /// Placeholder seed derived from the purchase date.
    /// TODO: Replace with IAP Transaction UUID once StoreKit 2 is wired up.
    ///
    /// The packed date value can exceed 2^24 (~16.7M), but `Float` only
    /// represents integers exactly up to 2^24. We hash through a Wang hash
    /// and mask to 24 bits so the value round-trips through `.float()` losslessly.
    static func seed(from date: Date) -> UInt64 {
        let packed = UInt64(date.timeIntervalSince1970)
        // Wang hash — decorrelates sequential dates, keeps range ≤ 2^24
        var s = UInt32(packed & 0xFFFFFFFF)
        s = (s ^ 61) ^ (s >> 16)
        s &*= 9
        s = s ^ (s >> 4)
        s &*= 0x27d4eb2d
        s = s ^ (s >> 15)
        return UInt64(s & 0x00FFFFFF) // mask to 24 bits for Float safety
    }
}
