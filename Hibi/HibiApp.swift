import SwiftUI
import WhatsNewKit

@main
struct HibiApp: App {
    private let whatsNewEnvironment: WhatsNewEnvironment

    init() {
        AppFont.registerFonts()
        AppGroup.migratePrefsIfNeeded()
        self.whatsNewEnvironment = Self.makeWhatsNewEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.whatsNew, whatsNewEnvironment)
        }
    }

    /// Fresh installs should not see the What's New sheet — it's meant for
    /// updates. On the very first launch we mark the current version as
    /// already presented, so WhatsNewKit only fires on subsequent upgrades.
    private static func makeWhatsNewEnvironment() -> WhatsNewEnvironment {
        let versionStore = UserDefaultsWhatsNewVersionStore()
        let defaults = UserDefaults.standard
        let firstLaunchKey = "hasLaunchedBefore"
        if !defaults.bool(forKey: firstLaunchKey) {
            versionStore.save(presentedVersion: WhatsNewContent.version)
            defaults.set(true, forKey: firstLaunchKey)
        }
        return WhatsNewEnvironment(
            versionStore: versionStore,
            whatsNewCollection: WhatsNewContent.collection
        )
    }

}
