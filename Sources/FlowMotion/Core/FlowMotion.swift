/// FlowMotion — Production-grade motion infrastructure for SwiftUI.
///
/// FlowMotion provides a composable, high-performance animation and navigation
/// framework built for iOS 17+, macOS 14+, and visionOS 1+. It layers on top of
/// SwiftUI's animation primitives to deliver cinematic, gesture-driven, and
/// physics-accurate motion — similar in philosophy to Framer Motion.
///
/// ## Quick-start
///
/// ```swift
/// // 1. Wrap your root view
/// FlowNavigationStack {
///     HomeView()
/// }
/// .flowMotionSetup()
///
/// // 2. Link shared elements
/// FlowMotionLink(id: item.id, namespace: ns) {
///     CardView(item)
/// } destination: {
///     DetailView(item)
/// }
///
/// // 3. Apply transitions
/// MyView()
///     .flowTransition(.liquid)
///     .flowInteractiveDismiss()
/// ```

import SwiftUI

// MARK: - Module namespace

/// Top-level namespace for FlowMotion configuration and factory helpers.
public enum FlowMotion {

    // MARK: Presets

    /// The global configuration applied to the entire motion system.
    /// Assign a custom value before rendering your root view.
    @MainActor
    public static var configuration: MotionConfiguration = .default

    /// Resets the global registry state. Useful for unit tests and scene resets.
    @MainActor
    public static func reset() {
        SharedElementRegistry.shared.reset()
        AnimationEngine.shared.cancelAll()
    }
}

// MARK: - Root-level convenience modifiers

public extension View {

    /// Installs the FlowMotion overlay infrastructure on the root view.
    ///
    /// Call once on your root `NavigationStack` or `WindowGroup` content.
    /// This injects the shared-element overlay and configures environment values.
    @MainActor
    func flowMotionSetup(
        configuration: MotionConfiguration = FlowMotion.configuration
    ) -> some View {
        let reduceMotion = configuration.respectsReduceMotion && accessibilityReduceMotionEnabled
        return self
            .environment(\.flowMotionConfiguration, configuration)
            .environment(\.reduceMotion, reduceMotion)
            .overlay(alignment: .topLeading) {
                HeroTransitionOverlay()
            }
    }

    private var accessibilityReduceMotionEnabled: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }
}

// MARK: - ReduceMotion environment key

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var reduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}
