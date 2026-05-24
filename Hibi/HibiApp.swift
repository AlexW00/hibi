import Notelet
import SwiftUI

@main
struct HibiApp: App {
    init() {
        AppFont.registerFonts()
        AppGroup.migratePrefsIfNeeded()
        Self.markWhatsNewSeenOnFreshInstall()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Fresh installs should not see the What's New sheet — it's meant for
    /// updates. On the very first launch we mark the current version as
    /// already seen, so Notelet only fires on subsequent upgrades.
    private static func markWhatsNewSeenOnFreshInstall() {
        let defaults = UserDefaults.standard
        let firstLaunchKey = "hasLaunchedBefore"
        if !defaults.bool(forKey: firstLaunchKey) {
            NoteletStorage.markCurrentVersionAsSeen()
            defaults.set(true, forKey: firstLaunchKey)
        }
    }
}
