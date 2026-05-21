import Foundation

/// Shared App Group between the Hibi app and the HibiWidgets extension.
///
/// The group is configured in Xcode under Signing & Capabilities → App Groups
/// for BOTH targets. If the capability is missing on either target,
/// `defaults` will be nil and shared reads/writes will silently no-op.
enum AppGroup {
    static let identifier = "group.com.weichart.hibi"

    /// Shared `UserDefaults`. `nil` if the App Group capability hasn't been
    /// added (development misconfiguration). Production code should treat
    /// this as best-effort: if writing the widget snapshot fails, the widget
    /// simply won't update — not a crash.
    static let defaults: UserDefaults? = UserDefaults(suiteName: identifier)

    enum Key {
        static let snapshot = "widget.todaysPage.snapshot.v1"
        static let didMigratePrefs = "didMigratePrefsToAppGroup_v1"
    }

    /// One-time migration: copy known preference keys from `.standard` into
    /// the App Group store so the widget (which can only see the group)
    /// renders with the user's actual choices.
    ///
    /// Idempotent — guarded by `Key.didMigratePrefs`. Safe to call on every
    /// app launch. Keys are only copied if not already present in the group
    /// (so a user who has already toggled a setting after the upgrade isn't
    /// reverted to the old value).
    static func migratePrefsIfNeeded() {
        guard let group = defaults else { return }
        guard !group.bool(forKey: Key.didMigratePrefs) else { return }

        let standard = UserDefaults.standard
        let prefKeys: [String] = [
            "useSimpleFont",
            TimeFormat.defaultsKey,
            TemperatureUnit.defaultsKey,
        ]

        for key in prefKeys {
            if group.object(forKey: key) == nil,
               let value = standard.object(forKey: key) {
                group.set(value, forKey: key)
            }
        }

        group.set(true, forKey: Key.didMigratePrefs)
    }
}
