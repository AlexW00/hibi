# CloudKit Schema Workflow

How Hibi's customization sync (SwiftData + CloudKit, private DB) stays safe across dev /
TestFlight / App Store. This is the quick reference; the full rationale + hosted-CI upgrade
path is in [customize-v3-cloudkit-schema-ops.md](customize-v3-cloudkit-schema-ops.md).

## Build → CloudKit environment

| Build | Environment |
|---|---|
| Run from Xcode (debug) | **Development** |
| TestFlight | **Production** |
| App Store | **Production** |

Development and Production each have their **own** schema and data. The whole workflow exists
to keep Production's schema from lagging behind the `@Model` types.

## Automatic — no Console action

- **Local persistence** (offline-first), always; works with no iCloud account.
- **Cross-device data sync**, once the schema exists in that environment.
- **Development schema** is just-in-time created as a debug build exercises new fields. (JIT
  only creates fields your test data touches — use **Settings → DEBUG → Initialize CloudKit
  Schema** to materialize *every* field at once.)

## Manual — only when a `@Model` field/type changed since the last release

Production **refuses** JIT schema creation, so before a TestFlight/App Store release that
changed the schema, run the gate (it's in the `create-release` checklist):

1. In Development: **Settings → DEBUG → Initialize CloudKit Schema**.
2. `make ck-export` → eyeball `CloudKit/schema.ckdb` → commit it.
3. **CloudKit Console → Deploy Schema Changes → Production** (the one click with no API).
4. `make ck-check` → must print ✅ **before** you archive/upload.

If you skip this, data **saves locally but silently never syncs** — no crash, no error.
`make ck-check` is the tripwire. (`make` reads your team id from `Local.xcconfig`; override
with `make ck-export APPLE_TEAM_ID=…`.)

## Nothing to do when…

- It's a **UI/logic-only release** (no `@Model` change) — `ck-check` already passes.
- You changed only **`stylePayload` blob *contents*** (e.g. a new finish parameter inside the
  JSON) — that's not a schema change, so no deploy. (This is why volatile styling lives in the
  blob.)

## The one rule: additive-only, forever

**Add** record types/fields; **never** delete, rename, or retype an existing one. A "rename" =
add a new field, migrate values, stop reading the old one. Local-store migration for existing
users' on-device DB is handled separately by `CustomizationMigrationPlan` (`VersionedSchema`) —
"can the app open the old local store?" is a different question from "can Production serve old +
new clients?".

## Gotcha

`initializeCloudKitSchema()` **silently no-ops** unless the store description enables
`NSPersistentHistoryTrackingKey` (and remote-change notifications). See
`Hibi/Models/Customization/CloudKitSchemaTool.swift`.
