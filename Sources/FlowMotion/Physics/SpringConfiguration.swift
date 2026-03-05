import SwiftUI

// MARK: - SpringConfiguration

/// Physical parameters for a damped harmonic oscillator.
///
/// Unlike SwiftUI's `Spring`, `SpringConfiguration` exposes the raw physical
/// parameters (stiffness, damping, mass) so the ``SpringSolver`` can compute
/// analytical solutions, velocity at any time t, and exact settlement durations.
public struct SpringConfiguration: Sendable, Hashable {

    /// Restoring force per unit displacement (N/m). Higher = stiffer / faster.
    public var stiffness: Double

    /// Energy-dissipation coefficient (N·s/m). Higher = more drag.
    public var damping: Double

    /// Effective mass of the simulated body (kg). Higher = slower, heavier feel.
    public var mass: Double

    /// Tolerance threshold below which the spring is considered at rest (pts).
    public var settlingThreshold: Double

    // MARK: Init

    public init(
        stiffness: Double,
        damping: Double,
        mass: Double = 1.0,
        settlingThreshold: Double = 0.01
    ) {
        precondition(stiffness > 0, "Stiffness must be positive")
        precondition(damping >= 0, "Damping must be non-negative")
        precondition(mass > 0, "Mass must be positive")
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
        self.settlingThreshold = settlingThreshold
    }
}

// MARK: - Derived parameters

public extension SpringConfiguration {

    /// Angular natural frequency ω = √(k/m)
    var omega: Double { (stiffness / mass).squareRoot() }

    /// Damping ratio ζ = c / (2√(km))
    var dampingRatio: Double { damping / (2 * (stiffness * mass).squareRoot()) }

    /// Damped angular frequency ωd = ω√(1−ζ²)  (underdamped only)
    var dampedOmega: Double {
        let ratio = dampingRatio
        guard ratio < 1 else { return 0 }
        return omega * (1 - ratio * ratio).squareRoot()
    }

    /// Converts response (≈ settling time) + bounce into raw spring parameters.
    static func from(response: Double, dampingFraction: Double, mass: Double = 1.0) -> SpringConfiguration {
        let stiffness = pow(2 * .pi / response, 2) * mass
        let damping   = 4 * .pi * dampingFraction * mass / response
        return SpringConfiguration(stiffness: stiffness, damping: damping, mass: mass)
    }

    /// Converts to a SwiftUI `Animation` for cases where native animation suffices.
    var swiftUIAnimation: Animation {
        .interpolatingSpring(stiffness: stiffness, damping: damping, initialVelocity: 0)
    }

    /// Converts to SwiftUI animation with an explicit initial velocity (pts/s).
    func swiftUIAnimation(initialVelocity: CGFloat) -> Animation {
        .interpolatingSpring(stiffness: stiffness, damping: damping, initialVelocity: Double(initialVelocity))
    }
}

// MARK: - Named presets

public extension SpringConfiguration {

    /// Snappy response — good for card taps, quick interactions.
    static let snappy = SpringConfiguration.from(response: 0.28, dampingFraction: 0.82)

    /// Smooth — relaxed feel for sheet presentations.
    static let smooth = SpringConfiguration.from(response: 0.40, dampingFraction: 0.90)

    /// Bouncy — playful overshoot, good for onboarding.
    static let bouncy = SpringConfiguration.from(response: 0.50, dampingFraction: 0.65)

    /// Hero — cinematic shared-element transition feel.
    static let hero = SpringConfiguration.from(response: 0.42, dampingFraction: 0.86)

    /// Hero with a subtle elastic bounce.
    static let heroElastic = SpringConfiguration.from(response: 0.48, dampingFraction: 0.72)

    /// Interactive dismiss — biased toward fast return.
    static let dismiss = SpringConfiguration.from(response: 0.30, dampingFraction: 0.88)

    /// Gentle — slow, cinematic reveal.
    static let gentle = SpringConfiguration.from(response: 0.70, dampingFraction: 0.95)

    /// Stiff — nearly instant snap, useful for haptic feedback animations.
    static let stiff = SpringConfiguration(stiffness: 800, damping: 60)
}
