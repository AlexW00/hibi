import Foundation

// APPEND-ONLY: never reorder/renumber/reuse. Stored as the raw Int in CloudKit.
enum PaperTexture: Int, Codable, CaseIterable { case smooth = 0, linen = 1, kraft = 2, news = 3, vellum = 4 }
// APPEND-ONLY: never reorder/renumber/reuse.
enum PaperRuling: Int, Codable, CaseIterable { case plain = 0, lines = 1, grid = 2, dots = 3 }
// APPEND-ONLY: never reorder/renumber/reuse.
enum PaperTint: Int, Codable, CaseIterable { case cream = 0, blush = 1, sky = 2, sage = 3, butter = 4, lilac = 5 }
// APPEND-ONLY: never reorder/renumber/reuse.
enum StructuralWidgetKind: Int, Codable, CaseIterable {
    case dayNumber = 0, weekday = 1, month = 2, year = 3, weather = 4, sunrise = 5, sunset = 6
}
