import SwiftUI

// MARK: - View extensions

public extension View {

    // MARK: Gesture-driven expand

    /// Attaches a pinch-to-expand gesture that scales the view and optionally
    /// fires a callback when expanded beyond a threshold.
    func flowGesture(
        _ kind: FlowGestureKind,
        onExpand: (() -> Void)? = nil
    ) -> some View {
        modifier(FlowGestureModifier(kind: kind, onExpand: onExpand))
    }

    // MARK: Parallax

    /// Applies a depth-based parallax offset relative to gesture position.
    ///
    /// ```swift
    /// CardView()
    ///     .flowParallax(depth: 12)
    /// ```
    func flowParallax(depth: CGFloat = 10) -> some View {
        modifier(ParallaxModifier(depth: depth))
    }

    // MARK: Shimmer

    /// Applies an animated shimmer effect — useful for skeleton loading states.
    func flowShimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    // MARK: Pulse

    /// Applies a pulsing scale animation — useful for attracting attention.
    func flowPulse(
        scale: CGFloat = 1.05,
        duration: Double = 0.8,
        active: Bool = true
    ) -> some View {
        modifier(PulseModifier(scale: scale, duration: duration, active: active))
    }

    // MARK: Spring tap

    /// Adds a tactile spring-scale response to tap gestures.
    func flowSpringTap(
        scale: CGFloat = 0.94,
        spring: SpringConfiguration = .stiff
    ) -> some View {
        modifier(SpringTapModifier(targetScale: scale, spring: spring))
    }

    // MARK: Morph

    /// Animates the view's clip shape between source and destination
    /// rounded rectangles as `progress` changes.
    func flowMorphClip(
        cornerRadius: CGFloat,
        progress: CGFloat
    ) -> some View {
        clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius * (1 - progress),
                style: .continuous
            )
        )
    }
}

// MARK: - FlowGestureKind

public enum FlowGestureKind: Sendable {
    case expand
    case pinch
    case orbit
}

// MARK: - FlowGestureModifier

struct FlowGestureModifier: ViewModifier {
    let kind: FlowGestureKind
    let onExpand: (() -> Void)?

    @State private var scale: CGFloat = 1
    @State private var isExpanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = value.magnification
                    }
                    .onEnded { value in
                        if value.magnification > 1.5 && !isExpanded {
                            isExpanded = true
                            onExpand?()
                        }
                        withAnimation(.spring(.bouncy)) {
                            scale = 1
                        }
                    }
            )
    }
}

// MARK: - ParallaxModifier

struct ParallaxModifier: ViewModifier {
    let depth: CGFloat
    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    // Offset proportional to distance from center
                    offset = CGSize(
                        width:  (location.x - 100) / 100 * depth,
                        height: (location.y - 100) / 100 * depth
                    )
                case .ended:
                    withAnimation(.spring(.snappy)) { offset = .zero }
                }
            }
    }
}

// MARK: - ShimmerModifier

struct ShimmerModifier: ViewModifier {
    let active: Bool

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .local)
                        shimmerGradient(in: frame)
                            .opacity(0.4)
                    }
                }
            }
            .onAppear {
                guard active else { return }
                withAnimation(
                    .linear(duration: 1.4).repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }

    private func shimmerGradient(in rect: CGRect) -> some View {
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.45),
                .init(color: .white, location: 0.55),
                .init(color: .clear, location: 1),
            ]),
            startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
            endPoint:   UnitPoint(x: phase + 0.3, y: 0.5)
        )
    }
}

// MARK: - PulseModifier

struct PulseModifier: ViewModifier {
    let scale: CGFloat
    let duration: Double
    let active: Bool

    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? scale : 1)
            .onAppear {
                guard active else { return }
                withAnimation(
                    .easeInOut(duration: duration).repeatForever(autoreverses: true)
                ) {
                    pulsing = true
                }
            }
    }
}

// MARK: - SpringTapModifier

struct SpringTapModifier: ViewModifier {
    let targetScale: CGFloat
    let spring: SpringConfiguration

    @State private var scale: CGFloat = 1
    @GestureState private var pressing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressing ? targetScale : scale)
            // simultaneousGesture so parent Button / NavigationLink still fires
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressing) { _, state, _ in state = true }
                    .onEnded { _ in
                        withAnimation(spring.swiftUIAnimation) { scale = 1 }
                    }
            )
            .onChange(of: pressing) { _, isPressed in
                if isPressed {
                    withAnimation(spring.swiftUIAnimation) { scale = targetScale }
                }
            }
    }
}
