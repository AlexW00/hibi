import Foundation
import WidgetKit

enum SettingsHome: Equatable {
    case appGroup
    case standard
}

struct SyncedSetting {
    let key: String
    let home: SettingsHome
    /// If true, a remote change to this key reloads widget timelines directly.
    /// (hiddenCalendarIDs is false: EventStore re-filters + rewrites its snapshot + reloads.)
    let affectsWidget: Bool
}

extension Notification.Name {
    /// Posted (main thread) after a remote KVS change writes hidden-calendar IDs
    /// down into standard defaults, so EventStore can re-read + re-filter.
    static let hibiHiddenCalendarsDidSyncRemotely = Notification.Name("hibiHiddenCalendarsDidSyncRemotely")
}

extension SyncedSettingsStore {
    static let registry: [SyncedSetting] = [
        SyncedSetting(key: TemperatureUnit.defaultsKey, home: .appGroup, affectsWidget: true),
        SyncedSetting(key: TimeFormat.defaultsKey,      home: .appGroup, affectsWidget: true),
        SyncedSetting(key: "useSimpleFont",             home: .appGroup, affectsWidget: true),
        SyncedSetting(key: "appearance",                home: .standard, affectsWidget: false),
        SyncedSetting(key: EventStore.hiddenIDsDefaultsKey, home: .standard, affectsWidget: false),
    ]
}

@MainActor
final class SyncedSettingsStore {

    static let seedFlagKey = "didSeedSettingsToKVS_v1"

    private let kvStore: KeyValueSyncStore
    private let appGroupDefaults: UserDefaults?
    private let standardDefaults: UserDefaults

    /// Designated init for tests (inject all three stores).
    init(kvStore: KeyValueSyncStore,
         appGroupDefaults: UserDefaults?,
         standardDefaults: UserDefaults) {
        self.kvStore = kvStore
        self.appGroupDefaults = appGroupDefaults
        self.standardDefaults = standardDefaults
    }

    /// Production convenience init.
    convenience init() {
        self.init(kvStore: NSUbiquitousKeyValueStore.default,
                  appGroupDefaults: AppGroup.defaults,
                  standardDefaults: .standard)
    }

    private func defaults(for home: SettingsHome) -> UserDefaults? {
        switch home {
        case .appGroup: return appGroupDefaults
        case .standard: return standardDefaults
        }
    }

    // MARK: Pull-down (KVS wins)

    @discardableResult
    func reconcileFromRemote(keys: [String] = registry.map(\.key)) -> Set<String> {
        var changed = Set<String>()
        for setting in Self.registry where keys.contains(setting.key) {
            guard let home = defaults(for: setting.home) else { continue }
            let remote = kvStore.object(forKey: setting.key)
            guard remote != nil else { continue }                 // absent remote → leave local
            let local = home.object(forKey: setting.key)
            if !plistValuesEqual(remote, local) {
                home.set(remote, forKey: setting.key)
                changed.insert(setting.key)
            }
        }
        return changed
    }

    // MARK: Write-through (local → KVS)

    func writeThroughToRemote(keys: [String] = registry.map(\.key)) {
        for setting in Self.registry where keys.contains(setting.key) {
            guard let home = defaults(for: setting.home) else { continue }
            let local = home.object(forKey: setting.key)
            guard local != nil else { continue }                  // never delete from KVS here
            let remote = kvStore.object(forKey: setting.key)
            if !plistValuesEqual(local, remote) {
                kvStore.set(local, forKey: setting.key)
            }
        }
    }

    // MARK: One-time seed-up of pre-existing local values

    func seedUpIfNeeded() {
        guard appGroupDefaults?.bool(forKey: Self.seedFlagKey) != true else { return }
        for setting in Self.registry {
            guard let home = defaults(for: setting.home) else { continue }
            if kvStore.object(forKey: setting.key) == nil,
               let local = home.object(forKey: setting.key) {
                kvStore.set(local, forKey: setting.key)
            }
        }
        appGroupDefaults?.set(true, forKey: Self.seedFlagKey)
    }

    // MARK: Remote-change classification

    func shouldReloadWidgets(changedKeys: Set<String>) -> Bool {
        Self.registry.contains { $0.affectsWidget && changedKeys.contains($0.key) }
    }

    func eventStoreNeedsRefresh(changedKeys: Set<String>) -> Bool {
        changedKeys.contains(EventStore.hiddenIDsDefaultsKey)
    }

    // MARK: Lifecycle / observers

    func start() {
        let nc = NotificationCenter.default

        // Remote KVS changes → pull down (KVS wins), reload widgets / nudge EventStore.
        nc.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                       object: kvStore as? NSUbiquitousKeyValueStore,
                       queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                self?.handleRemoteChange(note)
            }
        }

        // Local @AppStorage writes → write through to KVS.
        nc.addObserver(forName: UserDefaults.didChangeNotification,
                       object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.writeThroughToRemote()
            }
        }

        kvStore.synchronize()
        reconcileFromRemote()      // pull down whatever KVS already has (KVS wins; never clears local)
        seedUpIfNeeded()           // migrate existing users' current settings up (absent keys only)
    }

    private func handleRemoteChange(_ note: Notification) {
        // Only reconcile the keys CloudKit says changed; handle account-change gracefully.
        let info = note.userInfo
        let changedFromKVS = (info?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? Self.registry.map(\.key)
        let reason = info?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int

        // Account change (signed out / switched iCloud account): degrade to local-only.
        // Local home defaults remain the read source; do not clear anything.
        if reason == NSUbiquitousKeyValueStoreAccountChange { return }

        let changed = reconcileFromRemote(keys: changedFromKVS)
        guard !changed.isEmpty else { return }
        if shouldReloadWidgets(changedKeys: changed) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        if eventStoreNeedsRefresh(changedKeys: changed) {
            NotificationCenter.default.post(name: .hibiHiddenCalendarsDidSyncRemotely, object: nil)
        }
    }
}
