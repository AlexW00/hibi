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
