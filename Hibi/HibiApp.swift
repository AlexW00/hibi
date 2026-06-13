import Notelet
import SwiftData
import SwiftUI

@main
struct HibiApp: App {
    let customizationContainer: ModelContainer

    init() {
        AppFont.registerFonts()
        AppGroup.migratePrefsIfNeeded()
        Self.markWhatsNewSeenOnFreshInstall()
        // Screenshot-only: the widget gallery renders the Plus-gated widgets, so
        // flip the App-Group entitlement on to show them unlocked. Scoped to the
        // gallery launches so the regular screenshots keep their default state.
        if DemoEnvironment.widgetGallery != nil {
            PlusEntitlementStore().setIsPlus(true)
        }
        do {
            customizationContainer = try CustomizationContainer.make()
        } catch {
            fatalError("Failed to create customization container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let gallery = DemoEnvironment.widgetGallery {
                    WidgetGalleryView(kind: gallery)
                } else {
                    ContentView()
                }
            }
            .modelContainer(customizationContainer)
            .environment(CustomizationStore(context: customizationContainer.mainContext))
        }
    }

    /// Fresh installs should not see the What's New sheet — it's meant for
    /// updates. On the very first launch we mark the current version as
    /// already seen, so Notelet only fires on subsequent upgrades.
    private static func markWhatsNewSeenOnFreshInstall() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: AppIconDefaults.hasLaunchedBefore) {
            NoteletStorage.markCurrentVersionAsSeen()
            defaults.set(true, forKey: AppIconDefaults.hasLaunchedBefore)
            if defaults.object(forKey: AppIconDefaults.firstInstallDate) == nil {
                defaults.set(Date(), forKey: AppIconDefaults.firstInstallDate)
            }
        }
    }
}
