import SwiftUI

// MARK: - FlowTransitionStyle

/// The built-in transition styles provided by FlowMotion.
///
/// Pass one of these to `.flowTransition(_:)` to apply a named effect,
/// or use `.custom(_:)` to supply any `AnyTransition`.
public enum FlowTransitionStyle {
    /// Liquid morphing — surfaces appear to melt between routes.
    case liquid(intensity: CGFloat = 1.0)
    /// Cinematic zoom with depth blur — the iOS App Store card style.
    case cinematic(scale: CGFloat = 0.92)
    /// Enhanced directional slide with spring overshoot.
    case slide(edge: Edge = .trailing)
    /// Fade with momentum blur.
    case fade
    /// Vertical reveal (bottom sheet expand feel).
    case reveal
    /// No transition — use when reduce-motion is active.
    case identity
    /// Supply any SwiftUI `AnyTransition`.
    case custom(AnyTransition)
}

extension FlowTransitionStyle: @unchecked Sendable {}

// MARK: - View modifier

public extension View {
    /// Applies a FlowMotion transition to this view.
    ///
    /// The transition fires when the view is inserted or removed from the
    /// hierarchy (e.g., inside a `NavigationStack` or conditional `if`).
    ///
    /// ```swift
    /// DetailView()
    ///     .flowTransition(.cinematic())
    /// ```
    func flowTransition(
        _ style: FlowTransitionStyle,
        configuration: MotionConfiguration = FlowMotion.configuration
    ) -> some View {
        self.transition(style.asAnyTransition(configuration: configuration))
    }
}

// MARK: - FlowTransitionStyle → AnyTransition

extension FlowTransitionStyle {
    func asAnyTransition(configuration: MotionConfiguration) -> AnyTransition {
        // Honour reduce-motion by substituting a simple fade
        #if canImport(UIKit)
        if configuration.respectsReduceMotion && UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        #endif

        switch self {
        case .liquid(let intensity):
            return .modifier(
                active:   LiquidTransitionModifier(progress: 0, intensity: intensity),
                identity: LiquidTransitionModifier(progress: 1, intensity: intensity)
            )

        case .cinematic(let scale):
            return .modifier(
                active:   CinematicTransitionModifier(progress: 0, baseScale: scale),
                identity: CinematicTransitionModifier(progress: 1, baseScale: scale)
            )

        case .slide(let edge):
            return .asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity),
                removal:   .move(edge: edge.opposite).combined(with: .opacity)
            )

        case .fade:
            return .opacity

        case .reveal:
            return .modifier(
                active:   RevealTransitionModifier(progress: 0),
                identity: RevealTransitionModifier(progress: 1)
            )

        case .identity:
            return .identity

        case .custom(let t):
            return t
        }
    }
}

// MARK: - Edge helpers

private extension Edge {
    var opposite: Edge {
        switch self {
        case .top:     return .bottom
        case .bottom:  return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

// MARK: - RevealTransitionModifier

/// Vertical unmask reveal — the bottom sheet / card expand feel.
struct RevealTransitionModifier: ViewModifier, Animatable {
    var progress: CGFloat   // 0 = hidden, 1 = visible

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 1,
                y: 0.85 + 0.15 * progress,
                anchor: .bottom
            )
            .offset(y: (1 - progress) * 40)
            .opacity(Double(progress))
            .clipped()
    }
}
