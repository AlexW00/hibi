import Foundation
import SwiftData

@MainActor @Observable
final class CustomizationStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    /// Global paper style (deduped singleton). Creates one if none exists.
    func paperStyle() throws -> PaperStyle {
        let all = try context.fetch(FetchDescriptor<PaperStyle>())
        if all.isEmpty {
            let s = PaperStyle(); s.updatedAt = .now
            context.insert(s); try context.save()
            return s
        }
        if all.count == 1 { return all[0] }
        // Dedup: keep convergent survivor, delete the rest.
        // Uses PersistentIdentifier directly (Comparable, per-record unique) rather than
        // storeIdentifier (which is store-scoped and shared by all rows in the same store).
        let r = resolveDedup(all, id: { $0.persistentModelID }, updatedAt: { $0.updatedAt })
        let survivor = all.first { $0.persistentModelID == r.survivorID } ?? all[0]
        for s in all where s !== survivor { context.delete(s) }
        try context.save()
        return survivor
    }

    /// Fetch (deduped+merged) DayCustomization for a date key, or create one.
    func fetchOrCreateDay(dateKey: String) throws -> DayCustomization {
        let pred = #Predicate<DayCustomization> { $0.dateKey == dateKey }
        let matches = try context.fetch(FetchDescriptor<DayCustomization>(predicate: pred))
        if matches.isEmpty {
            let d = DayCustomization(dateKey: dateKey); d.updatedAt = .now
            context.insert(d); try context.save()
            return d
        }
        if matches.count == 1 { return matches[0] }
        return try mergeDays(matches)
    }

    /// MERGE same-date rows: reparent children onto survivor (union), LWW the ink blob, delete casualties.
    private func mergeDays(_ days: [DayCustomization]) throws -> DayCustomization {
        // Uses PersistentIdentifier directly (Comparable, per-record unique) rather than
        // storeIdentifier (which is store-scoped and shared by all rows in the same store).
        let r = resolveDedup(days, id: { $0.persistentModelID }, updatedAt: { $0.updatedAt })
        let survivor = days.first { $0.persistentModelID == r.survivorID } ?? days[0]
        for d in days where d !== survivor {
            for p in (d.placedStickers ?? []) { p.day = survivor }
            for t in (d.textObjects ?? []) { t.day = survivor }
            // inkStrokes can't auto-merge → survivor's blob already wins (LWW). Casualty's ink is dropped.
            context.delete(d)
        }
        try context.save()
        return survivor
    }
}
