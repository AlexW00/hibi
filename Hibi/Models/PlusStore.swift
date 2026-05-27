import Foundation
import Observation
import StoreKit
import WidgetKit

/// Owns the Hibi Plus entitlement and the StoreKit 2 purchase flow.
///
/// Source of truth for "is this user Plus?" across the app. On every verified
/// entitlement change it mirrors the result into the shared App Group via
/// `PlusEntitlementStore` and reloads widget timelines, so the locked widget
/// overlay clears the moment a purchase completes.
///
/// `isPlus` is seeded synchronously from the App Group cache in `init` so the
/// UI never flashes a "locked" state on launch for an existing Plus user;
/// `start()` then reconciles against StoreKit's current entitlements.
@Observable
@MainActor
final class PlusStore {
    private(set) var isPlus: Bool
    private(set) var purchaseDate: Date?
    /// Stable UUID that seeds the personalized stamp (see `PlusEntitlementStore`).
    private(set) var seedUUID: UUID?
    private(set) var product: Product?
    private(set) var isPurchasing = false

    /// Localized, ready-to-display price (e.g. "$4.99"). `nil` until the
    /// product loads; the purchase button shows a spinner while it's `nil`
    /// rather than a placeholder, so a wrong-currency price is never shown.
    var displayPrice: String? { product?.displayPrice }

    private let entitlement: PlusEntitlementStore
    private var updatesTask: Task<Void, Never>?

    init(entitlement: PlusEntitlementStore = PlusEntitlementStore()) {
        self.entitlement = entitlement
        self.isPlus = entitlement.isPlus
        self.purchaseDate = entitlement.purchaseDate
        self.seedUUID = entitlement.seedUUID
    }

    /// Begin listening for transaction updates and reconcile current state.
    /// Idempotent — safe to call from `.task` on every appearance.
    func start() {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.handle(update)
                }
            }
        }
        Task { await loadProduct() }
        Task { await refreshEntitlement() }
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [PlusProduct.id])
            product = products.first
        } catch {
            #if DEBUG
            print("[PlusStore] product load failed: \(error)")
            #endif
        }
    }

    /// Recompute the entitlement from StoreKit's current entitlements. This is
    /// what restores a purchase on a new device/reinstall.
    func refreshEntitlement() async {
        var entitled = false
        var date: Date?
        var uuid: UUID?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == PlusProduct.id,
                  transaction.revocationDate == nil else { continue }
            entitled = true
            date = transaction.purchaseDate
            uuid = Self.seedUUID(for: transaction)
        }
        apply(entitled: entitled, date: date, uuid: uuid)
    }

    /// Run the purchase sheet. Returns `true` only on a verified success.
    @discardableResult
    func purchase() async -> Bool {
        guard let product, !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            // Bind a stable UUID to this purchase. StoreKit persists it on the
            // transaction (and returns it via `appAccountToken` on restore /
            // reinstall), so the stamp it seeds stays identical forever.
            let token = entitlement.seedUUID ?? UUID()
            let result = try await product.purchase(options: [.appAccountToken(token)])
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                apply(entitled: true,
                      date: transaction.purchaseDate,
                      uuid: Self.seedUUID(for: transaction) ?? token)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            #if DEBUG
            print("[PlusStore] purchase failed: \(error)")
            #endif
            return false
        }
    }

    /// Ask the App Store to sync transactions (the "Restore Purchases" path),
    /// then re-evaluate the entitlement.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    /// Persist to the App Group and, if the entitlement actually flipped,
    /// publish the change and refresh widgets.
    ///
    /// The purchase date and seed UUID are written *once* and then kept stable
    /// across subsequent refreshes — the stamp's design and dated text must
    /// never change after it's been granted.
    private func apply(entitled: Bool, date: Date?, uuid: UUID?) {
        entitlement.setIsPlus(entitled)
        if entitled {
            let resolvedDate = entitlement.purchaseDate ?? date ?? Date()
            let resolvedUUID = entitlement.seedUUID ?? uuid ?? UUID()
            entitlement.setPurchaseDate(resolvedDate)
            entitlement.setSeedUUID(resolvedUUID)
            purchaseDate = resolvedDate
            seedUUID = resolvedUUID
        } else {
            entitlement.setPurchaseDate(nil)
            entitlement.setSeedUUID(nil)
            purchaseDate = nil
            seedUUID = nil
        }

        if isPlus != entitled {
            isPlus = entitled
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// The stamp seed UUID for a transaction: the `appAccountToken` we set at
    /// purchase, or — for legacy/restored purchases that predate it — a UUID
    /// derived deterministically from the original transaction ID so it stays
    /// stable across devices.
    private static func seedUUID(for transaction: Transaction) -> UUID? {
        transaction.appAccountToken ?? stableUUID(from: transaction.originalID)
    }

    /// Deterministically expands a 64-bit value into a UUID (splitmix64 fill).
    private static func stableUUID(from value: UInt64) -> UUID {
        let lo = value
        let hi = value &* 0x9E37_79B9_7F4A_7C15
        var b = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: hi.bigEndian) { for i in 0..<8 { b[i] = $0[i] } }
        withUnsafeBytes(of: lo.bigEndian) { for i in 0..<8 { b[8 + i] = $0[i] } }
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    #if DEBUG
    /// Bypass StoreKit for local UI testing (wired to the Settings debug row).
    /// Generates a one-off seed UUID so the debug stamp looks like a real one.
    func debugSetPlus(_ value: Bool) {
        apply(entitled: value, date: value ? Date() : nil, uuid: nil)
    }
    #endif
}
