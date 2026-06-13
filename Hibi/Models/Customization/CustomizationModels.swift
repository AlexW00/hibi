import Foundation
import SwiftData

@Model
final class PaperStyle {
    var recordUUID: String = UUID().uuidString
    var texture: PaperTexture = PaperTexture.smooth
    var ruling: PaperRuling = PaperRuling.plain
    var tint: PaperTint = PaperTint.cream
    var stylePayload: Data?
    var updatedAt: Date?
    init() {}
}

@Model
final class StructuralWidget {
    var kind: StructuralWidgetKind = StructuralWidgetKind.dayNumber
    var formatVariant: Int = 0
    var x: Double = 0
    var y: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var updatedAt: Date?
    init() {}
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
