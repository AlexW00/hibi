import Testing
@testable import Hibi

/// Truth table for the live tilt-specular gate.
///
/// The paper texture is baked; the only LIVE term is the tilt highlight. It must be
/// suppressed under Reduce Motion *or* Low Power — `paperTiltEnabled` is the pure
/// helper the substrate consults to decide whether to apply the `.layerEffect`.
struct PaperTiltEnabledTests {

    @Test func enabledOnlyWhenNeitherFlagSet() {
        #expect(paperTiltEnabled(reduceMotion: false, lowPower: false) == true)
    }

    @Test func disabledWhenReduceMotion() {
        #expect(paperTiltEnabled(reduceMotion: true, lowPower: false) == false)
    }

    @Test func disabledWhenLowPower() {
        #expect(paperTiltEnabled(reduceMotion: false, lowPower: true) == false)
    }

    @Test func disabledWhenBoth() {
        #expect(paperTiltEnabled(reduceMotion: true, lowPower: true) == false)
    }
}
