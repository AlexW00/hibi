import CoreMotion
import Observation

/// Observable device-tilt source for the Day view's paper-stack parallax.
///
/// Reports tilt **relative to the orientation the device was in when `start()`
/// was called** — the reference attitude is captured on the first sample and
/// every later sample is expressed as a delta from it (`multiply(byInverseOf:)`).
/// That makes "however you're holding the phone right now" the neutral pose, so
/// the stack rests centered regardless of whether you're upright on a couch or
/// flat on a desk.
///
/// `tiltX`/`tiltY` are low-pass filtered and gated by a small epsilon so a
/// perfectly still device produces no SwiftUI invalidations. Device motion needs
/// no authorization and no Info.plist key (unlike CMMotionActivity), so starting
/// it never prompts the user.
@MainActor
@Observable
final class MotionStore {
    /// Smoothed left/right tilt (roll) from rest, roughly -1…1.
    private(set) var tiltX: Double = 0
    /// Smoothed forward/back tilt (pitch) from rest, roughly -1…1.
    private(set) var tiltY: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?
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
        reference = nil
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
        reference = nil
        // Recenter so the stack doesn't keep a stale offset while parallax is off.
        tiltX = 0
        tiltY = 0
    }

    private func ingest(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        if reference == nil {
            reference = attitude.copy() as? CMAttitude
        }
        guard let reference, let current = attitude.copy() as? CMAttitude else { return }
        current.multiply(byInverseOf: reference)

        let newX = tiltX + (clampNorm(current.roll) - tiltX) * smoothing
        let newY = tiltY + (clampNorm(current.pitch) - tiltY) * smoothing
        if abs(newX - tiltX) > epsilon { tiltX = newX }
        if abs(newY - tiltY) > epsilon { tiltY = newY }
    }

    private func clampNorm(_ radians: Double) -> Double {
        max(-1, min(1, radians / maxTilt))
    }
}
