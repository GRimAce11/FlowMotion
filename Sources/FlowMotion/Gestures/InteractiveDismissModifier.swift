import SwiftUI

// MARK: - InteractiveDismissModifier

/// Adds a drag-to-dismiss gesture to a presented view.
///
/// Characteristics:
/// - Downward drag (or configurable edge) reduces opacity + scale.
/// - Release above threshold: spring snaps back.
/// - Release below threshold or with sufficient velocity: dismisses.
/// - Velocity-aware: fast flick dismisses even at low progress.
/// - Passes `interactiveDismissProgress` into the environment for
///   child views to drive parallax or counter-animation effects.
///
/// ```swift
/// DetailView()
///     .flowInteractiveDismiss()
/// ```
public struct InteractiveDismissModifier: ViewModifier {

    // MARK: Configuration

    public var edge: Edge
    public var springConfig: SpringConfiguration
    public var velocityThreshold: CGFloat
    public var progressThreshold: CGFloat

    // MARK: State

    @Environment(\.dismiss) private var dismiss
    @Environment(\.flowMotionConfiguration) private var config

    @State private var dragOffset: CGFloat = 0
    @State private var velocity: CGFloat   = 0
    @State private var isDragging = false

    private let tracker = VelocityTracker()

    // MARK: Body

    public func body(content: Content) -> some View {
        GeometryReader { proxy in
            let maxOffset = edgeMaxOffset(containerSize: proxy.size)

            content
                .offset(dragOffset(maxOffset: maxOffset))
                .scaleEffect(scale, anchor: .center)
                .opacity(opacity(maxOffset: maxOffset))
                .environment(\.interactiveDismissProgress, progress(maxOffset: maxOffset))
                .gesture(dragGesture(maxOffset: maxOffset))
                .animation(
                    isDragging ? .none : springConfig.swiftUIAnimation,
                    value: dragOffset
                )
        }
    }

    // MARK: - Gesture

    @MainActor
    private func dragGesture(maxOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true
                tracker.record(value.location)

                let raw = translationAlongEdge(value.translation)
                // Rubber-band: resist dragging in the wrong direction
                dragOffset = raw > 0 ? raw : raw / 4
            }
            .onEnded { value in
                isDragging = false
                let currentVelocity = tracker.velocity
                let axisVelocity = velocityAlongEdge(currentVelocity)
                tracker.reset()

                let prog = abs(dragOffset) / maxOffset

                if axisVelocity > CGFloat(config.commitVelocityThreshold)
                    || prog > config.commitProgressThreshold
                {
                    commitDismiss(maxOffset: maxOffset)
                } else {
                    snapBack()
                }
            }
    }

    // MARK: - Actions

    @MainActor
    private func commitDismiss(maxOffset: CGFloat) {
        withAnimation(springConfig.swiftUIAnimation) {
            dragOffset = maxOffset * 1.5    // fly off screen
        }
        Task {
            let duration = SpringSolver(
                configuration: springConfig,
                from: 0, to: 1
            ).settlingDuration
            try? await Task.sleep(nanoseconds: UInt64(duration * 0.5 * 1_000_000_000))
            await MainActor.run { dismiss() }
        }
    }

    @MainActor
    private func snapBack() {
        withAnimation(springConfig.swiftUIAnimation) {
            dragOffset = 0
        }
    }

    // MARK: - Derived values

    private func dragOffset(maxOffset: CGFloat) -> CGSize {
        switch edge {
        case .bottom:  return CGSize(width: 0, height: max(0, dragOffset))
        case .top:     return CGSize(width: 0, height: min(0, -dragOffset))
        case .trailing: return CGSize(width: max(0, dragOffset), height: 0)
        case .leading:  return CGSize(width: min(0, -dragOffset), height: 0)
        }
    }

    private func progress(maxOffset: CGFloat) -> CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(max(dragOffset / maxOffset, 0), 1)
    }

    private var scale: CGFloat {
        1 - dragOffset * 0.0002
    }

    private func opacity(maxOffset: CGFloat) -> Double {
        let prog = progress(maxOffset: maxOffset)
        return Double(1 - prog * 0.4)
    }

    private func edgeMaxOffset(containerSize: CGSize) -> CGFloat {
        switch edge {
        case .top, .bottom: return containerSize.height
        case .leading, .trailing: return containerSize.width
        }
    }

    private func translationAlongEdge(_ size: CGSize) -> CGFloat {
        switch edge {
        case .bottom:  return size.height
        case .top:     return -size.height
        case .trailing: return size.width
        case .leading:  return -size.width
        }
    }

    private func velocityAlongEdge(_ vector: CGVector) -> CGFloat {
        switch edge {
        case .bottom:  return vector.dy
        case .top:     return -vector.dy
        case .trailing: return vector.dx
        case .leading:  return -vector.dx
        }
    }
}

// MARK: - View extension

public extension View {
    /// Adds an interactive drag-to-dismiss gesture with spring physics.
    ///
    /// - Parameter edge: The edge the user drags toward to dismiss.
    func flowInteractiveDismiss(
        edge: Edge = .bottom,
        spring: SpringConfiguration = .dismiss,
        velocityThreshold: CGFloat = 300,
        progressThreshold: CGFloat = 0.45
    ) -> some View {
        modifier(
            InteractiveDismissModifier(
                edge: edge,
                springConfig: spring,
                velocityThreshold: velocityThreshold,
                progressThreshold: progressThreshold
            )
        )
    }
}
