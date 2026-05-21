---
name: localizing-user-strings
description: Use when adding or changing any user-facing content in Hibi — UI labels, alerts, button titles, accessibility strings, What's New entries, Info.plist usage descriptions, or any text the user can read on screen. Required before declaring such work done.
---

# Localizing User Strings

## Overview

Every user-facing string in Hibi ships to 11 locales. Hard-coded English literals are bugs — non-English users see English fallbacks. This skill is the gate: before any feature touching visible text is "done," every new string must exist in `Localizable.xcstrings` (or `InfoPlist.xcstrings`) with translations for **all 11 locales**.

**The rule, stated as a single line:**
> No user-visible string ships without entries in all 11 locales.

## Supported locales (all required)

`de`, `en`, `es`, `it`, `ja`, `ko`, `ms`, `pt-BR`, `zh-Hans-CN`, `zh-Hant-HK`, `zh-Hant-TW`

Source language is `en`. Empty `localizations: { }` is a bug — it ships English to non-English users. This has happened before (WhatsNewKit v1.8 fell back to English in Japanese).

## When to use

Trigger this skill whenever you add or change text that the user can see, including:

- `Text("…")`, `Label(…)`, `Button("…", …)`, `.navigationTitle(…)`, `.toolbar { … }` labels
- Alert titles/messages, confirmation dialogs, sheet headers
- `.accessibilityLabel(…)`, `.accessibilityHint(…)`
- `EventEditorSheet` / `WhatsNew` titles and subtitles
- `InfoPlist.xcstrings` keys (usage descriptions, `CFBundleDisplayName`, etc.)
- Error/empty/permission-prompt copy (e.g. `CalendarAccessPrompt`)

If you grep your diff for `Text(`, `Label(`, `Button(`, `alert(`, `.confirmationDialog(`, `accessibilityLabel`, `WhatsNew.Feature(` and any string literal is bare (not `String(localized:)` / `LocalizedStringKey`), you have unlocalized content. Fix it.

## Core pattern

```swift
// ❌ BAD — hard-coded English, no xcstrings entry
Text("All day")
Button("Add event") { … }
.accessibilityLabel("Next day")

// ✅ GOOD — keyed, and every key has an entry in Localizable.xcstrings
Text("All day")                            // SwiftUI auto-localizes via LocalizedStringKey
Text(String(localized: "All day"))         // Explicit, required outside SwiftUI literal context
Button(String(localized: "Add event")) { … }
.accessibilityLabel(Text("Next day"))
```

SwiftUI's `Text("literal")` already takes a `LocalizedStringKey` — but the key must still be added to `Localizable.xcstrings`. For string interpolation in non-SwiftUI contexts (logs, formatters, `accessibilityLabel(_:)` String overloads), use `String(localized: "…")`.

## Required xcstrings entry shape

For every new key, append an entry to `Hibi/Localizable.xcstrings` (or `Hibi/InfoPlist.xcstrings` for Info.plist values). It must have:

- `extractionState: "manual"`
- A `comment` describing where it appears (helps translators and future readers)
- A `localizations` block with **all 11 locales**, each `state: "translated"`

```json
"All day": {
  "comment": "Shown on the Day tab masthead for all-day events.",
  "extractionState": "manual",
  "localizations": {
    "de": { "stringUnit": { "state": "translated", "value": "Ganztägig" } },
    "en": { "stringUnit": { "state": "translated", "value": "All day" } },
    "es": { "stringUnit": { "state": "translated", "value": "Todo el día" } },
    "it": { "stringUnit": { "state": "translated", "value": "Tutto il giorno" } },
    "ja": { "stringUnit": { "state": "translated", "value": "終日" } },
    "ko": { "stringUnit": { "state": "translated", "value": "종일" } },
    "ms": { "stringUnit": { "state": "translated", "value": "Sepanjang hari" } },
    "pt-BR": { "stringUnit": { "state": "translated", "value": "Dia inteiro" } },
    "zh-Hans-CN": { "stringUnit": { "state": "translated", "value": "全天" } },
    "zh-Hant-HK": { "stringUnit": { "state": "translated", "value": "全日" } },
    "zh-Hant-TW": { "stringUnit": { "state": "translated", "value": "整天" } }
  }
}
```

The file is large; insert entries with a small Python/JSON script rather than hand-editing if you risk breaking the JSON.

## Translate naturally, not literally

A translation must read like a sentence a native speaker would actually write — not a word-for-word mapping. Concrete failure modes that have shipped here:

- **No past-participle adjective titles in de/ja/ko.** `"Verfeinerte Monatsansicht"`, `"整えられた月表示"`, `"다듬어진 월 보기"` all read like Google Translate. Prefer noun phrases or native release-note style.
- **Match Apple's localized terminology** for system concepts. Look at how iOS Calendar/Reminders phrases the same idea in that locale.
  - Recurrence: `wiederkehrend` (de) not `wiederholend`; `繰り返し` (ja) not `ループ`; `重复`/`重複` (zh) not `循环`/`循環`.
- **Rewrite English idioms** into the target language's equivalent rather than translating word-for-word. "Breathing room" rendered literally as `ruang nafas yang sepatutnya` (ms) or `o espaço que merece` (pt-BR) is wrong — translate the *meaning*.
- **Keep the register.** If English is warm and conversational, the translation should be too — not stiff and technical.

When unsure, ask the user before shipping rather than guessing literally.

## Workflow

1. Wrap every new visible string in `String(localized: "…")` / `Text("…")` / `LocalizedStringKey`.
2. For each new key, add an entry with all 11 locales to the right xcstrings file (`Localizable.xcstrings` for app strings, `InfoPlist.xcstrings` for Info.plist values).
3. Apply the natural-translation rules above to every locale, not just the obvious ones.
4. Before declaring the task done, run a self-check (see below). If any item fails, you are not done.

## Self-check before declaring done

Grep your diff and confirm each item:

- [ ] No bare `"…"` literal next to `Text(`, `Label(`, `Button(`, `.navigationTitle(`, `.accessibilityLabel(`, `.accessibilityHint(`, alert/dialog calls, `WhatsNew.Feature(`.
- [ ] Every new `String(localized: "KEY")` and every new `Text("KEY")` SwiftUI literal has a matching entry in `Hibi/Localizable.xcstrings`.
- [ ] Every new Info.plist usage description / display string has a matching entry in `Hibi/InfoPlist.xcstrings`.
- [ ] Every new entry contains **all 11** locales: `de`, `en`, `es`, `it`, `ja`, `ko`, `ms`, `pt-BR`, `zh-Hans-CN`, `zh-Hant-HK`, `zh-Hant-TW`. No `localizations: { }`.
- [ ] Every locale's `state` is `"translated"` (not `"new"` or missing).
- [ ] Translations follow the natural-translation rules: no past-participle adjective titles in de/ja/ko, Apple terminology for system concepts, idioms rewritten not calqued.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `Text("Add event")` with no xcstrings entry | Add entry to `Localizable.xcstrings` with all 11 locales. |
| `localizations: { }` (empty) | Fill all 11 locales — empty ships English fallback. |
| Translating "loop icon" → `ループアイコン` / `循环图标` | Use Apple's recurrence vocabulary: `繰り返しマーク` / `重复` / `重複`. |
| German title `"Verfeinerte Monatsansicht"` | Rewrite as a native release-note noun phrase, not a past-participle adjective. |
| Adding a new Info.plist usage description without updating `InfoPlist.xcstrings` | Localize Info.plist strings the same way as app strings. |
| Hand-editing the huge xcstrings JSON and breaking it | Use a small Python script to insert entries. |
| Marking the work done before checking translations | Run the self-check above. It is part of "done." |

## Red flags — STOP

- "It's just a debug label, no need to localize" → if the user can see it, localize it.
- "I'll translate the other 10 locales later" → later doesn't happen; ship with all 11 or don't ship.
- "Machine translation is close enough" → see the failure modes above; redo the ones that read stiff.
- "The English copy might change, I'll wait" → add all 11 now; updating is cheaper than shipping an English fallback.

If any of these thoughts appear: stop, finish the localizations, then continue.
