# Scroll-Driven Paper Collapse — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make HibiPlusView in Settings collapsible/expandable by scrolling the settings list, matching DayView's scroll-driven collapse behavior exactly.

**Architecture:** Replace SettingsView's `Form` with styled content inside `HijackingScrollView` (the proven UIKit scroll-intercept bridge from DayView). Convert HibiPlusView from boolean `expanded` to continuous `CGFloat` collapse progress. SettingsView owns the progress state; HijackingScrollView writes it per-frame during scroll; HibiPlusView reads it for visuals and writes it on tap-toggle.

**Tech Stack:** SwiftUI, UIKit (HijackingScrollView UIViewRepresentable), EventKit/WeatherStore environments

---

## Why not keep the Form?

SwiftUI `Form` is backed by `UICollectionView` internally. `HijackingScrollView` owns its own `UIScrollView` — you cannot nest a Form inside it without broken double-scrolling, and you cannot intercept Form's internal scroll without fragile UIKit introspection. Replacing the Form with manually-styled sections inside `HijackingScrollView` is the same proven pattern DayView uses for its schedule list. The settings list is small (≈7 rows across 4 sections), so the styling effort is minimal.

`NavigationLink` requires a `NavigationStack` ancestor in the SwiftUI view tree. Content hosted inside `HijackingScrollView`'s `UIHostingController` is in a separate SwiftUI tree, so `NavigationLink` won't work there. The fix: use `Button` + `@State` destination enum inside the scroll content, with `.navigationDestination(item:)` on the outer `SettingsView` (which IS in the `NavigationStack` tree). State mutations cross the UIKit boundary because SwiftUI's state graph is global — the `@State` lives on `SettingsView`, and the Button action closure captures a reference to it.

## Key design decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Progress convention | 0 = expanded, 1 = collapsed | Matches `HijackingScrollView` and DayView's `scheduleProgress` |
| Default state | `collapseProgress = 1` (collapsed) | Settings paper starts compact so the list is immediately usable |
| Content layout switching | Derived `expanded: Bool` from `collapseProgress < 0.5` | Card sub-views keep boolean show/hide; snaps during scroll (clipped by card shape), animates during snap/toggle |
| Chrome fade | `max(0, 1 - collapseProgress * 1.25)` | Continuous opacity; content fully invisible at 80% collapsed (same overshoot as DayView) |
| Collapse distance | Fixed 200pt | Compromise between stamp card (158pt visual change) and feature card (278pt). Both feel natural at ~0.8–1.4:1 ratio |
| Card-swipe vs collapse | Orthogonal | Card tear gesture (vertical DragGesture on front card) is `highPriorityGesture`, fires before scroll. No conflict. |
| Spring constant | `HijackingScrollView.snapSpring` (extracted) | Single source of truth for `.spring(response: 0.38, dampingFraction: 0.86)` used by DayView, HibiPlusView, and HijackingScrollView |

## Transaction discipline (from learnings.md)

Every per-frame write to `collapseProgress` MUST use:
```swift
var t = Transaction()
t.disablesAnimations = true
t.scrollContentOffsetAdjustmentBehavior = .disabled
withTransaction(t) { binding.wrappedValue = newValue }
```

Snap/toggle writes use the same flags minus `disablesAnimations`, plus a spring animation:
```swift
var t = Transaction()
t.animation = HijackingScrollView<EmptyView>.snapSpring
t.scrollContentOffsetAdjustmentBehavior = .disabled
withTransaction(t) { binding.wrappedValue = target }
```

`HijackingScrollView` already does this internally. The tap-toggle in `HibiPlusView` must follow the same pattern.

---

### Task 1: Extract shared collapse spring constant

**Files:**
- Modify: `Hibi/Views/Components/HijackingScrollView.swift`

- [ ] **Step 1: Add static `snapSpring` to HijackingScrollView**

At the top of the `HijackingScrollView` struct (after the properties, before `makeCoordinator`), add:

```swift
static var snapSpring: Animation {
    .spring(response: 0.38, dampingFraction: 0.86)
}
```

This must be a static computed property (not stored) because `HijackingScrollView` is generic — stored static properties aren't allowed on generic types.

- [ ] **Step 2: Use `snapSpring` in the Coordinator's snap closure**

In `makeCoordinator()` and `updateUIView(_:context:)`, replace the inline spring:

```swift
// OLD:
t.animation = .spring(response: 0.38, dampingFraction: 0.86)
// NEW:
t.animation = HijackingScrollView.snapSpring
```

There are two occurrences in `makeCoordinator` (line 38) and two in `updateUIView` (line 89).

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/Components/HijackingScrollView.swift
git commit -m "refactor: extract shared snapSpring constant on HijackingScrollView

Both DayView and the upcoming SettingsView scroll-collapse
use the same spring parameters. Single source of truth.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Convert HibiPlusView from Bool to CGFloat progress

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Change the HibiPlusView interface**

Replace the internal `expanded` state with a binding and derived Bool. In `struct HibiPlusView: View` (line 745):

```swift
// REMOVE these lines:
@State private var expanded = false

// ADD these lines (at the top of the struct, before other @State properties):
/// 0 = expanded (paper tall), 1 = collapsed (paper compact).
/// Owned by the parent (SettingsView); driven by HijackingScrollView
/// per-frame during scroll, and by tap-toggle on the front card.
@Binding var collapseProgress: CGFloat

/// Derived boolean for card sub-views that need binary show/hide.
/// Snaps at the midpoint — during scroll the snap is unanimated
/// (clipped by the card shape); during snap/toggle it animates
/// with the collapse spring.
private var expanded: Bool { collapseProgress < 0.5 }
```

- [ ] **Step 2: Add a continuous chromeFade computed property**

Below the `expanded` computed property, add:

```swift
/// Continuous 0…1 fade for expanded-only chrome. Reaches fully
/// invisible at 80% collapsed (overshoot matches DayView).
private var chromeFade: Double {
    Double(max(0, 1 - collapseProgress * 1.25))
}
```

- [ ] **Step 3: Update card sizing to continuous interpolation**

In the `body` computed property (line 770), replace the boolean-gated sizes with lerp:

```swift
// OLD:
let frontW = expanded ? w - 32 : HPLayout.collapsed.width
let frontH = expanded ? expandedHeight(for: frontIndex) : HPLayout.collapsed.height
let backW = expanded ? w - 32 : HPLayout.collapsed.width
let backH = expanded ? expandedHeight(for: backIndex) : HPLayout.collapsed.height

// NEW:
let ef = 1 - collapseProgress // expand fraction: 0 = collapsed, 1 = expanded
let frontW = HPLayout.collapsed.width + (w - 32 - HPLayout.collapsed.width) * ef
let frontH = HPLayout.collapsed.height + (expandedHeight(for: frontIndex) - HPLayout.collapsed.height) * ef
let backW = HPLayout.collapsed.width + (w - 32 - HPLayout.collapsed.width) * ef
let backH = HPLayout.collapsed.height + (expandedHeight(for: backIndex) - HPLayout.collapsed.height) * ef
```

- [ ] **Step 4: Update totalHeight to use continuous progress**

Replace the `totalHeight` computed property (line 792):

```swift
// OLD:
private var totalHeight: CGFloat {
    let frontH = expanded ? expandedHeight(for: frontIndex) : HPLayout.collapsed.height
    let backH = expanded ? expandedHeight(for: backIndex) : HPLayout.collapsed.height
    let h = lerp(frontH, backH, cardShift)
    return h + 14 + HPLayout.hintHeight
}

// NEW:
private var totalHeight: CGFloat {
    let ef = 1 - collapseProgress
    let frontH = HPLayout.collapsed.height + (expandedHeight(for: frontIndex) - HPLayout.collapsed.height) * ef
    let backH = HPLayout.collapsed.height + (expandedHeight(for: backIndex) - HPLayout.collapsed.height) * ef
    let h = lerp(frontH, backH, cardShift)
    let hintH = HPLayout.hintHeight * ef
    return h + 14 + hintH
}
```

- [ ] **Step 5: Update hint text to fade with progress**

Replace the `hint` computed property (line 935):

```swift
// OLD:
private var hint: some View {
    Text("Pull to tear · ↑ Next · ↓ Prev")
        .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
}

// NEW:
private var hint: some View {
    let ef = 1 - collapseProgress
    return Text("Pull to tear · ↑ Next · ↓ Prev")
        .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .frame(height: HPLayout.hintHeight * ef)
        .opacity(chromeFade)
        .clipped()
}
```

- [ ] **Step 6: Update toggleExpand to use transaction-based animation on the binding**

Replace the `toggleExpand()` function (line 959):

```swift
// OLD:
private func toggleExpand() {
    guard !isAnimating else { return }
    withAnimation(HPLayout.collapseSpring) { expanded.toggle() }
}

// NEW:
private func toggleExpand() {
    guard !isAnimating else { return }
    let target: CGFloat = collapseProgress >= 0.5 ? 0 : 1
    var t = Transaction()
    t.animation = HijackingScrollView<EmptyView>.snapSpring
    t.scrollContentOffsetAdjustmentBehavior = .disabled
    withTransaction(t) { collapseProgress = target }
}
```

- [ ] **Step 7: Remove the `.animation(_, value: expanded)` modifier**

In the body (line 788), remove:

```swift
// REMOVE:
.animation(HPLayout.collapseSpring, value: expanded)
```

Keep `.animation(HPLayout.collapseSpring, value: isPlus)` — that drives the purchase flow and is orthogonal.

- [ ] **Step 8: Update FeatureCardBody to accept continuous chromeFade**

In `FeatureCardBody` (line 616), change the `expanded` property and derived `chromeFade`:

```swift
// OLD:
let expanded: Bool
// ...
private var chromeFade: Double { expanded ? 1 : 0 }

// NEW:
let expanded: Bool
let chromeFade: Double
```

Remove the `private var chromeFade` computed property entirely (line 623). The `chromeFade` is now passed in from HibiPlusView.

- [ ] **Step 9: Update StampCardBody stamp size to continuous interpolation**

In `StampCardBody` (line 590), change the stamp size from boolean to continuous:

```swift
// OLD:
let expanded: Bool
// ...
HibiStamp(purchased: purchased, date: date,
          size: expanded ? 310 : 200, stampToken: stampToken)

// NEW:
let expanded: Bool
let expandFraction: CGFloat
// ...
HibiStamp(purchased: purchased, date: date,
          size: 200 + 110 * expandFraction, stampToken: stampToken)
```

- [ ] **Step 10: Update cardBody to pass the new parameters**

In `cardBody(index:)` (line 924), update the calls:

```swift
// OLD:
if index == 0 {
    StampCardBody(purchased: isPlus, date: purchaseDate,
                  expanded: expanded, stampToken: stampToken)
} else {
    FeatureCardBody(purchased: isPlus, expanded: expanded,
                    ctaSuccess: $ctaSuccess, onPurchase: purchase)
}

// NEW:
if index == 0 {
    StampCardBody(purchased: isPlus, date: purchaseDate,
                  expanded: expanded, expandFraction: 1 - collapseProgress,
                  stampToken: stampToken)
} else {
    FeatureCardBody(purchased: isPlus, expanded: expanded,
                    chromeFade: chromeFade,
                    ctaSuccess: $ctaSuccess, onPurchase: purchase)
}
```

- [ ] **Step 11: Build to verify compilation**

```bash
xcodebuild -project Hibi.xcodeproj -scheme Hibi \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. There will be a build error in SettingsView because `HibiPlusView()` is called without the new binding — that's fixed in Task 3.

To temporarily unblock the build, add a default value to the binding parameter:

In HibiPlusView, temporarily change:
```swift
// Add a convenience init that defaults to collapsed:
init(collapseProgress: Binding<CGFloat> = .constant(1)) {
    self._collapseProgress = collapseProgress
}
```

This will be removed in Task 3 when SettingsView passes the real binding.

- [ ] **Step 12: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "refactor: convert HibiPlusView from Bool expand to CGFloat progress

Card sizing now interpolates continuously with collapseProgress
(0 = expanded, 1 = collapsed). Sub-views receive continuous
chromeFade for smooth opacity transitions and a derived expanded
Bool for binary content switching. Tap-toggle uses the same
transaction discipline as HijackingScrollView.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Replace Form with scroll-driven content in SettingsView

**Files:**
- Modify: `Hibi/Views/SettingsView.swift`

- [ ] **Step 1: Add state variables and destination enum**

At the top of `SettingsView`, add:

```swift
/// Navigation target for settings sub-pages. Buttons inside
/// HijackingScrollView set this; .navigationDestination on the
/// outer VStack handles the push (the hosting controller's SwiftUI
/// tree can't see the NavigationStack, but state mutations cross
/// the UIKit boundary).
@State private var settingsDestination: SettingsDestination?

/// 0 = paper expanded, 1 = paper collapsed. Shared between
/// HibiPlusView (reads + tap-writes) and HijackingScrollView
/// (scroll-writes).
@State private var collapseProgress: CGFloat = 1

enum SettingsDestination: String, Hashable, Identifiable {
    case appearance, units, calendars
    var id: String { rawValue }
}
```

- [ ] **Step 2: Create private styled-section helpers**

Add these private helpers at the bottom of `SettingsView` (before the closing brace), or as a file-private extension:

```swift
// MARK: - Styled Form replacements

private func settingsSection(
    _ title: LocalizedStringKey? = nil,
    @ViewBuilder content: () -> some View
) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        if let title {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
        }
        VStack(spacing: 0) { content() }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private func settingsRow<Label: View>(
    action: @escaping () -> Void,
    @ViewBuilder label: () -> Label
) -> some View {
    Button(action: action) {
        label()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

private var settingsDivider: some View {
    Divider().padding(.leading, 16)
}

private func settingsNavRow(
    _ titleKey: LocalizedStringKey,
    systemImage: String,
    destination: SettingsDestination
) -> some View {
    settingsRow(action: { settingsDestination = destination }) {
        HStack {
            Label(titleKey, systemImage: systemImage)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
```

- [ ] **Step 3: Create the settings form content**

Add a private computed property that builds all the settings rows:

```swift
private var settingsFormContent: some View {
    VStack(spacing: 28) {
        settingsSection("General") {
            settingsNavRow("Appearance", systemImage: "paintbrush",
                           destination: .appearance)
            settingsDivider
            settingsNavRow("Units", systemImage: "ruler",
                           destination: .units)
            settingsDivider
            settingsRow(action: { settingsDestination = .calendars }) {
                HStack {
                    LabeledContent {
                        Text(calendarSummary)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Calendars & Reminders", systemImage: "calendar")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }

        if hasMissingPermission {
            settingsSection("Permissions") {
                settingsRow(action: {
                    onReopenPermissions()
                    dismiss()
                }) {
                    HStack {
                        Label("Review permissions",
                              systemImage: "exclamationmark.triangle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }

        settingsSection("About") {
            Button {
                whatsNewVersion = .v(WhatsNewContent.version)
            } label: {
                LabeledContent {
                    Text(Self.versionLabel)
                        .foregroundStyle(.secondary)
                } label: {
                    Text("What's New")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            settingsDivider

            Link(destination: URL(string: "https://apps.weichart.de")!) {
                HStack(spacing: 12) {
                    Image("WeichartApps")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6,
                                                     style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("More Apps")
                            .foregroundStyle(.primary)
                        Text(verbatim: "apps.weichart.de")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }

        #if DEBUG
        settingsSection("Debug") {
            Toggle(isOn: Binding(
                get: { eventStore.isDemoMode },
                set: { eventStore.setDemoMode($0) }
            )) {
                Label("Demo Mode", systemImage: "wand.and.stars")
            }
            .tint(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        #endif
    }
    .padding(.horizontal, 16)
    .padding(.top, 28)
    .padding(.bottom, 140)
}
```

- [ ] **Step 4: Replace the body with HijackingScrollView layout**

Replace the entire `body` computed property:

```swift
var body: some View {
    VStack(spacing: 0) {
        HibiPlusView(collapseProgress: $collapseProgress)
            .background(Color(.systemGroupedBackground))
            .zIndex(1)

        // Separator handle — visual cue matching DayView's
        // schedule separator. Not independently draggable;
        // collapse is driven by the HijackingScrollView below.
        HStack(spacing: 10) {
            Rectangle().fill(.quaternary).frame(height: 0.5)
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
            Rectangle().fill(.quaternary).frame(height: 0.5)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)

        HijackingScrollView(
            progress: $collapseProgress,
            collapseDistance: 200
        ) {
            settingsFormContent
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color(.systemGroupedBackground),
                         Color(.systemGroupedBackground).opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)
        }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(Text(verbatim: "Hibi"))
    .navigationDestination(item: $settingsDestination) { destination in
        switch destination {
        case .appearance: AppearanceSettingsView()
        case .units: UnitsSettingsView()
        case .calendars: CalendarSelectionView()
        }
    }
    .noteletSheet(
        notes: WhatsNewContent.allNotes,
        version: whatsNewVersion,
        onDismiss: { whatsNewVersion = nil },
        configuration: WhatsNewContent.configuration
    )
}
```

- [ ] **Step 5: Remove the temporary default binding from HibiPlusView**

In `HibiPlusView.swift`, remove the convenience init added in Task 2 Step 11. The binding is now always provided by SettingsView.

If HibiPlusView doesn't have a custom init (just uses memberwise), the `@Binding var collapseProgress: CGFloat` requires callers to pass it explicitly — which SettingsView now does.

- [ ] **Step 6: Make AppearanceSettingsView and UnitsSettingsView non-private**

Currently both are `private struct`. Since `.navigationDestination` in `SettingsView` now references them directly (they were previously only referenced via `NavigationLink` in the same file scope), they need to be accessible. Since they're in the same file as `SettingsView`, `private` already works. Verify this compiles — if `navigationDestination`'s closure can see private types in the same file, no change is needed. If not, change them to `fileprivate` or internal.

- [ ] **Step 7: Build to verify compilation**

```bash
xcodebuild -project Hibi.xcodeproj -scheme Hibi \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add Hibi/Views/SettingsView.swift Hibi/Views/HibiPlusView.swift
git commit -m "feat: scroll-driven paper collapse in Settings

Replace Form with styled sections inside HijackingScrollView.
Scrolling the settings list up collapses the paper stack;
pulling down at the top expands it. Same magnetic snap and
transaction discipline as DayView.

Button-based navigation with .navigationDestination replaces
NavigationLink (required because HijackingScrollView hosts
content in a UIHostingController, outside the NavigationStack
view tree).

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Build verification and manual test checklist

- [ ] **Step 1: Full clean build**

```bash
xcodebuild -project Hibi.xcodeproj -scheme Hibi \
  -destination 'generic/platform=iOS Simulator' \
  clean build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED with no warnings in modified files.

- [ ] **Step 2: Document what to test on device**

The following must be verified on a physical device (no simulator per CLAUDE.md):

**Scroll-driven collapse:**
- [ ] Open Settings → paper starts collapsed (compact)
- [ ] Scroll the settings list up → paper collapses smoothly (if not already)
- [ ] Pull down at the top of the settings list → paper expands smoothly
- [ ] Quick flick up → paper snaps to collapsed with spring
- [ ] Quick flick down at top → paper snaps to expanded with spring
- [ ] Slow drag and release at ~50% → snaps to nearest end
- [ ] Velocity-biased snap: fast flick from <50% still commits

**Tap-to-toggle:**
- [ ] Tap the paper stack → toggles between expanded and collapsed with spring animation
- [ ] Tap during scroll-driven mid-collapse → snaps correctly

**Card swipe (tear):**
- [ ] Pull card up/down past threshold → card tears, next card rises
- [ ] Card swipe works identically in both expanded and collapsed states
- [ ] No conflict between card swipe and scroll-driven collapse

**Navigation:**
- [ ] Tap "Appearance" row → pushes AppearanceSettingsView
- [ ] Tap "Units" row → pushes UnitsSettingsView
- [ ] Tap "Calendars & Reminders" row → pushes CalendarSelectionView
- [ ] Back button works from all sub-pages
- [ ] "Review permissions" button works (if permissions section visible)
- [ ] "What's New" button opens the Notelet sheet
- [ ] "More Apps" link opens Safari

**Visual polish:**
- [ ] Section styling approximates Form grouped-inset look (rounded corners, correct background colors)
- [ ] Gradient overlay at top of scroll content present
- [ ] Separator handle (capsule) visible between paper and list
- [ ] No flicker during slow drag (transaction discipline working)
- [ ] Dark mode: correct colors, high-contrast paper stack
- [ ] Card shadows render correctly over the settings list

**Performance:**
- [ ] No jank during scroll-driven collapse (60fps)
- [ ] No memory growth from repeated expand/collapse cycles

**DayView regression:**
- [ ] DayView schedule collapse still works identically
- [ ] DayView tap-to-toggle still works
- [ ] DayView HijackingScrollView behavior unchanged
