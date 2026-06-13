import Foundation

enum SyncStatusPhrase: Equatable {
    case justNow, fewMinutes, fewHours, fewDays, aWhile, never
}

enum SyncStatus {
    /// Coarse relative bucket for "last synced". Elapsed = now - lastSync.
    /// Negative elapsed (clock skew, lastSync in the future) collapses to .justNow
    /// because elapsed < 60 is true for any negative value.
    static func phrase(lastSync: Date?, now: Date) -> SyncStatusPhrase {
        guard let lastSync else { return .never }
        let elapsed = now.timeIntervalSince(lastSync)
        if elapsed < 60      { return .justNow }
        if elapsed < 3_600   { return .fewMinutes }
        if elapsed < 86_400  { return .fewHours }
        if elapsed < 604_800 { return .fewDays }
        return .aWhile
    }
}
