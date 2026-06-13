# Hibi — CloudKit Schema Operations (deploy workflow & release gate)

Operational companion to [customize-v3-sync.md](customize-v3-sync.md) §4 ("The operational
burden — CloudKit schema deployment") and the roadmap's Stage 2 + §4. The sync doc states
the *trap*; this doc states the *workflow that removes ~90% of the manual risk* of that trap.

> Sources: verified deep-research pass against Apple primary docs (current `cktool` page,
> CKTool JS / WWDC22, "Deploying an iCloud Container's Schema", `NSPersistentCloudKitContainer`
> docs, CloudKit testing/environment docs, WWDC24 CloudKit Console telemetry) + shipped-app
> practitioner reports (Fatbobman, Leo Kwan). **Current as of 2026-06-13.**

---

## Bottom line (what Apple supports today)

- **Development-side schema automation is officially supported**: `cktool` and **CKTool JS**
  do `export-schema`, `import-schema` (Development only), `reset-schema`/`resetToProduction`,
  and `validateSchema`. Apple explicitly endorses **keeping the text schema file in source
  control**.
- **Development → Production promotion is still the CloudKit Console UI**: *Schema → Deploy
  Schema Changes*. There is **no publicly documented `cktool`/CKTool JS command** that
  replaces that click (no `diff-schema`, no `promote-schema`, no `deploy-to-production`).
- **Therefore: do not try to fully automate production promotion.** Automate everything
  *around* it and make the release **refuse to ship unless Production already matches the
  committed schema**. That eliminates the actual trap while leaving the one unavoidable
  manual click.

**Why this matters for Hibi specifically:** TestFlight and App Store builds connect to the
**Production** CloudKit environment, which refuses just-in-time schema creation. If Production
is stale, data saves locally but **never syncs — no crash, no error**. Development success in
Xcode does *not* prove the release path works.

---

## The invariant

> **A release is allowed only when `CloudKit/schema.ckdb` (committed) == exported Production
> schema.** A gate enforces this. Humans forget; a script does not.

---

## Realistic scope for a solo dev (start here)

**You do not need hosted CI or macOS runners to get the safety this doc is about.** The thing
that actually prevents the silent-sync outage is one check — *export Production schema, diff it
against the committed file, fail if they differ* — and that is a shell script you run on your
Mac before each release.

Two facts that decide the scope:
- **The schema gate doesn't need macOS.** CKTool JS is a Node library hitting the CloudKit
  *Management API* over HTTPS; Apple's own sample runs it on `ubuntu-latest`. Only the **app
  build + TestFlight upload** (`xcodebuild` / `fastlane`) needs a macOS runner — and as a solo
  dev you almost certainly do that **by hand in Xcode** (Archive → Distribute), so no macOS
  runner is involved at all.
- **`xcrun cktool` is bundled with your Xcode** and stores its token in the **Keychain** — so
  the local path needs **no Node, no CKTool JS, no repo secrets, no CI account.**

**Minimum viable gate** — a `make` target (or a step in the `create-release` skill) run before
every release:

```make
APPLE_TEAM_ID ?= YOURTEAMID
ck-check:
	xcrun cktool export-schema \
	  --team-id "$(APPLE_TEAM_ID)" \
	  --container-id iCloud.com.weichart.hibi \
	  --environment production \
	  --output-file /tmp/production.ckdb
	@diff -u CloudKit/schema.ckdb /tmp/production.ckdb \
	  && echo "✅ Production matches committed schema — safe to release" \
	  || (echo "❌ CloudKit Console → Deploy Schema Changes first, then rerun"; exit 1)
```

**One-time setup for the local path:**
1. `xcrun cktool save-token` once → management token stored in the macOS Keychain. (Generate
   the token in CloudKit Console's token-management section. Schema ops need only the
   *management* token — no user token.)
2. Your Apple **Team ID** (passed as `APPLE_TEAM_ID`).
3. Container ID is already `iCloud.com.weichart.hibi`.

That's it: **one token in your Keychain + one Console click per schema change.** The full
CKTool-JS-on-Linux workflow below is an **upgrade you only need if/when you add hosted CI**
(it can't reach your Keychain, so it trades the Keychain token for a `CKTOOL_MGMT_TOKEN` repo
secret). Skip it otherwise.

---

## Full workflow (the hosted-CI upgrade)

Source of truth: **`CloudKit/schema.ckdb` committed to git**, reviewed in every PR that
changes a synced `@Model`.

1. **Local model-change loop** — when you change a synced `@Model`:
   - Run the DEBUG-only schema initializer against **Development** (materializes the schema
     via `initializeCloudKitSchema()`; see "SwiftData wrinkle" below).
   - Export Development → `CloudKit/schema.ckdb`:
     ```
     xcrun cktool export-schema \
       --team-id "$APPLE_TEAM_ID" \
       --container-id "iCloud.com.weichart.hibi" \
       --environment development \
       --output-file CloudKit/schema.ckdb
     ```
   - Commit the schema diff alongside the model change.

2. **PR / main CI** (proves the committed schema applies cleanly; prevents Console/dev drift):
   - **Validate** the committed schema (`validateSchema`).
   - **Reset Development to Production baseline** (`resetToProduction`).
   - **Import** `schema.ckdb` into Development (`importSchema`).
   - **No Production deploy here** (Apple's documented prod path is Console-only).

3. **Release CI gate** (the critical part) — on a release tag / before TestFlight upload:
   - Export **Production** schema.
   - `diff` it against `CloudKit/schema.ckdb`.
   - **Fail the release** on mismatch with an explicit message: *"Open CloudKit Console →
     Schema → Deploy Schema Changes, deploy, then rerun."*

4. **Manual step that remains:** CloudKit Console → **Deploy Schema Changes**. Now *enforced*
   by the gate, not dependent on memory.

5. **Verification:** install the internal **TestFlight** build (Production env) on **two
   physical devices** signed into the same Apple ID; create / edit / delete synced objects;
   confirm sync. Then watch CloudKit Console telemetry/error-rate after rollout.

### Tooling / runner note
Use **CKTool JS** for hosted CI, not bare `xcrun cktool`. Apple's own sample GitHub Actions
setup (`apple/sample-cloudkit-tooling`) runs on **`ubuntu-latest`** (no macOS runner needed for
the schema gate) and authenticates with a **management token from CI secrets**
(`CKTOOL_MGMT_TOKEN`), since a Linux runner has no Keychain. Management tokens are for
schema/config ops; user tokens are for data access — the gate needs only the management token.

Only the **build + TestFlight upload** step needs a **macOS runner** (`xcodebuild`/`fastlane`).
If you keep building/uploading from Xcode locally, you never provision a macOS runner at all.
Xcode Cloud (`ci_scripts/`) or a Fastlane `sh`-based lane can run the same gate — but there is
**no first-class Fastlane CloudKit action**; it just shells out to your Node/`xcrun` scripts.

---

## Hosted-CI gate (reference — only if you add CI)

```yaml
name: cloudkit-schema-gate
on:
  pull_request:
  push:
    branches: [main]
    tags: ["v*"]
jobs:
  schema:
    runs-on: ubuntu-latest
    env:
      CKTOOL_MGMT_TOKEN: ${{ secrets.CKTOOL_MGMT_TOKEN }}
      TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
      CONTAINER_ID: iCloud.com.weichart.hibi
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      # thin CKTool JS wrappers: validate / reset-dev (resetToProduction) /
      # import-dev (importSchema) / export-prod (exportSchema Production)
      - run: npm run ck:validate -- CloudKit/schema.ckdb
      - run: npm run ck:reset-dev
      - run: npm run ck:import-dev -- CloudKit/schema.ckdb
      - name: Block release if Production is stale
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          npm run ck:export-prod > /tmp/production.ckdb
          if ! diff -u CloudKit/schema.ckdb /tmp/production.ckdb; then
            echo "::error title=CloudKit Production schema drift::Production does not match CloudKit/schema.ckdb."
            echo "::error::CloudKit Console > Schema > Deploy Schema Changes, deploy, then rerun."
            exit 1
          fi
```

The three drift checks this buys: **repo↔Development** (Console/JIT experimentation drifted),
**repo↔Production** (deploy step missed), and (manually) **SwiftData model↔repo** (model
changed but `.ckdb` never re-exported).

---

## `initializeCloudKitSchema()` and the SwiftData wrinkle

- `initializeCloudKitSchema(options:)` lives on **`NSPersistentCloudKitContainer`, not**
  SwiftData's `ModelContainer`. Its job is only: *make Development aware of the latest model*
  — including fields JIT would miss (JIT only creates fields your test data exercised).
- **SwiftData has no first-class "emit `.ckdb` from `@Model`" API.** The community workaround:
  build an `NSManagedObjectModel` from the `@Model` types (e.g.
  `NSManagedObjectModel.makeManagedObjectModel(for:)`), wrap it in an
  `NSPersistentCloudKitContainer` pointed at the same store, call `initializeCloudKitSchema()`.
- **Keep it DEBUG-only / behind a schema-tool path — never in production app startup.** It is
  an expensive, environment-mutating operation. Don't add it to CI unless it proves
  deterministic; the robust path is "init Development locally → export → commit → CI diffs".

---

## Additive-only migration hierarchy (Production schema is immutable forever)

Once promoted, you can **add** record types and fields and **add/remove indexes**; you can
**never delete, rename, or change the type** of an existing field/record type.

| Change type | Pattern |
|---|---|
| **Add property** | Add optional/defaulted field. Commit schema. Deploy. |
| **Rename property** | Add new field, migrate values, stop reading the old field. Never delete the old one. |
| **Change type** | Add a new field with the new type. Backfill. Deprecate the old field. |
| **Big model redesign** | Add a **new record type**; dual-read; migrate lazily/idempotently; stop writing the old type. |
| **Experimental / volatile data** | Keep it inside one opaque `Codable` `stylePayload` blob — but only for non-queryable internals. |
| **Regretted shipped field** | Leave it in CloudKit **forever**; just stop using it in code (optionally drop its index). |

**SwiftData `VersionedSchema` / `SchemaMigrationPlan` solve the *local store* migration only.**
They do **not** grant permission to mutate previously shipped CloudKit fields. You usually need
**both**: VersionedSchema for "can the app open/migrate the local store?" and the additive
rules for "can Production keep serving old and new clients?"

This is exactly why Hibi's volatile shader/finish params live in an opaque `stylePayload`
`Data` blob (sync doc §3, roadmap §1.2) — the blob's *contents* evolve without a schema change.

---

## Monitoring (WWDC24 CloudKit Console)

Configure at minimum:
- **Notifications** for schema changes, promotions, resets, token status.
- **Telemetry** (requests, errors, latency, error rate) and at least one **alert on errors /
  error rate** (email/web).

After a schema rollout you want CloudKit Console to tell you about a regression within minutes —
not learn it from App Store reviews. **Act as iCloud** helps debug another account's
private-data sync issues without exposing encrypted fields.

---

## What NOT to do

- Do **not** rely on "I'll remember to press Deploy Schema Changes."
- Do **not** run `initializeCloudKitSchema()` in production app startup.
- Do **not** treat SwiftData migrations as equivalent to CloudKit schema migrations.
- Do **not** ship a TestFlight/App Store build unless CI proved Production == `schema.ckdb`.
- Do **not** try to keep the Production schema "clean" — old fields are permanent.

---

## Open questions / limitations (unverified by the research)

- No public Apple command for **unattended Dev→Production promotion** — Console UI remains the
  documented path.
- No first-class Apple **SwiftData→`.ckdb`** generator — relies on the Core Data drop-down
  workaround above.
- No Apple-supported turnkey harness for **fully automated two-device Production sync tests** —
  production verification stays TestFlight-on-device + Console monitoring. (Matches the no-
  simulator constraint: runtime verification is on the physical device anyway.)

---

## How this maps onto the roadmap

- **Stage 2** deploys the full schema **once** up front (the whole model graph, via
  `initializeCloudKitSchema()` so every field exists, then a single Console deploy). After that,
  every *future additive* change follows the loop above and re-runs the release gate.
- **Roadmap §4 / `create-release` checklist**: add "Deploy CloudKit schema (Console) + release
  gate passes (Production == `schema.ckdb`)" for any release that adds a record type or field.
