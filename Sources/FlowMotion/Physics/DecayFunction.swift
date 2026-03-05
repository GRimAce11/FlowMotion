import CoreFoundation

// MARK: - DecayFunction

/// Models friction-based decay for scrolling momentum and fling gestures.
///
/// Uses an exponential decay model: position(t) = v0 / λ * (1 − e^(−λt))
/// where λ is the decay rate (higher = more friction, stops sooner).
public struct DecayFunction: Sendable {

    /// Decay rate λ (1/s). Larger values produce quicker stops.
    /// iOS scroll view uses approximately 0.998 per frame (≈ 0.12 per second).
    public var decayRate: Double

    public init(decayRate: Double = 0.998) {
        self.decayRate = decayRate
    }

    // MARK: Named presets

    /// Matches UIScrollView scroll-deceleration feel (iOS default).
    public static let scrollView = DecayFunction(decayRate: 0.998)

    /// Fast stop — good for drag-to-dismiss snapping.
    public static let fast  = DecayFunction(decayRate: 0.92)

    /// Very gradual coast — similar to magnetic levitation feel.
    public static let coast = DecayFunction(decayRate: 0.9995)

    // MARK: - Queries

    /// Converts per-frame decay rate to a per-second rate (λ) at 60 Hz.
    private var lambda: Double {
        -log(decayRate) * 60   // frames/s
    }

    /// Position at time `t` seconds, given initial velocity `v0` (pts/s).
    public func position(at t: Double, from origin: Double = 0, initialVelocity v0: Double) -> Double {
        let λ = lambda
        guard λ > 0 else { return origin + v0 * t }
        return origin + v0 / λ * (1 - exp(-λ * t))
    }

    /// Velocity at time `t` seconds.
    public func velocity(at t: Double, initialVelocity v0: Double) -> Double {
        exp(-lambda * t) * v0
    }

    /// Total distance travelled from `origin` before velocity falls below `threshold`.
    public func totalDisplacement(initialVelocity v0: Double, threshold: Double = 0.5) -> Double {
        // v(t) = v0 * e^(-λt) < threshold → t = ln(|v0|/threshold) / λ
        let λ = lambda
        guard λ > 0 else { return 0 }
        let settleDuration = log(abs(v0) / threshold) / λ
        guard settleDuration > 0 else { return 0 }
        return position(at: settleDuration, initialVelocity: v0)
    }

    /// Time until velocity falls below `threshold`.
    public func settlingDuration(initialVelocity v0: Double, threshold: Double = 0.5) -> Double {
        let λ = lambda
        guard λ > 0, abs(v0) > threshold else { return 0 }
        return log(abs(v0) / threshold) / λ
    }
}
