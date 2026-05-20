import SwiftUI

// MARK: - FlowMotionLink

/// A navigation link with a built-in shared-element transition.
///
/// On iOS 18+ the native `zoom` navigation transition is used — the card
/// expands directly into the destination view with a system-quality animation.
/// On iOS 17 the standard NavigationStack slide is used as fallback.
///
/// ```swift
/// @Namespace var ns
///
/// FlowMotionLink(id: item.id, namespace: ns) {
///     CardView(item)
/// } destination: {
///     DetailView(item)
/// }
/// ```
public struct FlowMotionLink<Source: View, Destination: View>: View {

    private let id: AnyHashable
    private let namespace: Namespace.ID
    private let source: () -> Source
    private let destination: () -> Destination
    private let springConfig: SpringConfiguration

    @Namespace private var zoomNamespace
    @State private var sourceFrame: CGRect = .zero
    private let registry = SharedElementRegistry.shared

    public init<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID,
        spring: SpringConfiguration = .hero,
        @ViewBuilder source: @escaping () -> Source,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.id           = AnyHashable(id)
        self.namespace    = namespace
        self.springConfig = spring
        self.source       = source
        self.destination  = destination
    }

    // MARK: - Body

    public var body: some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            modernLink
        } else {
            legacyLink
        }
        #else
        legacyLink
        #endif
    }

    // MARK: - iOS 18 zoom

    #if os(iOS)
    @available(iOS 18, *)
    @ViewBuilder
    private var modernLink: some View {
        NavigationLink {
            destination()
                .navigationTransition(.zoom(sourceID: id, in: zoomNamespace))
        } label: {
            source()
                .matchedTransitionSource(id: id, in: zoomNamespace)
        }
    }
    #endif

    // MARK: - iOS 17 fallback

    @ViewBuilder
    private var legacyLink: some View {
        NavigationLink {
            destination()
        } label: {
            source()
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded { _ in triggerHeroAnimation() }
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { sourceFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, f in sourceFrame = f }
            }
        )
    }

    // MARK: - Hero animation (iOS 17 fallback)

    @MainActor
    private func triggerHeroAnimation() {
        let capturedSource = registry.frame(for: id) ?? sourceFrame
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 33_333_334)
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
    func sharedElement<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID,
        anchor: UnitPoint = .center
    ) -> some View {
        self
            .captureGeometry(id: AnyHashable(id), role: .source)
            .matchedGeometryEffect(id: id, in: namespace, anchor: anchor, isSource: true)
    }

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
