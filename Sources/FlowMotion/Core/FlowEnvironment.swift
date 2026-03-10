import SwiftUI

// MARK: - FlowEnvironment

/// Convenience namespace for FlowMotion environment values.
public enum FlowEnvironment {}

// MARK: - Namespace environment key

private struct FlowNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

public extension EnvironmentValues {
    /// The ambient namespace injected by `FlowNavigationStack`.
    var flowNamespace: Namespace.ID? {
        get { self[FlowNamespaceKey.self] }
        set { self[FlowNamespaceKey.self] = newValue }
    }
}

// MARK: - Transition context environment key

private struct TransitionContextKey: EnvironmentKey {
    static let defaultValue: TransitionContext = .idle
}

public extension EnvironmentValues {
    /// The current navigation transition state observed by child views.
    var flowTransitionContext: TransitionContext {
        get { self[TransitionContextKey.self] }
        set { self[TransitionContextKey.self] = newValue }
    }
}

// MARK: - Hero role environment key

/// Describes the role of a view inside a hero transition.
public enum HeroRole: @unchecked Sendable {
    case none
    case source(id: AnyHashable)
    case destination(id: AnyHashable)
}

private struct HeroRoleKey: EnvironmentKey {
    static let defaultValue: HeroRole = .none
}

public extension EnvironmentValues {
    var heroRole: HeroRole {
        get { self[HeroRoleKey.self] }
        set { self[HeroRoleKey.self] = newValue }
    }
}

// MARK: - Interactive dismiss progress

private struct InteractiveDismissProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

public extension EnvironmentValues {
    /// Normalised (0–1) progress of the current interactive dismiss gesture.
    /// Useful for parallax or opacity effects in the dismissing view.
    var interactiveDismissProgress: CGFloat {
        get { self[InteractiveDismissProgressKey.self] }
        set { self[InteractiveDismissProgressKey.self] = newValue }
    }
}
