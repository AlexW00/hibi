import CoreMotion
import Observation

/// Observable device-tilt source for the Day view's paper-stack parallax.
///
/// Reports tilt **relative to the orientation the device was in when `start()`
/// was called** — a reference pose is captured on the first sample and every
/// later sample is expressed as a delta from it. That makes "however you're
/// holding the phone right now" the neutral pose, so the stack rests centered
/// whether you're upright on a couch or flat on a desk.
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
    /// Smoothed left/right lean from rest, roughly -1…1.
    private(set) var tiltX: Double = 0
    /// Smoothed front/back recline from rest, roughly -1…1.
    private(set) var tiltY: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var referenceLean: Double?
    @ObservationIgnored private var referenceRecline: Double?
    @ObservationIgnored private var isRunning = false

    /// Tilt of this many radians from rest maps to the full ±1 range (~20°).
    private let maxTilt: Double = 0.35
    /// Low-pass blend per sample. Lower = smoother but laggier.
    private let smoothing: Double = 0.12
    /// Skip publishing sub-pixel changes so a still device doesn't redraw.
    private let epsilon: Double = 0.0008

    func start() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        isRunning = true
        referenceLean = nil
        referenceRecline = nil
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
        referenceLean = nil
        referenceRecline = nil
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

        if referenceLean == nil {
            referenceLean = lean
            referenceRecline = recline
        }
        guard let referenceLean, let referenceRecline else { return }

        let newX = tiltX + (clampNorm(lean - referenceLean) - tiltX) * smoothing
        let newY = tiltY + (clampNorm(recline - referenceRecline) - tiltY) * smoothing
        if abs(newX - tiltX) > epsilon { tiltX = newX }
        if abs(newY - tiltY) > epsilon { tiltY = newY }
    }

    private func clampNorm(_ radians: Double) -> Double {
        max(-1, min(1, radians / maxTilt))
    }
}
