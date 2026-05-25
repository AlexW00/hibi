# Hibi Plus — Settings UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-page paper-stack "Hibi Plus" support-tier surface at the top of Settings, with Day-view-style swipe + tap-to-expand, a placeholder stamp, and a CTA that toggles an in-memory Plus state.

**Architecture:** A self-contained `HibiPlusView` reuses the Day view's animation *grammar* (peek/inset constants, the collapse spring, easeIn/easeOut tear timings, no-anim reset) without sharing code with `DayView.tearStack`. Two cards: a placeholder stamp card and a feature card. Mounted as the first borderless `Section` of `SettingsView`'s `Form`.

**Tech Stack:** SwiftUI (iOS 26), `AppFont` (Instrument Serif), `PaperTints`, `PerforationEdge`, `Localizable.xcstrings` (11 locales).

---

## Environment / verification reality

- **No Xcode here.** Code cannot be compiled or run in this container. "Build"
  and "run" verification steps are **on-device, post-merge**. They are written
  as explicit checklists so a human (or a session with a Mac) can run them.
- Checks that DO run here: `grep`/`python3` JSON validation of
  `Localizable.xcstrings`, and reading code back for consistency.
- The spec lives at `docs/superpowers/specs/2026-05-25-hibi-plus-settings-design.md`.

## File structure

- **Create** `Hibi/Views/HibiPlusView.swift` — everything: `HibiPlusView`
  (state + stack + interaction), the two card content views, `HibiStamp`,
  `AppIconCarousel`, `EarlyAccessTile`, `PlusCTA`, and local layout constants.
  One file keeps the closely-coupled stack + content together (mirrors how
  `DayView.swift` keeps its stack + sub-views in one file).
- **Modify** `Hibi/Views/SettingsView.swift` — add the first `Form` section.
- **Modify** `Hibi/Views/PaperTints.swift` — add the vermillion seal ink color.
- **Modify** `Hibi/Localizable.xcstrings` — all new strings × 11 locales.

Constants (define once near the top of `HibiPlusView.swift`):

```swift
private enum HPLayout {
    static let collapsed = CGSize(width: 280, height: 280)
    static let stampExpandedHeight: CGFloat = 420   // ≈ Day view expanded paper
    static let featureExpandedHeight: CGFloat = 510 // bigger
    static let featureExpandedHeightPurchased: CGFloat = 450
    static let peek: CGFloat = 9        // back-card bottom peek (Day view --d1)
    static let side: CGFloat = 14       // back-card horizontal inset
    static let corner: CGFloat = 18
    static let tearThreshold: CGFloat = 70
    static let offScreen: CGFloat = 700
    static let collapseSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

// Hard-coded early-access window end. Edit here to change the countdown.
private let earlyAccessEndDate: Date = {
    var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: "de_DE")
    return cal.date(from: c) ?? Date()
}()
```

---

## Task 1: Vermillion ink color + `HibiStamp`

**Files:**
- Modify: `Hibi/Views/PaperTints.swift`
- Create: `Hibi/Views/HibiPlusView.swift` (start the file; add `HibiStamp`)

- [ ] **Step 1: Add the seal ink color to `PaperTints`**

In `Hibi/Views/PaperTints.swift`, inside `enum PaperTints`, add after `bindingHole`:

```swift
    /// Vermillion (shu-iro) ink for the Hibi Plus seal. Same in light + dark.
    static let sealInk = Color(uiColor: UIColor(displayP3Red: 0.784, green: 0.212, blue: 0.165, alpha: 1)) // #c8362a
```

- [ ] **Step 2: Create `HibiPlusView.swift` with the layout constants + `HibiStamp`**

Create `Hibi/Views/HibiPlusView.swift`:

```swift
import SwiftUI

// MARK: - Layout constants

private enum HPLayout {
    static let collapsed = CGSize(width: 280, height: 280)
    static let stampExpandedHeight: CGFloat = 420
    static let featureExpandedHeight: CGFloat = 510
    static let featureExpandedHeightPurchased: CGFloat = 450
    static let peek: CGFloat = 9
    static let side: CGFloat = 14
    static let corner: CGFloat = 18
    static let tearThreshold: CGFloat = 70
    static let offScreen: CGFloat = 700
    static let collapseSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

private let earlyAccessEndDate: Date = {
    var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: "de_DE")
    return cal.date(from: c) ?? Date()
}()

// MARK: - Stamp (placeholder seal)
//
// PLACEHOLDER. The seal is intentionally drawn with plain SwiftUI shapes/Text
// so the inner rendering can later be replaced by a custom Metal shader
// (.colorEffect / .layerEffect on the `sealBody`). Keep `sealBody` isolated so
// the swap is localized to this view.

struct HibiStamp: View {
    let purchased: Bool
    let date: Date?
    var size: CGFloat = 154
    var rotation: Double = -6
    /// Bumped by the owner to replay the stamp-in animation.
    var stampToken: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressScale: CGFloat = 1
    @State private var appeared = false

    var body: some View {
        Group {
            if purchased {
                sealBody
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(appeared ? pressScale : 1.18)
                    .opacity(appeared ? 1 : 0)
                    .onAppear { runStampIn() }
                    .onChange(of: stampToken) { _, _ in
                        appeared = false
                        runStampIn()
                    }
            } else {
                slotBody
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(purchased ? Text("Hibi Plus seal") : Text("Awaiting your seal"))
    }

    private func runStampIn() {
        guard !reduceMotion else { appeared = true; pressScale = 1; return }
        withAnimation(.easeOut(duration: 0.28)) { appeared = true }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { pressScale = 0.96 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12)) { pressScale = 1 }
    }

    // The replaceable seal artwork.
    private var sealBody: some View {
        let r = size / 2
        return ZStack {
            Circle()
                .fill(PaperTints.sealInk.opacity(0.06))
                .padding(4)
            Circle()
                .strokeBorder(PaperTints.sealInk.opacity(0.94), lineWidth: size * 0.045)
                .padding(6)
            VStack(spacing: size * 0.04) {
                Text("HIBI · PLUS")
                    .font(.system(size: size * 0.10, weight: .medium))
                    .tracking(size * 0.04)
                    .foregroundStyle(PaperTints.sealInk.opacity(0.92))
                Text(verbatim: "日々")
                    .font(.custom(AppFont.serifItalic, size: size * 0.42))
                    .foregroundStyle(PaperTints.sealInk.opacity(0.96))
                Text(verbatim: Self.format(date))
                    .font(.system(size: size * 0.085, design: .monospaced))
                    .tracking(size * 0.012)
                    .foregroundStyle(PaperTints.sealInk.opacity(0.86))
            }
        }
    }

    private var slotBody: some View {
        Circle()
            .strokeBorder(Color.primary.opacity(0.20), style: StrokeStyle(lineWidth: 1.25, dash: [4, 4]))
            .background(Circle().fill(Color.primary.opacity(0.02)))
            .overlay {
                VStack(spacing: 4) {
                    Text("AWAITING")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(.tertiary)
                    Text("your seal")
                        .font(.custom(AppFont.serifItalic, size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private static func format(_ date: Date?) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd · MM · yyyy"
        return f.string(from: date ?? Date())
    }
}
```

- [ ] **Step 3: Verify (read-back)**

Read `Hibi/Views/HibiPlusView.swift` and confirm: `HibiStamp` compiles
conceptually (uses `AppFont.serifItalic`, `PaperTints.sealInk`), the stamp-in
replays on `stampToken` change, and Reduce Motion snaps to placed. No build
possible here.

- [ ] **Step 4: Commit**

```bash
git add Hibi/Views/PaperTints.swift Hibi/Views/HibiPlusView.swift
git commit -m "Add Hibi Plus seal ink color and placeholder HibiStamp"
```

---

## Task 2: `AppIconCarousel`

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Add the icon facsimile + auto-scrolling carousel**

Append to `Hibi/Views/HibiPlusView.swift`:

```swift
// MARK: - App icon carousel
//
// Placeholder: repeats a SwiftUI facsimile of the current app icon. The real
// icon ships as a Liquid Glass `.icon` bundle (no usable PNG in the asset
// catalog), so we render a facsimile that matches its design: a paper tile,
// two faint binding dots, an italic "26".

private struct AppIconTile: View {
    var size: CGFloat = 42
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(PaperTints.card1)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
            }
            .overlay(alignment: .top) {
                HStack {
                    Circle().frame(width: 3, height: 3)
                    Spacer()
                    Circle().frame(width: 3, height: 3)
                }
                .foregroundStyle(.black.opacity(0.35))
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }
            .overlay {
                Text(verbatim: "26")
                    .font(.custom(AppFont.serifItalic, size: size * 0.58))
                    .foregroundStyle(.black)
            }
            .frame(width: size, height: size)
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.10), radius: 4, y: 2)
    }
}

struct AppIconCarousel: View {
    var size: CGFloat = 42
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    private let count = 8
    private var spacing: CGFloat { size * 0.27 }
    private var unitWidth: CGFloat { CGFloat(count) * (size + spacing) }

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: spacing) {
                ForEach(0..<(count * 2), id: \.self) { _ in
                    AppIconTile(size: size)
                }
            }
            .offset(x: offset)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                    offset = -unitWidth
                }
            }
        }
        .frame(height: size)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.14),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Verify (read-back)**

Confirm the track holds `count*2` tiles and animates by exactly `unitWidth`
(one full set), giving a seamless loop, and that Reduce Motion leaves it static.

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Add Hibi Plus app icon carousel (facsimile placeholder)"
```

---

## Task 3: `EarlyAccessTile`

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Add the widget illustration + early-access tile**

Append to `Hibi/Views/HibiPlusView.swift`:

```swift
// MARK: - Early access tile (Widgets promo)

private struct WidgetIllustration: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [Color(red: 0.83, green: 0.85, blue: 0.89),
                             Color(red: 0.55, green: 0.59, blue: 0.69)],
                    center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: 92
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PaperTints.card1)
                    .overlay {
                        VStack(spacing: 2) {
                            HStack(spacing: 18) {
                                Circle().fill(PaperTints.bindingHole).frame(width: 4, height: 4)
                                Circle().fill(PaperTints.bindingHole).frame(width: 4, height: 4)
                            }
                            Text("Thursday")
                                .font(.custom(AppFont.serifItalic, size: 8))
                                .foregroundStyle(.secondary)
                            Text(verbatim: "23")
                                .font(.custom(AppFont.serifRegular, size: 38))
                                .foregroundStyle(.primary)
                                .overlay(alignment: .bottom) {
                                    Rectangle().frame(width: 22, height: 1.25).foregroundStyle(.primary)
                                }
                        }
                        .padding(.vertical, 6)
                    }
                    .padding(8)
                    .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.10), radius: 4, y: 1)
            }
            .frame(width: 92, height: 92)
            .accessibilityHidden(true)
    }
}

struct EarlyAccessTile: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var daysLeft: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: earlyAccessEndDate)
        return max(0, cal.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(PaperTints.sealInk)
                    .frame(width: 5, height: 5)
                    .opacity(pulse ? 0.5 : 1)
                    .scaleEffect(pulse ? 0.85 : 1)
                Text("Currently in early access")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("\(daysLeft)d left")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
                Rectangle().frame(height: 0.5).foregroundStyle(Color.black.opacity(0.08))
            }

            HStack(spacing: 10) {
                WidgetIllustration()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widgets")
                        .font(.custom(AppFont.serifRegular, size: 18))
                    Text("On your home screen — paper, every day.")
                        .font(.custom(AppFont.serifItalic, size: 11.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
```

Note: `"\(daysLeft)d left"` is a placeholder; Task 9 replaces it with a
localized, pluralized string.

- [ ] **Step 2: Verify daysLeft math (read-back)**

Today is 2026-05-25, end is 2026-06-30 → expect 36 in `daysLeft`. Confirm the
`max(0, …)` guards against negatives once the window passes.

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Add Hibi Plus early-access Widgets tile with hard-coded countdown"
```

---

## Task 4: `PlusCTA` (idle → success morph) + Restore link

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Add the CTA + restore link**

Append to `Hibi/Views/HibiPlusView.swift`:

```swift
// MARK: - Purchase CTA

struct PlusCTA: View {
    /// True once the success morph has played; owner drives the rest.
    @Binding var showSuccess: Bool
    let onPurchase: () -> Void

    var body: some View {
        Button {
            guard !showSuccess else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showSuccess = true }
            onPurchase()
        } label: {
            Group {
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Thank you")
                            .font(.system(size: 15, weight: .semibold))
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "$4.99")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                        Text("one-time")
                            .font(.custom(AppFont.serifItalic, size: 12.5))
                            .opacity(0.7)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .foregroundStyle(showSuccess ? Color.white : PaperTints.card1)
            .background(showSuccess ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.primary)
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showSuccess ? Text("Purchased. Thank you.") : Text("Buy Hibi Plus, $4.99 one-time"))
    }
}

struct RestorePurchasesLink: View {
    var body: some View {
        Button {
            // No-op placeholder — no real IAP yet.
        } label: {
            Text("Restore purchases")
                .font(.custom(AppFont.serifItalic, size: 11.5))
                .foregroundStyle(.tertiary)
                .underline()
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Add Hibi Plus CTA with success morph and restore link"
```

---

## Task 5: Card content — stamp card + feature card

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Add the four card-content views**

Append to `Hibi/Views/HibiPlusView.swift`. These render the *body* only; the
stack chrome (fill, perforation, shadow) is added by the stack in Task 6.

```swift
// MARK: - Shared header (collapsed + expanded feature card)

private struct PlusHeader: View {
    var deck: LocalizedStringKey?
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false
    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: "日々")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(.secondary)
            Text("Hibi Plus")
                .font(.appSerif(size: 36, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
            if let deck {
                Text(deck)
                    .font(.appSerif(size: 13.5, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
    }
}

// Card 1 — stamp

private struct StampCardBody: View {
    let purchased: Bool
    let date: Date?
    let expanded: Bool
    let stampToken: Int
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    var body: some View {
        VStack(spacing: 18) {
            HibiStamp(purchased: purchased, date: date,
                      size: expanded ? 186 : 154, stampToken: stampToken)
            if expanded {
                Text(purchased
                     ? "Thank you."
                     : "Purchase Hibi Plus to receive your personalized seal.")
                    .font(.appSerif(size: 15, italic: true, simple: useSimpleFont))
                    .foregroundStyle(purchased ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }
}

// Card 2 — feature card

private struct FeatureCardBody: View {
    let purchased: Bool
    let expanded: Bool
    @Binding var ctaSuccess: Bool
    let onPurchase: () -> Void
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    var body: some View {
        if expanded { expandedBody } else { collapsedBody }
    }

    private var collapsedBody: some View {
        VStack(spacing: 14) {
            PlusHeader().padding(.top, 14)
            AppIconCarousel(size: 42).padding(.horizontal, -22)
            Text("Tap to see what's inside.")
                .font(.appSerif(size: 11.5, italic: true, simple: useSimpleFont))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
    }

    private var expandedBody: some View {
        VStack(spacing: 0) {
            PlusHeader(deck: "Your support matters a lot.")

            // hairline rule with center dot
            HStack(spacing: 8) {
                Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
            }
            .frame(width: 180)
            .padding(.top, 16).padding(.bottom, 12)

            AppIconCarousel(size: 42).padding(.horizontal, -22).padding(.bottom, 14)

            HStack(spacing: 12) {
                perk(rule: "App icons", title: "Dress Hibi up.")
                perk(rule: "Early access", title: "Try features first.")
            }
            .padding(.bottom, 12)

            EarlyAccessTile().padding(.bottom, 14)

            Spacer(minLength: 0)

            if !purchased {
                VStack(spacing: 8) {
                    PlusCTA(showSuccess: $ctaSuccess, onPurchase: onPurchase)
                    RestorePurchasesLink()
                }
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private func perk(rule: LocalizedStringKey, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rule)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.appSerif(size: 16, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        }
    }
}
```

- [ ] **Step 2: Verify (read-back)**

Confirm both cards use `.appSerif`, the feature card hides CTA+restore when
`purchased`, and `PlusHeader` is shared by collapsed + expanded.

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Add Hibi Plus stamp + feature card content views"
```

---

## Task 6: The two-card stack — swipe, tap-expand, sizing, hint

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Add the `HibiPlusView` stack container**

Append to `Hibi/Views/HibiPlusView.swift`. This owns all state and renders the
two-card stack + the static hint. (Purchase wiring is finished in Task 7; here
`purchase()` is stubbed to set state.)

```swift
// MARK: - The stack

struct HibiPlusView: View {
    // 0 = stamp card, 1 = feature card
    @State private var frontIndex = 0
    @State private var expanded: [Bool] = [false, false]
    @State private var isPlus = false
    @State private var purchaseDate: Date?

    // animation state
    @State private var dragY: CGFloat = 0
    @State private var isAnimating = false
    @State private var cardShift: CGFloat = 0          // 0…1, back rises to front
    @State private var swipeDir = 1                    // +1 drag up, -1 drag down
    @State private var commitCount = 0                 // haptic
    @State private var ctaSuccess = false
    @State private var stampToken = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont = false

    private var backIndex: Int { 1 - frontIndex }

    private func expandedHeight(for index: Int) -> CGFloat {
        if index == 0 { return HPLayout.stampExpandedHeight }
        return isPlus ? HPLayout.featureExpandedHeightPurchased : HPLayout.featureExpandedHeight
    }
    private func cardSize(_ index: Int, containerWidth: CGFloat) -> CGSize {
        expanded[index]
            ? CGSize(width: containerWidth, height: expandedHeight(for: index))
            : HPLayout.collapsed
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let frontSize = cardSize(frontIndex, containerWidth: w)
            VStack(spacing: 0) {
                stack(containerWidth: w, frontSize: frontSize)
                    .frame(width: frontSize.width, height: frontSize.height)
                    .frame(maxWidth: .infinity)   // center the (possibly narrower) stack
                    .sensoryFeedback(.impact(weight: .medium), trigger: commitCount)
                hint.padding(.top, 14)
            }
            .frame(width: w)
            .animation(HPLayout.collapseSpring, value: expanded)
            .animation(HPLayout.collapseSpring, value: frontIndex)
        }
        .frame(height: totalHeight)
        .animation(HPLayout.collapseSpring, value: expanded)
        .animation(HPLayout.collapseSpring, value: isPlus)
    }

    /// Drives the Form row height. Front card height + hint + spacing.
    private var totalHeight: CGFloat {
        let h = expanded[frontIndex] ? expandedHeight(for: frontIndex) : HPLayout.collapsed.height
        return h + 14 + 18 // hint top padding + hint line
    }

    @ViewBuilder
    private func stack(containerWidth w: CGFloat, frontSize: CGSize) -> some View {
        ZStack {
            // BACK card — the other card, peeking. During a swipe it rises into
            // the front slot (cardShift 0→1).
            cardChrome(index: backIndex, isFront: false, containerWidth: w)
                .frame(
                    width: lerp(HPLayout.collapsed.width - 2 * HPLayout.side, frontSize.width, cardShift),
                    height: lerp(HPLayout.collapsed.height, frontSize.height, cardShift)
                )
                .offset(y: lerp(HPLayout.peek, 0, cardShift))
                .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18 * Double(cardShift)),
                        radius: 22, y: 18)
                .zIndex(1)

            // NEW-BACK placeholder — fades into the back slot during a swipe so
            // the stack still has a second card after reset (the departing
            // card's content).
            if isAnimating {
                cardChrome(index: frontIndex, isFront: false, containerWidth: w)
                    .frame(width: HPLayout.collapsed.width - 2 * HPLayout.side,
                           height: HPLayout.collapsed.height)
                    .offset(y: HPLayout.peek)
                    .opacity(Double(cardShift))
                    .zIndex(0)
            }

            // FRONT card — draggable; slides off in the drag direction on commit.
            cardChrome(index: frontIndex, isFront: true, containerWidth: w)
                .frame(width: frontSize.width, height: frontSize.height)
                .offset(y: dragY)
                .rotationEffect(.degrees(Double(dragY * 0.02)),
                                anchor: dragY > 0 ? .top : .bottom)
                .shadow(color: Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.18),
                        radius: 22, y: 18)
                .opacity(1 - min(Double(abs(dragY)) / 400, 0.6))
                .zIndex(2)
                .highPriorityGesture(dragGesture)
                .onTapGesture { toggleExpand() }
                .accessibilityElement(children: .contain)
                .accessibilityActions {
                    Button("Next page") { commitSwipe(direction: 1) }
                    Button("Previous page") { commitSwipe(direction: -1) }
                    Button(expanded[frontIndex] ? "Collapse" : "Expand") { toggleExpand() }
                }
        }
    }

    /// One card with its paper chrome (fill, border, perforation if front).
    @ViewBuilder
    private func cardChrome(index: Int, isFront: Bool, containerWidth: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: HPLayout.corner, style: .continuous)
        ZStack {
            shape.fill(isFront ? PaperTints.card1 : PaperTints.card2)
            if !isFront {
                shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
            // Body only on the visually-front card.
            if isFront {
                VStack(spacing: 0) {
                    cardBody(index: index)
                    PerforationEdge().padding(.bottom, 6)
                }
            }
        }
        .clipShape(shape)
    }

    @ViewBuilder
    private func cardBody(index: Int) -> some View {
        if index == 0 {
            StampCardBody(purchased: isPlus, date: purchaseDate,
                          expanded: expanded[0], stampToken: stampToken)
        } else {
            FeatureCardBody(purchased: isPlus, expanded: expanded[1],
                            ctaSuccess: $ctaSuccess, onPurchase: purchase)
        }
    }

    private var hint: some View {
        Text("Pull to tear · ↑ Next · ↓ Prev")
            .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { g in
                guard !isAnimating else { return }
                dragY = g.translation.height
                if abs(g.translation.height) > 2 { swipeDir = g.translation.height < 0 ? 1 : -1 }
            }
            .onEnded { _ in
                if abs(dragY) > HPLayout.tearThreshold {
                    commitSwipe(direction: dragY < 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragY = 0 }
                }
            }
    }

    private func toggleExpand() {
        guard !isAnimating else { return }
        withAnimation(HPLayout.collapseSpring) { expanded[frontIndex].toggle() }
    }

    /// Flip to the other card, sliding the front off in `direction`
    /// (+1 = up/off-top, -1 = down/off-bottom). Symmetric + infinite.
    private func commitSwipe(direction: Int) {
        guard !isAnimating else { return }
        swipeDir = direction
        commitCount &+= 1
        isAnimating = true
        let dest = direction == 1 ? -HPLayout.offScreen : HPLayout.offScreen

        withAnimation(.easeIn(duration: 0.28)) { dragY = dest }
        withAnimation(.easeOut(duration: 0.28)) { cardShift = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) {
                frontIndex = backIndex
                dragY = 0
                cardShift = 0
                isAnimating = false
            }
        }
    }

    // MARK: purchase (finished in Task 7)

    private func purchase() {
        isPlus = true
        purchaseDate = Date()
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}
```

- [ ] **Step 2: Verify (read-back)**

Confirm: only two cards in the resting stack; `commitSwipe` works for both
`+1` and `-1`; the no-anim reset swaps `frontIndex`; `toggleExpand` springs the
size; the hint string matches the Day view verbatim. Note for on-device: the
`totalHeight` may need tuning so the Form row isn't clipped.

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Add Hibi Plus two-card stack with symmetric infinite swipe and tap-expand"
```

---

## Task 7: Purchase flow — success → flip to stamp → stamp-in

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Replace `purchase()` with the full sequence**

In `HibiPlusView`, replace the stub `purchase()` with:

```swift
    /// CTA tapped: success morph has already started (PlusCTA set ctaSuccess).
    /// After a beat, set Plus state, flip to the stamp card, and stamp the seal.
    private func purchase() {
        // 1) brief success dwell so the checkmark reads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            isPlus = true
            purchaseDate = Date()

            // 2) flip to the stamp card (collapsed) using the swipe animation
            //    so the motion matches manual navigation. Stamp card is index 0.
            if frontIndex != 0 {
                // animate a downward flip back to card 0
                swipeDir = -1
                isAnimating = true
                withAnimation(.easeIn(duration: 0.28)) { dragY = HPLayout.offScreen }
                withAnimation(.easeOut(duration: 0.28)) { cardShift = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) {
                        frontIndex = 0
                        dragY = 0; cardShift = 0; isAnimating = false
                        expanded[1] = false   // reset feature card to collapsed
                    }
                    // 3) place the seal
                    stampToken &+= 1
                    // reset CTA morph for correctness (card is now hidden)
                    ctaSuccess = false
                }
            } else {
                stampToken &+= 1
                ctaSuccess = false
            }
        }
    }
```

Note: because the feature card's footer is hidden once `isPlus` is true, the
`ctaSuccess` reset is cosmetic but keeps state clean.

- [ ] **Step 2: Verify (read-back)**

Walk the sequence: tap CTA → `ctaSuccess` true (green checkmark) → 0.55s →
`isPlus` true → flip to card 0 → `stampToken` bump → `HibiStamp` replays
stamp-in. Confirm `frontIndex==0` branch also stamps.

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Wire Hibi Plus purchase flow: success morph, flip to stamp, stamp-in"
```

---

## Task 8: Mount in `SettingsView`

**Files:**
- Modify: `Hibi/Views/SettingsView.swift:30-52`

- [ ] **Step 1: Add the first borderless section**

In `Hibi/Views/SettingsView.swift`, inside `Form { … }`, **before** the
`Section("General")`, insert:

```swift
            Section {
                HibiPlusView()
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
```

- [ ] **Step 2: Verify (read-back)**

Confirm the new section is the first child of `Form`, has a cleared background
and hidden separators, and that `HibiPlusView` resolves (same module, no import
needed).

- [ ] **Step 3: Commit**

```bash
git add Hibi/Views/SettingsView.swift
git commit -m "Mount Hibi Plus stack as the first Settings section"
```

---

## Task 9: Localization — all 11 locales

**Files:**
- Modify: `Hibi/Localizable.xcstrings`

The 11 locales: `de, en, es, it, ja, ko, ms, pt-BR, zh-Hans-CN, zh-Hant-HK,
zh-Hant-TW`. Translate **naturally** (see AGENTS.md — no past-participle
title calques, match Apple's localized system terminology, rewrite idioms).

- [ ] **Step 1: Inventory the keys**

These literal keys are introduced (English source):

- `Hibi Plus`
- `Your support matters a lot.`
- `Tap to see what's inside.`
- `App icons`
- `Dress Hibi up.`
- `Early access`
- `Try features first.`
- `Currently in early access`
- `Widgets`
- `On your home screen — paper, every day.`
- `one-time`
- `Restore purchases`
- `Thank you`        (CTA success label)
- `Thank you.`       (stamp deck — distinct, with period)
- `Awaiting your seal`
- `Purchase Hibi Plus to receive your personalized seal.`
- `Pull to tear · ↑ Next · ↓ Prev`  (reuse Day view's existing key if present)
- Accessibility: `Hibi Plus seal`, `Next page`, `Previous page`, `Expand`,
  `Collapse`, `Buy Hibi Plus, $4.99 one-time`, `Purchased. Thank you.`

Plus a **pluralized** days-left string (Step 3).

- [ ] **Step 2: Check whether the hint key already exists**

Run:
```bash
python3 - <<'PY'
import json
d = json.load(open("Hibi/Localizable.xcstrings"))
key = "Pull to tear · ↑ Next · ↓ Prev"
print("HINT PRESENT:", key in d["strings"])
PY
```
Expected: prints `HINT PRESENT: True` or `False`. If True, reuse it (don't
duplicate). If False, the DayView likely builds the hint via interpolation —
in that case add the literal key above for the Plus hint.

- [ ] **Step 3: Replace the days-left placeholder with a pluralized string**

In `EarlyAccessTile`, change:
```swift
                Text("\(daysLeft)d left")
```
to:
```swift
                Text("^[\(daysLeft) day](inflect: true) left")
```
…and add this key to `Localizable.xcstrings` with a `plural` variation per
locale (the executor fills `one`/`other` for each). For locales without
plural distinctions (ja, ko, zh-*, ms), `other` carries the form. Keep it
short like the design ("12d left" style is acceptable per-locale; pick the
natural short form).

> If `inflect` markup proves awkward for the short "Nd left" form, fall back to
> a single `%lld d left`-style key with per-locale variations defined in the
> xcstrings `variations.plural` block. Either way, **every locale must be
> filled** — no empty `localizations: {}`.

- [ ] **Step 4: Add every key with all 11 translations**

Edit `Hibi/Localizable.xcstrings`. For each key above, add a `strings` entry of
the shape:

```json
"Your support matters a lot." : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Your support matters a lot." } },
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Deine Unterstützung bedeutet uns viel." } },
    "es" : { "stringUnit" : { "state" : "translated", "value" : "Tu apoyo significa mucho." } },
    "it" : { "stringUnit" : { "state" : "translated", "value" : "Il tuo sostegno conta molto." } },
    "ja" : { "stringUnit" : { "state" : "translated", "value" : "応援、本当にありがとう。" } },
    "ko" : { "stringUnit" : { "state" : "translated", "value" : "여러분의 응원이 큰 힘이 됩니다." } },
    "ms" : { "stringUnit" : { "state" : "translated", "value" : "Sokongan anda amat bermakna." } },
    "pt-BR" : { "stringUnit" : { "state" : "translated", "value" : "Seu apoio significa muito." } },
    "zh-Hans-CN" : { "stringUnit" : { "state" : "translated", "value" : "感谢你的支持。" } },
    "zh-Hant-HK" : { "stringUnit" : { "state" : "translated", "value" : "多謝你嘅支持。" } },
    "zh-Hant-TW" : { "stringUnit" : { "state" : "translated", "value" : "感謝你的支持。" } }
  }
}
```

Apply the same structure to every key. Suggested natural translations for the
trickier ones (the executor may refine, but must not leave English):

- `Tap to see what's inside.` — de "Tippen, um hineinzuschauen.", ja "タップして中身を見る", ko "탭하여 내용 보기", zh-Hans "点按查看内容", zh-Hant "輕點查看內容", es "Toca para ver qué incluye.", it "Tocca per vedere cosa include.", ms "Ketik untuk lihat kandungan.", pt-BR "Toque para ver o que há dentro."
- `Dress Hibi up.` — de "Hibi neu einkleiden.", ja "Hibi を着せ替え", ko "Hibi 꾸미기", zh-Hans "为 Hibi 换装", zh-Hant "為 Hibi 換裝", es "Viste Hibi a tu gusto.", it "Vesti Hibi come vuoi.", ms "Persiapkan gaya Hibi.", pt-BR "Personalize o visual do Hibi."
- `Try features first.` — de "Funktionen zuerst testen.", ja "新機能をいち早く", ko "새 기능 먼저 사용", zh-Hans "抢先体验新功能", zh-Hant "搶先體驗新功能", es "Prueba funciones antes que nadie.", it "Prova le novità in anteprima.", ms "Cuba ciri lebih awal.", pt-BR "Use os recursos primeiro."
- `On your home screen — paper, every day.` — keep the warm tone; e.g. de "Auf dem Home-Bildschirm — Papier, jeden Tag.", ja "ホーム画面に、毎日の紙を。", etc.
- `Awaiting your seal` — de "Wartet auf dein Siegel", ja "印を待っています", ko "도장을 기다리는 중", etc.
- `Restore purchases` — match Apple's wording per locale (de "Käufe wiederherstellen", ja "購入を復元", ko "구입 복원", zh-Hans "恢复购买", zh-Hant "回復購買項目", es "Restaurar compras", it "Ripristina acquisti", ms "Pulihkan pembelian", pt-BR "Restaurar compras").

(Full per-key tables are the executor's to fill; the rule is: **all 11, natural, no empties**.)

- [ ] **Step 5: Validate JSON + completeness**

```bash
python3 - <<'PY'
import json
LOCALES = {"de","en","es","it","ja","ko","ms","pt-BR","zh-Hans-CN","zh-Hant-HK","zh-Hant-TW"}
d = json.load(open("Hibi/Localizable.xcstrings"))
keys = [
 "Hibi Plus","Your support matters a lot.","Tap to see what's inside.","App icons",
 "Dress Hibi up.","Early access","Try features first.","Currently in early access",
 "Widgets","On your home screen — paper, every day.","one-time","Restore purchases",
 "Thank you","Thank you.","Awaiting your seal",
 "Purchase Hibi Plus to receive your personalized seal.",
]
bad = []
for k in keys:
    e = d["strings"].get(k)
    if not e: bad.append((k,"MISSING")); continue
    locs = set(e.get("localizations",{}).keys())
    missing = LOCALES - locs
    empties = [l for l in locs if not e["localizations"][l].get("stringUnit",{}).get("value")]
    if missing: bad.append((k, "missing "+",".join(sorted(missing))))
    if empties: bad.append((k, "empty "+",".join(sorted(empties))))
print("OK" if not bad else "PROBLEMS:")
for b in bad: print(" ", b)
PY
```
Expected: `OK`. Fix any reported gaps.

- [ ] **Step 6: Grep the diff for unlocalized literals**

```bash
git diff --cached Hibi/Views/HibiPlusView.swift | grep -nE 'Text\("' | grep -v 'verbatim' || echo "none"
```
Every `Text("…")` (non-`verbatim`) must correspond to an xcstrings key. The
`Text(verbatim:)` calls (日々, "26", "23", "$4.99", the seal date) are
intentionally not localized.

- [ ] **Step 7: Commit**

```bash
git add Hibi/Localizable.xcstrings Hibi/Views/HibiPlusView.swift
git commit -m "Localize Hibi Plus strings for all 11 locales"
```

---

## Task 10: Accessibility + Reduce Motion sweep

**Files:**
- Modify: `Hibi/Views/HibiPlusView.swift`

- [ ] **Step 1: Confirm Reduce Motion gating**

Read `HibiPlusView.swift` and confirm each animated decoration checks
`reduceMotion`:
- `AppIconCarousel` — no auto-scroll when reduced (already gated in `.onAppear`).
- `EarlyAccessTile` — no pulse when reduced (already gated).
- `HibiStamp` — `runStampIn()` snaps when reduced (already gated).

The swipe/expand springs are user-initiated and may remain.

- [ ] **Step 2: Confirm VoiceOver actions exist**

Confirm the front card exposes `accessibilityActions` (Next/Previous/Expand)
so the stack is operable without a swipe gesture, and the stamp/CTA have labels.

- [ ] **Step 3: Commit (if changes were needed)**

```bash
git add Hibi/Views/HibiPlusView.swift
git commit -m "Tighten Hibi Plus accessibility and reduce-motion handling"
```

(If Step 1–2 found nothing to change, skip the commit.)

---

## Task 11: Final verification

- [ ] **Step 1: Static read-through**

Read the whole `Hibi/Views/HibiPlusView.swift` once more for:
- Type/name consistency (`ctaSuccess`, `stampToken`, `commitSwipe`,
  `expandedHeight(for:)`, `cardChrome(index:isFront:containerWidth:)`).
- No references to undefined symbols.
- Imports: only `import SwiftUI` is needed.

- [ ] **Step 2: Confirm no Day-view regression risk**

```bash
git diff --stat ed6635e..HEAD
```
Expected: only `HibiPlusView.swift` (new), `SettingsView.swift`,
`PaperTints.swift`, `Localizable.xcstrings`, and the docs are touched.
`DayView.swift` must be untouched.

- [ ] **Step 3: On-device checklist (post-merge, needs a Mac/device)**

Build and run, open Settings:
1. Plus stack renders at top, above General, light + dark.
2. Default = stamp card collapsed (empty slot).
3. Swipe up flips to feature card; swipe down flips back; both directions work
   from either card (infinite); motion matches Day-view feel; no pop on reset.
4. Tap expands/collapses the front card; each card keeps its own state across
   swipes; stamp-expanded ≈ Day-view expanded size; feature-expanded is taller.
5. Dragging on the card swipes (does not scroll the Form); dragging elsewhere
   scrolls the Form normally; `totalHeight` doesn't clip the card.
6. On the expanded feature card, tap "$4.99 one-time" → green "Thank you"
   morph → flips to stamp card → seal stamps in with the bounce; deck reads
   "Thank you."; CTA + Restore are gone; feature card is shorter.
7. Early-access tile shows the correct "Nd left" from `earlyAccessEndDate`.
8. Reduce Motion: carousel static, no pulse, stamp snaps (no bounce).
9. VoiceOver: front card exposes Next/Previous/Expand actions; labels read.

- [ ] **Step 4: Push**

```bash
git push -u origin claude/sharp-cannon-oZ0T9
```

---

## Self-review notes (author)

- **Spec coverage:** stack/2-card/no-holes (T6), symmetric infinite swipe (T6),
  tap-expand + per-card state (T6), sizing (T6 constants), stamp placeholder +
  swap point (T1), carousel current-icon facsimile (T2), early-access +
  hard-coded date (T3), CTA + restore (T4), purchase flow (T7), placement (T8),
  localization 11 locales (T9), accessibility/reduce-motion (T10). All covered.
- **Known tuning risks (call out to executor):** `totalHeight` vs. Form row
  clipping; `highPriorityGesture` vs. List scroll; expanded full-width vs. Form
  row insets; cross-fade between collapsed/expanded bodies may need an explicit
  `.transition`/opacity if the swap looks abrupt. These need a device.
- **Placeholders:** none — every code step shows code; translations give
  concrete values with the rule for the rest.
```
