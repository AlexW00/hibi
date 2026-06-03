# Localized App Store screenshots

Automated, re-runnable screenshots of the app in every App Store language, built
on [`fastlane snapshot`](https://docs.fastlane.tools/actions/snapshot/) driving a
UI test through demo mode.

## TL;DR

```sh
brew install fastlane        # one-time
./scripts/screenshots.sh     # pick a simulator, wait, done
```

Output lands in `screenshots/<locale>/` — one folder per locale:
`en-US`, `zh-Hans`, `zh-Hant`, `ja`, `ko`. Open `screenshots/screenshots.html`
to review the whole set, then drag the folders into App Store Connect.

## How it works

1. **`scripts/screenshots.sh`** is the entry point. It:
   - fetches fastlane's `SnapshotHelper.swift` into `HibiUITests/` if missing,
   - runs **`scripts/setup_screenshots.rb`**, which idempotently adds the
     `HibiUITests` UI-test target and a shared `HibiScreenshots` scheme to
     `Hibi.xcodeproj` (programmatically, via the `xcodeproj` gem — never a
     hand-edited `project.pbxproj`),
   - lists available iPhone **simulators** and lets you pick one (or set
     `DEVICE="iPhone 16 Pro Max"` to skip the menu),
   - runs `fastlane snapshot`.

2. **`fastlane/Snapfile`** holds the language list, the default device
   (6.9" Pro Max = the required App Store iPhone size), the scheme, and a clean
   status bar override.

3. **`HibiUITests/ScreenshotUITests.swift`** launches the app with
   `-uiTestScreenshots` and captures seven screens per locale, relaunching with
   an extra flag for the seeded / gallery states. Tabs are tapped **by index**,
   not by (localized) label, so it works in every language:

   | File | What | How |
   |---|---|---|
   | `01-Month` | Month tab | tab 0 |
   | `02-Week` | Week tab | tab 1 |
   | `03-Day` | Day tab | tab 2 |
   | `04-Day-Tear` | Day, paper torn mid-swipe | `-uiTestScene dayTear` seeds `DayView.dragY` |
   | `05-Day-Collapsed` | Day, schedule expanded | `-uiTestScene dayCollapsed` seeds `scheduleProgress = 1` |
   | `06-Widget-Schedule` | Schedule widget (medium + large) | `-uiTestScene widgetsSchedule` → `WidgetGalleryView` |
   | `07-Widget-Today` | Today's Page widget (small + large) | `-uiTestScene widgetsToday` → `WidgetGalleryView` |

   All special states key off a single `-uiTestScene <name>` arg, resolved once
   in `DemoEnvironment.Scene` — so screenshot special-casing stays in one place.

   **Widgets** can't be screenshotted on the real Home Screen by XCUITest, so
   `WidgetGalleryView` hosts the actual `EventsWidgetView` / `TodaysPageWidgetView`
   *inside the app* at real widget sizes, fed demo entries
   (`DemoFixtures+WidgetSnapshots`). The widget view files are shared into the app
   target via a membership exception in `project.pbxproj` (this project uses Xcode
   16 synchronized folder groups). The Plus entitlement is flipped on for those
   launches so the widgets render unlocked.

4. The app reacts to `-uiTestScreenshots` via **`DemoEnvironment.isScreenshotRun`**:
   - `EventStore` / `WeatherStore` force **demo mode** on — curated events,
     reminders, and a synthesized forecast (`DemoFixtures`), so no real
     calendar / reminders / location / network are touched, and screenshots are
     identical run to run.
   - The onboarding and "What's New" sheets are suppressed.
   - Demo fixtures are localized by `Locale.preferredLanguages`, which fastlane
     sets per run — `zh-Hans` → Simplified, `zh-Hant` → Traditional, etc.

## Customizing

- **Which screens** → edit `ScreenshotUITests.swift` (add `snapshot("04-…")`
  after navigating). To shoot the Hibi Plus sheet, open Settings (the gear) and
  drill in before calling `snapshot`.
- **Languages / device** → edit `fastlane/Snapfile`.
- **Demo data** → one today-anchored model in `Hibi/Models/DemoFixtures.swift`
  (the `highlightEvents` schedule = the per-day event counts; `reminderSlots` =
  reminders; ambient filler fills the Month grid). All words live in
  `DemoStrings.swift` (every locale in one file); weather in
  `DemoFixtures+Weather.swift`; widget entries in `DemoFixtures+WidgetSnapshots.swift`.

## Notes & limits

- Demo mode is `#if DEBUG`-only, so screenshots come from a **Debug** build (the
  `HibiScreenshots` scheme builds Debug). That's intentional.
- **Simulator** is the target by design: it guarantees the exact App Store pixel
  size and a clean 09:41 status bar. A physical device works too (pass its name
  via `DEVICE=…`), but its status bar can't be faked and it only fits the App
  Store 6.9" slot if it's a Pro Max.
- The `HibiUITests` target and `HibiScreenshots` scheme are committed once the
  setup script has run; `SnapshotHelper.swift` and the `screenshots/` output are
  git-ignored (regenerated on demand).
- This repo's CI/build hosts are Linux; the screenshot flow needs **macOS +
  Xcode** and is run locally.
