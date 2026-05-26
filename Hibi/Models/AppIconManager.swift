import StoreKit
import SwiftUI
import UIKit

// MARK: - Icon option model

struct AppIconOption: Identifiable {
    let id: String
    let displayName: LocalizedStringResource
    let description: LocalizedStringResource
    let previewAssetName: String
    /// `nil` = primary/default icon. Non-nil = the name passed to
    /// `UIApplication.shared.setAlternateIconName(_:)`.
    let alternateIconName: String?
    let unlock: Unlock

    enum Unlock {
        case always
        case beforeDate(Date)
    }
}

// MARK: - Manager

@Observable
@MainActor
final class AppIconManager {
    private(set) var selectedIconID: String
    private(set) var installDate: Date?

    static let icons: [AppIconOption] = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let cutoff = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!

        return [
            AppIconOption(
                id: "default",
                displayName: "Default",
                description: "The current Hibi icon.",
                previewAssetName: "AppIconPreview-Default",
                alternateIconName: nil,
                unlock: .always
            ),
            AppIconOption(
                id: "early-user",
                displayName: "Early User",
                description: "For those who were there from the start.",
                previewAssetName: "AppIconPreview-EarlyUser",
                alternateIconName: "EarlyUser",
                unlock: .beforeDate(cutoff)
            ),
            AppIconOption(
                id: "disco-balloon",
                displayName: "Disco Balloon",
                description: "A shimmering disco calendar.",
                previewAssetName: "AppIconPreview-DiscoBalloon",
                alternateIconName: "DiscoBalloon",
                unlock: .always
            ),
            AppIconOption(
                id: "leatherbag",
                displayName: "Leatherbag",
                description: "Warm leather-bound planner.",
                previewAssetName: "AppIconPreview-Leatherbag",
                alternateIconName: "Leatherbag",
                unlock: .always
            ),
            AppIconOption(
                id: "pearl-hibi",
                displayName: "Pearl",
                description: "Iridescent pearl pages.",
                previewAssetName: "AppIconPreview-PearlHibi",
                alternateIconName: "PearlHibi",
                unlock: .always
            ),
            AppIconOption(
                id: "pixel-sun",
                displayName: "Pixel Sun",
                description: "A pixelated sunrise.",
                previewAssetName: "AppIconPreview-PixelSun",
                alternateIconName: "PixelSun",
                unlock: .always
            ),
            AppIconOption(
                id: "porcelain",
                displayName: "Porcelain",
                description: "Delicate blue porcelain.",
                previewAssetName: "AppIconPreview-Porcelain",
                alternateIconName: "Porcelain",
                unlock: .always
            ),
            AppIconOption(
                id: "wood-stroke",
                displayName: "Wood",
                description: "Brushed kanji on warm wood.",
                previewAssetName: "AppIconPreview-WoodStroke",
                alternateIconName: "WoodStroke",
                unlock: .always
            ),
        ]
    }()

    init() {
        let current = UIApplication.shared.alternateIconName
        self.selectedIconID = Self.icons.first { $0.alternateIconName == current }?.id ?? "default"
    }

    func loadInstallDate() async {
        if let stored = UserDefaults.standard.object(forKey: "firstInstallDate") as? Date {
            self.installDate = stored
            return
        }

        do {
            let appTransaction = try await AppTransaction.shared
            if case .verified(let transaction) = appTransaction {
                let date = transaction.originalPurchaseDate
                UserDefaults.standard.set(date, forKey: "firstInstallDate")
                self.installDate = date
                return
            }
        } catch {}

        // Fallback: existing user who updated but has no recorded date.
        // hasLaunchedBefore is true → they were here before this version.
        if UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            let fallback = Date.distantPast
            UserDefaults.standard.set(fallback, forKey: "firstInstallDate")
            self.installDate = fallback
        }
    }

    func isUnlocked(_ option: AppIconOption) -> Bool {
        switch option.unlock {
        case .always:
            return true
        case .beforeDate(let cutoff):
            guard let install = installDate else { return false }
            return install < cutoff
        }
    }

    func select(_ option: AppIconOption) async {
        guard isUnlocked(option) else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
            selectedIconID = option.id
        } catch {}
    }
}
