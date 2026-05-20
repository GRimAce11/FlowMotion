import SwiftUI

// MARK: - ScrollOffsetPreferenceKey

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - FlowScrollProxy

/// Published to the environment so child views can read scroll state.
@Observable
public final class FlowScrollProxy: @unchecked Sendable {
    public internal(set) var offset: CGPoint = .zero
    public internal(set) var contentSize: CGSize = .zero
    public internal(set) var viewportSize: CGSize = .zero

    /// Normalized vertical progress (0 = top, 1 = bottom). Clamped to 0–1.
    public var verticalProgress: CGFloat {
        let scrollable = contentSize.height - viewportSize.height
        guard scrollable > 0 else { return 0 }
        return max(0, min(1, (-offset.y) / scrollable))
    }
}

// MARK: - EnvironmentKey

struct FlowScrollProxyKey: EnvironmentKey {
    static let defaultValue: FlowScrollProxy? = nil
}

public extension EnvironmentValues {
    var flowScrollProxy: FlowScrollProxy? {
        get { self[FlowScrollProxyKey.self] }
        set { self[FlowScrollProxyKey.self] = newValue }
    }
}

// MARK: - FlowScrollView

/// A ScrollView that tracks scroll position and publishes it to child views
/// via the `\.flowScrollProxy` environment key.
///
/// Children can read the current offset to drive parallax, fade, or
/// spring-reactive effects.
///
/// ```swift
/// FlowScrollView {
///     ForEach(items) { item in
///         CardView(item)
///             .flowScrollEffect(.parallax(depth: 30))
///     }
/// }
/// ```
public struct FlowScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let content: () -> Content

    @State private var proxy = FlowScrollProxy()

    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }

    public var body: some View {
        GeometryReader { viewport in
            ScrollView(axes, showsIndicators: showsIndicators) {
                content()
                    .background(
                        GeometryReader { inner in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: inner.frame(in: .named("flowScroll")).origin
                                )
                                .onAppear {
                                    proxy.contentSize = inner.size
                                    proxy.viewportSize = viewport.size
                                }
                                .onChange(of: inner.size) { _, s in proxy.contentSize = s }
                        }
                    )
            }
            .coordinateSpace(name: "flowScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                proxy.offset = offset
            }
            .onAppear { proxy.viewportSize = viewport.size }
            .onChange(of: viewport.size) { _, s in proxy.viewportSize = s }
        }
        .environment(\.flowScrollProxy, proxy)
    }
}
