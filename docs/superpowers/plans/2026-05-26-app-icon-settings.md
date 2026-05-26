# App Icon Settings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "App Icon" settings screen where users can switch between 8 icons: the default icon, an "Early User" legacy icon (restricted to pre-July-2026 installs), and 6 additional alternate icons (Disco Balloon, Leatherbag, Pearl Hibi, Pixel Sun, Porcelain, Wood Stroke). The architecture makes adding future icons trivial — one array entry each.

**Architecture:** An `AppIconManager` (`@Observable`, `@MainActor`) holds a static registry of `AppIconOption` values and manages selection via `UIApplication.shared.setAlternateIconName`. Install-date detection uses StoreKit 2's `AppTransaction.shared` → `originalPurchaseDate` (authoritative App Store date) with a `UserDefaults`-based fallback for dev/TestFlight. The settings sub-page (`AppIconSettingsView`) is pushed onto the existing `NavigationStack` from `SettingsView`, matching the Appearance/Units/Calendars pattern.

**Tech Stack:** SwiftUI (iOS 26), StoreKit 2 (`AppTransaction`), `UIApplication.setAlternateIconName`, `Localizable.xcstrings` (11 locales).

---

## Environment / verification reality

- **No simulator.** The user tests on a physical device. Build-only (`build_sim` or `xcodebuild build`) to verify compilation. Never launch, run, or deploy to a simulator.
- Alternate icon switching (the system alert, the Home Screen icon change) must be verified on-device.
- All `.icon` bundles and preview PNGs have already been copied into the project (Task 1 is pre-completed).
- `.icon` bundles: `Hibi/EarlyUser.icon`, `Hibi/DiscoBalloon.icon`, `Hibi/Leatherbag.icon`, `Hibi/PearlHibi.icon`, `Hibi/PixelSun.icon`, `Hibi/Porcelain.icon`, `Hibi/WoodStroke.icon`
- Preview PNGs: `Hibi/Assets.xcassets/AppIconPreview-{Default,EarlyUser,DiscoBalloon,Leatherbag,PearlHibi,PixelSun,Porcelain,WoodStroke}.imageset/`

## File structure

| Action | Path | Responsibility |
|--------|------|----------------|
| **Done** | `Hibi/{EarlyUser,DiscoBalloon,Leatherbag,PearlHibi,PixelSun,Porcelain,WoodStroke}.icon/` | Alternate icon bundles (already copied) |
| **Done** | `Hibi/Assets.xcassets/AppIconPreview-*.imageset/` | Preview PNGs for all 8 icons (already copied) |
| **Create** | `Hibi/Models/AppIconManager.swift` | `AppIconOption` model, 8-icon registry, selection logic, install-date detection |
| **Create** | `Hibi/Views/AppIconSettingsView.swift` | Grid/list UI for icon selection, lock badge for restricted icons |
| **Modify** | `Hibi/Views/SettingsView.swift:35–56` | Add "App Icon" `NavigationLink` row in the General section |
| **Modify** | `Hibi/HibiApp.swift:21–28` | Record install date on first launch |
| **Modify** | `Hibi/ContentView.swift` | Create `AppIconManager` as `@State`, pass via `.environment()` |
| **Modify** | `Hibi/Localizable.xcstrings` | All new user-facing strings × 11 locales |

---

## Task 1: Copy icon assets into the project ✅ PRE-COMPLETED

All `.icon` bundles and preview PNGs have been copied into the project already:
- 7 alternate `.icon` bundles: `Hibi/{EarlyUser,DiscoBalloon,Leatherbag,PearlHibi,PixelSun,Porcelain,WoodStroke}.icon/`
- 8 preview image sets: `Hibi/Assets.xcassets/AppIconPreview-{Default,EarlyUser,DiscoBalloon,Leatherbag,PearlHibi,PixelSun,Porcelain,WoodStroke}.imageset/`

- [x] **Step 1: Verify with a build**

```bash
xcodebuild -project Hibi.xcodeproj -scheme Hibi \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Expected: **BUILD SUCCEEDED**. If it fails, investigate whether `.icon` bundles need explicit `project.pbxproj` references or `CFBundleAlternateIcons` entries in `Info.plist`.

- [x] **Step 2: Commit**

```bash
git add Hibi/EarlyUser.icon Hibi/DiscoBalloon.icon Hibi/Leatherbag.icon \
        Hibi/PearlHibi.icon Hibi/PixelSun.icon Hibi/Porcelain.icon Hibi/WoodStroke.icon \
        Hibi/Assets.xcassets/AppIconPreview-*.imageset
git commit -m "feat: add all alternate icon bundles and preview images"
```

---

## Task 2: Record install date on first launch

**Files:**
- Modify: `Hibi/HibiApp.swift:21–28`

The existing `markWhatsNewSeenOnFreshInstall()` already runs on first launch (guarded by `hasLaunchedBefore`). We piggyback on that same guard to record the install date.

- [ ] **Step 1: Add install-date recording inside the existing first-launch guard**

In `HibiApp.swift`, modify `markWhatsNewSeenOnFreshInstall()` to also persist the current date as the install date. This captures the date for all NEW installs going forward. Existing users who already have `hasLaunchedBefore = true` won't hit this path — they'll be handled by the StoreKit 2 fallback in `AppIconManager` (Task 3).

```swift
private static func markWhatsNewSeenOnFreshInstall() {
    let defaults = UserDefaults.standard
    let firstLaunchKey = "hasLaunchedBefore"
    if !defaults.bool(forKey: firstLaunchKey) {
        NoteletStorage.markCurrentVersionAsSeen()
        defaults.set(true, forKey: firstLaunchKey)
        if defaults.object(forKey: "firstInstallDate") == nil {
            defaults.set(Date(), forKey: "firstInstallDate")
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Hibi/HibiApp.swift
git commit -m "feat: record install date on first launch for icon unlock gating"
```

---

## Task 3: Create `AppIconManager` model

**Files:**
- Create: `Hibi/Models/AppIconManager.swift`

This is the core model. It defines the icon registry, manages selection, and determines install-date-based unlock eligibility.

- [ ] **Step 1: Create `AppIconManager.swift` with the full model**

```swift
import StoreKit
import SwiftUI

// MARK: - Icon option model

struct AppIconOption: Identifiable {
    let id: String
    let displayName: LocalizedStringResource
    let description: LocalizedStringResource
    let previewAssetName: String
    /// `nil` = primary/default icon. Non-nil = the name passed to
    /// `UIApplication.shared.setAlternateIconName(_:)`.
    let alternateIconName: String?
    let unlock: Unlock

    enum Unlock {
        case always
        case beforeDate(Date)
    }
}

// MARK: - Manager

@Observable
@MainActor
final class AppIconManager {
    private(set) var selectedIconID: String
    private(set) var installDate: Date?

    static let icons: [AppIconOption] = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let cutoff = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!

        return [
            AppIconOption(
                id: "default",
                displayName: "Default",
                description: "The current Hibi icon.",
                previewAssetName: "AppIconPreview-Default",
                alternateIconName: nil,
                unlock: .always
            ),
            AppIconOption(
                id: "early-user",
                displayName: "Early User",
                description: "For those who were there from the start.",
                previewAssetName: "AppIconPreview-EarlyUser",
                alternateIconName: "EarlyUser",
                unlock: .beforeDate(cutoff)
            ),
            AppIconOption(
                id: "disco-balloon",
                displayName: "Disco Balloon",
                description: "A shimmering disco calendar.",
                previewAssetName: "AppIconPreview-DiscoBalloon",
                alternateIconName: "DiscoBalloon",
                unlock: .always
            ),
            AppIconOption(
                id: "leatherbag",
                displayName: "Leatherbag",
                description: "Warm leather-bound planner.",
                previewAssetName: "AppIconPreview-Leatherbag",
                alternateIconName: "Leatherbag",
                unlock: .always
            ),
            AppIconOption(
                id: "pearl-hibi",
                displayName: "Pearl",
                description: "Iridescent pearl pages.",
                previewAssetName: "AppIconPreview-PearlHibi",
                alternateIconName: "PearlHibi",
                unlock: .always
            ),
            AppIconOption(
                id: "pixel-sun",
                displayName: "Pixel Sun",
                description: "A pixelated sunrise.",
                previewAssetName: "AppIconPreview-PixelSun",
                alternateIconName: "PixelSun",
                unlock: .always
            ),
            AppIconOption(
                id: "porcelain",
                displayName: "Porcelain",
                description: "Delicate blue porcelain.",
                previewAssetName: "AppIconPreview-Porcelain",
                alternateIconName: "Porcelain",
                unlock: .always
            ),
            AppIconOption(
                id: "wood-stroke",
                displayName: "Wood",
                description: "Brushed kanji on warm wood.",
                previewAssetName: "AppIconPreview-WoodStroke",
                alternateIconName: "WoodStroke",
                unlock: .always
            ),
        ]
    }()

    init() {
        let current = UIApplication.shared.alternateIconName
        self.selectedIconID = Self.icons.first { $0.alternateIconName == current }?.id ?? "default"
    }

    func loadInstallDate() async {
        if let stored = UserDefaults.standard.object(forKey: "firstInstallDate") as? Date {
            self.installDate = stored
            return
        }

        do {
            let appTransaction = try await AppTransaction.shared
            if case .verified(let transaction) = appTransaction {
                let date = transaction.originalPurchaseDate
                UserDefaults.standard.set(date, forKey: "firstInstallDate")
                self.installDate = date
                return
            }
        } catch {}

        // Fallback: existing user who updated but has no recorded date.
        // hasLaunchedBefore is true → they were here before this version.
        if UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            let fallback = Date.distantPast
            UserDefaults.standard.set(fallback, forKey: "firstInstallDate")
            self.installDate = fallback
        }
    }

    func isUnlocked(_ option: AppIconOption) -> Bool {
        switch option.unlock {
        case .always:
            return true
        case .beforeDate(let cutoff):
            guard let install = installDate else { return false }
            return install < cutoff
        }
    }

    func select(_ option: AppIconOption) async {
        guard isUnlocked(option) else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
            selectedIconID = option.id
        } catch {}
    }
}
```

Key design decisions:
- `icons` is a static array — adding a new icon is one array entry.
- `loadInstallDate()` is async because `AppTransaction.shared` is async. Called from `.task {}` in the view.
- **StoreKit 2 path**: `AppTransaction.shared` → `originalPurchaseDate` gives the authoritative App Store install date for production users.
- **Fallback path**: If `UserDefaults` already has `firstInstallDate` (set in Task 1 for new installs), use that. If neither exists but `hasLaunchedBefore` is `true`, the user predates this feature → treat as `distantPast` (always unlocked).
- `select(_:)` calls `setAlternateIconName` which triggers a system alert. This is iOS standard behavior.

- [ ] **Step 2: Commit**

```bash
git add Hibi/Models/AppIconManager.swift
git commit -m "feat: add AppIconManager with icon registry and install-date gating"
```

---

## Task 4: Wire `AppIconManager` into the environment

**Files:**
- Modify: `Hibi/ContentView.swift`

Follow the existing pattern: `eventStore`, `weatherStore`, and `clock` are all `@State` properties on `ContentView` and injected via `.environment()`. Do the same for `AppIconManager`.

- [ ] **Step 1: Add `AppIconManager` as `@State` on `ContentView` and inject it**

```swift
// In ContentView.swift, near the existing @State stores:
@State private var appIconManager = AppIconManager()
```

```swift
// After .environment(clock):
.environment(appIconManager)
```

- [ ] **Step 2: Commit**

```bash
git add Hibi/ContentView.swift
git commit -m "feat: inject AppIconManager into SwiftUI environment"
```

---

## Task 5: Create `AppIconSettingsView`

**Files:**
- Create: `Hibi/Views/AppIconSettingsView.swift`

This is the settings sub-page that displays available icons in a list. Each row shows the icon preview, name, and description. Locked icons show a lock badge and are non-interactive.

- [ ] **Step 1: Create `AppIconSettingsView.swift`**

```swift
import SwiftUI

struct AppIconSettingsView: View {
    @Environment(AppIconManager.self) private var iconManager

    var body: some View {
        List {
            ForEach(AppIconManager.icons) { option in
                AppIconRow(
                    option: option,
                    isSelected: iconManager.selectedIconID == option.id,
                    isUnlocked: iconManager.isUnlocked(option)
                ) {
                    Task { await iconManager.select(option) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .task { await iconManager.loadInstallDate() }
    }
}

private struct AppIconRow: View {
    let option: AppIconOption
    let isSelected: Bool
    let isUnlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // TODO: replace with user-provided preview asset
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(option.previewAssetName)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.ultraThinMaterial, in: Circle())
                                .offset(x: 4, y: 4)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.body)
                        .foregroundStyle(isUnlocked ? .primary : .secondary)
                    Text(option.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !isUnlocked {
                        Text("Available to early users")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accent)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(!isUnlocked)
        .tint(.primary)
    }
}
```

Design notes:
- List style matches existing settings pages (inset grouped).
- Icon preview is a 64×64 rounded rectangle — placeholder until user provides images. The `Image(option.previewAssetName)` will resolve to the provided PNG once added to `Assets.xcassets`.
- Lock badge appears on restricted icons when the user doesn't qualify.
- Selected icon gets a blue checkmark (`.accent` resolves to the system tint).
- The `Button` is `.disabled(!isUnlocked)` so locked icons can't be tapped.
- `.task {}` triggers `loadInstallDate()` which is idempotent (early-returns if already loaded).

- [ ] **Step 2: Commit**

```bash
git add Hibi/Views/AppIconSettingsView.swift
git commit -m "feat: add AppIconSettingsView with icon grid and lock states"
```

---

## Task 6: Wire into `SettingsView`

**Files:**
- Modify: `Hibi/Views/SettingsView.swift:35–56`

Add a new `NavigationLink` row for "App Icon" in the General section, between the Appearance row and the Units row (or after Units — whichever reads better). The row shows the current icon name as a trailing detail.

- [ ] **Step 1: Add the App Icon NavigationLink**

In `SettingsView.swift`, inside the `Section("General")` block, after the Appearance NavigationLink (line ~40), add:

```swift
NavigationLink {
    AppIconSettingsView()
} label: {
    Label("App Icon", systemImage: "app.dashed")
}
```

Also add the environment dependency at the top of `SettingsView`:

```swift
@Environment(AppIconManager.self) private var iconManager
```

- [ ] **Step 2: Commit**

```bash
git add Hibi/Views/SettingsView.swift
git commit -m "feat: add App Icon row in Settings general section"
```

---

## Task 7: Preview image sets ✅ PRE-COMPLETED

All 8 preview image sets are already in `Hibi/Assets.xcassets/AppIconPreview-*.imageset/` with actual PNG files (not placeholders). No work needed.

---

## Task 8: Localize all new strings (11 locales)

**Files:**
- Modify: `Hibi/Localizable.xcstrings`

New strings to localize:

| Key (English) | Context |
|---|---|
| `"App Icon"` | Settings row label + navigation title |
| `"Default"` | Icon name |
| `"The current Hibi icon."` | Icon description |
| `"Early User"` | Icon name |
| `"For those who were there from the start."` | Icon description |
| `"Available to early users"` | Lock explanation on restricted icons |
| `"Disco Balloon"` | Icon name |
| `"A shimmering disco calendar."` | Icon description |
| `"Leatherbag"` | Icon name |
| `"Warm leather-bound planner."` | Icon description |
| `"Pearl"` | Icon name |
| `"Iridescent pearl pages."` | Icon description |
| `"Pixel Sun"` | Icon name |
| `"A pixelated sunrise."` | Icon description |
| `"Porcelain"` | Icon name |
| `"Delicate blue porcelain."` | Icon description |
| `"Wood"` | Icon name |
| `"Brushed kanji on warm wood."` | Icon description |

All 18 strings × 11 locales (de, en, es, it, ja, ko, ms, pt-BR, zh-Hans-CN, zh-Hant-HK, zh-Hant-TW). Translations must be natural, not literal — follow the guidance in AGENTS.md.

- [ ] **Step 1: Add all localized strings**

Open `Localizable.xcstrings` and add entries. Each entry follows the existing pattern in the file. See the translation tables below.

**UI strings:**

| Key | de | es | it | ja | ko | ms | pt-BR | zh-Hans | zh-Hant-HK | zh-Hant-TW |
|---|---|---|---|---|---|---|---|---|---|---|
| App Icon | App-Symbol | Icono de la app | Icona dell'app | アプリアイコン | 앱 아이콘 | Ikon App | Ícone do App | 应用图标 | 應用程式圖示 | 應用程式圖示 |
| Available to early users | Nur für frühe Nutzer | Solo para usuarios pioneros | Solo per i primi utenti | 初期ユーザー限定 | 초기 사용자 전용 | Untuk pengguna awal sahaja | Exclusivo para usuários pioneiros | 仅限早期用户 | 僅限早期用戶 | 僅限早期使用者 |

**Icon names:**

| Key | de | es | it | ja | ko | ms | pt-BR | zh-Hans | zh-Hant-HK | zh-Hant-TW |
|---|---|---|---|---|---|---|---|---|---|---|
| Default | Standard | Predeterminado | Predefinita | デフォルト | 기본 | Lalai | Padrão | 默认 | 預設 | 預設 |
| Early User | Frühe Nutzer | Usuario pionero | Primo utente | 初期ユーザー | 초기 사용자 | Pengguna Awal | Usuário Pioneiro | 早期用户 | 早期用戶 | 早期使用者 |
| Disco Balloon | Diskokugel | Globo disco | Palla da discoteca | ディスコバルーン | 디스코 벌룬 | Belon Disko | Balão Disco | 迪斯科气球 | 迪斯可氣球 | 迪斯可氣球 |
| Leatherbag | Ledertasche | Bolso de cuero | Borsa in pelle | レザーバッグ | 가죽 가방 | Beg Kulit | Bolsa de Couro | 皮革包 | 皮革袋 | 皮革袋 |
| Pearl | Perle | Perla | Perla | パール | 진주 | Mutiara | Pérola | 珍珠 | 珍珠 | 珍珠 |
| Pixel Sun | Pixelsonne | Sol de píxeles | Sole a pixel | ピクセルサン | 픽셀 해 | Matahari Piksel | Sol de Pixel | 像素太阳 | 像素太陽 | 像素太陽 |
| Porcelain | Porzellan | Porcelana | Porcellana | ポーセリン | 도자기 | Porselin | Porcelana | 青花瓷 | 青花瓷 | 青花瓷 |
| Wood | Holz | Madera | Legno | 木 | 나무 | Kayu | Madeira | 木纹 | 木紋 | 木紋 |

**Icon descriptions:**

| Key | de | es | it | ja | ko | ms | pt-BR | zh-Hans | zh-Hant-HK | zh-Hant-TW |
|---|---|---|---|---|---|---|---|---|---|---|
| The current Hibi icon. | Das aktuelle Hibi-Symbol. | El icono actual de Hibi. | L'icona attuale di Hibi. | 現在のHibiアイコンです。 | 현재 Hibi 아이콘입니다. | Ikon Hibi semasa. | O ícone atual do Hibi. | 当前的Hibi图标。 | 目前的Hibi圖示。 | 目前的Hibi圖示。 |
| For those who were there from the start. | Für alle, die von Anfang an dabei waren. | Para quienes estuvieron desde el principio. | Per chi c'era fin dall'inizio. | 最初から使ってくれた方へ。 | 처음부터 함께해 주신 분들을 위해. | Untuk mereka yang bersama sejak awal. | Para quem esteve aqui desde o início. | 献给从一开始就在的你。 | 給從一開始就在的你。 | 給從一開始就在的你。 |
| A shimmering disco calendar. | Ein schimmernder Disco-Kalender. | Un calendario disco reluciente. | Un calendario da discoteca scintillante. | きらめくディスコカレンダー。 | 반짝이는 디스코 달력. | Kalendar disko berkilauan. | Um calendário disco brilhante. | 闪耀的迪斯科日历。 | 閃耀的迪斯可日曆。 | 閃耀的迪斯可日曆。 |
| Warm leather-bound planner. | Ein warmer Lederplaner. | Agenda de cuero cálido. | Agenda rilegata in pelle. | あたたかみのある革装プランナー。 | 따뜻한 가죽 플래너. | Perancang kulit yang hangat. | Agenda de couro aconchegante. | 温暖的皮革手账。 | 溫暖的皮革手帳。 | 溫暖的皮革手帳。 |
| Iridescent pearl pages. | Schimmernde Perlmutt-Seiten. | Páginas de perla iridiscente. | Pagine di perla iridescente. | 虹色に輝くパールのページ。 | 무지개빛 진주 페이지. | Halaman mutiara berkilauan. | Páginas peroladas iridescentes. | 珠光闪烁的页面。 | 珠光閃爍的頁面。 | 珠光閃爍的頁面。 |
| A pixelated sunrise. | Ein verpixelter Sonnenaufgang. | Un amanecer pixelado. | Un'alba in pixel. | ピクセルの日の出。 | 픽셀 일출. | Matahari terbit berpiksel. | Um nascer do sol pixelado. | 像素日出。 | 像素日出。 | 像素日出。 |
| Delicate blue porcelain. | Zartes blaues Porzellan. | Delicada porcelana azul. | Delicata porcellana blu. | 繊細な青い磁器。 | 섬세한 청자. | Porselin biru yang halus. | Porcelana azul delicada. | 精致的青花瓷。 | 精緻的青花瓷。 | 精緻的青花瓷。 |
| Brushed kanji on warm wood. | Kanji-Pinselstrich auf warmem Holz. | Kanji pintado sobre madera cálida. | Kanji dipinto su legno caldo. | 温もりある木に墨書き。 | 따뜻한 나무 위의 붓글씨. | Kanji berus di atas kayu hangat. | Kanji pincelado em madeira. | 温润木板上的墨书。 | 溫潤木板上的墨書。 | 溫潤木板上的墨書。 |

Note: "Default" here uses a different English key from `SettingsView.Appearance.system` ("System"), so no localization conflict.

- [ ] **Step 2: Show translation table to user for review**

Before committing, present the full translation table above to the user and ask them to approve or correct any translations. AGENTS.md says "When unsure, ask the user before shipping rather than guessing literally." CJK and Malay translations especially benefit from a native speaker check.

- [ ] **Step 3: Verify no missing translations**

```bash
python3 -c "
import json, sys
with open('Hibi/Localizable.xcstrings') as f:
    data = json.load(f)
keys = ['App Icon', 'Default', 'The current Hibi icon.', 'Early User',
        'For those who were there from the start.', 'Available to early users',
        'Disco Balloon', 'A shimmering disco calendar.',
        'Leatherbag', 'Warm leather-bound planner.',
        'Pearl', 'Iridescent pearl pages.',
        'Pixel Sun', 'A pixelated sunrise.',
        'Porcelain', 'Delicate blue porcelain.',
        'Wood', 'Brushed kanji on warm wood.']
locales = ['de','en','es','it','ja','ko','ms','pt-BR','zh-Hans-CN','zh-Hant-HK','zh-Hant-TW']
missing = []
for k in keys:
    entry = data.get('strings', {}).get(k, {})
    locs = entry.get('localizations', {})
    for loc in locales:
        if loc not in locs:
            missing.append(f'{k} -> {loc}')
if missing:
    print('MISSING:', *missing, sep='\n  ')
    sys.exit(1)
else:
    print('All strings present for all locales')
"
```

- [ ] **Step 4: Commit**

```bash
git add Hibi/Localizable.xcstrings
git commit -m "feat: localize App Icon settings strings for all 11 locales"
```

---

## Task 9: Build verification

**Files:** None (verification only)

- [ ] **Step 1: Build the project**

```bash
xcodebuild -project Hibi.xcodeproj -scheme Hibi \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 2: Grep for any un-localized hard-coded strings**

```bash
grep -n 'Text("' Hibi/Views/AppIconSettingsView.swift Hibi/Models/AppIconManager.swift | grep -v 'Text(option\.' | grep -v '//'
```

Every `Text(` should use a `LocalizedStringResource` from the model, not a hard-coded literal.

- [ ] **Step 3: Note for on-device verification**

The following must be verified on-device by the user:
1. "App Icon" row appears in Settings → General
2. Tapping it pushes the icon selection screen
3. Default icon is selected with a checkmark
4. Early User icon shows locked state (if installed after July 1, 2026 UTC)
5. Early User icon is selectable (if installed before the cutoff)
6. Selecting an icon triggers the system "You have changed the icon" alert
7. After selection, the Home Screen icon actually changes
8. Killing and relaunching the app preserves the selection
9. All strings display correctly in non-English locales

---

## Summary of additions

| # | What | Risk |
|---|---|---|
| Task 1 | Copy icon assets (`.icon` bundles + preview PNGs) | ✅ Pre-completed |
| Task 2 | Install date in UserDefaults | Low — one line in existing first-launch guard |
| Task 3 | `AppIconManager` model (8-icon registry) | Medium — StoreKit 2 + `setAlternateIconName` interaction |
| Task 4 | Environment wiring | Low — follows existing pattern |
| Task 5 | `AppIconSettingsView` | Low — standard SwiftUI list |
| Task 6 | Settings row wiring | Low — one NavigationLink |
| Task 7 | Preview image sets | ✅ Pre-completed |
| Task 8 | Localization (18 strings × 11 locales) | Medium — translation quality (user review step included) |
| Task 9 | Build verification | N/A |

**Highest-risk item:** Whether Xcode auto-discovers alternate `.icon` bundles via `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`. The bundles are already in the project (Task 1). If the build succeeds but `setAlternateIconName` fails at runtime, we may need:
1. `CFBundleAlternateIcons` entries in `Info.plist`, or
2. Explicit `.icon` bundle references in `project.pbxproj`.

Task 9's build step will catch compile-time issues; runtime behavior must be verified on-device.
