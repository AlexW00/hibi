# Hibi — Customize v3: Persistence & iCloud Sync

Detailed plan for where v3 customization data lives and how it syncs across a user's
devices. Referenced from [customize-v3-plan.md](customize-v3-plan.md).

**The requirement that drives everything:** customizations must **survive app
uninstall/reinstall** and **appear on the user's other devices**. Today Hibi has *no
database* — state lives in `@Observable` stores, persisted to `UserDefaults` and the App
Group (`group.com.weichart.hibi`). There is no iCloud/CloudKit entitlement. So this is a
**greenfield sync layer**, not a migration.

> Sources: verified deep-research pass (22 claims confirmed against Apple primary docs —
> CloudKit Web Services Reference, iCloud Design Guide, "Deploying an iCloud Container's
> Schema", `NSPersistentCloudKitContainer` docs, Apple Frameworks Engineer forum posts,
> the Apple-authored VLDB CloudKit paper) + Axiom `axiom-data` (cloud-sync, cloudkit-ref).

---

## 1. Three data kinds → three stores

Each kind has a different *shape*, so each gets the Apple mechanism built for that shape.
Do **not** try to put everything in one store.

| Data kind | Store | Schema to deploy? | iCloud capability |
|---|---|---|---|
| **Settings** — units, time format, appearance, hidden calendars/lists | `NSUbiquitousKeyValueStore` (KVS) | ❌ **None** | "Key-value storage" |
| **Calendar customizations** — global paper style, structural widgets, per-day ink/text/placed-stickers | **SwiftData + CloudKit** | ✅ Yes — deploy + additive-only forever | "CloudKit" |
| **Sticker library** — ≤500 compressed cut-outs + style payload | Same SwiftData store; image blob via `@Attribute(.externalStorage)` → CKAsset | ✅ Same container | "CloudKit" |

Why not the others we evaluated:
- **iCloud Documents / `FileManager` ubiquitous container** — for files the *user* sees in
  the Files app (export/share). Our data is app-internal. Wrong tool. (Reconsider only if
  v3+ adds "export my page as an image".)
- **Core Data + `NSPersistentCloudKitContainer` directly** — same engine SwiftData sits on,
  more boilerplate. We drop to it for *one* thing only: `initializeCloudKitSchema()` (see
  §4). Otherwise SwiftData is the lower-effort front door on iOS 26.

---

## 2. Settings → `NSUbiquitousKeyValueStore`

Operationally the simplest: **no schema, no Console, no deployment.** Enable the iCloud
"Key-value storage" capability (auto-generates `com.apple.developer.ubiquity-kvstore-identifier`),
write key-value pairs, done. Syncs automatically, survives reinstall.

**Hard limits (Apple iCloud Design Guide, verbatim):** 1 MB total per user, max **1024
keys**, each value ≤1 MB, property-list types only (`Bool`, number, `String`, `Date`,
`Data`, array/dict). Our settings are a few enums + a hidden-ID set → <1% of budget.

### Hibi-specific: KVS is **not** the App Group

Settings today live in App Group `UserDefaults` because the **widgets** read them
(`Preferences`, hidden calendars in `EventStore`). KVS is a *separate* store the widget
extension can't (and shouldn't) read. So mirror, exactly like `PlusStore` →
`PlusEntitlementStore` already does for the entitlement:

```
KVS  ← source of truth for SYNC (cross-device)
 │  observe NSUbiquitousKeyValueStore.didChangeExternallyNotification
 ▼
App Group UserDefaults  ← source of truth for the WIDGET (same device)
 │  on write
 ▼
WidgetCenter.reloadAllTimelines()
```

On local change: write KVS **and** App Group. On remote KVS change: update in-memory store
+ App Group + reload widgets. Last-writer-wins is fine for settings.

---

## 3. Customizations + sticker library → SwiftData + CloudKit

Structured, relational, on iOS 26, no existing DB → SwiftData + CloudKit (wraps
`NSPersistentCloudKitContainer`). Syncs automatically; on reinstall it refetches from the
user's private CloudKit DB and rebuilds the local store. The ≤500 sticker images are fine:
mark the image `Data` `@Attribute(.externalStorage)` and SwiftData auto-externalizes
anything over CloudKit's **1 MB-per-record limit into CKAssets**, billed against the
*user's* iCloud quota (free to us).

> ⚠️ Don't trust the "50 MB per CKAsset" figure floating around — the research **refuted**
> it. The only verified asset fact: assets are counted *separately* from the 1 MB record
> limit. Keep compressed stickers small regardless (HEIC-with-alpha, not raw PNG).

### 3a. Model constraints — these shape the v3 data model directly

CloudKit sync forces a specific model shape (verified, stable since iOS 14). Design for it
from the first line:

- **NO `@Attribute(.unique)`.** Throws an explicit error under CloudKit. Hits us directly:
  per-day customizations keyed by date, and stickers with a stable ID, **cannot** use a
  uniqueness constraint. Dedupe at the app layer (persistent-history-driven dedup) instead.
- **Every property optional or defaulted.** `PaperStyle.texture/.ruling/.tint` already have
  natural defaults (Smooth/Plain/Cream) — give every stored property one.
- **Every relationship optional, with an inverse, no `.deny` delete rule, not ordered.**
  Our "page → structural widgets" and "day → stickers/strokes/text" relationships model
  fine as optional-with-inverse. **Not-ordered matters:** z-order is meaningful in the
  editor, so store an explicit `zIndex: Int`, never rely on relationship order.

### 3b. Proposed model sketch

```
SwiftData ModelContainer(cloudKitDatabase: .automatic)   // private DB
 ├─ PaperStyle          global; texture/ruling/tint, all defaulted (one row)
 ├─ StructuralWidget    page-4 placed date/weather/sun widgets; kind, format, x/y, zIndex
 ├─ DayCustomization    keyed by date (app-level dedup, NOT .unique)
 │   ├─ placedStickers  → PlacedSticker (ref to Sticker, x/y/scale/rotation, zIndex)
 │   ├─ inkStrokes      PKDrawing.dataRepresentation(), .externalStorage
 │   └─ textObjects     string + style payload + transform + zIndex
 └─ Sticker             library asset: masked image .externalStorage → CKAsset,
                        + style payload (finish, intensity). SDF composite NOT stored.
```

### 3c. What NOT to sync — derived caches stay local

Mirror the existing `StampCompositor` philosophy (disk/memory cache, rebuilt on demand):

- Sticker **SDF composite**, baked finishes, rendered bitmaps — **derived**, rebuilt on
  device from the stored cut-out + style payload. Never in CloudKit.
- Sync only the **source of truth**: the compressed masked image (`.externalStorage`) + the
  small style payload. Keeps sync small *and* keeps the most volatile data (shader params)
  out of the additive-only schema trap (§4b).

This also matches Appendix B §4 of the main plan ("SDF composite is a derived cache;
the saved alpha image *is* the result").

---

## 4. The operational burden — CloudKit schema deployment

This is the real homework and the #1 silent-failure trap. **Two recurring obligations.**

> **The concrete workflow that removes ~90% of this risk** — schema-as-code + a CI release
> gate, the additive-only migration hierarchy, `initializeCloudKitSchema()` mechanics, and
> CloudKit Console monitoring — is in
> [customize-v3-cloudkit-schema-ops.md](customize-v3-cloudkit-schema-ops.md). Read it before
> implementing Stage 2 or touching the release checklist. The sections below state the trap;
> that doc states the fix.

### 4a. Deploy Development → Production before every release

- Development env auto-creates schema just-in-time as you write data in Xcode →
  "just works" while debugging.
- **TestFlight & App Store builds connect to Production**, which refuses JIT schema
  creation. If you haven't deployed, **data saves locally but never syncs** — no crash, no
  error. Real engineers have shipped this and only noticed on a second device.
- **Fix:** CloudKit Console → *Deploy Schema Changes* → Deploy. **Repeat for every release
  that adds a new model type or field.** Add this to the `create-release` checklist.
- Gotcha-within-the-gotcha: JIT only creates fields your test data actually exercised, so
  the dev schema is often *incomplete*. Robust fix: `initializeCloudKitSchema()` — but it
  lives on `NSPersistentCloudKitContainer`, **not** SwiftData's `ModelContainer`. To call
  it, build an `NSManagedObjectModel` from the `@Model` types, wrap in a
  `NSPersistentCloudKitContainer`, call it once in a DEBUG-only bring-up path, then deploy.

### 4b. Production schema is additive-only — forever

Once deployed you can **add** record types and fields; you can **never delete, rename, or
change the type** of an existing one (CloudKit treats rename as delete+add; delete is
forbidden). Consequences:

- **Design every field addable-only from day one.**
- When a sticker style payload or customization shape must change incompatibly post-launch,
  **add a new versioned field/type and migrate** — never edit the old one. (This is exactly
  why the volatile shader params live in an opaque `stylePayload` blob, not as individual
  CloudKit fields — the blob's *contents* can evolve without a schema change.)

---

## 5. Entitlements & capabilities to add

Hibi has **none** of these today (only WeatherKit + App Group). Add to the **app** target:

- **iCloud → CloudKit** + create/select a container (e.g. `iCloud.com.weichart.hibi`).
- **iCloud → Key-value storage.**
- **Background Modes → Remote notifications** (so CloudKit can push sync changes).

The widget target does **not** need iCloud — it keeps reading the App Group snapshot the
app writes. Customizations reach the widget the same way events/weather already do: the app
renders/writes what the widget needs into `group.com.weichart.hibi`.

---

## 6. Open decisions (need a call before implementation)

1. **Conflict policy.** Two devices edit the same day offline. SwiftData+CloudKit does
   last-writer-wins automatically. Acceptable for decoration? (Almost certainly yes — it's
   not irreplaceable data. Confirm.)
2. **First-launch latency.** Sync is *eventual* and can be throttled; on a fresh reinstall
   customizations won't appear instantly. Need a "syncing…" affordance / graceful empty
   state, not a blank-looking regression.
3. **iCloud-off / not-signed-in users.** The store must work fully **offline-first** with no
   iCloud account — local SwiftData is the source of truth, sync is additive. Verify the
   container config degrades gracefully (no hard dependency on an iCloud account).
4. **Exact private-DB quota** for the 500-sticker cap. The well-established model (private
   DB counts against the *user's* iCloud, free to us) holds, but precise 2026 quotas were
   **not** independently verified in the research — check current Apple docs if the cap math
   matters.
5. **Plus gating.** Is any of this (e.g. stickers, or sync itself) Plus-gated? Affects
   whether the container/models load unconditionally. (Plus is already gated in 3 places —
   see AGENTS.md.)

---

## 7. Suggested build order

1. **KVS for settings** first — no schema, lowest risk, immediately useful, proves the
   iCloud entitlement plumbing. Wire the KVS ↔ App Group mirror.
2. **SwiftData store, local-only** — models + editors persisting locally, *before* turning
   on CloudKit. Validate the model shape against §3a constraints.
3. **Turn on CloudKit** (`.automatic`), run `initializeCloudKitSchema()` in DEBUG, deploy to
   Production, verify cross-device on two real devices.
4. **Stickers last** — heaviest (external-storage blobs + CKAssets); land it once the
   structured path is proven.
