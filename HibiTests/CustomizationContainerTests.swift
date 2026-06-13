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

    /// Forward-compat: a future client writes rawValue 99 (unknown enum case).
    /// An older client fetching that record must coalesce to the default — no crash, no silent drop.
    @Test func unknownTextureRawCoalescesToDefault() throws {
        let c = try memoryContainer()
        let ctx = c.mainContext
        let style = PaperStyle()
        ctx.insert(style)
        try ctx.save()

        // Simulate a future client having written an unknown raw value into the column.
        style.textureRaw = 99
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PaperStyle>())
        #expect(fetched.count == 1)
        // Unknown raw must coalesce to .smooth — the computed accessor ?? fallback.
        #expect(fetched.first?.texture == .smooth)
        // Raw stored value is preserved as-is (we don't mutate it back).
        #expect(fetched.first?.textureRaw == 99)
    }

    /// Forward-compat: same coalescing guarantee for StructuralWidget.kindRaw.
    @Test func unknownKindRawCoalescesToDefault() throws {
        let c = try memoryContainer()
        let ctx = c.mainContext
        let widget = StructuralWidget()
        ctx.insert(widget)
        try ctx.save()

        widget.kindRaw = 99
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<StructuralWidget>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.kind == .dayNumber)
        #expect(fetched.first?.kindRaw == 99)
    }
}
