import Foundation

enum CustomizationDateKey {
    /// Civil-component construction ONLY — never from a Date()+timezone.
    static func make(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Stable visual order from an unordered set + zIndex. Ties broken by id → deterministic/convergent.
func orderedByZIndex<T, ID: Comparable>(_ items: [T], id: (T) -> ID, zIndex: (T) -> Int) -> [T] {
    items.sorted { a, b in
        let za = zIndex(a), zb = zIndex(b)
        return za != zb ? za < zb : id(a) < id(b)
    }
}

struct DedupResult<ID> { let survivorID: ID; let casualtyIDs: [ID] }

/// Convergent survivor pick: newest updatedAt, ties broken by larger stable id.
func resolveDedup<T, ID: Comparable>(_ rows: [T], id: (T) -> ID, updatedAt: (T) -> Date?) -> DedupResult<ID> {
    precondition(!rows.isEmpty)
    let sorted = rows.sorted { a, b in
        let ta = updatedAt(a) ?? .distantPast, tb = updatedAt(b) ?? .distantPast
        if ta != tb { return ta > tb }      // newest first
        return id(a) > id(b)                 // tie → larger id first (deterministic)
    }
    return DedupResult(survivorID: id(sorted[0]), casualtyIDs: sorted.dropFirst().map(id))
}
