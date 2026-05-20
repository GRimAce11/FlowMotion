import SwiftUI

// MARK: - Animation factory extensions

public extension Animation {

    // MARK: Named spring presets

    /// Snappy spring — card taps, quick interactions.
    static var flowSnappy: Animation {
        SpringConfiguration.snappy.swiftUIAnimation
    }

    /// Smooth spring — sheet presentations, relaxed transitions.
    static var flowSmooth: Animation {
        SpringConfiguration.smooth.swiftUIAnimation
    }

    /// Bouncy spring — playful onboarding, attention-grabbing UI.
    static var flowBouncy: Animation {
        SpringConfiguration.bouncy.swiftUIAnimation
    }

    /// Hero spring — cinematic shared-element transitions.
    static var flowHero: Animation {
        SpringConfiguration.hero.swiftUIAnimation
    }

    /// Elastic hero — hero with subtle bounce.
    static var flowHeroElastic: Animation {
        SpringConfiguration.heroElastic.swiftUIAnimation
    }

    /// Dismiss spring — fast return for interactive dismiss snapping.
    static var flowDismiss: Animation {
        SpringConfiguration.dismiss.swiftUIAnimation
    }

    /// Gentle spring — slow cinematic reveals.
    static var flowGentle: Animation {
        SpringConfiguration.gentle.swiftUIAnimation
    }

    /// Matches iOS interactive back-swipe spring.
    static var flowInteractive: Animation { SpringConfiguration.interactiveSpring.swiftUIAnimation }
    /// Matches iOS sheet presentation.
    static var flowSheet: Animation { SpringConfiguration.sheetPresentation.swiftUIAnimation }
    /// Keyboard-linked fast animation.
    static var flowKeyboard: Animation { SpringConfiguration.keyboardAware.swiftUIAnimation }

    // MARK: Velocity-aware constructors

    /// Creates a spring animation seeded with an initial velocity (pts/s).
    static func flowSpring(
        _ config: SpringConfiguration = .snappy,
        initialVelocity: CGFloat = 0
    ) -> Animation {
        config.swiftUIAnimation(initialVelocity: initialVelocity)
    }

    // MARK: Time-scaled variants

    /// Returns the animation with its duration scaled by `factor`.
    func timeScaled(by factor: Double) -> Animation {
        speed(1 / factor)
    }
}

// MARK: - Custom timing curves

/// A collection of production-tested easing functions.
public enum FlowCurve {
    /// iOS spring-inspired ease — fast out, gentle settle.
    public static let appleEaseOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.5)

    /// Dramatic ease in — good for exits.
    public static let swiftEaseIn  = Animation.timingCurve(0.55, 0, 1, 0.45, duration: 0.35)

    /// Expo ease out — fast initial deceleration.
    public static let expoOut      = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.6)

    /// Back ease — slight overshoot then settle.
    public static let backOut      = Animation.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.5)

    /// Elastic out — pronounced bounce.
    public static let elasticOut   = Animation.timingCurve(0.36, 0.07, 0.19, 0.97, duration: 0.7)

    /// Cinematic slow-motion feel.
    public static let cinematic    = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.8)
}

// MARK: - withFlowAnimation

/// Runs a state mutation with FlowMotion's default animation and engine tracking.
///
/// ```swift
/// withFlowAnimation(.hero) {
///     cardScale = 1.2
///     backgroundOpacity = 0.8
/// }
/// ```
@MainActor
public func withFlowAnimation(
    _ config: SpringConfiguration = .snappy,
    body: @MainActor () -> Void
) {
    withAnimation(config.swiftUIAnimation) { body() }
}

/// Async-safe variant that also creates an `AnimationToken` for tracking.
@MainActor
@discardableResult
public func withFlowAnimation(
    _ config: SpringConfiguration = .snappy,
    tag: String? = nil,
    body: @MainActor () -> Void
) -> AnimationToken {
    let engine = AnimationEngine.shared
    let token  = engine.makeToken()
    let solver = SpringSolver(configuration: config, from: 0, to: 1)
    engine.register(AnimationRecord(tag: tag), token: token)

    withAnimation(config.swiftUIAnimation) { body() }

    Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(solver.settlingDuration * 1_000_000_000))
        engine.complete(token: token)
    }
    return token
}
