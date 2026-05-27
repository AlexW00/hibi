import Foundation
import Testing
@testable import Hibi

@Suite("WhatsNewContent.version matches bundle")
struct WhatsNewVersionTests {

    @Test func versionMatchesBundleShortVersionString() {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        #expect(
            WhatsNewContent.version == bundleVersion,
            "WhatsNewContent.version (\(WhatsNewContent.version)) must match CFBundleShortVersionString (\(bundleVersion ?? "nil")). Update WhatsNewContent.version and add release notes."
        )
    }

    @Test func allNotesCountIsReasonable() {
        #expect(WhatsNewContent.allNotes.count >= 2, "Should have at least 2 version notes")
    }
}
