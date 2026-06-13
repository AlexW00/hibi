import Foundation
import SwiftData

@Model
final class PaperStyle {
    var recordUUID: String = UUID().uuidString
    var textureRaw: Int = PaperTexture.smooth.rawValue
    var rulingRaw: Int = PaperRuling.plain.rawValue
    var tintRaw: Int = PaperTint.cream.rawValue
    var stylePayload: Data?
    var updatedAt: Date?
    init() {}
    var texture: PaperTexture {
        get { PaperTexture(rawValue: textureRaw) ?? .smooth }
        set { textureRaw = newValue.rawValue }
    }
    var ruling: PaperRuling {
        get { PaperRuling(rawValue: rulingRaw) ?? .plain }
        set { rulingRaw = newValue.rawValue }
    }
    var tint: PaperTint {
        get { PaperTint(rawValue: tintRaw) ?? .cream }
        set { tintRaw = newValue.rawValue }
    }
}

@Model
final class StructuralWidget {
    var recordUUID: String = UUID().uuidString
    var kindRaw: Int = StructuralWidgetKind.dayNumber.rawValue
    var formatVariant: Int = 0
    var x: Double = 0
    var y: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var updatedAt: Date?
    init() {}
    var kind: StructuralWidgetKind {
        get { StructuralWidgetKind(rawValue: kindRaw) ?? .dayNumber }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class DayCustomization {
    var recordUUID: String = UUID().uuidString
    var dateKey: String = ""
    @Attribute(.externalStorage) var inkStrokes: Data?
    var stylePayload: Data?
    var updatedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \PlacedSticker.day) var placedStickers: [PlacedSticker]?
    @Relationship(deleteRule: .cascade, inverse: \TextObject.day) var textObjects: [TextObject]?
    init(dateKey: String = "") { self.dateKey = dateKey }
}

@Model
final class PlacedSticker {
    var recordUUID: String = UUID().uuidString
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var day: DayCustomization?
    var sticker: Sticker?
    init() {}
}

@Model
final class TextObject {
    var recordUUID: String = UUID().uuidString
    var text: String = ""
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var day: DayCustomization?
    init() {}
}

@Model
final class Sticker {
    var stickerID: String = UUID().uuidString
    var createdAt: Date?
    @Attribute(.externalStorage) var maskedImage: Data?
    var stylePayload: Data?
    var updatedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \PlacedSticker.sticker) var placements: [PlacedSticker]?
    init() {}
}
