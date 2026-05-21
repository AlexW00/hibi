# Today's Page widget — design spec

**Status:** proposed
**Author:** Alex (via Claude)
**Date:** 2026-05-21

## What we're building

A home‑screen widget that renders the **top paper** of the Day tab's paper stack — nothing else. No stack, no schedule, no masthead, no "pull to tear" hint. The widget always displays the current day; there is no configuration.

Two sizes, both square, both the same widget kind:

- **`.systemSmall` ("Today's Page", small)** — mirrors the *collapsed* paper state from the Day tab: binding holes, weekday name, big day numeral with today‑underline, perforation edge. No weather, no sunrise/sunset, no month/year sub‑text.
- **`.systemLarge` ("Today's Page", large)** — mirrors the *expanded* paper state: every paper element (binding holes, sunrise/sunset corners, weekday, big numeral with today‑underline, month/year, weather pill with high/low + location, Apple Weather attribution, perforation).

This is v1 of a wider widget surface. The architecture leaves room for an "Event list" widget and others later.

## Why

Users want Hibi on their home screen. The Day‑tab paper is the single most recognisable piece of Hibi visually — putting it on the home screen costs nothing in concept work and gives the app continuous presence without rebuilding a new visual language for the widget.

## Goals & non‑goals

**Goals**

- Visually identical to the in‑app top paper (collapsed for small, expanded for large) at native widget sizes.
- Reuses the existing paper components (`BindingHoles`, `PerforationEdge`, `PaperTints`, `PageContent`, `WeatherIcon`, `MarqueeText`, `AppFont`) — no duplicated drawing code.
- Updates correctly across the midnight rollover.
- Tapping the widget deep‑links into the Day tab on today.
- Respects the existing 11‑locale localisation rule.

**Non‑goals (v1)**

- No `.systemMedium`, no `.systemExtraLarge`, no accessory/Lock Screen widgets, no Live Activities, no Control Center controls.
- No configurability (date picker, theme override, etc).
- No event list inside this widget. (That's a separate widget kind, later.)
- No widget‑side WeatherKit, CoreLocation, or EventKit calls.

## Architecture

### Targets

- **New target:** `HibiWidgets` (Widget Extension, iOS 26 deployment target, Swift 5, same project).
- One `@main WidgetBundle` exposing one widget kind: `TodaysPageWidget`. The widget's `supportedFamilies([.systemSmall, .systemLarge])` declares both sizes — single gallery entry with a size picker.
- The widget extension links against shared types via **target membership** (no library target). Files added to both `Hibi` and `HibiWidgets`:
  - `Hibi/Views/Components/PaperChrome.swift` (BindingHoles, PerforationEdge)
  - `Hibi/Views/PaperTints.swift`
  - `Hibi/Views/Components/WeatherIcon.swift`
  - `Hibi/Views/Components/MarqueeText.swift`
  - `Hibi/Models/SampleData.swift` (for `MonthNames`, `DayNames`, `AppFont`, `AppColor`, `daysInMonth`/`weekday`)
  - `Hibi/Models/CalendarEvent.swift` — *only* the `DayWeather` + `WeatherCode` types are needed; the rest of the file is harmless to include but we should consider extracting `DayWeather`/`WeatherCode` to their own file if compile time matters (defer unless it does).
  - `Hibi/Models/Preferences.swift` (for `TimeFormat`, `TemperatureUnit` — both read by the page content)
  - **New shared files** (added below): `WidgetWeatherSnapshot.swift`, `AppGroup.swift`, `SharedPageContent.swift`.

### Data flow

Widgets run in a **separate process** and cannot share `EventStore` / `WeatherStore` in memory. The widget reads a snapshot the main app writes via an App Group.

```
Main app (Hibi)
  └── WeatherStore.apply(...)
        ├── updates in-memory `weatherByDay`
        └── writes `WidgetWeatherSnapshot` JSON to
              UserDefaults(suiteName: "group.com.weichart.hibi")
            then calls WidgetCenter.shared.reloadAllTimelines()

Widget (HibiWidgets)
  └── TodaysPageTimelineProvider.timeline(in:)
        ├── reads snapshot from group UserDefaults
        ├── emits one entry per day for the next 3 days
        └── reload policy: .after(midnight of day 3 + 1 min)
```

### App Group

- Identifier: `group.com.weichart.hibi`
- Capability added to **both** the `Hibi` and `HibiWidgets` targets.
- Shared keys (single key only): `widget.todaysPage.snapshot.v1` → JSON `WidgetWeatherSnapshot`.

The `.v1` suffix is forward‑defence: if we change the snapshot shape later, we bump the key rather than crashing the widget on decode of an old blob.

### Shared types

```swift
// AppGroup.swift  (member of Hibi + HibiWidgets)
enum AppGroup {
    static let identifier = "group.com.weichart.hibi"
    static let snapshotKey = "widget.todaysPage.snapshot.v1"
    static let defaults: UserDefaults? = UserDefaults(suiteName: identifier)
}

// WidgetWeatherSnapshot.swift  (member of Hibi + HibiWidgets)
struct WidgetWeatherSnapshot: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int
    let high: Double        // Celsius (display layer converts)
    let low: Double         // Celsius
    let code: WeatherCode   // already RawRepresentable: String
    let sunrise: Date?
    let sunset: Date?
    let locationName: String?
    let capturedAt: Date
}
```

### WeatherStore changes (main app)

At the end of `WeatherStore.apply(...)`:

```swift
let todayKey = DayKey(year: y, month: m, day: d)  // today, via self.calendar
if let today = byDay[todayKey] {
    let snapshot = WidgetWeatherSnapshot(
        year: todayKey.year, month: todayKey.month, day: todayKey.day,
        high: today.high, low: today.low, code: today.code,
        sunrise: today.sunrise, sunset: today.sunset,
        locationName: placeName ?? self.locationName,
        capturedAt: Date()
    )
    if let data = try? JSONEncoder().encode(snapshot) {
        AppGroup.defaults?.set(data, forKey: AppGroup.snapshotKey)
    }
    WidgetCenter.shared.reloadAllTimelines()
}
```

Also call `WidgetCenter.shared.reloadAllTimelines()` from `ContentView.onAppear` as a belt‑and‑braces refresh on app launch.

## Timeline

`TodaysPageTimelineProvider: TimelineProvider` (not `AppIntentTimelineProvider` — no configuration).

- `placeholder(in:)` — returns an entry for today with `snapshot = nil`. Synchronous, no I/O.
- `getSnapshot(in:completion:)` — reads cached snapshot, builds a single entry for `Date()`. Used by the widget gallery preview.
- `getTimeline(in:completion:)` — builds three entries:
  - **Entry 0:** date = now (or today's 00:00:01 if we're past it — really just "now"), `snapshot = cached if matches today's date, else nil`.
  - **Entry 1:** date = tomorrow 00:00:01 (local), `snapshot = cached if matches that date, else nil`.
  - **Entry 2:** date = day‑after 00:00:01 (local), `snapshot = cached if matches that date, else nil`.
  - Reload policy: `.after(<entry 2 date + 60s>)`.
- All three entries also carry `daysSinceCapture: Int` derived from `(entryDate - snapshot.capturedAt)` so the view can branch on "stale ≥ 3 days".
- The "always‑today" rule: every entry's `displayedDate` is its own `date`, not a fixed `Date.now`. WidgetKit picks which entry to render based on wall‑clock time, so the entry's `date` *is* "today" at the moment it renders. This is how the midnight rollover works without any extra plumbing.

### Refresh budget sanity check

Apple budgets 40–70 timeline reloads / day. We trigger reloads from:

- (a) main app foreground (`ContentView.onAppear`)
- (b) any WeatherStore fetch completion (already throttled to once per 30 min)
- (c) at most once on the 3‑day fallback boundary

Well inside budget.

## Views

### `TodaysPageEntry`

```swift
struct TodaysPageEntry: TimelineEntry, Sendable {
    let date: Date                            // when WidgetKit displays this entry
    let day: Int                              // derived from `date` in local calendar
    let month: Int
    let year: Int
    let snapshot: WidgetWeatherSnapshot?      // nil if cache missing or wrong date
    let daysSinceCapture: Int?                // nil if no snapshot
}
```

### `TodaysPageWidget`

```swift
struct TodaysPageWidget: Widget {
    let kind = "TodaysPageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysPageTimelineProvider()) { entry in
            TodaysPageWidgetView(entry: entry)
                .containerBackground(PaperTints.card1, for: .widget)
                .widgetURL(URL(string: "hibi://today"))
        }
        .configurationDisplayName(String(localized: "Today's Page"))
        .description(String(localized: "Today as a tear-off page."))
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()  // we draw our own paper edge with rounded corners
    }
}
```

### `TodaysPageWidgetView`

```swift
@Environment(\.widgetFamily) private var family

var body: some View {
    switch family {
    case .systemLarge:  largeBody
    default:            smallBody
    }
}
```

Both branches render a single rounded‑corner card (`RoundedRectangle(cornerRadius: 18)`) filled with `PaperTints.card1`, with the same hairline border the in‑app cards use (so dark mode reads cleanly against the home‑screen background), `BindingHoles` overlay at the top, `PerforationEdge` overlay at the bottom.

### Small body (collapsed paper)

Composition mirrors `DayView` at `scheduleProgress == 1`, where `chromeFadeOpacity → 0`:

- Binding holes overlay (top, same component, full opacity).
- Weekday name centered horizontally — `AppFont.serifItalic`, size scaled to ~14pt at `.systemSmall`. Reads from `DayNames.full[SampleData.weekday(...)]`.
- Big day numeral centered — `AppFont.serifRegular`, size 72pt with `.minimumScaleFactor(0.55)` and `.lineLimit(1)`, with the today underline (`Rectangle` 60×1.2pt offset y: -6pt). Underline is **always** drawn — the widget only shows today.
- Perforation overlay (bottom, same component).
- No weather row, no sunrise/sunset, no month/year subtext, no Apple Weather attribution.

No `snapshot` data is read for the small widget — so it's never stale.

### Large body (expanded paper)

Reuses the existing `PageContent` view from `DayView.swift`. We extract `PageContent` into its own file `Hibi/Views/Components/PageContent.swift` and add it to both targets (no behavior change).

Mapping:
- `day/month/year` from `entry.day/month/year`.
- `isToday = true` (always — the widget only shows today).
- `weather: DayWeather?` — built from `entry.snapshot` if present, else `nil`.
- `locationName: String?` — from `entry.snapshot?.locationName`.
- `preview: false`.
- `chromeFade: 1.0`.

Wrapped in the same rounded card + binding holes overlay + perforation overlay as the small.

### Stale fallback (large only)

When `entry.snapshot == nil` **and** `entry.daysSinceCapture ?? .max >= 3`, replace the weather pill row with a single italic line: *"Open Hibi to update"* (localised). When `entry.snapshot == nil` but `daysSinceCapture < 3` (or never captured), hide the whole bottom row — same look as the in‑app paper on a no‑weather day. Apple Weather attribution is **only** shown when weather data is actually rendered (otherwise we'd be claiming attribution for nothing).

### Liquid Glass / accented rendering

Set `.widgetAccentedRenderingMode(.fullColor)` on the root so the paper tint, weather icon, and underline render in full colour in iOS 26's accented variant. The editorial palette is the whole point of Hibi — desaturated would lose it.

## Localisation

User‑facing strings introduced by this feature, **all must be added to `Hibi/Localizable.xcstrings` with translations in all 11 shipping locales** (de, en, es, it, ja, ko, ms, pt‑BR, zh‑Hans‑CN, zh‑Hant‑HK, zh‑Hant‑TW) per the project rule:

| Key | English | Where |
|---|---|---|
| `Today's Page` | Today's Page | `configurationDisplayName` |
| `Today as a tear-off page.` | Today as a tear-off page. | `.description` |
| `Open Hibi to update` | Open Hibi to update | Stale‑fallback line |

(Translate naturally per the AGENTS.md guidance — no past‑participle adjectives, match Apple's localised vocabulary where applicable.)

Weekday and month names continue to come from `DayNames.full` / `MonthNames.full`, which are intentionally English per the existing project convention.

The widget target also needs the `Localizable.xcstrings` available — we add the existing `Hibi/Localizable.xcstrings` to the widget target's membership so the same keys resolve. (Alternative: separate widget‑target xcstrings. We pick shared membership to avoid maintaining two catalogs.)

## Fonts

The widget extension needs Instrument Serif loaded before any view renders. We replicate the registration trick used in `HibiApp.init`:

```swift
// HibiWidgetsBundle.swift
@main
struct HibiWidgetsBundle: WidgetBundle {
    init() { AppFont.registerInstrumentSerifIfNeeded() }
    var body: some Widget { TodaysPageWidget() }
}
```

`registerInstrumentSerifIfNeeded()` is added to `SampleData.swift` (where `AppFont` lives) as an idempotent helper using `CTFontManagerRegisterFontsForURL`. The two `.ttf` files (`Hibi/Fonts/InstrumentSerif-Regular.ttf`, `Hibi/Fonts/InstrumentSerif-Italic.ttf`) are added to the widget target's bundle resources.

## Tap behavior

`widgetURL(URL(string: "hibi://today")!)` is set on the widget body. The main app must:

1. Add `hibi` to **CFBundleURLTypes / URL Schemes** in the Info plist (Xcode UI).
2. Handle the URL in `HibiApp` via `.onOpenURL { ... }` on the root view. Behavior: switch the active tab to Day, set `selectedDay` to today, bump `scrollToNowToken` so the Day view scrolls to "now".

## Accessibility

- Both sizes provide an `accessibilityLabel` that reads (e.g.) "Thursday, May 21. 19 degrees high, 9 degrees low. Sunny." (Large; for small, "Thursday, May 21."). Built in the view, not from the entry.
- Children are ignored (`.accessibilityElement(children: .ignore)`) so VoiceOver doesn't read each text node individually.
- Numerals respect `.minimumScaleFactor` and remain legible at the smallest dynamic type setting; we do **not** opt in to `.dynamicTypeSize(...)` overrides because the widget is fixed‑size.
- Hairline border on the card defines the silhouette in dark mode (same trick as the in‑app card).

## Edge cases

| Case | Behavior |
|---|---|
| Cache key absent (fresh install, never fetched) | Snapshot = nil → small unaffected; large hides weather row, *no* stale hint (daysSinceCapture = nil) |
| Cache present but for a different day | Snapshot = nil → same as above |
| Cache present for today | Snapshot used; no stale hint |
| Cache from 3+ days ago | Snapshot = nil, daysSinceCapture ≥ 3 → large shows "Open Hibi to update" italic line |
| Midnight rollover | Next timeline entry fires automatically; widget shows the new day; snapshot likely becomes "wrong date" until the app is opened and refreshes |
| User has dark mode on | `PaperTints.card1` resolves to the dark variant; hairline border switches to white@12%; perforation/holes already use dynamic colors |
| WeatherKit error | Main app already logs and falls back; snapshot is simply not written that fetch cycle. Widget keeps showing the most recent snapshot until it ages past 3 days |
| Demo mode (DEBUG) | The widget reads the same App Group cache — it sees real device weather, not demo fixtures. This is fine and intentional: demo mode is for in‑app screenshots, not widget previews |

## What you need to do manually in Xcode

I cannot do these from the Claude session — they live in the Xcode project UI:

1. **Add a Widget Extension target** named `HibiWidgets` (File → New → Target → Widget Extension). Uncheck "Include Live Activity" and "Include Configuration App Intent". Bundle ID `com.weichart.hibi.HibiWidgets`. Deployment target iOS 26.0.
2. **Add App Groups capability** to *both* `Hibi` and `HibiWidgets` targets. Group: `group.com.weichart.hibi`. (Signing & Capabilities → + Capability → App Groups, then check the box.)
3. **Add shared file target membership.** Open the File Inspector for each of these and check the `HibiWidgets` box:
   - `Hibi/Views/Components/PaperChrome.swift`
   - `Hibi/Views/PaperTints.swift`
   - `Hibi/Views/Components/WeatherIcon.swift`
   - `Hibi/Views/Components/MarqueeText.swift`
   - `Hibi/Models/SampleData.swift`
   - `Hibi/Models/CalendarEvent.swift`
   - `Hibi/Models/Preferences.swift`
   - `Hibi/Localizable.xcstrings`
   - the new `AppGroup.swift`, `WidgetWeatherSnapshot.swift`, `PageContent.swift` (after I extract it)
4. **Add the fonts** `Hibi/Fonts/InstrumentSerif-Regular.ttf` and `Hibi/Fonts/InstrumentSerif-Italic.ttf` to the `HibiWidgets` target's Copy Bundle Resources phase (File Inspector → check `HibiWidgets`).
5. **Register the URL scheme** `hibi` in the main app's Info plist: Project → `Hibi` target → Info → URL Types → add row, `URL Schemes = hibi`, `Identifier = com.weichart.hibi`.

I'll list these again, in order, in the implementation plan so they're impossible to miss.

## Out of scope (future widgets)

Captured here so the architecture stays honest:

- **Event list widget** (`.systemMedium` / `.systemLarge`) — reads from a *second* App Group key: today's events serialised as a small array. The `EventStore.reload` path would write it. Same widget bundle, different widget kind. Defer entirely.
- **Lock Screen accessory widgets** — possible but unspec'd.
- **Live Activity** — no source event for one.

## Open questions

None remaining. The design is concrete enough to write a plan against.
