import SwiftUI

// MARK: - TransitionContext

/// Describes the current state of a navigation or modal transition.
///
/// Views can read this from the environment to adapt their appearance —
/// e.g., hiding controls during hero animation or animating parallax offsets.
public enum TransitionContext: Sendable, Equatable {
    /// No transition in flight.
    case idle

    /// A push/present transition is currently animating.
    ///
    /// - `progress`: 0 = started, 1 = completed (destination fully visible).
    case presenting(progress: CGFloat)

    /// A pop/dismiss transition is currently animating.
    ///
    /// - `progress`: 0 = started, 1 = completed (source fully visible).
    case dismissing(progress: CGFloat)

    /// An interactive gesture is controlling the transition.
    ///
    /// - `progress`: 0 = source, 1 = destination.
    case interactive(progress: CGFloat)

    // MARK: Derived values

    /// Normalised progress in [0, 1] regardless of direction.
    public var progress: CGFloat {
        switch self {
        case .idle:                      return 0
        case .presenting(let p):         return p
        case .dismissing(let p):         return p
        case .interactive(let p):        return p
        }
    }

    public var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    public var isAnimating: Bool { !isIdle }

    public var isInteractive: Bool {
        if case .interactive = self { return true }
        return false
    }
}

// MARK: - NavigationTransitionPhase

/// Mirrors the underlying NavigationStack's transition phase.
/// Useful when building custom `NavigationTransition` conformances.
public enum NavigationTransitionPhase: Sendable {
    case identity
    case willAppear
    case didAppear
    case willDisappear
    case didDisappear
}
