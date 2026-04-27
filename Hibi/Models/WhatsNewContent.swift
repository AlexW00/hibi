import SwiftUI
import WhatsNewKit

/// Changelog shown on first launch after update, and re-openable from Settings.
///
/// Version string must match `CFBundleShortVersionString` so
/// `UserDefaultsWhatsNewVersionStore` correctly records the presentation.
/// We currently ship `MARKETING_VERSION = 1.5`.
enum WhatsNewContent {
    static let version: WhatsNew.Version = "1.5"

    /// Built on access so `String(localized:)` resolves against the user's current locale.
    static var latest: WhatsNew {
        WhatsNew(
            version: version,
            title: .init(stringLiteral: String(localized: "What's New in Hibi")),
            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "sparkles"),
                    title: .init(String(localized: "Discover more apps")),
                    subtitle: .init(String(localized: "Settings now links to apps.weichart.de, where you can find my other apps ^^"))
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

    // MARK: - Previous versions

    static var v1_4: WhatsNew {
        WhatsNew(
            version: "1.4",
            title: .init(stringLiteral: String(localized: "What's New in Hibi")),
            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "calendar.badge.arrow.right"),
                    title: .init(String(localized: "Seamless month transitions")),
                    subtitle: .init(String(localized: "Tearing past the last or first day of a month now smoothly continues into the next or previous month."))
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

    static var v1_3: WhatsNew {
        WhatsNew(
            version: "1.3",
            title: .init(stringLiteral: String(localized: "What's New in Hibi")),
            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "thermometer.medium"),
                    title: .init(String(localized: "Temperature & time format")),
                    subtitle: .init(String(localized: "Choose Celsius or Fahrenheit, and 12-hour or 24-hour time — or let the system decide."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "arrow.down.doc"),
                    title: .init(String(localized: "New back animation")),
                    subtitle: .init(String(localized: "Navigating to the previous day now slides a new page onto the stack instead of tearing one away."))
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

    static var v1_2: WhatsNew {
        WhatsNew(
            version: "1.2",
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

    static var collection: WhatsNewCollection { [latest, v1_4, v1_3, v1_2] }
}
