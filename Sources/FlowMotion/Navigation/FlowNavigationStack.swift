import SwiftUI

// MARK: - FlowNavigationStack

/// A drop-in replacement for `NavigationStack` that:
/// - Installs the shared-element overlay infrastructure.
/// - Injects `flowNamespace` into the environment.
/// - Provides `flowTransitionContext` to all descendants.
/// - Supports custom `FlowTransitionStyle` for push/pop animations.
///
/// ## Usage
/// ```swift
/// @main struct App: SwiftUI.App {
///     var body: some Scene {
///         WindowGroup {
///             FlowNavigationStack {
///                 HomeView()
///             }
///         }
///     }
/// }
/// ```
public struct FlowNavigationStack<Root: View>: View {

    // MARK: Properties

    private let root: () -> Root
    private let transitionStyle: FlowTransitionStyle

    @Namespace private var heroNamespace
    @State private var transitionContext: TransitionContext = .idle
    @State private var path = NavigationPath()

    // MARK: Init

    public init(
        transition: FlowTransitionStyle = .cinematic(),
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.transitionStyle = transition
        self.root = root
    }

    // MARK: Body

    public var body: some View {
        NavigationStack(path: $path) {
            root()
                .installGeometrySink()
        }
        .environment(\.flowNamespace, heroNamespace)
        .environment(\.flowTransitionContext, transitionContext)
        .flowMotionSetup()
    }
}

// MARK: - FlowNavigationStack (path-bound)

/// Variant that accepts an external `Binding<NavigationPath>` for programmatic navigation.
public struct FlowNavigationStackWithPath<Root: View>: View {

    private let root: () -> Root
    private let transitionStyle: FlowTransitionStyle

    @Binding private var path: NavigationPath
    @Namespace private var heroNamespace
    @State private var transitionContext: TransitionContext = .idle

    public init(
        path: Binding<NavigationPath>,
        transition: FlowTransitionStyle = .cinematic(),
        @ViewBuilder root: @escaping () -> Root
    ) {
        self._path = path
        self.transitionStyle = transition
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: $path) {
            root()
                .installGeometrySink()
        }
        .environment(\.flowNamespace, heroNamespace)
        .environment(\.flowTransitionContext, transitionContext)
        .flowMotionSetup()
    }
}

// MARK: - FlowSheet

/// Presents a sheet with `FlowMotion` transition and interactive dismiss.
///
/// ```swift
/// Button("Open") { isPresented = true }
///     .flowSheet(isPresented: $isPresented) {
///         DetailView()
///     }
/// ```
public extension View {
    func flowSheet<Content: View>(
        isPresented: Binding<Bool>,
        transition: FlowTransitionStyle = .reveal,
        dismissEdge: Edge = .bottom,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
                .flowTransition(transition)
                .flowInteractiveDismiss(edge: dismissEdge)
        }
    }
}
