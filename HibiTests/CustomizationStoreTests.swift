import Testing
import Foundation
import SwiftData
@testable import Hibi

@MainActor
struct CustomizationStoreTests {
    private func makeStore() throws -> (CustomizationStore, ModelContext) {
        let container = try CustomizationContainer.make(inMemory: true, cloudKit: false)
        let ctx = container.mainContext
        return (CustomizationStore(context: ctx), ctx)
    }

    // MARK: - Day merge

    /// Two DayCustomization rows with the same dateKey and equal updatedAt must:
    /// - collapse to exactly one survivor (larger recordUUID wins tie)
    /// - reparent ALL children (union, nothing lost via cascade)
    @Test func dayMergePicksLargerRecordUUIDAndUnionsChildren() throws {
        let (store, ctx) = try makeStore()
        let ts = Date(timeIntervalSince1970: 1_000_000) // identical timestamp → forces recordUUID tie-break

        // "aaa" < "bbb", so "bbb" is the expected survivor.
        let dayA = DayCustomization(dateKey: "2026-06-13")
        dayA.recordUUID = "aaa"
        dayA.updatedAt = ts

        let dayB = DayCustomization(dateKey: "2026-06-13")
        dayB.recordUUID = "bbb"
        dayB.updatedAt = ts

        // Child on the CASUALTY ("aaa") — reparenting must save it from cascade delete.
        let sticker = Sticker()
        let placed = PlacedSticker()
        placed.day = dayA
        placed.sticker = sticker
        placed.zIndex = 1

        // Child on the SURVIVOR ("bbb") — must remain untouched.
        let text = TextObject()
        text.day = dayB
        text.text = "hello"
        text.zIndex = 2

        ctx.insert(dayA)
        ctx.insert(dayB)
        ctx.insert(sticker)
        ctx.insert(placed)
        ctx.insert(text)
        try ctx.save()

        // Act: fetchOrCreateDay deduplicates and merges.
        let result = try store.fetchOrCreateDay(dateKey: "2026-06-13")

        // Exactly one DayCustomization must remain.
        let allDays = try ctx.fetch(FetchDescriptor<DayCustomization>())
        #expect(allDays.count == 1)

        // Survivor must be "bbb" (larger recordUUID wins the equal-timestamp tie).
        #expect(result.recordUUID == "bbb")

        // Both children must be reparented onto the survivor (union — nothing lost).
        #expect(result.placedStickers?.count == 1)
        #expect(result.textObjects?.count == 1)
    }

    // MARK: - PaperStyle dedup

    /// Two PaperStyle rows must collapse to exactly one survivor.
    @Test func paperStyleDedupLeavesExactlyOneRow() throws {
        let (store, ctx) = try makeStore()

        let s1 = PaperStyle(); s1.recordUUID = "aaa"; s1.updatedAt = Date(timeIntervalSince1970: 1)
        let s2 = PaperStyle(); s2.recordUUID = "bbb"; s2.updatedAt = Date(timeIntervalSince1970: 2)
        ctx.insert(s1)
        ctx.insert(s2)
        try ctx.save()

        // Act: paperStyle() deduplicates.
        _ = try store.paperStyle()

        // Exactly one PaperStyle must remain.
        let allStyles = try ctx.fetch(FetchDescriptor<PaperStyle>())
        #expect(allStyles.count == 1)
    }
}
