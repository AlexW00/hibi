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
