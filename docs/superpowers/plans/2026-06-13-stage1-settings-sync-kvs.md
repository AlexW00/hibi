# Stage 1 — Settings Sync via iCloud KVS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Existing user settings stop being lost on reinstall and sync across the user's devices, by mirroring them through `NSUbiquitousKeyValueStore` (KVS) while keeping the existing `@AppStorage`/App-Group reads working unchanged.

**Architecture:** A `SyncedSettingsStore` owns a two-way mirror between KVS (source of truth for **sync**) and the existing UserDefaults "homes" (App Group + standard — source of truth for the **widget** and the app's `@AppStorage` views). On a remote KVS change it writes **down** into the home defaults (KVS-wins) and reloads widgets / nudges `EventStore`; on a local change (observed via `UserDefaults.didChangeNotification`) it writes **up** to KVS. The feedback loop is broken by **value-equality** (never write if equal), not a transient flag. KVS is abstracted behind a `KeyValueSyncStore` protocol and both UserDefaults suites are injected, so all decision logic is unit-testable without iCloud.

**Tech Stack:** Swift / SwiftUI, `NSUbiquitousKeyValueStore`, `UserDefaults` (App Group `group.com.weichart.hibi` + standard), WidgetKit (`WidgetCenter`), Swift Testing (`@Test`) following the existing `TemperatureUnitTests`/`PlusEntitlementStoreTests` patterns.

---

## Background the implementer needs

**Current state (verified):**

- Hibi has **no central settings store**. Settings are read via `@AppStorage` bindings scattered across views.
- Synced-relevant settings live in two homes today:
  - **App Group** (`AppGroup.defaults`, suite `group.com.weichart.hibi`): `useSimpleFont` (Bool), `timeFormat` (String rawValue, key = `TimeFormat.defaultsKey` = `"timeFormat"`), `temperatureUnit` (String rawValue, key = `TemperatureUnit.defaultsKey` = `"temperatureUnit"`). The widget reads these synchronously via `@AppStorage(_, store: AppGroup.defaults)`.
  - **Standard** (`UserDefaults.standard`): `appearance` (String rawValue: `system`/`light`/`dark`, read at `Hibi/ContentView.swift:50`), `hiddenCalendarIDs` (`[String]`, key = `EventStore.hiddenIDsDefaultsKey` = `"hiddenCalendarIDs"`, read into a `Set<String>` at `EventStore` init `Hibi/Models/EventStore.swift:55`, written at `:219`).
- The **template** for the mirror is `PlusStore`→`PlusEntitlementStore` (`Hibi/Models/PlusStore.swift`, `Hibi/Models/PlusEntitlement.swift`): an App-Group-backed mirror, written through, with `WidgetCenter.shared.reloadAllTimelines()` on change, and tested by injecting a fresh `UserDefaults(suiteName:)`.
- `AppGroup.swift` already has a one-time, idempotent migration (`migratePrefsIfNeeded`, guard key `"didMigratePrefsToAppGroup_v1"`) that copied the three App-Group prefs from standard. Follow that idempotency style.
- `@AppStorage` observes its UserDefaults suite via KVO: when `SyncedSettingsStore` writes a home value with `UserDefaults.set(_:forKey:)`, the bound views update automatically. **Exception:** `EventStore` caches `hiddenCalendarIDs` in a plain `Set<String>` property (not `@AppStorage`), so a remote write to that key must explicitly nudge `EventStore` to re-read and re-filter.

**Scope decisions (locked for this stage):**

- **Synced key set (this stage):** `temperatureUnit`, `timeFormat`, `useSimpleFont`, `appearance`, `hiddenCalendarIDs`. (`invertDaySwipe` / `preferCompactDayView` are deliberately deferred — a handoff question for the user. The registry is built so adding them later is one line each.)
- **Local-only, never synced:** `demoMode`, stamp-noise (DEBUG), app-icon install tracking (`firstInstallDate`/`installDateVerified`/`hasLaunchedBefore`), `settingsTipSeen`, What's-New version.
- **Entitlement scope:** add **only** the iCloud **Key-value storage** entitlement in this stage (it is all that is used). The CloudKit container + Background Modes are deferred to Stage 2 where they are first needed. (Deviation from roadmap §Stage-1 front-loading, intentional — avoids an unregistered-container device-signing dependency for zero Stage-1 benefit. Flagged to the user at handoff.)
- **Conflict policy:** last-writer-wins (acceptable for decoration/settings).

**Verification limits:** Build-only (`xcodebuild ... -destination 'generic/platform=iOS Simulator' build`). The `HibiTests` target is compile-checked here, **run on-device by the user**. Simulator builds do **not** validate the iCloud entitlement/provisioning — actual KVS sync verification is on-device by the user (Stage 1 has a concrete test handoff).

---

## File Structure

- **Create** `Hibi/Models/KeyValueSyncStore.swift` — `KeyValueSyncStore` protocol, `NSUbiquitousKeyValueStore` conformance, `InMemoryKeyValueStore` test double, and the `plistValuesEqual` helper.
- **Create** `Hibi/Models/SyncedSettingsStore.swift` — the `SyncedSetting` registry, `SettingsHome` enum, and the `SyncedSettingsStore` class (mirror logic + lifecycle/observers).
- **Modify** `Hibi/Hibi.entitlements` — add the KVS entitlement.
- **Modify** `Hibi/ContentView.swift` — create + `start()` the store; pass `EventStore` so it can nudge on hidden-calendar remote changes.
- **Modify** `Hibi/Models/EventStore.swift` — add `reloadHiddenCalendarsFromDefaults()` and subscribe to the remote-change notification.
- **Create** `HibiTests/SyncedSettingsStoreTests.swift` — pure-logic tests (Swift Testing).
- **Create** `HibiTests/KeyValueSyncStoreTests.swift` — protocol/double + equality-helper tests (Swift Testing).

---

## Task 1: `KeyValueSyncStore` protocol, conformance, in-memory double, equality helper

**Files:**
- Create: `Hibi/Models/KeyValueSyncStore.swift`
- Test: `HibiTests/KeyValueSyncStoreTests.swift`

The protocol mirrors the four primitive `NSUbiquitousKeyValueStore` methods so the store can be injected in tests. `plistValuesEqual` compares property-list values (Bool/NSNumber, String, `[String]`, Date, nil) via `NSObject.isEqual` — bridged plist values all respond to it.

- [ ] **Step 1: Write the failing tests**

```swift
// HibiTests/KeyValueSyncStoreTests.swift
import Testing
import Foundation
@testable import Hibi

struct KeyValueSyncStoreTests {

    @Test func inMemoryStoreRoundTrips() {
        let kv = InMemoryKeyValueStore()
        #expect(kv.object(forKey: "a") == nil)
        kv.set("hello", forKey: "a")
        #expect(kv.object(forKey: "a") as? String == "hello")
        kv.set(true, forKey: "b")
        #expect(kv.object(forKey: "b") as? Bool == true)
        kv.set(["x", "y"], forKey: "c")
        #expect(kv.object(forKey: "c") as? [String] == ["x", "y"])
        kv.removeObject(forKey: "a")
        #expect(kv.object(forKey: "a") == nil)
    }

    @Test func plistEqualityHandlesSupportedTypes() {
        #expect(plistValuesEqual(nil, nil))
        #expect(!plistValuesEqual(nil, "x"))
        #expect(!plistValuesEqual("x", nil))
        #expect(plistValuesEqual("x", "x"))
        #expect(!plistValuesEqual("x", "y"))
        #expect(plistValuesEqual(true, true))
        #expect(!plistValuesEqual(true, false))
        #expect(plistValuesEqual(["a", "b"], ["a", "b"]))
        #expect(!plistValuesEqual(["a", "b"], ["b", "a"]))
        let d = Date(timeIntervalSince1970: 1000)
        #expect(plistValuesEqual(d, Date(timeIntervalSince1970: 1000)))
        #expect(!plistValuesEqual(d, Date(timeIntervalSince1970: 1001)))
    }
}
```

- [ ] **Step 2: Run tests, verify they fail** (types not defined). Expected: compile failure / FAIL.

- [ ] **Step 3: Implement**

```swift
// Hibi/Models/KeyValueSyncStore.swift
import Foundation

/// Minimal seam over NSUbiquitousKeyValueStore so the mirror is injectable in tests.
protocol KeyValueSyncStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueSyncStore {}

/// In-memory double for tests. Posts no notifications; tests call reconcile/writeThrough directly.
final class InMemoryKeyValueStore: KeyValueSyncStore {
    private var storage: [String: Any] = [:]
    func object(forKey key: String) -> Any? { storage[key] }
    func set(_ value: Any?, forKey key: String) {
        if let value { storage[key] = value } else { storage.removeValue(forKey: key) }
    }
    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
    @discardableResult func synchronize() -> Bool { true }
}

/// Value-equality for property-list values (the only types we mirror). Bridged
/// plist values (NSString/NSNumber/NSArray/NSDate) all respond to `isEqual:`.
func plistValuesEqual(_ a: Any?, _ b: Any?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case (nil, _), (_, nil): return false
    default:
        guard let lhs = a as? NSObject, let rhs = b as? NSObject else { return false }
        return lhs.isEqual(rhs)
    }
}
```

- [ ] **Step 4: Run tests, verify they pass.**

- [ ] **Step 5: Commit** — `feat(sync): add KeyValueSyncStore seam + plist equality helper`

---

## Task 2: `SyncedSetting` registry + `SettingsHome`

**Files:**
- Create (start of): `Hibi/Models/SyncedSettingsStore.swift`
- Test: `HibiTests/SyncedSettingsStoreTests.swift` (registry assertions)

The registry is the single source of truth for *what* syncs and *where each key lives*. `affectsWidget` decides whether a remote change triggers `WidgetCenter` reload directly. `hiddenCalendarIDs` is `affectsWidget: false` on purpose — `EventStore` owns its own snapshot rewrite + reload, so it's routed through the EventStore nudge instead (Task 4/5).

- [ ] **Step 1: Write the failing test**

```swift
// HibiTests/SyncedSettingsStoreTests.swift
import Testing
import Foundation
@testable import Hibi

struct SyncedSettingsStoreTests {

    @Test func registryContainsExpectedKeysAndHomes() {
        let byKey = Dictionary(uniqueKeysWithValues: SyncedSettingsStore.registry.map { ($0.key, $0) })
        #expect(byKey[TemperatureUnit.defaultsKey]?.home == .appGroup)
        #expect(byKey[TimeFormat.defaultsKey]?.home == .appGroup)
        #expect(byKey["useSimpleFont"]?.home == .appGroup)
        #expect(byKey["appearance"]?.home == .standard)
        #expect(byKey[EventStore.hiddenIDsDefaultsKey]?.home == .standard)
        // Widget-relevant prefs reload the widget directly; hidden calendars do not.
        #expect(byKey[TemperatureUnit.defaultsKey]?.affectsWidget == true)
        #expect(byKey[TimeFormat.defaultsKey]?.affectsWidget == true)
        #expect(byKey["useSimpleFont"]?.affectsWidget == true)
        #expect(byKey["appearance"]?.affectsWidget == false)
        #expect(byKey[EventStore.hiddenIDsDefaultsKey]?.affectsWidget == false)
        // Deferred / local-only keys must NOT be present.
        #expect(byKey["invertDaySwipe"] == nil)
        #expect(byKey["preferCompactDayView"] == nil)
        #expect(byKey["demoMode"] == nil)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement (top of `SyncedSettingsStore.swift`)**

```swift
// Hibi/Models/SyncedSettingsStore.swift
import Foundation
import WidgetKit

enum SettingsHome {
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

extension SyncedSettingsStore {
    static let registry: [SyncedSetting] = [
        SyncedSetting(key: TemperatureUnit.defaultsKey, home: .appGroup, affectsWidget: true),
        SyncedSetting(key: TimeFormat.defaultsKey,      home: .appGroup, affectsWidget: true),
        SyncedSetting(key: "useSimpleFont",             home: .appGroup, affectsWidget: true),
        SyncedSetting(key: "appearance",                home: .standard, affectsWidget: false),
        SyncedSetting(key: EventStore.hiddenIDsDefaultsKey, home: .standard, affectsWidget: false),
    ]
}
```

> Note: `SyncedSettingsStore` class is declared in Task 3; this `extension` will compile once Task 3 lands. If you prefer to keep Task 2 independently compiling, declare an empty `final class SyncedSettingsStore {}` stub now and flesh it out in Task 3. Either way the registry test above must pass.

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `feat(sync): add synced-settings registry`

---

## Task 3: `SyncedSettingsStore` mirror logic (pull-down, write-through, seed-up)

**Files:**
- Modify: `Hibi/Models/SyncedSettingsStore.swift`
- Test: `HibiTests/SyncedSettingsStoreTests.swift`

These three pure methods are the testable core. They take the injected `KeyValueSyncStore` + two injected `UserDefaults` suites. **No `NSUbiquitousKeyValueStore.default` or `UserDefaults.standard` access inside the logic** — everything is injected.

**Behavior contract:**
- `reconcileFromRemote(keys:) -> Set<String>` — for each key in `keys` (default: all registry keys): if KVS has a value for the key and it differs from the home value → write KVS value into home; collect the key. Returns the set of keys actually changed locally. **KVS wins.** (A key absent in KVS is left untouched locally — never clears local.)
- `writeThroughToRemote(keys:)` — for each key: if the home value exists and differs from the KVS value → write home → KVS. (Absent home value with present KVS value is NOT removed from KVS here — removal would fight pull-down; settings only ever set, not delete, in this stage.)
- `seedUpIfNeeded()` — one-time (guarded by `Self.seedFlagKey` in the App Group home): for each key whose KVS value is **absent**, if the home has a value, write home → KVS. Sets the flag. Idempotent: a second call is a no-op.

- [ ] **Step 1: Write the failing tests**

```swift
// add to HibiTests/SyncedSettingsStoreTests.swift

private func makeStore() -> (SyncedSettingsStore, InMemoryKeyValueStore, UserDefaults, UserDefaults) {
    let kv = InMemoryKeyValueStore()
    let group = UserDefaults(suiteName: "test.sync.group.\(UUID().uuidString)")!
    let standard = UserDefaults(suiteName: "test.sync.std.\(UUID().uuidString)")!
    let store = SyncedSettingsStore(kvStore: kv, appGroupDefaults: group, standardDefaults: standard)
    return (store, kv, group, standard)
}

@Test func writeThroughPushesLocalToKVS() {
    let (store, kv, group, _) = makeStore()
    group.set(TemperatureUnit.fahrenheit.rawValue, forKey: TemperatureUnit.defaultsKey)
    store.writeThroughToRemote()
    #expect(kv.object(forKey: TemperatureUnit.defaultsKey) as? String == TemperatureUnit.fahrenheit.rawValue)
}

@Test func writeThroughSkipsEqualValues() {
    let (store, kv, group, _) = makeStore()
    group.set("x", forKey: "useSimpleFont")            // (type mismatch irrelevant for equality test)
    kv.set("x", forKey: "useSimpleFont")
    // No change expected; both already equal. (Smoke: no crash, value stable.)
    store.writeThroughToRemote()
    #expect(kv.object(forKey: "useSimpleFont") as? String == "x")
}

@Test func reconcilePullsRemoteDownAndKVSWins() {
    let (store, kv, group, _) = makeStore()
    group.set(TimeFormat.twelveHour.rawValue, forKey: TimeFormat.defaultsKey)   // local
    kv.set(TimeFormat.twentyFourHour.rawValue, forKey: TimeFormat.defaultsKey)  // remote, newer
    let changed = store.reconcileFromRemote()
    #expect(changed.contains(TimeFormat.defaultsKey))
    #expect(group.string(forKey: TimeFormat.defaultsKey) == TimeFormat.twentyFourHour.rawValue) // KVS won
}

@Test func reconcileLeavesLocalWhenRemoteAbsent() {
    let (store, kv, group, _) = makeStore()
    group.set(TimeFormat.twelveHour.rawValue, forKey: TimeFormat.defaultsKey)
    _ = kv // empty
    let changed = store.reconcileFromRemote()
    #expect(changed.isEmpty)
    #expect(group.string(forKey: TimeFormat.defaultsKey) == TimeFormat.twelveHour.rawValue)
}

@Test func reconcileRoutesHomesCorrectly() {
    let (store, kv, group, standard) = makeStore()
    kv.set("dark", forKey: "appearance")                       // standard home
    kv.set(true, forKey: "useSimpleFont")                      // appGroup home
    _ = store.reconcileFromRemote()
    #expect(standard.string(forKey: "appearance") == "dark")
    #expect(group.bool(forKey: "useSimpleFont") == true)
}

@Test func seedUpPushesAbsentKeysOnceAndIsIdempotent() {
    let (store, kv, group, standard) = makeStore()
    group.set(TemperatureUnit.celsius.rawValue, forKey: TemperatureUnit.defaultsKey)
    standard.set("light", forKey: "appearance")
    store.seedUpIfNeeded()
    #expect(kv.object(forKey: TemperatureUnit.defaultsKey) as? String == TemperatureUnit.celsius.rawValue)
    #expect(kv.object(forKey: "appearance") as? String == "light")
    // Mutate KVS, call again — must NOT re-seed (flag set).
    kv.set("dark", forKey: "appearance")
    store.seedUpIfNeeded()
    #expect(kv.object(forKey: "appearance") as? String == "dark")
}

@Test func seedUpSkipsKeysAlreadyInKVS() {
    let (store, kv, group, _) = makeStore()
    group.set(TemperatureUnit.celsius.rawValue, forKey: TemperatureUnit.defaultsKey)
    kv.set(TemperatureUnit.fahrenheit.rawValue, forKey: TemperatureUnit.defaultsKey) // already remote
    store.seedUpIfNeeded()
    #expect(kv.object(forKey: TemperatureUnit.defaultsKey) as? String == TemperatureUnit.fahrenheit.rawValue) // untouched
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement the class + three methods**

```swift
// Hibi/Models/SyncedSettingsStore.swift  (append below the registry)

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
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `feat(sync): SyncedSettingsStore mirror logic (pull-down/write-through/seed-up)`

---

## Task 4: Remote-change classification + widget-reload / EventStore-nudge decision

**Files:**
- Modify: `Hibi/Models/SyncedSettingsStore.swift`
- Test: `HibiTests/SyncedSettingsStoreTests.swift`

Two pure decisions are extracted so the (untestable) notification glue in Task 5 stays thin:
- `shouldReloadWidgets(changedKeys:) -> Bool` — true iff any changed key has `affectsWidget == true`.
- `eventStoreNeedsRefresh(changedKeys:) -> Bool` — true iff changed keys include `EventStore.hiddenIDsDefaultsKey`.

Also add the notification name used to nudge `EventStore`.

- [ ] **Step 1: Write the failing tests**

```swift
// add to HibiTests/SyncedSettingsStoreTests.swift

@Test func widgetReloadDecision() {
    let s = makeStore().0
    #expect(s.shouldReloadWidgets(changedKeys: [TimeFormat.defaultsKey]) == true)
    #expect(s.shouldReloadWidgets(changedKeys: ["useSimpleFont"]) == true)
    #expect(s.shouldReloadWidgets(changedKeys: ["appearance"]) == false)
    #expect(s.shouldReloadWidgets(changedKeys: [EventStore.hiddenIDsDefaultsKey]) == false)
    #expect(s.shouldReloadWidgets(changedKeys: []) == false)
}

@Test func eventStoreRefreshDecision() {
    let s = makeStore().0
    #expect(s.eventStoreNeedsRefresh(changedKeys: [EventStore.hiddenIDsDefaultsKey]) == true)
    #expect(s.eventStoreNeedsRefresh(changedKeys: ["appearance"]) == false)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```swift
// add to SyncedSettingsStore

extension Notification.Name {
    /// Posted (main thread) after a remote KVS change writes hidden-calendar IDs
    /// down into standard defaults, so EventStore can re-read + re-filter.
    static let hibiHiddenCalendarsDidSyncRemotely = Notification.Name("hibiHiddenCalendarsDidSyncRemotely")
}

extension SyncedSettingsStore {
    func shouldReloadWidgets(changedKeys: Set<String>) -> Bool {
        Self.registry.contains { $0.affectsWidget && changedKeys.contains($0.key) }
    }
    func eventStoreNeedsRefresh(changedKeys: Set<String>) -> Bool {
        changedKeys.contains(EventStore.hiddenIDsDefaultsKey)
    }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `feat(sync): remote-change classification (widget reload / EventStore nudge)`

---

## Task 5: Lifecycle, observers, and integration wiring

**Files:**
- Modify: `Hibi/Models/SyncedSettingsStore.swift` (add `start()` + observers)
- Modify: `Hibi/Hibi.entitlements`
- Modify: `Hibi/ContentView.swift`
- Modify: `Hibi/Models/EventStore.swift`

This is the glue (not unit-tested; the decision logic it calls is already tested). Wire it carefully.

- [ ] **Step 1: Add `start()` + observers to `SyncedSettingsStore`**

```swift
// add to SyncedSettingsStore

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
```

> **Loop-safety note for the reviewer:** `writeThroughToRemote()` only writes KVS when values differ, and `didChangeExternallyNotification` fires only for *external* changes (not our own KVS writes), so a remote→local write that re-fires `didChangeNotification` finds KVS already equal and stops in one hop. Verify there is no unconditional write in either path.

- [ ] **Step 2: Add the KVS entitlement.** Edit `Hibi/Hibi.entitlements` to add the key (keep existing WeatherKit + App Group):

```xml
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

- [ ] **Step 3: Wire into `ContentView`.** Where the other stores are created, add:

```swift
@State private var syncedSettings = SyncedSettingsStore()
```

and in the same `.task`/`.onAppear` chain that boots the app (near where `AppGroup.migratePrefsIfNeeded()` / store setup happens), start it once:

```swift
.task { syncedSettings.start() }
```

(Find the existing app-boot hook in `ContentView`; if `migratePrefsIfNeeded()` is called in `HibiApp.init`, keep `start()` in `ContentView.task` so the KVS observers attach when the UI is alive. Do not double-start.)

- [ ] **Step 4: Make `EventStore` react to remote hidden-calendar changes.** Add a method that re-reads the hidden set from standard defaults and re-applies filtering + rewrites the widget snapshot (reuse whatever `EventStore` already calls after a local hidden-calendars change at `:219`), and subscribe to the notification in `EventStore.init`:

```swift
// in EventStore.init, after the existing setup:
NotificationCenter.default.addObserver(
    forName: .hibiHiddenCalendarsDidSyncRemotely, object: nil, queue: .main
) { [weak self] _ in
    MainActor.assumeIsolated { self?.reloadHiddenCalendarsFromDefaults() }
}

// new method:
func reloadHiddenCalendarsFromDefaults() {
    let ids = (UserDefaults.standard.array(forKey: Self.hiddenIDsDefaultsKey) as? [String]) ?? []
    let newSet = Set(ids)
    guard newSet != hiddenCalendarIDs else { return }
    hiddenCalendarIDs = newSet
    // Re-run the same refresh the local setter triggers (re-filter, refresh views,
    // rewrite WidgetEventsSnapshot, reload widget timelines). Match the existing path at :219.
    objectWillChange.send()         // if applicable to the store's observation model
    refreshAfterHiddenCalendarsChanged()   // factor the post-:219 work into this if not already a method
}
```

> Implementer: inspect `EventStore.swift` around `:206`/`:219`/`:248`/`:329` to reuse the exact existing re-filter + snapshot-write path rather than duplicating it. If the post-change work isn't already a method, extract it to `refreshAfterHiddenCalendarsChanged()` and call it from both the local setter and this remote path. Don't invent a second filtering path (DRY).

- [ ] **Step 5: Build-verify.**

Run:
```bash
xcodebuild -project Hibi.xcodeproj -scheme Hibi \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit** — `feat(sync): wire SyncedSettingsStore lifecycle, KVS entitlement, EventStore remote refresh`

---

## Task 6: Localization & final pass

**Files:** none expected (Stage 1 adds no user-facing strings). Verify.

- [ ] **Step 1:** `git diff` the whole branch range for hard-coded user-facing `"…"` near `Text(`, alerts, button labels. Expected: none (this stage is plumbing). If any slipped in, add to `Hibi/Localizable.xcstrings` with all 11 locales.
- [ ] **Step 2:** Confirm no `NSUbiquitousKeyValueStore.default` / `UserDefaults.standard` access leaked into the *logic* methods (`reconcileFromRemote`/`writeThroughToRemote`/`seedUpIfNeeded`) — they must stay injection-only. The only direct `.default`/`.standard` references allowed are in the `convenience init()` and the `EventStore` nudge path.
- [ ] **Step 3:** Final build-verify (command from Task 5 Step 5).
- [ ] **Step 4: Commit** if anything changed — `chore(sync): stage 1 final pass`.

---

## Spec coverage self-check

| Stage 1 requirement (roadmap §Stage 1) | Task |
|---|---|
| iCloud Key-value storage entitlement (KVS only this stage; CloudKit + Background Modes deferred to Stage 2) | Task 5 |
| `SyncedSettingsStore` owns the mirror: KVS = sync truth, App Group = widget truth | Tasks 3, 5 |
| On local change → write both | Task 3 (`writeThroughToRemote`) + Task 5 (observer) |
| On remote KVS change → update store + App Group + widget reload | Tasks 3/4/5 (`reconcileFromRemote`, `handleRemoteChange`) |
| Migrate existing settings (units, time, appearance, hidden calendars) write-through; seed KVS from existing values (one-time, idempotent) | Task 3 (`seedUpIfNeeded`) |
| Last-writer-wins | Task 3 (KVS-wins pull-down + write-through) |
| Widgets still honor units/time format | Tasks 4/5 (widget reload on synced change; widget keeps reading App Group) |
| Tests: mirror round-trip; remote-change handler; idempotent migration; LWW | Tasks 1–4 |
| Advisor #1 per-key KVS-wins reconcile, no cold-launch clobber | Task 3 (`reconcileFromRemote` leaves absent-remote local untouched; `seedUpIfNeeded` only absent keys) |
| Advisor #2 value-equality loop break | Tasks 1/3 (`plistValuesEqual`, guarded writes) |
| Advisor #3 protocol + injected suites for testability | Tasks 1/3 |
| Advisor #4 changed-keys payload + account-change | Task 5 (`handleRemoteChange`) |

---

## Handoff to user (on-device verification — REQUIRED before Stage 2)

This stage produces concretely testable behavior. Before continuing to Stage 2, the user must:

1. **In Xcode → Signing & Capabilities for the Hibi (app) target → add "iCloud → Key-value storage".** Hand-editing `Hibi.entitlements` is not enough; the provisioning profile must register the capability. (Build on a real device; no simulator.)
2. **Verify cross-device sync:** change Temperature Unit / Time Format / Appearance / Simple-Font / hidden calendars on device A → appears on device B (allow a few seconds for KVS to settle).
3. **Verify reinstall survival:** set non-default settings, delete the app, reinstall → settings return.
4. **Verify the widget** still honors units/time format after a synced change.
5. **Decision for the user:** should `invertDaySwipe` and `preferCompactDayView` (day-view behavior toggles) also sync? If yes, they are a one-line registry addition each.

**Note the deviation:** CloudKit container + Background Modes are intentionally deferred to Stage 2 (not added here).
