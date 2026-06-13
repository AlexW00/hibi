import Testing
import Foundation
@testable import Hibi

@MainActor
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
}
