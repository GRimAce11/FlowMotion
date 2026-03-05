import SwiftUI

// MARK: - SpringSolver

/// An analytical, deterministic spring physics solver.
///
/// Implements the closed-form solution to the damped harmonic oscillator ODE:
///
///     m·x'' + c·x' + k·x = 0
///
/// Because it computes exact values at any time `t` (no numerical integration),
/// it is both deterministic and interruptible — you can query x(t) and v(t)
/// at any moment and start a new spring from that state.
///
/// All values are in the scalar domain. Call twice for 2D motion (x and y axes).
public struct SpringSolver: Sendable {

    public let configuration: SpringConfiguration
    public let x0: Double   // initial displacement from target
    public let v0: Double   // initial velocity

    /// Regime determined by the damping ratio.
    private enum Regime: Sendable {
        case underdamped(ωd: Double)
        case criticallyDamped
        case overdamped(r1: Double, r2: Double)
    }

    private let regime: Regime

    // MARK: Init

    /// Creates a solver for a spring starting at `from` (current position)
    /// targeting `to`, with an optional initial velocity `initialVelocity`.
    public init(
        configuration: SpringConfiguration,
        from: Double,
        to: Double,
        initialVelocity: Double = 0
    ) {
        self.configuration = configuration
        self.x0 = from - to   // displacement in centred coordinates
        self.v0 = initialVelocity

        let ζ = configuration.dampingRatio
        let ω = configuration.omega
        if ζ < 1 {
            regime = .underdamped(ωd: configuration.dampedOmega)
        } else if ζ == 1 {
            regime = .criticallyDamped
        } else {
            let r1 = -ω * (ζ - (ζ * ζ - 1).squareRoot())
            let r2 = -ω * (ζ + (ζ * ζ - 1).squareRoot())
            regime = .overdamped(r1: r1, r2: r2)
        }
    }

    // MARK: - Queries

    /// Displacement from target at time `t` (seconds). Add `to` to recover position.
    public func displacement(at t: Double) -> Double {
        guard t > 0 else { return x0 }
        switch regime {
        case .underdamped(let ωd):
            let decay = exp(-configuration.dampingRatio * configuration.omega * t)
            let cos   = Foundation.cos(ωd * t)
            let sin   = Foundation.sin(ωd * t)
            let A     = x0
            let B     = (v0 + configuration.dampingRatio * configuration.omega * x0) / ωd
            return decay * (A * cos + B * sin)

        case .criticallyDamped:
            let ω   = configuration.omega
            let decay = exp(-ω * t)
            return decay * (x0 + (v0 + ω * x0) * t)

        case .overdamped(let r1, let r2):
            let A = (v0 - r2 * x0) / (r1 - r2)
            let B = (r1 * x0 - v0) / (r1 - r2)
            return A * exp(r1 * t) + B * exp(r2 * t)
        }
    }

    /// Velocity (first derivative of displacement) at time `t` (seconds).
    public func velocity(at t: Double) -> Double {
        guard t > 0 else { return v0 }
        switch regime {
        case .underdamped(let ωd):
            let ζ     = configuration.dampingRatio
            let ω     = configuration.omega
            let decay = exp(-ζ * ω * t)
            let cos   = Foundation.cos(ωd * t)
            let sin   = Foundation.sin(ωd * t)
            let A     = x0
            let B     = (v0 + ζ * ω * x0) / ωd
            return decay * (
                (B * ωd - A * ζ * ω) * cos
              - (A * ωd + B * ζ * ω) * sin
            )

        case .criticallyDamped:
            let ω   = configuration.omega
            let decay = exp(-ω * t)
            return decay * (v0 - (v0 + ω * x0) * ω * t)

        case .overdamped(let r1, let r2):
            let A = (v0 - r2 * x0) / (r1 - r2)
            let B = (r1 * x0 - v0) / (r1 - r2)
            return A * r1 * exp(r1 * t) + B * r2 * exp(r2 * t)
        }
    }

    /// Returns the normalised position in [0, 1] at time `t`,
    /// where 0 = start (`from`) and 1 = target (`to`).
    public func progress(at t: Double) -> Double {
        guard x0 != 0 else { return 1 }
        let disp = displacement(at: t)
        return 1 - disp / x0
    }

    // MARK: - Settlement

    /// Estimated time (s) after which |displacement| stays below
    /// `configuration.settlingThreshold`.
    ///
    /// Uses binary search bounded to [0, 20] seconds for correctness.
    public var settlingDuration: Double {
        let threshold = configuration.settlingThreshold
        guard abs(x0) > threshold else { return 0 }

        var lo: Double = 0
        var hi: Double = 20

        // Clamp upper bound to first time we're definitively below threshold
        for _ in 0 ..< 50 {
            let mid = (lo + hi) / 2
            if isSettled(at: mid, threshold: threshold) {
                hi = mid
            } else {
                lo = mid
            }
        }
        return hi
    }

    private func isSettled(at t: Double, threshold: Double) -> Bool {
        abs(displacement(at: t)) < threshold && abs(velocity(at: t)) < threshold
    }

    // MARK: - Sampling

    /// Samples the spring curve at `count` evenly-spaced time steps
    /// from t=0 to `duration`, returning (t, position) pairs.
    public func sample(count: Int, duration: Double, to: Double = 0) -> [(t: Double, position: Double)] {
        guard count > 1 else { return [(0, to + x0)] }
        let step = duration / Double(count - 1)
        return (0 ..< count).map { i in
            let t = Double(i) * step
            return (t, to + displacement(at: t))
        }
    }
}

// MARK: - 2D Spring

/// Convenience wrapper that runs two independent `SpringSolver` instances
/// for 2D (x, y) motion.
public struct SpringSolver2D: Sendable {

    public let x: SpringSolver
    public let y: SpringSolver

    public init(
        configuration: SpringConfiguration,
        from: CGPoint,
        to: CGPoint,
        initialVelocity: CGVector = .zero
    ) {
        self.x = SpringSolver(configuration: configuration, from: from.x, to: to.x, initialVelocity: initialVelocity.dx)
        self.y = SpringSolver(configuration: configuration, from: from.y, to: to.y, initialVelocity: initialVelocity.dy)
    }

    public func position(at t: Double, to: CGPoint) -> CGPoint {
        CGPoint(
            x: to.x + x.displacement(at: t),
            y: to.y + y.displacement(at: t)
        )
    }

    public func velocity(at t: Double) -> CGVector {
        CGVector(dx: x.velocity(at: t), dy: y.velocity(at: t))
    }

    public var settlingDuration: Double {
        max(x.settlingDuration, y.settlingDuration)
    }
}
