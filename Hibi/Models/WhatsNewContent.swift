import SwiftUI
import WhatsNewKit

/// 1.1 changelog shown on first launch after update, and re-openable from Settings.
///
/// Version string must match `CFBundleShortVersionString` so
/// `UserDefaultsWhatsNewVersionStore` correctly records the presentation.
/// We currently ship `MARKETING_VERSION = 1.1`.
enum WhatsNewContent {
    static let version: WhatsNew.Version = "1.1"

    /// Built on access so `String(localized:)` resolves against the user's current locale.
    static var latest: WhatsNew {
        WhatsNew(
            version: version,
            title: .init(stringLiteral: String(localized: "What's New in Hibi")),
            features: [
                WhatsNew.Feature(
                    image: .init(systemName: "rectangle.stack"),
                    title: .init(String(localized: "Multi-day events")),
                    subtitle: .init(String(localized: "Events spanning several days now appear on every day they cover, across Month, Week, and Day."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "hand.draw"),
                    title: .init(String(localized: "Drag to reschedule")),
                    subtitle: .init(String(localized: "Long-press an event in the Week view and drop it on another day to move it."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "globe"),
                    title: .init(String(localized: "Deutsch & 日本語")),
                    subtitle: .init(String(localized: "Hibi now speaks German and Japanese, with locale-appropriate week-start and time format."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "textformat"),
                    title: .init(String(localized: "Simple font")),
                    subtitle: .init(String(localized: "A new Settings toggle swaps the serif for the system sans, for a cleaner read."))
                ),
                WhatsNew.Feature(
                    image: .init(systemName: "arrow.up.arrow.down"),
                    title: .init(String(localized: "Flip the swipe")),
                    subtitle: .init(String(localized: "Prefer swipe-up to go back? Invert the Day-view tear direction in Settings."))
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
