import SwiftUI
import CoreText
import WhatsNewKit

@main
struct HibiApp: App {
    private let whatsNewEnvironment: WhatsNewEnvironment

    init() {
        Self.registerFonts()
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

    private static func registerFonts() {
        let fonts: [(name: String, ext: String)] = [
            ("InstrumentSerif-Regular", "ttf"),
            ("InstrumentSerif-Italic", "ttf"),
            ("NotoSerifJP-Regular", "otf"),
        ]
        for font in fonts {
            guard let url = Bundle.main.url(forResource: font.name, withExtension: font.ext) else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
