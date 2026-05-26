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
    private(set) var product: Product?
    private(set) var isPurchasing = false

    /// Localized, ready-to-display price (e.g. "$4.99"). `nil` until the
    /// product loads; views fall back to a hard-coded placeholder.
    var displayPrice: String? { product?.displayPrice }

    private let entitlement: PlusEntitlementStore
    private var updatesTask: Task<Void, Never>?

    init(entitlement: PlusEntitlementStore = PlusEntitlementStore()) {
        self.entitlement = entitlement
        self.isPlus = entitlement.isPlus
        self.purchaseDate = entitlement.purchaseDate
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
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == PlusProduct.id,
                  transaction.revocationDate == nil else { continue }
            entitled = true
            date = transaction.purchaseDate
        }
        apply(entitled: entitled, date: date)
    }

    /// Run the purchase sheet. Returns `true` only on a verified success.
    @discardableResult
    func purchase() async -> Bool {
        guard let product, !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                apply(entitled: true, date: transaction.purchaseDate)
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
    private func apply(entitled: Bool, date: Date?) {
        entitlement.setIsPlus(entitled)
        if entitled {
            // Keep the earliest known purchase date stable across refreshes so
            // the derived stamp art never changes once granted.
            let resolved = entitlement.purchaseDate ?? date ?? Date()
            entitlement.setPurchaseDate(resolved)
            purchaseDate = resolved
        } else {
            entitlement.setPurchaseDate(nil)
            purchaseDate = nil
        }

        if isPlus != entitled {
            isPlus = entitled
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    #if DEBUG
    /// Bypass StoreKit for local UI testing (wired to the Settings debug row).
    func debugSetPlus(_ value: Bool) {
        apply(entitled: value, date: value ? Date() : nil)
    }
    #endif
}
