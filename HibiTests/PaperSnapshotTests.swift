import Testing
import Foundation
@testable import Hibi

/// Tests for `PaperSnapshot` — App Group serialization of the user's paper
/// tokens. Tests are not run (no simulator); compile correctness is verified
/// via `build-for-testing`.
@MainActor
struct PaperSnapshotTests {

    // MARK: - Helpers

    /// Returns a fresh, isolated `UserDefaults` suite that doesn't touch the
    /// real App Group. Cleaned before handing back so tests stay independent.
    private func freshDefaults() -> UserDefaults {
        let name = "com.weichart.hibi.tests.paperSnapshot.\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name)!
    }

    /// Builds an uninserted `PaperStyle` with distinct raw values so a field
    /// transposition (e.g. swapping tintRaw and rulingRaw) is detectable.
    private func makeStyle(texture: Int = 1, ruling: Int = 2, tint: Int = 3) -> PaperStyle {
        let style = PaperStyle()
        style.textureRaw = texture
        style.rulingRaw = ruling
        style.tintRaw = tint
        return style
    }

    // MARK: - init(from:) mapping

    @Test func initFromStyleMapsRawsCorrectly() {
        let style = makeStyle(texture: 1, ruling: 2, tint: 3)
        let snapshot = PaperSnapshot(from: style)
        #expect(snapshot.textureRaw == 1)
        #expect(snapshot.rulingRaw == 2)
        #expect(snapshot.tintRaw == 3)
    }

    // MARK: - Encode / decode round-trip

    @Test func encodeThenDecodePreservesAllRaws() throws {
        let original = PaperSnapshot(from: makeStyle(texture: 2, ruling: 1, tint: 4))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaperSnapshot.self, from: data)
        #expect(decoded == original)
        #expect(decoded.textureRaw == original.textureRaw)
        #expect(decoded.rulingRaw == original.rulingRaw)
        #expect(decoded.tintRaw == original.tintRaw)
    }

    // MARK: - write(from:defaults:reload:) + read(from:)

    @Test func writePopulatesAppGroupKeyAndReadReturnsIt() {
        let defaults = freshDefaults()
        let style = makeStyle(texture: 3, ruling: 1, tint: 5)

        // Verify the key is absent before write.
        #expect(PaperSnapshot.read(from: defaults) == nil)

        PaperSnapshot.write(from: style, defaults: defaults, reload: false)

        let snapshot = PaperSnapshot.read(from: defaults)
        #expect(snapshot != nil)
        #expect(snapshot?.textureRaw == 3)
        #expect(snapshot?.rulingRaw == 1)
        #expect(snapshot?.tintRaw == 5)
    }

    @Test func writeOverwritesPreviousSnapshot() {
        let defaults = freshDefaults()

        PaperSnapshot.write(from: makeStyle(texture: 0, ruling: 0, tint: 0), defaults: defaults, reload: false)
        PaperSnapshot.write(from: makeStyle(texture: 4, ruling: 3, tint: 2), defaults: defaults, reload: false)

        let snapshot = PaperSnapshot.read(from: defaults)
        #expect(snapshot?.textureRaw == 4)
        #expect(snapshot?.rulingRaw == 3)
        #expect(snapshot?.tintRaw == 2)
    }

    @Test func readReturnsNilFromEmptySuite() {
        let defaults = freshDefaults()
        #expect(PaperSnapshot.read(from: defaults) == nil)
    }

    @Test func readReturnsNilFromNilDefaults() {
        #expect(PaperSnapshot.read(from: nil) == nil)
    }

    @Test func writeWithNilDefaultsDoesNotCrash() {
        let style = makeStyle()
        // Must not crash even when no App Group suite is available.
        PaperSnapshot.write(from: style, defaults: nil, reload: false)
    }
}
