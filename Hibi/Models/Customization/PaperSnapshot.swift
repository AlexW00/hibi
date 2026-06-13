import Foundation
import WidgetKit

/// Snapshot of the user's chosen paper tokens, written to the App Group so the
/// widget extension can read them without needing SwiftData access.
///
/// Stage 10 reads these tokens to render paper in the widget; this file only
/// guarantees the data lands in the App Group. Bump the key suffix if the shape
/// changes (a stale blob from an old install must never crash the widget).
struct PaperSnapshot: Codable, Sendable, Equatable {
    var textureRaw: Int
    var rulingRaw: Int
    var tintRaw: Int

    /// Convenience init from a SwiftData `PaperStyle`.
    init(from style: PaperStyle) {
        textureRaw = style.textureRaw
        rulingRaw = style.rulingRaw
        tintRaw = style.tintRaw
    }

    // MARK: - App Group I/O

    /// Encode this snapshot to the App Group and optionally reload widget
    /// timelines.
    ///
    /// - Parameters:
    ///   - style: The committed `PaperStyle` to snapshot.
    ///   - defaults: The `UserDefaults` suite to write into. Defaults to
    ///     `AppGroup.defaults`. Pass an isolated suite in tests.
    ///   - reload: When `true`, calls `WidgetCenter.shared.reloadAllTimelines()`.
    ///     Pass `false` in tests to avoid importing WidgetKit into the test process.
    static func write(
        from style: PaperStyle,
        defaults: UserDefaults? = AppGroup.defaults,
        reload: Bool = true
    ) {
        let snapshot = PaperSnapshot(from: style)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: AppGroup.Key.paperSnapshot)
        if reload {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Decode a previously written snapshot from the given defaults suite.
    ///
    /// Returns `nil` if the key is absent or the blob cannot be decoded.
    static func read(from defaults: UserDefaults? = AppGroup.defaults) -> PaperSnapshot? {
        guard let data = defaults?.data(forKey: AppGroup.Key.paperSnapshot) else { return nil }
        return try? JSONDecoder().decode(PaperSnapshot.self, from: data)
    }
}
