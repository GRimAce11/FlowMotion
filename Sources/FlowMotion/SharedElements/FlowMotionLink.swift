import SwiftUI

// MARK: - FlowMotionLink

/// A navigation link that coordinates a shared-element hero animation
/// alongside a standard NavigationStack push transition.
///
/// `FlowMotionLink` wraps SwiftUI's `NavigationLink` (not a `Button` with
/// `navigationDestination`) so navigation works correctly inside any
/// container — `LazyVStack`, `List`, `ScrollView`, etc.
///
/// The hero animation is triggered via `.simultaneousGesture` so it fires
/// at the same time as the navigation without blocking it.
///
/// ## Usage
/// ```swift
/// @Namespace var ns
///
/// FlowMotionLink(id: item.id, namespace: ns) {
///     CardView(item)
///         .sharedElement(id: item.id, namespace: ns)
/// } destination: {
///     DetailView(item)
///         .sharedElementDestination(id: item.id, namespace: ns)
/// }
/// ```
public struct FlowMotionLink<Source: View, Destination: View>: View {

    // MARK: Properties

    private let id: AnyHashable
    private let namespace: Namespace.ID
    private let source: () -> Source
    private let destination: () -> Destination
    private let springConfig: SpringConfiguration

    @State private var sourceFrame: CGRect = .zero
    private let registry = SharedElementRegistry.shared

    // MARK: Init

    public init<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID,
        spring: SpringConfiguration = .hero,
        @ViewBuilder source: @escaping () -> Source,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.id          = AnyHashable(id)
        self.namespace   = namespace
        self.springConfig = spring
        self.source      = source
        self.destination = destination
    }

    // MARK: Body

    public var body: some View {
        NavigationLink {
            destination()
                .captureGeometry(id: id, role: .destination)
                .environment(\.heroRole, .destination(id: id))
        } label: {
            source()
                .captureGeometry(id: id, role: .source)
        }
        .buttonStyle(.plain)
        // Hero trigger fires at the same time as the NavigationLink push,
        // without consuming the tap that drives navigation.
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                triggerHeroAnimation()
            }
        )
        // Capture source frame continuously so it's fresh at tap time.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { sourceFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        sourceFrame = frame
                    }
            }
        )
    }

    // MARK: - Hero animation

    @MainActor
    private func triggerHeroAnimation() {
        let capturedSource = registry.frame(for: id) ?? sourceFrame

        Task { @MainActor in
            // One layout pass — give the destination view time to appear
            // and register its frame before we read it.
            try? await Task.sleep(nanoseconds: 33_333_334)  // ~2 frames @ 60Hz

            let destFrame = registry.frame(for: id) ?? capturedSource
            registry.beginHero(
                id: id,
                sourceFrame: capturedSource,
                destinationFrame: destFrame,
                configuration: springConfig,
                onCompletion: {}
            )
        }
    }
}

// MARK: - SharedElement modifiers

public extension View {
    /// Marks this view as a shared element source.
    func sharedElement<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID,
        anchor: UnitPoint = .center
    ) -> some View {
        self
            .captureGeometry(id: AnyHashable(id), role: .source)
            .matchedGeometryEffect(id: id, in: namespace, anchor: anchor, isSource: true)
    }

    /// Marks this view as the destination counterpart of a shared element.
    func sharedElementDestination<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID,
        anchor: UnitPoint = .center
    ) -> some View {
        self
            .captureGeometry(id: AnyHashable(id), role: .destination)
            .matchedGeometryEffect(id: id, in: namespace, anchor: anchor, isSource: false)
    }
}
