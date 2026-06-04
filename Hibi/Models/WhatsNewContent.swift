import Notelet
import SwiftUI
import UIKit

/// Changelog shown on first launch after update, and re-openable from Settings.
///
/// `version` must match `CFBundleShortVersionString` so Notelet's `.current`
/// presentation records the changelog as seen. We currently ship
/// `MARKETING_VERSION = 2.0`.
enum WhatsNewContent {
    static let version = "2.0"

    /// Looks up a bundled `.mp4` used for media slides. Lives in
    /// `Hibi/Resources/` so the file-system-synchronized group bundles it.
    /// Returns `nil` (slide skipped) rather than crashing if the clip is missing.
    private static func videoURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4")
    }

    /// Single page, dark "Continue" button to match the app's monochrome chrome.
    static var configuration: NoteletConfiguration {
        NoteletConfiguration(
            doneButtonLabel: "Continue",
            accentColor: buttonAccentColor
        )
    }

    /// One accent color drives both the `.borderedProminent` button (whose label
    /// is always white) and the hierarchical list icons. In light mode near-black
    /// satisfies both. In dark mode those needs conflict — a dark fill hides the
    /// icons, a light fill hides the white button label — so a mid gray keeps both
    /// legible.
    private static let buttonAccentColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGray
            : UIColor(red: 0.043, green: 0.043, blue: 0.051, alpha: 1)
    })

    static var allNotes: [NoteletVersionNotes] {
        [latest, v1_9, v1_8, v1_7, v1_5, v1_4, v1_3, v1_2]
    }

    /// Shared header. `LocalizedStringResource` resolves lazily against the
    /// user's current locale, so each entry stays localized without rebuilding.
    private static let title: LocalizedStringResource = "What's New in Hibi"

    private static func notes(
        _ version: String,
        _ rows: [NoteletVersionNoteItem.ListRow]
    ) -> NoteletVersionNotes {
        NoteletVersionNotes(version: version, items: [.list(title: title, rows: rows)])
    }

    static var latest: NoteletVersionNotes {
        var items: [NoteletVersionNoteItem] = []

        // Slide 1 — Widgets
        if let url = videoURL("widgets") {
            items.append(.media(
                kind: .video,
                url: url,
                title: "Widgets, finally",
                description: "Hibi now has iOS widgets: put your events and reminders right on your Home Screen."
            ))
        }

        // Slide 2 — App Icons
        if let url = videoURL("icons") {
            items.append(.media(
                kind: .video,
                url: url,
                title: "App Icons",
                description: "Eight fresh app icons to match your Home Screen: from porcelain to pixel sun."
            ))
        }

        // Slide 3 — Support Hibi
        if let url = videoURL("stamp") {
            items.append(.media(
                kind: .video,
                url: url,
                title: "Support Hibi",
                description: "Hibi has always been free. With Hibi Plus you can now support it. As a thank-you, you get widgets, app icons and receive your own personal Hanko stamp!"
            ))
        }

        // Slide 4 — More improvements (free for everyone)
        items.append(.list(title: "Other changes", rows: [
            .init(
                symbolSystemName: "move.3d",
                title: "Paper that tilts",
                description: "Tilt your phone and the paper stack leans with you."
            ),
            .init(
                symbolSystemName: "calendar.day.timeline.left",
                title: "New event design",
                description: "Events have a cleaner, rounded shape, and back-to-back ones flow together."
            ),
            .init(
                symbolSystemName: "sparkles",
                title: "A tidier Day view",
                description: "Cleaned up the Day view so your schedule has more room to breathe."
            ),
            .init(
                symbolSystemName: "arrow.left.arrow.right",
                title: "Smoother switching",
                description: "Moving between Month, Week, and Day has fewer jumps."
            ),
        ]))

        return NoteletVersionNotes(version: version, items: items)
    }

    static var v1_9: NoteletVersionNotes {
        notes("1.9", [
            .init(
                symbolSystemName: "arrow.left.arrow.right",
                title: "Seamless tab switching",
                description: "Switching between Month, Week, and Day now picks up right where you left off."
            ),
            .init(
                symbolSystemName: "mappin",
                title: "Scrolling location names",
                description: "Long venue names now scroll smoothly instead of being cut off."
            ),
            .init(
                symbolSystemName: "repeat",
                title: "Recurring event fixes",
                description: "Deleting a single occurrence of a recurring event now removes just that one, not the entire series."
            ),
            .init(
                symbolSystemName: "arrow.clockwise",
                title: "Event sync fix",
                description: "Events you create now appear on the calendar right away — no more waiting for an app restart to see them."
            ),
        ])
    }

    static var v1_8: NoteletVersionNotes {
        notes("1.8", [
            .init(
                symbolSystemName: "checklist",
                title: "Reminders",
                description: "Your reminders now appear alongside calendar events. Tap the checkbox to mark them complete — right from Hibi."
            ),
            .init(
                symbolSystemName: "arrow.triangle.2.circlepath",
                title: "Recurring events",
                description: "Recurring calendar events now show a small repeat icon, so you can tell them apart at a glance."
            ),
            .init(
                symbolSystemName: "calendar",
                title: "Polished month grid",
                description: "The today indicator no longer clips into the row below — the month grid has proper breathing room now."
            ),
        ])
    }

    static var v1_7: NoteletVersionNotes {
        notes("1.7", [
            .init(
                symbolSystemName: "character.bubble",
                title: "More languages",
                description: "Hibi now includes Traditional Chinese for Taiwan and Hong Kong, Simplified Chinese for Mainland China, plus Korean, Malay, Spanish, Brazilian Portuguese, and Italian."
            ),
        ])
    }

    // MARK: - Previous versions

    static var v1_5: NoteletVersionNotes {
        notes("1.5", [
            .init(
                symbolSystemName: "sparkles",
                title: "Discover more apps",
                description: "Settings now links to apps.weichart.de, where you can find my other apps ^^"
            ),
        ])
    }

    static var v1_4: NoteletVersionNotes {
        notes("1.4", [
            .init(
                symbolSystemName: "calendar.badge.arrow.right",
                title: "Seamless month transitions",
                description: "Tearing past the last or first day of a month now smoothly continues into the next or previous month."
            ),
        ])
    }

    static var v1_3: NoteletVersionNotes {
        notes("1.3", [
            .init(
                symbolSystemName: "thermometer.medium",
                title: "Temperature & time format",
                description: "Choose Celsius or Fahrenheit, and 12-hour or 24-hour time — or let the system decide."
            ),
            .init(
                symbolSystemName: "arrow.down.doc",
                title: "New back animation",
                description: "Navigating to the previous day now slides a new page onto the stack instead of tearing one away."
            ),
        ])
    }

    static var v1_2: NoteletVersionNotes {
        notes("1.2", [
            .init(
                symbolSystemName: "checkmark.shield",
                title: "Permissions, walked through",
                description: "A first-launch sheet grants Calendar and Location access in one place, and dismisses itself once you're set."
            ),
            .init(
                symbolSystemName: "calendar",
                title: "Month opens on today",
                description: "Fixed a case where Month could land on the wrong month if you'd scrolled Week first."
            ),
        ])
    }
}
