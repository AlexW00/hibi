import Testing
import Foundation
@testable import Hibi

struct CustomizationDedupTests {
    @Test func dateKeyFromCivilComponents() {
        #expect(CustomizationDateKey.make(year: 2026, month: 6, day: 13) == "2026-06-13")
        #expect(CustomizationDateKey.make(year: 2026, month: 12, day: 1) == "2026-12-01")
    }

    @Test func orderedByZIndexSortsStably() {
        let items = [Z(id: "a", z: 2), Z(id: "b", z: 0), Z(id: "c", z: 2), Z(id: "d", z: 1)]
        let ordered = orderedByZIndex(items, id: \.id, zIndex: \.z).map(\.id)
        #expect(ordered == ["b", "d", "a", "c"])   // z asc, ties broken by id asc → deterministic
    }

    @Test func singletonSurvivorIsNewestThenStableID() {
        let rows = [
            DedupRow(id: "x", updatedAt: Date(timeIntervalSince1970: 100)),
            DedupRow(id: "y", updatedAt: Date(timeIntervalSince1970: 200)),
            DedupRow(id: "z", updatedAt: Date(timeIntervalSince1970: 200)), // tie with y
        ]
        let r = resolveDedup(rows, id: \.id, updatedAt: \.updatedAt)
        #expect(r.survivorID == "z")          // newest; tie → larger id "z" > "y" (deterministic rule)
        #expect(Set(r.casualtyIDs) == ["x", "y"])
    }

    // local helpers
    struct Z { let id: String; let z: Int }
    struct DedupRow { let id: String; let updatedAt: Date? }
}
