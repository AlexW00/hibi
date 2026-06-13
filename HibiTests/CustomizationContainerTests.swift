import Testing
import SwiftData
@testable import Hibi

@MainActor
struct CustomizationContainerTests {
    private func memoryContainer() throws -> ModelContainer {
        try CustomizationContainer.make(inMemory: true, cloudKit: false)
    }

    @Test func containerInitializesOfflineWithoutAccount() throws {
        // cloudKit: false + inMemory proves offline-first shape validity (no account needed).
        _ = try memoryContainer()
    }

    @Test func insertAndFetchPaperStyle() throws {
        let c = try memoryContainer()
        let ctx = c.mainContext
        let style = PaperStyle(); style.tint = .sky
        ctx.insert(style); try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PaperStyle>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.tint == .sky)
    }

    @Test func dayWithChildrenWiresRelationships() throws {
        let c = try memoryContainer()
        let ctx = c.mainContext
        let day = DayCustomization(dateKey: "2026-06-13")
        let sticker = Sticker()
        let placed = PlacedSticker(); placed.day = day; placed.sticker = sticker; placed.zIndex = 1
        let text = TextObject(); text.day = day; text.text = "hi"; text.zIndex = 2
        ctx.insert(day); ctx.insert(sticker); ctx.insert(placed); ctx.insert(text)
        try ctx.save()
        let days = try ctx.fetch(FetchDescriptor<DayCustomization>())
        #expect(days.first?.placedStickers?.count == 1)
        #expect(days.first?.textObjects?.count == 1)
        #expect(placed.sticker === sticker)
    }
}
