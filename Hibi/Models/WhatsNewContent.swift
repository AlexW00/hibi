import SwiftUI
import WhatsNewKit

/// 1.2 changelog shown on first launch after update, and re-openable from Settings.
///
/// Version string must match `CFBundleShortVersionString` so
/// `UserDefaultsWhatsNewVersionStore` correctly records the presentation.
/// We currently ship `MARKETING_VERSION = 1.2`.
enum WhatsNewContent {
    static let version: WhatsNew.Version = "1.2"

    /// Built on access so `String(localized:)` resolves against the user's current locale.
    static var latest: WhatsNew {
        WhatsNew(
            version: version,
            title: .init(stringLiteral: String(localized: "What's New in Hibi")),
            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "checkmark.shield"),
                    title: .init(String(localized: "Permissions, walked through")),
                    subtitle: .init(String(localized: "A first-launch sheet grants Calendar and Location access in one place, and dismisses itself once you're set."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "calendar"),
                    title: .init(String(localized: "Month opens on today")),
                    subtitle: .init(String(localized: "Fixed a case where Month could land on the wrong month if you'd scrolled Week first."))
                ),
            ],
            primaryAction: WhatsNew.PrimaryAction(
                title: .init(String(localized: "Continue")),
                backgroundColor: .primary,
                foregroundColor: Color(uiColor: .systemBackground),
                hapticFeedback: .selection
            )
        )
    }

    static var collection: WhatsNewCollection { [latest] }
}
