# Hibi — Agent Orientation

A personal iOS calendar app with an editorial / paper-stationery aesthetic. This file is the index: skim it first, then jump to the specific file(s) you need.

> **Before touching the calendar scrolling code** (`MonthsScrollView`, `StreamView`, `CalendarWindow`, `StreamWindow`, `HijackingScrollView`), read [learnings.md](learnings.md) — it captures the SwiftUI infinite-scroll gotchas we hit and the patterns that survived.

## What it is

Hibi reads the user's system calendars **and reminders** via EventKit and presents them across three tabs in a single `NavigationStack`. The visual language is black-on-cream paper (dark mode is high-contrast black), Instrument Serif display type, hand-picked pastel tints. The Day tab uses a tear-off paper-pad metaphor (drag to rip, haptic on commit) with subtle gyroscope parallax.

There are two home-screen **widgets** (Upcoming Events, Today's Page) that share data with the app through an App Group. A one-time **Hibi Plus** in-app purchase (StoreKit 2) unlocks alternate app icons, a personalized rubber-stamp on the paper, and reminder interaction in the widget.

Not a backend-backed product. No account, no sync beyond the system calendar/reminder database. Weather is pulled from WeatherKit for the user's current location.

## Stack & targets

- **Platform:** iOS 26.0 minimum (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`). Uses iOS 26 APIs (e.g. `Tab(..., value:)`, `MKReverseGeocodingRequest`, `ScrollPosition`).
- **Language:** Swift 5 toolchain, SwiftUI-first. `@Observable` stores, `@MainActor` isolation, `nonisolated` delegate callbacks. UIKit is used where SwiftUI can't reach — `UIColor` for dynamic P3 colors (`PaperTints.swift`), a `UIScrollView` wrapper (`HijackingScrollView`), `EKEventEditViewController`, and alternate-icon APIs.
- **Three targets in one project** (`Hibi.xcodeproj`, no SPM-only split):
  - **Hibi** — the app. Bundle id `com.weichart.hibi`.
  - **HibiWidgetsExtension** — the widget extension (`HibiWidgets/`). Bundle id `com.weichart.hibi.HibiWidgets`.
  - **HibiTests** — XCTest unit tests (`HibiTests/`). Bundle id `com.weichart.hibi.HibiTests`, `TEST_HOST = Hibi.app` (so running them needs a device/simulator — see Verification limits).
- **Package dependencies** (`XCRemoteSwiftPackageReference`):
  - [`Notelet`](https://github.com/mykolaharmash/notelet) — the "What's New" changelog sheet (`.noteletSheet`, `NoteletVersionNotes`).
  - [`PermissionsKit`](https://github.com/sparrowcode/PermissionsKit) — native permission-request UI; products `CalendarPermission` and `LocationPermission`.
- **Frameworks:** EventKit (+ EventKitUI), WeatherKit, CoreLocation, MapKit (reverse geocoding), CoreText (font registration), StoreKit (Plus), WidgetKit + AppIntents (widgets + interactive intents), Metal (stamp shader), CoreMotion (paper parallax).
- **Entitlements (both app + widget):** WeatherKit, and App Group `group.com.weichart.hibi`.

## Verification limits

This laptop is resource-constrained. Agents may build the project, but must not boot, run, install to, inspect, or otherwise use an iOS Simulator. Do not call simulator-oriented tools or commands such as `build_run_sim`, `boot_sim`, `open_sim`, `xcrun simctl`, or Xcode "Run" workflows. Prefer build-only verification, e.g. `xcodebuild ... -destination 'generic/platform=iOS Simulator' build`, and clearly state when runtime or visual verification is left to the user. The `HibiTests` target exists but cannot be *run* here (it needs a host device/simulator); treat it as compile-checked only and leave execution to the user.

## Architecture

`@Observable` `@MainActor` stores own all non-view state. Views receive them via `.environment(...)` from `ContentView`.

- **`EventStore`** — wraps `EKEventStore` for **both events and reminders**. Caches events per `MonthKey` in `eventsByMonth`; lazy-loads via `ensureLoaded(year:month:)` when a view scrolls into a new month. `reloadReminders()` fetches incomplete + completed `EKReminder`s, groups them by due date, and surfaces overdue items on today. Watches `.EKEventStoreChanged` and reloads. Owns the hidden-calendars/lists set (persisted in `UserDefaults`), a DEBUG-only demo mode (`DemoFixtures`), and writes the **`WidgetEventsSnapshot`** to the App Group whenever today's data changes. Tracks both calendar and reminder access state.
- **`WeatherStore`** — `CLLocationManager` + `WeatherService`. 30-minute self-throttle. Keys daily forecasts by `(year, month, day)`, reverse-geocodes the location into a city name for the Day masthead, and writes the **`WidgetWeatherSnapshot`** to the App Group.
- **`PlusStore`** — StoreKit 2 purchase manager and source of truth for the Hibi Plus entitlement. Mirrors state into `PlusEntitlementStore` (App-Group-backed, readable synchronously by the widget) and reloads widget timelines on purchase/restore. Seeds the stamp with a stable purchase UUID.
- **`AppIconManager`** — alternate-app-icon catalog and gating (free vs. early-user vs. Plus-gated); verifies eligibility via `AppTransaction` and tracks install date.
- **`MotionStore`** — gravity-based `CMMotionManager` sampler driving the Day view's paper-stack parallax and the stamp's specular tilt. No permissions required.
- **`Clock`** — the current-date source views read to highlight "today"; `refresh()` handles midnight rollover / timezone change.
- **`Preferences`** — `TemperatureUnit` and `TimeFormat` enums (system/explicit) with locale resolution + shared formatters; persisted in the App Group so widgets honor them.
- **`SampleData`** — `todayYear/Month/Day` computed from `Date()` in the device time zone. A fixed `demoAnchor` (2026-04-18) drives DEBUG demo-mode time-of-day progress via `isDemoAnchor(...)` in `CalendarEvent.progress(...)`.

State flow for the three tabs lives on `ContentView`: `displayedYear/Month`, `selectedDay`, and a `scrollToNowToken` that views observe via `.onChange` to scroll back to today when the active tab is re-tapped.

**App ↔ widget data flow:** the app process writes `WidgetEventsSnapshot` / `WidgetWeatherSnapshot` and the Plus entitlement to `group.com.weichart.hibi`; widget timeline providers read those snapshots (and `PlusEntitlementStore`) synchronously. See `AppGroup.swift`.

## File index

### Entry + shell

- [HibiApp.swift](Hibi/HibiApp.swift) — `@main`. Registers the two Instrument Serif TTFs via CoreText at launch.
- [ContentView.swift](Hibi/ContentView.swift) — `TabView` with Month/Week/Day tabs, principal toolbar title, settings + add-event buttons, background radial gradient (cream in light, near-black in dark), appearance override + onboarding wiring.

### Models / stores (`Hibi/Models/`)

- [CalendarEvent.swift](Hibi/Models/CalendarEvent.swift) — view-layer `CalendarEvent` (with demo-aware `progress(at:)`) **and `CalendarReminder`**; also defines `WeatherCode` + `DayWeather`.
- [EventStore.swift](Hibi/Models/EventStore.swift) — events + reminders; see Architecture. Pastelizes each EKCalendar color.
- [WeatherStore.swift](Hibi/Models/WeatherStore.swift) — see Architecture.
- [PlusStore.swift](Hibi/Models/PlusStore.swift) / [PlusEntitlement.swift](Hibi/Models/PlusEntitlement.swift) — StoreKit purchase manager + App-Group-backed entitlement mirror.
- [AppIconManager.swift](Hibi/Models/AppIconManager.swift) — alternate-icon catalog + unlock gating.
- [MotionStore.swift](Hibi/Models/MotionStore.swift) — gyroscope/gravity sampler for parallax + stamp tilt.
- [Clock.swift](Hibi/Models/Clock.swift) — current-date source with midnight/timezone refresh.
- [Preferences.swift](Hibi/Models/Preferences.swift) — `TemperatureUnit` / `TimeFormat` enums + formatters.
- [AppGroup.swift](Hibi/Models/AppGroup.swift) — shared `UserDefaults` suite + keys for the app↔widget snapshots (with one-time migration from standard defaults).
- [WidgetEventsSnapshot.swift](Hibi/Models/WidgetEventsSnapshot.swift) / [WidgetWeatherSnapshot.swift](Hibi/Models/WidgetWeatherSnapshot.swift) — Codable today's-data blobs the app writes and the widgets read (each carries a capture timestamp for staleness checks).
- [WhatsNewContent.swift](Hibi/Models/WhatsNewContent.swift) — changelog entries for the Notelet sheet; `version` must match `CFBundleShortVersionString`.
- [SampleData.swift](Hibi/Models/SampleData.swift) — calendar math, month/day name tables, `AppFont`/`AppColor` constants.
- [DemoFixtures.swift](Hibi/Models/DemoFixtures.swift) + [+English](Hibi/Models/DemoFixtures+English.swift) / [+German](Hibi/Models/DemoFixtures+German.swift) / [+Japanese](Hibi/Models/DemoFixtures+Japanese.swift) — hand-crafted localized events for screenshot days (DEBUG only); base enum routes to the per-language extension.

### Stamp pipeline (`Hibi/Models/` + `Hibi/Shaders/`)

The Plus rubber-stamp effect. See the **stamp-ink-noise** skill before changing any of these.

- [StampConfig.swift](Hibi/Models/StampConfig.swift) — loads `stamps.json`, derives the deterministic seed (production: FNV-1a hash of the purchase UUID; DEBUG preview: Wang hash of a date), selects the stamp design, formats date text (incl. Japanese era).
- [StampCompositor.swift](Hibi/Models/StampCompositor.swift) — rasterizes mask PNG + date text into a grayscale composite with a baked SDF in the green channel; memory + disk cached.
- [StampNoise.swift](Hibi/Models/StampNoise.swift) — the 15-float procedural-noise parameter system (single source of truth; index order must match the shader's `P_*` defines).
- [StampShader.metal](Hibi/Shaders/StampShader.metal) — `[[stitchable]]` SwiftUI layer effect: role-separated ink noise + specular/emboss, tilt-reactive.

### Views (`Hibi/Views/`)

- [MonthView.swift](Hibi/Views/MonthView.swift) — single-month grid; `MonthsScrollView` (same file) implements infinite vertical month scrolling; defines `MonthKey`.
- [StreamView.swift](Hibi/Views/StreamView.swift) — "Week" tab: infinite day-stream scroll with `ScrollPosition` + `StreamWindow`. Tapping a day jumps to the Day tab. Defines `DayKey` and `StreamWindow`.
- [DayView.swift](Hibi/Views/DayView.swift) — tear-off paper-pad day view: stacked paper cards with progressive `PaperTints`, drag-to-rip prev/next, motion parallax, and a schedule list (events + reminders) below.
- [EventRowShape.swift](Hibi/Views/EventRowShape.swift) — corner-radius rules for stacked event/reminder rows (shared by Day view and widget).
- [SettingsView.swift](Hibi/Views/SettingsView.swift) — iOS-Settings-style root list **pushed onto `ContentView`'s `NavigationStack`** (not a sheet) via `.navigationDestination(isPresented:)`. General section drills into Appearance, Units, App Icon, and Calendars & Reminders sub-pages; a **Behavior** section (e.g. day-view swipe); a Hibi Plus row; About (What's New via `whatsNewVersion`/`.noteletSheet`, More Apps, Contact, Suggest a Feature); and DEBUG-only toggles (demo mode, **Debug → Stamp Noise** = `StampNoiseDebugView`). `AppearanceSettingsView` / `UnitsSettingsView` live in this file.
- [AppIconSettingsView.swift](Hibi/Views/AppIconSettingsView.swift) — alternate-icon picker with per-icon lock/unlock status and previews.
- [HibiPlusView.swift](Hibi/Views/HibiPlusView.swift) — Hibi Plus marketing/purchase sheet; hosts the live `HibiStamp` Metal preview (DEBUG noise tuning) and the StoreKit purchase button.
- [CalendarSelectionView.swift](Hibi/Views/CalendarSelectionView.swift) — hide/show individual EKCalendars / reminder lists (persists via `EventStore`).
- [PaperTints.swift](Hibi/Views/PaperTints.swift) — dynamic (light/dark) P3 paper-stack colors + `Color.pastelized(cgColor:)` for EKCalendar tints.

### Components (`Hibi/Views/Components/`)

- [EventCard.swift](Hibi/Views/Components/EventCard.swift) — stream-row event card.
- [DayEventRow.swift](Hibi/Views/Components/DayEventRow.swift) — event row in the Day tab schedule.
- [ReminderRow.swift](Hibi/Views/Components/ReminderRow.swift) — reminder row in the Day tab schedule (checkbox, overdue/recurring indicators).
- [ReminderCard.swift](Hibi/Views/Components/ReminderCard.swift) — compact reminder pill (used in previews/widget contexts).
- [RecurringGlyph.swift](Hibi/Views/Components/RecurringGlyph.swift) — the small "repeat" indicator for recurring items.
- [EventEditorSheet.swift](Hibi/Views/Components/EventEditorSheet.swift) — create/edit wrapper around `EKEventEditViewController`.
- [PermissionsOnboardingSheet.swift](Hibi/Views/Components/PermissionsOnboardingSheet.swift) — first-launch permissions flow (Calendar / Reminders / Location) via PermissionsKit.
- [CalendarAccessPrompt.swift](Hibi/Views/Components/CalendarAccessPrompt.swift) — shown when EventKit access is missing.
- [HijackingScrollView.swift](Hibi/Views/Components/HijackingScrollView.swift) — `UIScrollView` wrapper that hijacks scroll delta to drive a collapse `progress` binding, then yields to native scrolling.
- [PageContent.swift](Hibi/Views/Components/PageContent.swift) — reusable paper-page layout (weekday, day numeral, weather, sunrise/sunset) shared by the Day view and the Today's Page widget.
- [MarqueeText.swift](Hibi/Views/Components/MarqueeText.swift) — single-line ticker text that scrolls when it overflows.
- [PaperChrome.swift](Hibi/Views/Components/PaperChrome.swift) — shared paper-card chrome (edges, shadow).
- [WeatherIcon.swift](Hibi/Views/Components/WeatherIcon.swift) — `WeatherCode` → SF Symbol.

### Widgets (`HibiWidgets/`)

WidgetKit extension. Reads App-Group snapshots written by the app; never touches EventKit/WeatherKit directly except through the toggle intent.

- [HibiWidgetsBundle.swift](HibiWidgets/HibiWidgetsBundle.swift) — `@main` bundle; registers the fonts (separate process) and both widgets.
- **Upcoming Events** — [EventsWidget.swift](HibiWidgets/EventsWidget.swift), [EventsWidgetView.swift](HibiWidgets/EventsWidgetView.swift), [EventsEntry.swift](HibiWidgets/EventsEntry.swift), [EventsTimelineProvider.swift](HibiWidgets/EventsTimelineProvider.swift), [EventsWidgetIntent.swift](HibiWidgets/EventsWidgetIntent.swift) (small/medium/large; AppIntent-configurable: all-day, past events, reminders).
- **Today's Page** — [TodaysPageWidget.swift](HibiWidgets/TodaysPageWidget.swift), [TodaysPageWidgetView.swift](HibiWidgets/TodaysPageWidgetView.swift), [TodaysPageEntry.swift](HibiWidgets/TodaysPageEntry.swift), [TodaysPageTimelineProvider.swift](HibiWidgets/TodaysPageTimelineProvider.swift), + [SmallPaperView.swift](HibiWidgets/SmallPaperView.swift) / [LargePaperView.swift](HibiWidgets/LargePaperView.swift).
- [PlusLockOverlay.swift](HibiWidgets/PlusLockOverlay.swift) — `.plusLocked(_:)` modifier: desaturate/blur + lock chip when Plus isn't owned.
- [ToggleReminderCompletionIntent.swift](HibiWidgets/ToggleReminderCompletionIntent.swift) — interactive AppIntent that flips `EKReminder.isCompleted` and optimistically updates the snapshot (Plus-gated).

### Tests (`HibiTests/`)

XCTest. Compile-checked here; run on a device by the user.

- [AppIconUnlockTests.swift](HibiTests/AppIconUnlockTests.swift) — icon gating (free vs. Plus, install-date / `isPlus` logic).
- [PlusEntitlementStoreTests.swift](HibiTests/PlusEntitlementStoreTests.swift) — App-Group entitlement persistence across store instances.
- [StampSeedTests.swift](HibiTests/StampSeedTests.swift) — stamp seed determinism + 24-bit Float-safe range.

### Assets, resources, scripts

- `Hibi/Fonts/` — `InstrumentSerif-Regular.ttf`, `InstrumentSerif-Italic.ttf` (registered at launch via CoreText, **not** in Info.plist).
- `Hibi/Resources/stamps.json` + `Hibi/Resources/StampMasks/*.png` — stamp definitions and 256×256 grayscale mask PNGs (bright = ink).
- `Hibi/Assets.xcassets` — colors + app icons; `Hibi/AppIcon.icon` — Liquid Glass icon bundle.
- `Hibi.storekit` — local StoreKit config: one non-consumable (`com.weichart.hibi.plus`).
- `Config.xcconfig` (optionally includes the gitignored `Local.xcconfig`) + `Local.xcconfig.template` — developer `DEVELOPMENT_TEAM` only.
- `scripts/bootstrap.sh` — copies the xcconfig template and installs the pre-commit hook.
- `scripts/pre-commit` — blocks committing a hardcoded `DEVELOPMENT_TEAM` in `project.pbxproj`.
- `docs/superpowers/{plans,specs}/` — design docs / implementation plans for recent features (widget, Plus settings, app-icon settings, scroll unification).

## Conventions & gotchas

- **Locale is pinned to `de_DE`** inside the stores' `Calendar` and `DateFormatter` (week-start, 24h HH:mm times). User-visible month/day names in `SampleData` are English. Don't re-derive locale from the environment without checking whether a string is labeled German-week or English-month.
- **Always localize user-facing strings — no exceptions.** Every string the user can see goes through `String(localized: "…")` (or `Text("…")` / `LocalizedStringKey` in SwiftUI), and the key MUST be added to [Hibi/Localizable.xcstrings](Hibi/Localizable.xcstrings) with translations for **all 11 shipping locales**: `de`, `en`, `es`, `it`, `ja`, `ko`, `ms`, `pt-BR`, `zh-Hans-CN`, `zh-Hant-HK`, `zh-Hant-TW`. Empty `localizations: { }` is a bug — it ships English to non-English users (this has happened before; the v1.8 What's New strings were caught only because a user noticed Japanese fell back to English). Same rule for `Hibi/InfoPlist.xcstrings` (usage descriptions, etc.). This also covers **widget** strings and What's New entries. Before declaring any feature done, grep the diff for hard-coded `"…"` literals near `Text(`, `.init(`, alerts, button labels, accessibility labels, and What's New entries — every one of them needs an xcstrings entry with all 11 translations filled in.
- **Translate naturally, not literally.** A translation should read like a sentence a native speaker would actually write — not a word-for-word mapping of the English source. Concrete failure modes that have shipped here: passive past participles as titles in German/Japanese/Korean (`"Verfeinerte Monatsansicht"`, `"整えられた月表示"`, `"다듬어진 월 보기"` — all sound like Google Translate); calque katakana like `ループアイコン` instead of Apple's `繰り返しマーク`; "loop icon" rendered as `循环图标`/`循環圖示` when Apple's Chinese consistently uses `重复/重複` for recurrence; idioms like "breathing room" rendered literally as `ruang nafas yang sepatutnya` (ms) or `o espaço que merece` (pt-BR). Rules: prefer noun phrases or native release-note style for short titles, not past-participle adjectives; match Apple's localized terminology for system concepts (look at how iOS Calendar/Reminders phrases the same idea in that locale); rewrite English idioms into the target language's equivalent rather than translating word-for-word; if a translation reads stiff or technical when the English is warm and conversational, redo it. When unsure, ask the user before shipping rather than guessing literally.
- **App Group is the only app↔widget channel.** The widget extension is a separate process — it can't read the app's in-memory stores or standard `UserDefaults`. Anything the widget needs (today's events/reminders, weather, Plus entitlement, unit/time preferences) must be written to `group.com.weichart.hibi` (via `AppGroup.swift`) by the app and read back as a Codable snapshot. After changing Plus state or today's data, reload widget timelines (`WidgetCenter`).
- **Plus is gated in three places, not one.** `PlusStore`/`PlusEntitlementStore.isPlus` is the source of truth; alternate icons (`AppIconManager`), the on-paper stamp (`HibiPlusView`/`HibiStamp`), and the widget reminder toggle (`ToggleReminderCompletionIntent`) each check it independently. Keep them consistent and remember the widget reads the App-Group mirror, not `PlusStore`.
- **The stamp must be deterministic.** Seed comes from the purchase UUID (FNV-1a, masked to 24 bits for `Float` safety) and stays fixed for the life of the purchase. Release always uses `StampNoise.defaultValues`; only DEBUG reads the tunable persisted values. Read the **stamp-ink-noise** skill before editing the pipeline.
- **Demo mode is DEBUG-only.** Guarded by `#if DEBUG` both in `EventStore.setDemoMode` and in the Settings UI. In release builds the flag reads `false` and the toggle doesn't appear.
- **Fonts aren't declared in Info.plist** — they're registered via `CTFontManagerRegisterFontsForURL` in `HibiApp.init` (and again in the widget bundle, since it's a separate process). Always reference them through `AppFont.serifRegular` / `AppFont.serifItalic`.
- **Tap-an-active-tab returns to now.** `ContentView.selectionBinding` detects "selected → selected" and bumps `scrollToNowToken`; views react via `.onChange(of: scrollToNowToken)`. Don't break this by replacing the binding with `$selection` directly.
- **EventKit writes go through `EventEditorSheet` (`EKEventEditViewController`)** — not our own forms. The `+` toolbar button is disabled in demo mode or without full access.
- **Pastel tints are dynamic `Color`s** that resolve differently in light vs. dark. Don't snapshot them to static hex values.
- **Dark mode is intentionally high-contrast** (front paper = `#242424`, back = pure black matching the app bg). The gradient parameters in `ContentView.backgroundGradient` are tuned by eye — changing them will visibly shift the mood.
- **Never commit a hardcoded `DEVELOPMENT_TEAM`.** It lives in the gitignored `Local.xcconfig`; the `scripts/pre-commit` hook rejects pbxproj diffs that hardcode it. Run `scripts/bootstrap.sh` on a fresh clone.

## Skills worth reaching for

The repo ships curated Agent skills under `.agents/skills/` (symlinked at `.claude/skills`). Most work here maps to:

- **SwiftUI layout / tabs / scrolling / Liquid Glass** → `swiftui-metal-shaders` for shader-backed views, `liquid-glass-design` for iOS 26 glass; check [learnings.md](learnings.md) first for the infinite-scroll patterns.
- **The Plus rubber-stamp (Metal)** → `stamp-ink-noise` (pipeline + parameters), `msl-techniques` (MSL/noise/SDF fundamentals), `swiftui-metal-shaders` (the `[[stitchable]]` integration), `metal-motion-effects` (tilt/gyro driving the shader).
- **Widgets / Live Activities / App Intents** → `widgetkit`.
- **Concurrency (nonisolated delegates, actor isolation, Swift 6)** → `swift-concurrency`.
- **Cutting a release** → `create-release` (version bump + What's New + localizations + tag).
- **Process skills** — `systematic-debugging`, `test-driven-development`, `writing-plans` / `executing-plans`, `requesting-code-review` / `receiving-code-review`, `verification-before-completion`.

Third-party skills are pinned in `skills-lock.json` (`liquid-glass-design`, `nothing-design`, `swift-concurrency`, `widgetkit`).
