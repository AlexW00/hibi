# Stage 2 — SwiftData + CloudKit Persistence Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. The `@Model`/enum definitions are the **irreversible CloudKit schema** — transcribe them VERBATIM; do not rename fields, retype, or reorder enum cases.

**Goal:** A synced, offline-first SwiftData store containing the **entire** v3 customization model graph (signed off in `docs/superpowers/specs/2026-06-13-stage2-model-graph.md`), with the Production CloudKit schema deployable once. No customization UI yet — a DEBUG harness exercises and deploys the schema.

**Architecture:** Six `@Model` types wrapped in a `VersionedSchema` (`SchemaV1`), in a `ModelContainer(cloudKitDatabase: .private("iCloud.com.weichart.hibi"))` (private DB, offline-first). App-level dedup (no `.unique` allowed) lives in pure functions + a thin `@MainActor CustomizationStore`. Volatile styling lives in manually-encoded `Data` `stylePayload` blobs. A DEBUG-only path materializes + exports the schema for a one-time Console deploy.

**Tech Stack:** SwiftData (iOS 26), CloudKit (private DB), `NSPersistentCloudKitContainer` (schema bring-up only), Swift Testing, `xcrun cktool`.

---

## Hard rules for this stage (irreversible / safety)

1. **Enum cases are APPEND-ONLY with pinned raw values.** `case smooth = 0` etc. Never reorder/renumber/reuse. Add a `// APPEND-ONLY: never reorder/renumber/reuse` comment above each enum.
2. **No `@Attribute(.unique)` / `#Unique` anywhere.** Identity is app-level dedup.
3. **Every stored property optional or defaulted. Every relationship optional, with explicit inverse, unordered.** `@Relationship` macro on the to-many side only.
4. **`dateKey` is built from civil Y/M/D components**, never from a `Date()` instant + timezone.
5. **`stylePayload` is `Data?`** holding a manually JSON-encoded versioned struct — NOT a SwiftData-stored Codable property.
6. **Same-day dedup MERGES** (reparents children), never discards.
7. **`initializeCloudKitSchema()` / deploy is DEBUG-only**, never in production startup.
8. **Build-only verification** (no simulator runs). Tests compile-checked here, run on-device by the user. The CloudKit-constraint validation + `.ckdb` deploy are on-device user steps (test handoff).

**Git hygiene:** stage only files you create/modify per task; never `git add -A`.

---

## File Structure

- Create `Hibi/Models/Customization/CustomizationTokens.swift` — the 4 enums (pinned).
- Create `Hibi/Models/Customization/StylePayloads.swift` — versioned Codable payload envelopes + encode/decode helpers.
- Create `Hibi/Models/Customization/CustomizationModels.swift` — the 6 `@Model` types.
- Create `Hibi/Models/Customization/CustomizationSchema.swift` — `SchemaV1`, `CustomizationMigrationPlan`, container factory.
- Create `Hibi/Models/Customization/CustomizationDedup.swift` — pure dedup/ordering/dateKey functions.
- Create `Hibi/Models/Customization/CustomizationStore.swift` — `@MainActor` store wrapping `mainContext`.
- Create `Hibi/Models/Customization/CloudKitSchemaTool.swift` — DEBUG-only schema bring-up.
- Modify `Hibi/Hibi.entitlements` — CloudKit container + services.
- Modify `Hibi/Info.plist` — `UIBackgroundModes` → `remote-notification`.
- Modify `Hibi/HibiApp.swift` (or `ContentView.swift`) — attach `.modelContainer`, inject `CustomizationStore`.
- Modify `Hibi/Views/SettingsView.swift` — DEBUG-only "Initialize CloudKit Schema" button.
- Create `CloudKit/.gitkeep` + `Makefile` (`ck-check`/`ck-export` targets) per the schema-ops doc.
- Create tests under `HibiTests/`: `CustomizationTokensTests`, `StylePayloadsTests`, `CustomizationDedupTests`, `CustomizationContainerTests`.

---

## Task 1: Tokens (enums) + style-payload envelopes

**Files:** Create `CustomizationTokens.swift`, `StylePayloads.swift`; Test `HibiTests/CustomizationTokensTests.swift`, `HibiTests/StylePayloadsTests.swift`.

- [ ] **Step 1: Failing tests**

```swift
// HibiTests/CustomizationTokensTests.swift
import Testing
@testable import Hibi

struct CustomizationTokensTests {
    @Test func enumRawValuesArePinned() {
        // APPEND-ONLY contract: these numbers must never change.
        #expect(PaperTexture.smooth.rawValue == 0)
        #expect(PaperTexture.linen.rawValue == 1)
        #expect(PaperTexture.kraft.rawValue == 2)
        #expect(PaperTexture.news.rawValue == 3)
        #expect(PaperTexture.vellum.rawValue == 4)
        #expect(PaperRuling.plain.rawValue == 0)
        #expect(PaperRuling.lines.rawValue == 1)
        #expect(PaperRuling.grid.rawValue == 2)
        #expect(PaperRuling.dots.rawValue == 3)
        #expect(PaperTint.cream.rawValue == 0)
        #expect(PaperTint.blush.rawValue == 1)
        #expect(PaperTint.sky.rawValue == 2)
        #expect(PaperTint.sage.rawValue == 3)
        #expect(PaperTint.butter.rawValue == 4)
        #expect(PaperTint.lilac.rawValue == 5)
        #expect(StructuralWidgetKind.dayNumber.rawValue == 0)
        #expect(StructuralWidgetKind.weekday.rawValue == 1)
        #expect(StructuralWidgetKind.month.rawValue == 2)
        #expect(StructuralWidgetKind.year.rawValue == 3)
        #expect(StructuralWidgetKind.weather.rawValue == 4)
        #expect(StructuralWidgetKind.sunrise.rawValue == 5)
        #expect(StructuralWidgetKind.sunset.rawValue == 6)
    }
    @Test func unknownRawDecodesToDefault() {
        #expect(PaperTexture(rawValue: 99) == nil) // callers coalesce to .smooth
    }
}
```

```swift
// HibiTests/StylePayloadsTests.swift
import Testing
import Foundation
@testable import Hibi

struct StylePayloadsTests {
    @Test func textPayloadRoundTrips() throws {
        var p = TextStylePayload()
        p.font = "InstrumentSerif"; p.bold = true; p.colorToken = 2
        let data = try p.encoded()
        let back = try TextStylePayload(data: data)
        #expect(back.font == "InstrumentSerif")
        #expect(back.bold == true)
        #expect(back.colorToken == 2)
        #expect(back.v == 1)
    }
    @Test func oldBlobMissingNewFieldsStillDecodes() throws {
        // Simulate a blob written by an older version (only v + font present).
        let old = Data(#"{"v":1,"font":"X"}"#.utf8)
        let p = try TextStylePayload(data: old)
        #expect(p.font == "X")
        #expect(p.bold == nil)         // new field defaults, no crash
        #expect(p.effect == nil)
    }
    @Test func emptyDataDecodesToDefault() {
        #expect((try? TextStylePayload(data: Data())) == nil) // callers treat nil/empty as default payload
    }
}
```

- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement.**

```swift
// Hibi/Models/Customization/CustomizationTokens.swift
import Foundation

// APPEND-ONLY: never reorder/renumber/reuse. Stored as the raw Int in CloudKit.
enum PaperTexture: Int, Codable, CaseIterable { case smooth = 0, linen = 1, kraft = 2, news = 3, vellum = 4 }
// APPEND-ONLY: never reorder/renumber/reuse.
enum PaperRuling: Int, Codable, CaseIterable { case plain = 0, lines = 1, grid = 2, dots = 3 }
// APPEND-ONLY: never reorder/renumber/reuse.
enum PaperTint: Int, Codable, CaseIterable { case cream = 0, blush = 1, sky = 2, sage = 3, butter = 4, lilac = 5 }
// APPEND-ONLY: never reorder/renumber/reuse.
enum StructuralWidgetKind: Int, Codable, CaseIterable {
    case dayNumber = 0, weekday = 1, month = 2, year = 3, weather = 4, sunrise = 5, sunset = 6
}
```

```swift
// Hibi/Models/Customization/StylePayloads.swift
import Foundation

/// Versioned Codable envelopes stored as Data in `stylePayload`. ALL fields optional →
/// old blobs decode, new fields default. Never remove/retype a field; only append optionals.
protocol StylePayload: Codable { var v: Int { get } }
extension StylePayload {
    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    init(data: Data) throws { self = try JSONDecoder().decode(Self.self, from: data) }
}

struct PaperStylePayload: StylePayload { var v = 1; var grainIntensity: Double? }
struct WidgetStylePayload: StylePayload { var v = 1; var colorToken: Int?; var fontToken: Int?; var sizeToken: Int? }
struct TextStylePayload: StylePayload {
    var v = 1
    var font: String?
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?
    var effect: Int?       // none/background/outline token (Stage 6)
    var colorToken: Int?  // AdaptivePalette token (Stage 6)
}
struct StickerStylePayload: StylePayload { var v = 1; var finish: Int?; var intensity: Double? }   // Stage 8/9
struct PlacedStickerPayload: StylePayload { var v = 1; var finishOverride: Int? }                  // reserved
```

- [ ] **Step 4: Run → pass.**
- [ ] **Step 5: Commit** — `feat(customization): tokens + versioned style-payload envelopes`

---

## Task 2: The six `@Model` types + VersionedSchema + container factory

**Files:** Create `CustomizationModels.swift`, `CustomizationSchema.swift`; Test `HibiTests/CustomizationContainerTests.swift`.

> Transcribe the models VERBATIM. Field names/types here are the irreversible schema.

- [ ] **Step 1: Failing test**

```swift
// HibiTests/CustomizationContainerTests.swift
import Testing
import SwiftData
@testable import Hibi

@MainActor
struct CustomizationContainerTests {
    private func memoryContainer() throws -> ModelContainer {
        try CustomizationContainer.make(inMemory: true, cloudKit: false)
    }

    @Test func containerInitializesOfflineWithoutAccount() throws {
        // cloudKit: false + inMemory proves offline-first shape validity (no account needed).
        _ = try memoryContainer()
    }

    @Test func insertAndFetchPaperStyle() throws {
        let c = try memoryContainer()
        let ctx = c.mainContext
        let style = PaperStyle(); style.tint = .sky
        ctx.insert(style); try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PaperStyle>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.tint == .sky)
    }

    @Test func dayWithChildrenWiresRelationships() throws {
        let c = try memoryContainer()
        let ctx = c.mainContext
        let day = DayCustomization(dateKey: "2026-06-13")
        let sticker = Sticker()
        let placed = PlacedSticker(); placed.day = day; placed.sticker = sticker; placed.zIndex = 1
        let text = TextObject(); text.day = day; text.text = "hi"; text.zIndex = 2
        ctx.insert(day); ctx.insert(sticker); ctx.insert(placed); ctx.insert(text)
        try ctx.save()
        let days = try ctx.fetch(FetchDescriptor<DayCustomization>())
        #expect(days.first?.placedStickers?.count == 1)
        #expect(days.first?.textObjects?.count == 1)
        #expect(placed.sticker === sticker)
    }
}
```

- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement models (VERBATIM).**

```swift
// Hibi/Models/Customization/CustomizationModels.swift
import Foundation
import SwiftData

@Model
final class PaperStyle {
    var texture: PaperTexture = PaperTexture.smooth
    var ruling: PaperRuling = PaperRuling.plain
    var tint: PaperTint = PaperTint.cream
    var stylePayload: Data?
    var updatedAt: Date?
    init() {}
}

@Model
final class StructuralWidget {
    var kind: StructuralWidgetKind = StructuralWidgetKind.dayNumber
    var formatVariant: Int = 0
    var x: Double = 0
    var y: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var updatedAt: Date?
    init() {}
}

@Model
final class DayCustomization {
    var dateKey: String = ""
    @Attribute(.externalStorage) var inkStrokes: Data?
    var stylePayload: Data?
    var updatedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \PlacedSticker.day) var placedStickers: [PlacedSticker]?
    @Relationship(deleteRule: .cascade, inverse: \TextObject.day) var textObjects: [TextObject]?
    init(dateKey: String = "") { self.dateKey = dateKey }
}

@Model
final class PlacedSticker {
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var day: DayCustomization?
    var sticker: Sticker?
    init() {}
}

@Model
final class TextObject {
    var text: String = ""
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
    var zIndex: Int = 0
    var stylePayload: Data?
    var day: DayCustomization?
    init() {}
}

@Model
final class Sticker {
    var stickerID: String = UUID().uuidString
    var createdAt: Date?
    @Attribute(.externalStorage) var maskedImage: Data?
    var stylePayload: Data?
    var updatedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \PlacedSticker.sticker) var placements: [PlacedSticker]?
    init() {}
}
```

```swift
// Hibi/Models/Customization/CustomizationSchema.swift
import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        PaperStyle.self, StructuralWidget.self, DayCustomization.self,
        PlacedSticker.self, TextObject.self, Sticker.self,
    ]
}

enum CustomizationMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []   // grows additively per future version
}

enum CustomizationContainer {
    static let cloudKitContainerID = "iCloud.com.weichart.hibi"

    static func make(inMemory: Bool = false, cloudKit: Bool = true) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .private(cloudKitContainerID) : .none
        )
        return try ModelContainer(for: schema, migrationPlan: CustomizationMigrationPlan.self, configurations: config)
    }
}
```

- [ ] **Step 4: Run → pass.** Then build-verify (`build-for-testing`, expect `** TEST BUILD SUCCEEDED **`).
- [ ] **Step 5: Commit** — `feat(customization): v3 @Model graph + VersionedSchema + container factory`

> If the compiler rejects any model shape (e.g. a relationship-inverse error), STOP and report — do not work around it by violating a CloudKit rule. The shape was signed off; a compile error means an API detail to resolve, not a design change.

---

## Task 3: Dedup / ordering / dateKey pure functions + `CustomizationStore`

**Files:** Create `CustomizationDedup.swift`, `CustomizationStore.swift`; Test `HibiTests/CustomizationDedupTests.swift`.

- [ ] **Step 1: Failing tests**

```swift
// HibiTests/CustomizationDedupTests.swift
import Testing
import Foundation
@testable import Hibi

struct CustomizationDedupTests {
    @Test func dateKeyFromCivilComponents() {
        #expect(CustomizationDateKey.make(year: 2026, month: 6, day: 13) == "2026-06-13")
        #expect(CustomizationDateKey.make(year: 2026, month: 12, day: 1) == "2026-12-01")
    }

    @Test func orderedByZIndexSortsStably() {
        let items = [Z(id: "a", z: 2), Z(id: "b", z: 0), Z(id: "c", z: 2), Z(id: "d", z: 1)]
        let ordered = orderedByZIndex(items, id: \.id, zIndex: \.z).map(\.id)
        #expect(ordered == ["b", "d", "a", "c"])   // z asc, ties broken by id asc → deterministic
    }

    @Test func singletonSurvivorIsNewestThenStableID() {
        let rows = [
            DedupRow(id: "x", updatedAt: Date(timeIntervalSince1970: 100)),
            DedupRow(id: "y", updatedAt: Date(timeIntervalSince1970: 200)),
            DedupRow(id: "z", updatedAt: Date(timeIntervalSince1970: 200)), // tie with y
        ]
        let r = resolveDedup(rows, id: \.id, updatedAt: \.updatedAt)
        #expect(r.survivorID == "z")          // newest; tie → larger id "z" > "y" (deterministic rule)
        #expect(Set(r.casualtyIDs) == ["x", "y"])
    }

    // local helpers
    struct Z { let id: String; let z: Int }
    struct DedupRow { let id: String; let updatedAt: Date? }
}
```

- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement pure functions + store.**

```swift
// Hibi/Models/Customization/CustomizationDedup.swift
import Foundation

enum CustomizationDateKey {
    /// Civil-component construction ONLY — never from a Date()+timezone.
    static func make(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Stable visual order from an unordered set + zIndex. Ties broken by id → deterministic/convergent.
func orderedByZIndex<T, ID: Comparable>(_ items: [T], id: (T) -> ID, zIndex: (T) -> Int) -> [T] {
    items.sorted { a, b in
        let za = zIndex(a), zb = zIndex(b)
        return za != zb ? za < zb : id(a) < id(b)
    }
}

struct DedupResult<ID> { let survivorID: ID; let casualtyIDs: [ID] }

/// Convergent survivor pick: newest updatedAt, ties broken by larger stable id.
func resolveDedup<T, ID: Comparable>(_ rows: [T], id: (T) -> ID, updatedAt: (T) -> Date?) -> DedupResult<ID> {
    precondition(!rows.isEmpty)
    let sorted = rows.sorted { a, b in
        let ta = updatedAt(a) ?? .distantPast, tb = updatedAt(b) ?? .distantPast
        if ta != tb { return ta > tb }      // newest first
        return id(a) > id(b)                 // tie → larger id first (deterministic)
    }
    return DedupResult(survivorID: id(sorted[0]), casualtyIDs: sorted.dropFirst().map(id))
}
```

```swift
// Hibi/Models/Customization/CustomizationStore.swift
import Foundation
import SwiftData

@MainActor @Observable
final class CustomizationStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    /// Global paper style (deduped singleton). Creates one if none exists.
    func paperStyle() throws -> PaperStyle {
        let all = try context.fetch(FetchDescriptor<PaperStyle>())
        if all.isEmpty {
            let s = PaperStyle(); s.updatedAt = .now
            context.insert(s); try context.save()
            return s
        }
        if all.count == 1 { return all[0] }
        // Dedup: keep convergent survivor, delete the rest.
        let r = resolveDedup(all, id: { $0.persistentModelID.storeIdentifier ?? "" }, updatedAt: { $0.updatedAt })
        let survivor = all.first { ($0.persistentModelID.storeIdentifier ?? "") == r.survivorID } ?? all[0]
        for s in all where s !== survivor { context.delete(s) }
        try context.save()
        return survivor
    }

    /// Fetch (deduped+merged) DayCustomization for a date key, or create one.
    func fetchOrCreateDay(dateKey: String) throws -> DayCustomization {
        let pred = #Predicate<DayCustomization> { $0.dateKey == dateKey }
        let matches = try context.fetch(FetchDescriptor<DayCustomization>(predicate: pred))
        if matches.isEmpty {
            let d = DayCustomization(dateKey: dateKey); d.updatedAt = .now
            context.insert(d); try context.save()
            return d
        }
        if matches.count == 1 { return matches[0] }
        return try mergeDays(matches)
    }

    /// MERGE same-date rows: reparent children onto survivor (union), LWW the ink blob, delete casualties.
    private func mergeDays(_ days: [DayCustomization]) throws -> DayCustomization {
        let r = resolveDedup(days, id: { $0.persistentModelID.storeIdentifier ?? "" }, updatedAt: { $0.updatedAt })
        let survivor = days.first { ($0.persistentModelID.storeIdentifier ?? "") == r.survivorID } ?? days[0]
        for d in days where d !== survivor {
            for p in (d.placedStickers ?? []) { p.day = survivor }
            for t in (d.textObjects ?? []) { t.day = survivor }
            // inkStrokes can't auto-merge → survivor's blob already wins (LWW). Casualty's ink is dropped.
            context.delete(d)
        }
        try context.save()
        return survivor
    }
}
```

> Implementer note: `persistentModelID.storeIdentifier` may be nil before first save / has a specific shape — verify the exact API for a stable string id; if it differs, use whatever stable string the SDK provides (the dedup *contract* is "deterministic tie-break on a stable id", the exact accessor is an implementation detail). Keep the pure `resolveDedup`/`orderedByZIndex` functions id-type-generic so the tests don't depend on SwiftData.

- [ ] **Step 4: Run → pass.**
- [ ] **Step 5: Commit** — `feat(customization): dedup/ordering/dateKey helpers + CustomizationStore`

---

## Task 4: Entitlements, Background Modes, container wiring

**Files:** Modify `Hibi.entitlements`, `Info.plist`, `HibiApp.swift`/`ContentView.swift`.

- [ ] **Step 1: Add CloudKit entitlements** to `Hibi/Hibi.entitlements` (keep KVS + WeatherKit + App Group):

```xml
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.weichart.hibi</string>
    </array>
```

- [ ] **Step 2: Add Background Modes** to `Hibi/Info.plist`:

```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
```

- [ ] **Step 3: Attach the container + store** at the app root. In `HibiApp.swift` build the container once and inject; expose `CustomizationStore` via environment. Concretely:

```swift
// HibiApp.swift — create once
@main struct HibiApp: App {
    let customizationContainer: ModelContainer
    init() {
        // ...existing font registration / migratePrefs...
        do { customizationContainer = try CustomizationContainer.make() }
        catch { fatalError("Failed to create customization container: \(error)") }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(customizationContainer)
                .environment(CustomizationStore(context: customizationContainer.mainContext))
        }
    }
}
```

> If `ContentView` is where stores are created instead, mirror that pattern — keep ONE container instance. Do not create the container inside `body`.

- [ ] **Step 4: Build-verify** (`build-for-testing`). Expect `** TEST BUILD SUCCEEDED **`.

> Note: a simulator build does NOT validate CloudKit entitlements/constraints. Real CloudKit constraint validation happens on the user's device in Task 5.

- [ ] **Step 5: Commit** — `feat(customization): CloudKit entitlements, background mode, container wiring`

---

## Task 5: DEBUG schema bring-up + deploy harness

**Files:** Create `CloudKitSchemaTool.swift`, `Makefile`, `CloudKit/.gitkeep`; Modify `SettingsView.swift` (DEBUG section).

The completeness goal: materialize EVERY field of EVERY type in the Development schema. **Research the preferred path first** (use the apple-docs / context7 skills + a compile check):

- **Preferred:** `NSManagedObjectModel.makeManagedObjectModel(for:)` (or the current SDK equivalent) → wrap in `NSPersistentCloudKitContainer` → `initializeCloudKitSchema(options:)`. Guarantees completeness regardless of test data.
- **Fallback (if that bridge isn't available/compilable):** a DEBUG "seed one fully-populated instance of every type with every scalar field set and every relationship linked" function against the CloudKit-backed `ModelContainer`, which makes JIT create the complete Development schema. Either path ends at the same export+inspect+deploy.

- [ ] **Step 1: Implement the DEBUG tool** (`#if DEBUG` whole file). Example shape (adapt to whichever path compiles):

```swift
#if DEBUG
import Foundation
import CoreData
import SwiftData

enum CloudKitSchemaTool {
    /// DEBUG-ONLY. Materializes the full schema in the Development CloudKit environment.
    /// Run once on a real device signed into iCloud, then `make ck-export`, inspect, and deploy in Console.
    @MainActor static func initializeSchema() throws {
        // Preferred path (verify API name compiles); else use the seed-every-field fallback.
        let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models)
        let desc = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        desc.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(containerIdentifier: CustomizationContainer.cloudKitContainerID)
        let container = NSPersistentCloudKitContainer(name: "HibiCustomization", managedObjectModel: model)
        container.persistentStoreDescriptions = [desc]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        try container.initializeCloudKitSchema(options: [])
    }
}
#endif
```

- [ ] **Step 2: Add a DEBUG Settings button** in `SettingsView.swift` (alongside the existing `#if DEBUG` Stamp Noise entry) that calls `CloudKitSchemaTool.initializeSchema()` and shows success/failure. DEBUG-only strings need not be localized (consistent with the existing DEBUG views).

- [ ] **Step 3: Add the schema gate tooling.** Create `Makefile`:

```make
APPLE_TEAM_ID ?= $(shell defaults read /dev/null 2>/dev/null; echo YOURTEAMID)
CONTAINER_ID := iCloud.com.weichart.hibi
ck-export:
	xcrun cktool export-schema --team-id "$(APPLE_TEAM_ID)" --container-id "$(CONTAINER_ID)" --environment development --output-file CloudKit/schema.ckdb
ck-check:
	xcrun cktool export-schema --team-id "$(APPLE_TEAM_ID)" --container-id "$(CONTAINER_ID)" --environment production --output-file /tmp/production.ckdb
	@diff -u CloudKit/schema.ckdb /tmp/production.ckdb && echo "✅ Production matches committed schema" || (echo "❌ Deploy schema in CloudKit Console, then rerun"; exit 1)
```

and `CloudKit/.gitkeep` (the `schema.ckdb` is committed by the user after on-device export + inspection).

- [ ] **Step 4: Build-verify** (`build-for-testing`).
- [ ] **Step 5: Commit** — `feat(customization): DEBUG CloudKit schema bring-up + deploy gate tooling`

---

## Task 6: Release checklist + final pass

**Files:** Modify the `create-release` skill/checklist doc; final build.

- [ ] **Step 1:** Add to the `create-release` checklist: "If this release adds/changes a CloudKit `@Model` field or type → run `make ck-export`, inspect, commit `CloudKit/schema.ckdb`, **Deploy Schema Changes** in CloudKit Console, then `make ck-check` must pass before archiving." (Find the create-release skill at `.claude/skills/create-release/` or the docs equivalent.)
- [ ] **Step 2:** Grep the diff for hard-coded user-facing strings (expect none — Stage 2 is plumbing + DEBUG). DEBUG-only strings are exempt.
- [ ] **Step 3:** Final `build-for-testing` → `** TEST BUILD SUCCEEDED **`.
- [ ] **Step 4: Commit** — `chore(customization): stage 2 release-checklist + final pass`.

---

## Spec coverage self-check

| Stage 2 requirement | Task |
|---|---|
| All 6 `@Model` types per signed-off spec (no `.unique`, optional/defaulted, optional+inverse+unordered relationships, `zIndex`, externalStorage) | Task 2 |
| Append-only pinned enum tokens | Task 1 |
| `stylePayload` Data blobs (manual versioned Codable) | Task 1 |
| `dateKey` civil-component construction | Task 3 |
| App-level dedup: singleton + day-by-date MERGE + zIndex ordering (convergent, deterministic) | Task 3 |
| `VersionedSchema` + migration plan | Task 2 |
| Offline-first container; init without account | Task 2 |
| CloudKit on (`.private`) + entitlements + Background Modes | Tasks 2, 4 |
| DEBUG schema bring-up (`initializeCloudKitSchema`/JIT-seed) + early validation + `.ckdb` gate | Task 5 |
| Release checklist updated | Task 6 |
| Tests: dedup-by-date, singleton dedup, zIndex order, payload round-trip + old-blob, dateKey, offline init | Tasks 1–3 |

---

## Handoff to user (on-device — REQUIRED before Stage 3 sync, the irreversible deploy)

After the code lands + builds, the user must (no simulator):
1. **Xcode → Hibi target → Signing & Capabilities → add iCloud (CloudKit, container `iCloud.com.weichart.hibi`) + Background Modes → Remote notifications.** (Keep KVS.)
2. **One-time:** `xcrun cktool save-token` (management token from CloudKit Console → Keychain); set `APPLE_TEAM_ID`.
3. Run the app on a real device signed into iCloud → Settings → DEBUG → **Initialize CloudKit Schema**. Confirm it succeeds (this is also the real validator that the whole graph satisfies CloudKit constraints).
4. **`make ck-export`** → **inspect `CloudKit/schema.ckdb`** (the GATE): every enum field is scalar `Int(64)`; `maskedImage`/`inkStrokes` are asset-backed; no reserved-name collisions. Commit the `.ckdb`.
5. **CloudKit Console → Deploy Schema Changes** (the one-way door — only after the `.ckdb` inspection passes).
6. **Two-device verify:** write a model on device A (a DEBUG insert), confirm it appears on device B after sync.
7. Confirm the app still launches + works with **no iCloud account** (offline-first).

Only after the schema is in Production is it safe for Stages 3+ to start writing real customization data that must sync.
