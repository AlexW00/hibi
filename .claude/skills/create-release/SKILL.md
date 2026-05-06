---
name: create-release
description: Create a new Hibi release — bump version/build, add What's New entry with localizations, commit, push, tag, and generate App Store Connect text.
---

# Create Release

Full release checklist for Hibi. Trigger: "create a release", "ship a release", "new release", "bump version".

## Steps

### 1. Identify changes

Run `git log --oneline --merges` to find PRs merged since the last release. Summarize each in one sentence.

### 2. Bump version and build number

In `Hibi.xcodeproj/project.pbxproj`, update both build configurations (Debug + Release):
- `MARKETING_VERSION` — increment minor (e.g. 1.8 → 1.9)
- `CURRENT_PROJECT_VERSION` — increment by 1 (e.g. 19 → 20)

Use `replace_all` since both configurations must match.

### 3. Update WhatsNewContent.swift

In `Hibi/Models/WhatsNewContent.swift`:

1. Copy the current `latest` body into a new `static var v1_X` (using the OLD version number, e.g. `v1_8`), changing only `version:` to a hardcoded string (e.g. `"1.8"`).
2. Replace `latest`'s features with the new release features (one `WhatsNew.Feature` per change, with SF Symbol, localized title, localized subtitle).
3. Update `static let version` to the new version string.
4. Update the doc comment `MARKETING_VERSION` reference.
5. Add the new `v1_X` to `collection` after `latest`.

### 4. Add localizations

Add each new `String(localized:)` key to `Hibi/Localizable.xcstrings` with translations for **all 11 locales**: `de`, `en`, `es`, `it`, `ja`, `ko`, `ms`, `pt-BR`, `zh-Hans-CN`, `zh-Hant-HK`, `zh-Hant-TW`.

Use Python/JSON to insert entries (the file is large). Set `extractionState: "manual"` and include a `comment` referencing the version.

Translation rules from AGENTS.md:
- No past-participle adjective titles in de/ja/ko
- Use Apple's localized terminology (e.g. `wiederkehrend` not `wiederholend`, `繰り返し` not `ループ`, `重复`/`重複` not `循环`/`循環`)
- Rewrite idioms naturally, don't translate literally
- Every locale must have a value — empty `localizations: {}` is a bug

### 5. Commit, push, and tag

```
git add Hibi.xcodeproj/project.pbxproj Hibi/Models/WhatsNewContent.swift Hibi/Localizable.xcstrings
git commit -m "bump to vX.Y (build N) with What's New for PRs #A–#Z"
git push
git tag vX.Y
git push origin vX.Y
```

### 6. App Store Connect "What's New" text

Provide the release notes as copyable markdown code blocks in these languages:
- English
- Chinese (Simplified)
- Chinese (Traditional)
- Japanese
- Korean

Format: bulleted list of the subtitle-level descriptions (not the titles). One bullet per feature.
