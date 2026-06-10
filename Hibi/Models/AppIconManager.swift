import StoreKit
import SwiftUI
import UIKit

// MARK: - Shared keys

enum AppIconDefaults {
    static let firstInstallDate = "firstInstallDate"
    static let installDateVerified = "installDateVerified"
    static let hasLaunchedBefore = "hasLaunchedBefore"
}

// MARK: - Icon option model

struct AppIconOption: Identifiable, Sendable {
    let id: String
    let displayName: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let previewAssetName: String
    /// `nil` = primary/default icon. Non-nil = the name passed to
    /// `UIApplication.shared.setAlternateIconName(_:)`.
    let alternateIconName: String?
    let unlock: Unlock

    enum Unlock: Sendable {
        case always
        case beforeDate(Date)
        /// Unlocked only while the Hibi Plus entitlement is active.
        case plus
    }
}

// MARK: - Manager

@Observable
@MainActor
final class AppIconManager {
    private(set) var selectedIconID: String
    private(set) var installDate: Date?

    /// Mirrors the Hibi Plus entitlement. Owned by `PlusStore`; the view layer
    /// pushes changes in so `.plus`-gated icons unlock the moment a purchase
    /// completes (this is `@Observable`, so the icon list re-renders).
    var isPlus: Bool = false

    static let icons: [AppIconOption] = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let cutoff = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let cutoffString = formatter.string(from: cutoff)

        return [
            AppIconOption(
                id: "default",
                displayName: "Default",
                subtitle: "Available for everyone",
                previewAssetName: "AppIconPreview-Default",
                alternateIconName: nil,
                unlock: .always
            ),
            AppIconOption(
                id: "early-user",
                displayName: "Early User",
                subtitle: "Available to users who downloaded Hibi before \(cutoffString)",
                previewAssetName: "AppIconPreview-EarlyUser",
                alternateIconName: "EarlyUser",
                unlock: .beforeDate(cutoff)
            ),
            AppIconOption(
                id: "disco-balloon",
                displayName: "Disco Balloon",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-DiscoBalloon",
                alternateIconName: "DiscoBalloon",
                unlock: .plus
            ),
            AppIconOption(
                id: "leatherbag",
                displayName: "Leatherbag",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-Leatherbag",
                alternateIconName: "Leatherbag",
                unlock: .plus
            ),
            AppIconOption(
                id: "pearl-hibi",
                displayName: "Pearl",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-PearlHibi",
                alternateIconName: "PearlHibi",
                unlock: .plus
            ),
            AppIconOption(
                id: "pixel-sun",
                displayName: "Pixel Sun",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-PixelSun",
                alternateIconName: "PixelSun",
                unlock: .plus
            ),
            AppIconOption(
                id: "porcelain",
                displayName: "Porcelain",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-Porcelain",
                alternateIconName: "Porcelain",
                unlock: .plus
            ),
            AppIconOption(
                id: "wood-stroke",
                displayName: "Wood",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-WoodStroke",
                alternateIconName: "WoodStroke",
                unlock: .plus
            ),
            AppIconOption(
                id: "fluff",
                displayName: "Fluff",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-Fluff",
                alternateIconName: "Fluff",
                unlock: .plus
            ),
            AppIconOption(
                id: "heart",
                displayName: "Heart",
                subtitle: "Available for Hibi Plus users",
                previewAssetName: "AppIconPreview-Heart",
                alternateIconName: "Heart",
                unlock: .plus
            ),
        ]
    }()

    init() {
        let current = UIApplication.shared.alternateIconName
        self.selectedIconID = Self.icons.first { $0.alternateIconName == current }?.id ?? "default"
    }

    func loadInstallDate() async {
        guard installDate == nil else { return }

        let defaults = UserDefaults.standard

        // If we already verified against AppTransaction, trust the cache.
        if defaults.bool(forKey: AppIconDefaults.installDateVerified),
           let cached = defaults.object(forKey: AppIconDefaults.firstInstallDate) as? Date {
            self.installDate = cached
            return
        }

        // Always consult AppTransaction — it survives reinstalls.
        do {
            let appTransaction = try await AppTransaction.shared
            if case .verified(let transaction) = appTransaction {
                let date = transaction.originalPurchaseDate
                defaults.set(date, forKey: AppIconDefaults.firstInstallDate)
                defaults.set(true, forKey: AppIconDefaults.installDateVerified)
                self.installDate = date
                return
            }
        } catch {
            #if DEBUG
            print("[AppIconManager] AppTransaction failed: \(error)")
            #endif
        }

        // Unverified cache (written by HibiApp on first launch).
        if let cached = defaults.object(forKey: AppIconDefaults.firstInstallDate) as? Date {
            self.installDate = cached
            return
        }

        // Existing user who updated but has no recorded date.
        if defaults.bool(forKey: AppIconDefaults.hasLaunchedBefore) {
            let fallback = Date()
            defaults.set(fallback, forKey: AppIconDefaults.firstInstallDate)
            self.installDate = fallback
        }
    }

    func isUnlocked(_ option: AppIconOption) -> Bool {
        Self.isUnlocked(option, isPlus: isPlus, installDate: installDate)
    }

    /// Pure unlock rule, factored out so it can be unit-tested without a
    /// `UIApplication`.
    static func isUnlocked(
        _ option: AppIconOption,
        isPlus: Bool,
        installDate: Date?
    ) -> Bool {
        switch option.unlock {
        case .always:
            return true
        case .beforeDate(let cutoff):
            guard let installDate else { return false }
            return installDate < cutoff
        case .plus:
            return isPlus
        }
    }

    #if DEBUG
    func overrideInstallDate(_ date: Date?) {
        installDate = date
    }
    #endif

    func select(_ option: AppIconOption) async {
        guard isUnlocked(option) else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
            selectedIconID = option.id
        } catch {
            #if DEBUG
            print("[AppIconManager] setAlternateIconName failed: \(error)")
            #endif
        }
    }
}
