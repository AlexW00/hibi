import Testing
@testable import Hibi

struct CustomizationTokensTests {
    @Test func enumRawValuesArePinned() {
        // APPEND-ONLY contract: these numbers must never change.
        #expect(PaperTexture.smooth.rawValue == 0)
        #expect(PaperTexture.linen.rawValue == 1)
        #expect(PaperTexture.kraft.rawValue == 2)
        #expect(PaperTexture.news.rawValue == 3)
        #expect(PaperTexture.vellum.rawValue == 4)
        #expect(PaperRuling.plain.rawValue == 0)
        #expect(PaperRuling.lines.rawValue == 1)
        #expect(PaperRuling.grid.rawValue == 2)
        #expect(PaperRuling.dots.rawValue == 3)
        #expect(PaperTint.cream.rawValue == 0)
        #expect(PaperTint.blush.rawValue == 1)
        #expect(PaperTint.sky.rawValue == 2)
        #expect(PaperTint.sage.rawValue == 3)
        #expect(PaperTint.butter.rawValue == 4)
        #expect(PaperTint.lilac.rawValue == 5)
        #expect(StructuralWidgetKind.dayNumber.rawValue == 0)
        #expect(StructuralWidgetKind.weekday.rawValue == 1)
        #expect(StructuralWidgetKind.month.rawValue == 2)
        #expect(StructuralWidgetKind.year.rawValue == 3)
        #expect(StructuralWidgetKind.weather.rawValue == 4)
        #expect(StructuralWidgetKind.sunrise.rawValue == 5)
        #expect(StructuralWidgetKind.sunset.rawValue == 6)
    }
    @Test func unknownRawDecodesToDefault() {
        #expect(PaperTexture(rawValue: 99) == nil) // callers coalesce to .smooth
    }
}
