import Foundation

/// Identifiers for the single Hibi Plus in-app purchase.
///
/// One non-consumable unlocks every Plus perk (extra app icons, the
/// personalized stamp, home-screen widgets). The identifier must match the
/// product configured in App Store Connect and in `Hibi.storekit`.
enum PlusProduct {
    static let id = "com.weichart.hibi.plus"
}

/// App-Group-backed mirror of the Hibi Plus entitlement.
///
/// `PlusStore` (app target, StoreKit) is the source of truth: it writes here
/// whenever the verified entitlement changes. The widget extension — which
/// can't run a purchase flow — reads this synchronously to decide whether to
/// show the locked overlay. Both sides share the same App Group suite, so a
/// purchase in the app is visible to the widget after a timeline reload.
///
/// `defaults` is injectable so the unlock logic can be unit-tested against an
/// isolated suite instead of the real shared store.
struct PlusEntitlementStore {
    static let entitledKey = "hibiPlusEntitled.v1"
    static let purchaseDateKey = "hibiPlusPurchaseDate.v1"
    static let seedUUIDKey = "hibiPlusStampSeedUUID.v1"

    let defaults: UserDefaults?

    init(defaults: UserDefaults? = AppGroup.defaults) {
        self.defaults = defaults
    }

    var isPlus: Bool {
        defaults?.bool(forKey: Self.entitledKey) ?? false
    }

    /// The date the entitlement was first granted. Shown as the dated text on
    /// the stamp. `nil` until a purchase is recorded.
    var purchaseDate: Date? {
        defaults?.object(forKey: Self.purchaseDateKey) as? Date
    }

    /// Stable UUID that seeds the stamp's design and ink noise (the StoreKit
    /// transaction's `appAccountToken`, or a deterministic fallback). Cached
    /// here so the stamp renders identically across launches without
    /// re-querying StoreKit. `nil` until a purchase is recorded.
    var seedUUID: UUID? {
        guard let raw = defaults?.string(forKey: Self.seedUUIDKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func setIsPlus(_ value: Bool) {
        defaults?.set(value, forKey: Self.entitledKey)
    }

    func setPurchaseDate(_ date: Date?) {
        if let date {
            defaults?.set(date, forKey: Self.purchaseDateKey)
        } else {
            defaults?.removeObject(forKey: Self.purchaseDateKey)
        }
    }

    func setSeedUUID(_ uuid: UUID?) {
        if let uuid {
            defaults?.set(uuid.uuidString, forKey: Self.seedUUIDKey)
        } else {
            defaults?.removeObject(forKey: Self.seedUUIDKey)
        }
    }
}
