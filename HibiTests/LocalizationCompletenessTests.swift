import Foundation
import Testing
@testable import Hibi

/// Verifies every key in `Localizable.xcstrings` has a non-empty translation
/// for all 11 shipping locales. Prevents the bug class where What's New or
/// Settings text ships English-only to non-English users (v1.8 incident).
///
/// A Run Script build phase on HibiTests copies the raw `.xcstrings` JSON
/// into the test host bundle so these tests work on-device (where `#filePath`
/// paths are unreachable).
@Suite("Localization completeness")
struct LocalizationCompletenessTests {

    private final class _BundleAnchor {}

    private static let shippingLocales = [
        "en", "de", "ja", "ko", "ms", "es", "it", "pt-BR",
        "zh-Hans-CN", "zh-Hant-HK", "zh-Hant-TW",
    ]

    private struct CatalogEntry: Decodable {
        let strings: [String: StringEntry]
    }

    private struct StringEntry: Decodable {
        let localizations: [String: LocalizationValue]?
        let shouldTranslate: Bool?

        private enum CodingKeys: String, CodingKey {
            case localizations, shouldTranslate
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            localizations = try c.decodeIfPresent([String: LocalizationValue].self, forKey: .localizations)
            shouldTranslate = try c.decodeIfPresent(Bool.self, forKey: .shouldTranslate)
        }
    }

    private struct LocalizationValue: Decodable {
        let stringUnit: StringUnit?
    }

    private struct StringUnit: Decodable {
        let state: String?
        let value: String?
    }

    private static func loadCatalog(named name: String) -> CatalogEntry? {
        let bundle = Bundle(for: _BundleAnchor.self)
        guard let url = bundle.url(forResource: name, withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(CatalogEntry.self, from: data)
        else { return nil }
        return catalog
    }

    @Test func localizableCatalogHasAllLocales() throws {
        let catalog = try #require(
            Self.loadCatalog(named: "Localizable"),
            "Could not load Localizable.xcstrings from project"
        )

        var missing: [(key: String, locale: String)] = []

        for (key, entry) in catalog.strings {
            if entry.shouldTranslate == false { continue }

            let locs = entry.localizations ?? [:]
            for locale in Self.shippingLocales {
                guard let loc = locs[locale] else {
                    missing.append((key, locale))
                    continue
                }
                let value = loc.stringUnit?.value ?? ""
                if value.isEmpty {
                    missing.append((key, locale))
                }
            }
        }

        if !missing.isEmpty {
            let summary = missing.prefix(20).map { "\($0.locale): \"\($0.key)\"" }
                .joined(separator: "\n  ")
            Issue.record("Missing \(missing.count) translations:\n  \(summary)")
        }
    }

    @Test func infoPlistCatalogHasAllLocales() throws {
        let catalog = try #require(
            Self.loadCatalog(named: "InfoPlist"),
            "Could not load InfoPlist.xcstrings from project"
        )

        var missing: [(key: String, locale: String)] = []

        for (key, entry) in catalog.strings {
            if entry.shouldTranslate == false { continue }

            let locs = entry.localizations ?? [:]
            for locale in Self.shippingLocales {
                guard let loc = locs[locale] else {
                    missing.append((key, locale))
                    continue
                }
                let value = loc.stringUnit?.value ?? ""
                if value.isEmpty {
                    missing.append((key, locale))
                }
            }
        }

        if !missing.isEmpty {
            let summary = missing.prefix(20).map { "\($0.locale): \"\($0.key)\"" }
                .joined(separator: "\n  ")
            Issue.record("Missing \(missing.count) InfoPlist translations:\n  \(summary)")
        }
    }
}
