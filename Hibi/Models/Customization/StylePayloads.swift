import Foundation

/// Versioned Codable envelopes stored as Data in `stylePayload`. ALL fields optional →
/// old blobs decode, new fields default. Never remove/retype a field; only append optionals.
protocol StylePayload: Codable { var v: Int { get } }
extension StylePayload {
    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    init(data: Data) throws { self = try JSONDecoder().decode(Self.self, from: data) }
}

struct PaperStylePayload: StylePayload { var v = 1; var grainIntensity: Double? }
struct WidgetStylePayload: StylePayload { var v = 1; var colorToken: Int?; var fontToken: Int?; var sizeToken: Int? }
struct TextStylePayload: StylePayload {
    var v = 1
    var font: String?
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?
    var effect: Int?       // none/background/outline token (Stage 6)
    var colorToken: Int?  // AdaptivePalette token (Stage 6)
}
struct StickerStylePayload: StylePayload { var v = 1; var finish: Int?; var intensity: Double? }   // Stage 8/9
struct PlacedStickerPayload: StylePayload { var v = 1; var finishOverride: Int? }                  // reserved
