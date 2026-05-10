import SwiftUI

// MARK: - MotionStyle

/// A named motion personality that coordinates springs, timing, and rendering
/// intensity across an entire view subtree.
///
/// `MotionStyle` is the single configuration object that makes FlowMotion
/// contexts feel cohesive. Instead of tuning individual springs and durations,
/// you declare a style once and the framework applies it everywhere:
///
/// ```swift
/// MyView()
///     .flowStyle(.cinematic)
/// ```
///
/// Styles are fully composable — override any property to create a custom
/// personality derived from an existing one:
///
/// ```swift
/// extension MotionStyle {
///     static let brand = MotionStyle.cinematic.modified(liquidIntensity: 0.4)
/// }
/// ```
public struct MotionStyle: Sendable, Hashable {

    // MARK: Springs

    /// Primary interaction spring (tap, expand, hero).
    public var primarySpring: SpringConfiguration

    /// Secondary spring for subsidiary elements (labels, icons, overlays).
    public var secondarySpring: SpringConfiguration

    /// Spring used for snapping back from incomplete gestures.
    public var snapSpring: SpringConfiguration

    /// Spring used for dismissal gestures.
    public var dismissSpring: SpringConfiguration

    // MARK: Timing

    /// Global time-scale multiplier (1.0 = normal speed).
    public var timeScale: Double

    /// Stagger interval between successive staggered elements.
    public var staggerInterval: Double

    // MARK: Rendering

    /// Liquid transition wave intensity (0 = none, 1 = maximum).
    public var liquidIntensity: CGFloat

    /// Blur radius applied during cinematic transitions.
    public var cinematicBlur: CGFloat

    // MARK: Gesture

    /// Commit velocity threshold for interactive transitions.
    public var commitVelocity: CGFloat

    /// Commit progress threshold for interactive transitions.
    public var commitProgress: CGFloat

    // MARK: Init

    public init(
        primarySpring:    SpringConfiguration = .hero,
        secondarySpring:  SpringConfiguration = .smooth,
        snapSpring:       SpringConfiguration = .snappy,
        dismissSpring:    SpringConfiguration = .dismiss,
        timeScale:        Double  = 1.0,
        staggerInterval:  Double  = 0.06,
        liquidIntensity:  CGFloat = 1.0,
        cinematicBlur:    CGFloat = 4.0,
        commitVelocity:   CGFloat = 300,
        commitProgress:   CGFloat = 0.45
    ) {
        self.primarySpring   = primarySpring
        self.secondarySpring = secondarySpring
        self.snapSpring      = snapSpring
        self.dismissSpring   = dismissSpring
        self.timeScale       = timeScale
        self.staggerInterval = staggerInterval
        self.liquidIntensity = liquidIntensity
        self.cinematicBlur   = cinematicBlur
        self.commitVelocity  = commitVelocity
        self.commitProgress  = commitProgress
    }

    // MARK: - Non-mutating modification

    /// Returns a copy with any properties overridden.
    public func modified(
        primarySpring:   SpringConfiguration? = nil,
        secondarySpring: SpringConfiguration? = nil,
        timeScale:       Double?   = nil,
        liquidIntensity: CGFloat?  = nil,
        cinematicBlur:   CGFloat?  = nil
    ) -> MotionStyle {
        var copy = self
        if let v = primarySpring   { copy.primarySpring   = v }
        if let v = secondarySpring { copy.secondarySpring = v }
        if let v = timeScale       { copy.timeScale       = v }
        if let v = liquidIntensity { copy.liquidIntensity = v }
        if let v = cinematicBlur   { copy.cinematicBlur   = v }
        return copy
    }
}

// MARK: - Named presets

public extension MotionStyle {

    /// Cinematic — deliberate, weighty motion with liquid intensity.
    /// Inspired by the iOS App Store card expansion.
    static let cinematic = MotionStyle(
        primarySpring:   .hero,
        secondarySpring: .smooth,
        snapSpring:      .dismiss,
        timeScale:       1.0,
        staggerInterval: 0.07,
        liquidIntensity: 1.0,
        cinematicBlur:   6.0
    )

    /// Snappy — fast, responsive motion with minimal decoration.
    /// Good for data-dense UIs where animations must be brief.
    static let snappy = MotionStyle(
        primarySpring:   .snappy,
        secondarySpring: .snappy,
        snapSpring:      .stiff,
        timeScale:       0.85,
        staggerInterval: 0.04,
        liquidIntensity: 0.5,
        cinematicBlur:   2.0
    )

    /// Playful — bouncy, expressive motion with full liquid transitions.
    /// Good for consumer/onboarding contexts.
    static let playful = MotionStyle(
        primarySpring:   .bouncy,
        secondarySpring: .bouncy,
        snapSpring:      .snappy,
        timeScale:       1.1,
        staggerInterval: 0.05,
        liquidIntensity: 1.0,
        cinematicBlur:   4.0
    )

    /// Minimal — subtle, almost imperceptible motion.
    /// Good for professional/productivity apps.
    static let minimal = MotionStyle(
        primarySpring:   .smooth,
        secondarySpring: .gentle,
        snapSpring:      .smooth,
        timeScale:       0.7,
        staggerInterval: 0.03,
        liquidIntensity: 0.2,
        cinematicBlur:   1.0
    )

    /// Accessible — respects reduce-motion preference.
    /// All springs are gentle; liquid intensity is zero.
    static let accessible = MotionStyle(
        primarySpring:   .gentle,
        secondarySpring: .gentle,
        snapSpring:      .smooth,
        timeScale:       0.6,
        staggerInterval: 0.0,
        liquidIntensity: 0.0,
        cinematicBlur:   0.0
    )
}

// MARK: - EnvironmentKey

private struct MotionStyleKey: EnvironmentKey {
    static let defaultValue = MotionStyle.cinematic
}

public extension EnvironmentValues {
    /// The ambient `MotionStyle` injected into the view hierarchy.
    var flowStyle: MotionStyle {
        get { self[MotionStyleKey.self] }
        set { self[MotionStyleKey.self] = newValue }
    }
}

// MARK: - View modifier

public extension View {
    /// Applies a `MotionStyle` to all FlowMotion effects in the subtree.
    ///
    /// ```swift
    /// FlowNavigationStack {
    ///     HomeView()
    /// }
    /// .flowStyle(.cinematic)
    /// ```
    func flowStyle(_ style: MotionStyle) -> some View {
        self.environment(\.flowStyle, style)
    }
}
