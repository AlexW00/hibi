# Stage 2 — Complete v3 SwiftData + CloudKit Model Graph (for sign-off)

**This is the irreversible decision.** Once the CloudKit schema is deployed to Production, record-type names, field names, and field types are **additive-only forever** (no delete / rename / retype). So we design **every** model up front — for all of Stages 3–9 — and deploy once. Unused record types in Production are harmless; a forbidden retype discovered mid-program is not.

**What is forever vs. tunable (so you know what you're signing off):**
- **Forever (CloudKit schema):** record-type names, field names, field **types**, and which fields are relationships.
- **Tunable later (app-side, NOT in the CloudKit schema):** delete rules, dedup logic, the **contents** of every `stylePayload` `Data` blob, default values, and anything stored *inside* the blobs.

That second bullet is the whole reason volatile/evolving styling lives in opaque `Data` blobs: their contents can change with zero schema change.

> **Refinements applied during implementation (post-sign-off, still pre-deploy — so safe):**
> 1. **Enum tokens are stored as `<name>Raw: Int`** (e.g. `textureRaw`, `rulingRaw`, `tintRaw`, `kindRaw`) with a **coalescing computed accessor** (`texture { PaperTexture(rawValue: textureRaw) ?? .smooth }`). This matches the existing house pattern (`TimeFormat`/`TemperatureUnit` store `…Raw`) and is **forward-compatible**: an older client that fetches a record carrying a future enum case it doesn't know falls back to the default instead of failing the fetch. The CloudKit field is the same Int64 either way; the *field name* is `…Raw`.
> 2. **`recordUUID: String = UUID().uuidString` is on every independently-syncable record** — `PaperStyle`, `StructuralWidget`, `DayCustomization`, `PlacedSticker`, `TextObject` — as the synced, convergent tie-break for dedup and z-order. (`Sticker` uses its existing `stickerID` for this.) So the field tables below should be read with `recordUUID` present on those types and `texture`/`ruling`/`tint`/`kind` stored as `…Raw: Int`.

---

## Design rules applied (verified against CloudKit constraints)

1. **No `@Attribute(.unique)` / `#Unique`** — forbidden under CloudKit (breaks local too). Identity/uniqueness is enforced by **app-level dedup**.
2. **Every stored property optional or defaulted.**
3. **Every relationship optional, with an explicit inverse, unordered, no `.deny` delete rule.** Z-order is an explicit `zIndex: Int`, never relationship order.
4. **Colours/finishes/textures are stored as semantic tokens** (Int-backed `Codable` enums → scalar CloudKit fields), **never baked RGB** — so each device resolves light/dark at render time. **The raw Int is what's stored, so enum cases are APPEND-ONLY**: every case gets an explicit pinned number (`case smooth = 0`, `case linen = 1`, …) with a `// APPEND-ONLY: never reorder/renumber/reuse` comment. Reordering/renumbering silently corrupts every existing Production record. Adding a new case with a new number later is safe.
5. **Volatile / evolving styling lives in an opaque `stylePayload: Data?` blob** (a manually-encoded versioned `Codable` envelope), so it evolves without schema changes.
6. **Transforms** are normalized `Double`s (`x`,`y` in 0…1 of the page; `scale` relative to a base; `rotation` in radians) → resolution-independent across devices.
7. **Large binary** (`inkStrokes`, sticker `maskedImage`) is `Data` + `@Attribute(.externalStorage)` → SwiftData externalizes to CKAsset when big.
8. **Derived caches are never stored/synced** (SDF composites, baked finishes) — rebuilt on device like `StampCompositor`.

---

## The six record types

### 1. `PaperStyle` — global paper substrate (one logical row)
| Field | Type | Default | Notes |
|---|---|---|---|
| `recordUUID` | `String` | `UUID().uuidString` | synced app-assigned id; **convergent dedup tie-break** (a value identical on every device after sync). NOT `.unique`. |
| `texture` | `PaperTexture` enum (Int) | `.smooth` | smooth/linen/kraft/news/vellum |
| `ruling` | `PaperRuling` enum (Int) | `.plain` | plain/lines/grid/dots |
| `tint` | `PaperTint` enum (Int) | `.cream` | cream/blush/sky/sage/butter/lilac (the colour token) |
| `stylePayload` | `Data?` | nil | reserved for future paper params (grain intensity, etc.) |
| `updatedAt` | `Date?` | nil | LWW tie-break for singleton dedup |

App-level: exactly one logical row. Two devices can each create one offline → dedup keeps newest `updatedAt`, deletes the rest.

### 2. `StructuralWidget` — global page-4 widgets (rendered on every day page)
| Field | Type | Default | Notes |
|---|---|---|---|
| `kind` | `StructuralWidgetKind` enum (Int) | `.dayNumber` | dayNumber, weekday, month, year, weather, sunrise, sunset |
| `formatVariant` | `Int` | 0 | kind-dependent index (e.g. day `5`/`05`; weekday `Monday`/`Mon`; month `June`/`Jun`/`06`; year `2026`/`'26`) |
| `x` | `Double` | 0 | normalized 0…1 |
| `y` | `Double` | 0 | normalized 0…1 |
| `zIndex` | `Int` | 0 | explicit z-order |
| `stylePayload` | `Data?` | nil | future per-widget styling (colour token, font, size) |
| `updatedAt` | `Date?` | nil | |

No relationships (standalone global set). Each widget is its own record; the global set merges by per-record LWW (CloudKit-native). No scale/rotation field — structural widgets are move + switch-format only (addable later if ever needed).

### 3. `DayCustomization` — per-day decoration (keyed by date)
| Field | Type | Default | Notes |
|---|---|---|---|
| `recordUUID` | `String` | `UUID().uuidString` | synced app-assigned id; **convergent dedup tie-break** (critical: same-date merge must pick the same survivor on every device, else `.cascade` children are mutually deleted). NOT `.unique`. |
| `dateKey` | `String` | `""` | canonical `"yyyy-MM-dd"`. **Built from civil year/month/day components the user navigated to — never from an `Date()` instant run through a timezone** (the key is the cross-device sync identity; "June 13" must land on June 13 on every device regardless of TZ). Sortable → supports range queries. NOT `.unique` → app dedups by this. |
| `inkStrokes` | `Data?` `.externalStorage` | nil | the day's freeform ink, opaque blob (point arrays or PKDrawing — decided in Stage 7; schema is just `Data` either way) |
| `stylePayload` | `Data?` | nil | future per-day settings |
| `updatedAt` | `Date?` | nil | LWW tie-break for same-date dedup |
| `placedStickers` | `[PlacedSticker]?` | nil | `@Relationship(.cascade, inverse: \PlacedSticker.day)` |
| `textObjects` | `[TextObject]?` | nil | `@Relationship(.cascade, inverse: \TextObject.day)` |

### 4. `PlacedSticker` — a library sticker placed on one day
| Field | Type | Default | Notes |
|---|---|---|---|
| `x` | `Double` | 0 | normalized |
| `y` | `Double` | 0 | normalized |
| `scale` | `Double` | 1 | user-driven (pinch) |
| `rotation` | `Double` | 0 | radians (two-finger rotate) |
| `zIndex` | `Int` | 0 | |
| `stylePayload` | `Data?` | nil | reserved per-placement override |
| `day` | `DayCustomization?` | nil | inverse of `DayCustomization.placedStickers` |
| `sticker` | `Sticker?` | nil | inverse of `Sticker.placements` (which library asset) |

### 5. `TextObject` — a styled text object on one day
| Field | Type | Default | Notes |
|---|---|---|---|
| `text` | `String` | `""` | the typed string |
| `x` | `Double` | 0 | normalized |
| `y` | `Double` | 0 | normalized |
| `scale` | `Double` | 1 | |
| `rotation` | `Double` | 0 | radians |
| `zIndex` | `Int` | 0 | |
| `stylePayload` | `Data?` | nil | **all** volatile styling: font, B/I/U, effect (none/background/outline), colour token. Keeps the schema minimal. |
| `day` | `DayCustomization?` | nil | inverse of `DayCustomization.textObjects` |

### 6. `Sticker` — library asset (≤500)
| Field | Type | Default | Notes |
|---|---|---|---|
| `stickerID` | `String` | `UUID().uuidString` | stable app-side identity (NOT `.unique`) |
| `createdAt` | `Date?` | nil | library-grid ordering |
| `maskedImage` | `Data?` `.externalStorage` | nil | compressed cut-out **with alpha** (HEIC-with-alpha / quality-compressed, not raw PNG) → CKAsset |
| `stylePayload` | `Data?` | nil | finish token (none/shiny/holographic/glitter) + intensity |
| `updatedAt` | `Date?` | nil | |
| `placements` | `[PlacedSticker]?` | nil | `@Relationship(.nullify, inverse: \PlacedSticker.sticker)` |

> **SDF composite / baked finishes are NOT fields** — derived, rebuilt on device. The saved `maskedImage` alpha *is* the result (so Re-select-subject works only during the creation session).

---

## Relationship & delete-rule summary

```
DayCustomization ──cascade──> PlacedSticker   (inverse: PlacedSticker.day)
DayCustomization ──cascade──> TextObject      (inverse: TextObject.day)
Sticker         ──nullify──> PlacedSticker   (inverse: PlacedSticker.sticker)
```
- Cascade on owned children (deleting a day's customization removes its placed objects).
- **Nullify** on `Sticker.placements` is the conservative default: deleting a library sticker does **not** silently wipe its past-day placements (the app can clean up placements explicitly if we decide that's better). **Delete rules are app-side and tunable** — this is not part of the irreversible schema. *(Decision to confirm: should deleting a library sticker also remove its placements from past days? Default = no.)*

---

## `stylePayload` strategy (the evolution escape hatch)

Each `stylePayload` is a **versioned `Codable` envelope** encoded to `Data` by the app (not stored as a SwiftData-Codable property — we control the bytes). Pattern:

```swift
struct TextStylePayload: Codable {
    var v: Int = 1                 // schema-of-the-blob version
    var font: String?             // all fields OPTIONAL → old blobs decode, new fields default
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?
    var effect: Int?              // none/background/outline token
    var colorToken: Int?         // AdaptivePalette token
    // Stages 6+ add optional fields here — never remove/retype existing ones.
}
```
Tested invariant (Stage 2): encode → decode round-trips, **and an old blob missing new fields still decodes** (forward/backward compatible via optional fields). One concrete payload is implemented + tested as the pattern; the rest are minimal stubs filled in by their stages.

---

## Container / configuration

**Versioned from line one** (local-store migration ≠ CloudKit additive discipline — we need both). The record-type names (`CD_PaperStyle`, …) are identical whether or not it's versioned, so this costs nothing today and makes the first future local migration sane:

```swift
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

let config = ModelConfiguration(
    schema: Schema(versionedSchema: SchemaV1.self),
    cloudKitDatabase: .private("iCloud.com.weichart.hibi")   // private DB, offline-first
)
let container = try ModelContainer(
    for: Schema(versionedSchema: SchemaV1.self),
    migrationPlan: CustomizationMigrationPlan.self,
    configurations: config
)
```
- **Offline-first:** with no iCloud account the local store still works; CloudKit is additive. The container must not hard-fail without an account (tested with `cloudKitDatabase: .none` / in-memory).
- Injected at the app root via `.modelContainer(container)`; a `@MainActor` `CustomizationStore` wraps `container.mainContext` for the app-level helpers below.

---

## App-level dedup & ordering helpers (pure-logic, tested)

Because there's no uniqueness constraint, two devices can independently create the "same" logical record offline. Resolution must be **convergent** (every device picks the same survivor) and **non-destructive for user content**:

- **`dedupSingleton(_:)`** (`PaperStyle`) — survivor = newest `updatedAt`, **tie-break on `recordUUID`** (a synced app-assigned id, identical on every device after sync) so clock-skew ties resolve identically on all devices; casualties deleted. PaperStyle has no children, so discard is safe. *(Note: `persistentModelID` is device-local and NOT convergent — it must not be the tie-break.)*
- **`dedupByDateKey(_:)`** (`DayCustomization`) — **MERGE, never discard.** Two same-date rows → choose a survivor (newest `updatedAt`, `recordUUID` tie-break), then **reparent the casualties' `placedStickers` + `textObjects` onto the survivor (union)** before deleting the casualty rows. The **`inkStrokes` blob cannot auto-merge** → LWW it (keep the survivor's, i.e. newer/larger), and that's documented as the one acceptable loss. (Discarding a whole day's stickers/text would be silent, unrecoverable data loss — explicitly forbidden.)
- **`fetchOrCreateDay(dateKey:in:)`** — fetch the (deduped/merged) day for a key, or create one.
- **`orderedByZIndex(_:)`** — reconstruct visual order from an **unordered** relationship + `zIndex` (stable sort; deterministic tie-break on id).

The decision logic (which survives, what reparents, ordering) is **pure functions over arrays** (no live CloudKit), unit-tested without an account; only the apply step touches the context.

---

## Entitlements / capabilities to add in Stage 2 (deferred from Stage 1)

- **iCloud → CloudKit**, container `iCloud.com.weichart.hibi` (`com.apple.developer.icloud-services` = CloudKit, `com.apple.developer.icloud-container-identifiers`).
- **Background Modes → Remote notifications** (`UIBackgroundModes` includes `remote-notification`) so CloudKit can push sync.
- Keep the Stage-1 KVS entitlement. Widget target unchanged (App Group only).
- **User must add these in Xcode → Signing & Capabilities** (file edits alone don't register the container with the provisioning profile).

---

## Schema deploy (once) — the irreversible action

DEBUG-only bring-up (never in production startup): build an `NSManagedObjectModel` from the `@Model` types (`NSManagedObjectModel.makeManagedObjectModel(for:)`), wrap in `NSPersistentCloudKitContainer`, call `initializeCloudKitSchema()` so **every** field materializes in Development (JIT would only create fields exercised by test data).

**Run `initializeCloudKitSchema()` EARLY** (as soon as the models compile) — it is the real validator of the whole graph: it fails loudly if any CloudKit constraint is violated (non-optional property, `.unique`, missing inverse, ordered relationship). Treat it as the graph's compile-test, not a final formality.

**Hard pre-deploy GATE — inspect the exported `.ckdb` before the one-way door:** after materializing Development, export and **read** the schema and confirm, by inspection (not by assumption):
- every enum field (`texture`/`ruling`/`tint`/`kind`/`formatVariant`) is a **scalar `Int(64)`**, not a bytes/transformable/asset field;
- `maskedImage`/`inkStrokes` came through as the **asset-backed** type expected for external storage;
- no field name collides with a **CloudKit reserved name** (e.g. `recordID`, `recordName`, `modifiedAt`, `createdAt` system fields — note our `createdAt`/`updatedAt` are app fields and SwiftData prefixes them `CD_`, but verify).

Only after the `.ckdb` inspection passes: commit `CloudKit/schema.ckdb` (`xcrun cktool export-schema … --environment development`) and **Deploy to Production** in CloudKit Console (the one unavoidable manual click). Add the release gate (`docs/customize-v3-cloudkit-schema-ops.md`) to `create-release`.

---

## Stage 2 test targets (compile-checked here, run on-device)

- `dedupByDateKey` (same date → one survivor); `dedupSingleton`; `orderedByZIndex` (unordered + zIndex → correct order, stable on ties).
- `stylePayload` encode/decode round-trip + old-blob-decodes-with-new-fields.
- `dateKey(for:calendar:)` canonical formatting (timezone/locale stable).
- Container initializes with **no account** (offline-first) without throwing.
- (No CloudKit network tests — sync verified on-device via TestFlight per schema-ops doc.)

---

## Open decisions for sign-off

**Where to spend your scrutiny:** only **record-type names, field names, field types, and field-vs-relationship** are irreversible. Enum *case sets* (adding a 6th texture later), all `stylePayload` *contents*, delete rules, defaults, and dedup logic are additive/tunable any time. So the two questions worth real attention are: **(a) is the type/field/name list complete for Stages 3–9?** and **(b) did I put anything in a `Data` blob that I'll later need to query/sort/filter on?** Don't agonize over enum cases or blob internals — those are free to change.

1. **The 6 record types + every field name/type above** — correct and complete for Stages 3–9? (This is the irreversible part.)
2. **`dateKey` as a `String` `"yyyy-MM-dd"`** vs. three `Int`s (year/month/day). Default: String (sortable, simplest).
3. **Sticker delete → remove placements?** Default: no (`.nullify`). Tunable later.
4. Anything in Stages 3–9 that needs a **stored, queryable** field I've put in a blob instead (or vice-versa)?
