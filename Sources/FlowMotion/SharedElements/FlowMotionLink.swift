import SwiftUI

// MARK: - FlowMotionLink

/// A navigation link that animates a shared element from source to destination.
///
/// `FlowMotionLink` is the primary API for hero/shared-element transitions.
/// On activation it:
/// 1. Captures the source element's global frame.
/// 2. Pushes the destination onto the navigation stack.
/// 3. Animates a hero layer from source → destination frame.
///
/// ## Usage
/// ```swift
/// @Namespace var heroNamespace
///
/// FlowMotionLink(id: item.id, namespace: heroNamespace) {
///     CardView(item)
///         .sharedElement(id: item.id, namespace: heroNamespace)
/// } destination: {
///     DetailView(item)
///         .sharedElementDestination(id: item.id, namespace: heroNamespace)
/// }
/// ```
///
/// - Note: Wrap the root view with `.flowMotionSetup()` to install the overlay
///   infrastructure required by this component.
public struct FlowMotionLink<Source: View, Destination: View>: View {

    // MARK: Properties

    private let id: AnyHashable
    private let namespace: Namespace.ID
    private let source: () -> Source
    private let destination: () -> Destination
    private let springConfig: SpringConfiguration

    @State private var isPresented = false
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
        self.id = AnyHashable(id)
        self.namespace = namespace
        self.springConfig = spring
        self.source = source
        self.destination = destination
    }

    // MARK: Body

    public var body: some View {
        Button {
            activateTransition()
        } label: {
            source()
                .captureGeometry(id: id, role: .source)
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear {
                    sourceFrame = proxy.frame(in: .global)
                }
                .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                    sourceFrame = newFrame
                }
            }
        )
        .navigationDestination(isPresented: $isPresented) {
            destination()
                .captureGeometry(id: id, role: .destination)
                .environment(\.heroRole, .destination(id: id))
        }
    }

    // MARK: - Transition activation

    @MainActor
    private func activateTransition() {
        let capturedSource = registry.frame(for: id) ?? sourceFrame

        isPresented = true

        // Give the destination a frame to animate toward (resolved on appear)
        Task { @MainActor in
            // Wait one layout pass for destination to register its frame
            try? await Task.sleep(nanoseconds: 16_666_667) // ~1 frame @ 60Hz

            let destinationFrame = registry.frame(for: id) ?? capturedSource

            registry.beginHero(
                id: id,
                sourceFrame: capturedSource,
                destinationFrame: destinationFrame,
                configuration: springConfig,
                onCompletion: {}
            )
        }
    }
}

// MARK: - SharedElement modifier

public extension View {
    /// Marks this view as a shared element participating in hero transitions.
    ///
    /// Apply to the source view inside `FlowMotionLink` and the corresponding
    /// element inside the destination view.
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
