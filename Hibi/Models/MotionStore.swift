import CoreMotion
import Observation

/// Observable device-tilt source for the Day view's paper-stack parallax.
///
/// **Motion-based, not orientation-based.** The effect responds to *changes* in
/// tilt, then eases back to neutral: move the phone and the stack drifts; hold
/// it steady at any angle and it returns to base. That's deliberate — people
/// don't hold a phone perfectly upright, and an absolute-tilt mapping would
/// leave a permanent offset for whatever resting angle they happen to use.
///
/// The recentering is a high-pass filter: a baseline pose continuously drifts
/// toward the current pose (`baselineFollow`), and the output is the difference
/// between the two. A sustained pose is absorbed by the baseline and decays to
/// zero; a quick move outruns the baseline and produces a transient that springs
/// back once you settle.
///
/// Tilt is derived from the **gravity vector**, not the attitude's Euler
/// angles. Euler `pitch`/`roll` degenerate (gimbal lock) when the phone is held
/// near-vertical — which is exactly the Day-view reading pose — so front/back
/// tilt would read as zero there. The gravity vector stays well-defined at any
/// orientation, giving two decoupled, responsive tilt axes.
///
/// `tiltX`/`tiltY` are low-pass filtered and gated by a small epsilon so a
/// perfectly still device produces no SwiftUI invalidations. Device motion needs
/// no authorization and no Info.plist key (unlike CMMotionActivity), so starting
/// it never prompts the user.
@MainActor
@Observable
final class MotionStore {
    /// Smoothed left/right lean transient, roughly -1…1. Decays to 0 at rest.
    private(set) var tiltX: Double = 0
    /// Smoothed front/back recline transient, roughly -1…1. Decays to 0 at rest.
    private(set) var tiltY: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var baselineLean: Double?
    @ObservationIgnored private var baselineRecline: Double?
    @ObservationIgnored private var isRunning = false

    /// A transient of this many radians maps to the full ±1 range. Smaller =
    /// gentler moves reach full parallax.
    private let maxTilt: Double = 0.2
    /// How fast the neutral baseline drifts toward the current pose — i.e. how
    /// quickly a held tilt returns to base. Larger = snappier return (and
    /// demands quicker motion to register). ~0.04 ≈ settles in roughly a second.
    private let baselineFollow: Double = 0.04
    /// Low-pass blend per sample. Lower = smoother but laggier.
    private let smoothing: Double = 0.12
    /// Skip publishing sub-pixel changes so a still device doesn't redraw.
    private let epsilon: Double = 0.0008

    func start() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        isRunning = true
        baselineLean = nil
        baselineRecline = nil
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                self?.ingest(motion)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        baselineLean = nil
        baselineRecline = nil
        // Recenter so the stack doesn't keep a stale offset while parallax is off.
        tiltX = 0
        tiltY = 0
    }

    private func ingest(_ motion: CMDeviceMotion) {
        let g = motion.gravity
        // Left/right lean: gravity's angle out of the device's Y–Z plane.
        // ~0 when held straight, grows as the phone leans to either side.
        let lean = atan2(g.x, hypot(g.y, g.z))
        // Front/back recline (tilting the bottom up / top back): gravity's
        // angle within the Y–Z plane. ~0 when upright, →π/2 when flat.
        let recline = atan2(-g.z, -g.y)

        // First sample seeds the baseline so we don't fire a transient on start.
        if baselineLean == nil {
            baselineLean = lean
            baselineRecline = recline
        }
        guard var bLean = baselineLean, var bRecline = baselineRecline else { return }

        // High-pass: ease the baseline toward the current pose so a sustained
        // tilt is absorbed (returns to base) while a quick move produces a
        // transient. The published value is the current pose minus this
        // drifting baseline.
        bLean += (lean - bLean) * baselineFollow
        bRecline += (recline - bRecline) * baselineFollow
        baselineLean = bLean
        baselineRecline = bRecline

        let newX = tiltX + (clampNorm(lean - bLean) - tiltX) * smoothing
        let newY = tiltY + (clampNorm(recline - bRecline) - tiltY) * smoothing
        if abs(newX - tiltX) > epsilon { tiltX = newX }
        if abs(newY - tiltY) > epsilon { tiltY = newY }
    }

    private func clampNorm(_ radians: Double) -> Double {
        max(-1, min(1, radians / maxTilt))
    }
}
