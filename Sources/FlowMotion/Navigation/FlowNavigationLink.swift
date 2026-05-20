import SwiftUI

// MARK: - FlowLink

/// Enhanced `NavigationLink` that applies a `FlowTransitionStyle` to the
/// destination and optionally performs a haptic feedback tap.
///
/// Unlike `FlowMotionLink`, `FlowLink` does NOT perform a shared-element
/// animation — it's suitable for standard push transitions where you want
/// the cinematic or liquid effect without a hero element.
///
/// ```swift
/// FlowLink(transition: .liquid()) {
///     Text("Tap me")
/// } destination: {
///     DetailView()
/// }
/// ```
public struct FlowLink<Label: View, Destination: View>: View {

    private let transition: FlowTransitionStyle
    private let feedbackStyle: FeedbackStyle
    private let label: () -> Label
    private let destination: () -> Destination

    @Namespace private var zoomNamespace

    public init(
        transition: FlowTransitionStyle = .cinematic(),
        feedback: FeedbackStyle = .selection,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.transition    = transition
        self.feedbackStyle = feedback
        self.label         = label
        self.destination   = destination
    }

    public var body: some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            NavigationLink {
                destination()
                    .navigationTransition(.zoom(sourceID: "flowlink", in: zoomNamespace))
            } label: {
                label()
                    .matchedTransitionSource(id: "flowlink", in: zoomNamespace)
            }
            .simultaneousGesture(TapGesture().onEnded { _ in feedbackStyle.trigger() })
        } else {
            legacyBody
        }
        #else
        legacyBody
        #endif
    }

    private var legacyBody: some View {
        NavigationLink {
            destination()
                .flowTransition(transition)
        } label: {
            label()
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in feedbackStyle.trigger() }
        )
    }
}

// MARK: - FeedbackStyle

/// Haptic feedback triggered on navigation link taps.
public enum FeedbackStyle: Sendable {
    case none
    case selection
    case impact

    @MainActor
    func trigger() {
        #if canImport(UIKit)
        switch self {
        case .none:
            break
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .impact:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        #endif
    }
}

// MARK: - NavigationDestination convenience

/// Registers a destination using `navigationDestination(for:)` with a `FlowTransitionStyle`.
public extension View {
    func flowDestination<D: Hashable, C: View>(
        for type: D.Type,
        transition: FlowTransitionStyle = .cinematic(),
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        navigationDestination(for: type) { value in
            destination(value)
                .flowTransition(transition)
        }
    }
}
