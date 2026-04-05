import SwiftUI

// MARK: - DragProgressModifier

/// Links a drag gesture's displacement to an externally-bound progress value.
///
/// Use this to drive any custom animation — carousel scroll position, reveal
/// progress, parallax offset — directly from the gesture without intermediate
/// state. The modifier handles:
/// - Clamping progress to [0, 1]
/// - Velocity-aware spring settle
/// - Rubber-banding at the edges
/// - Gesture conflict mitigation with `simultaneousGesture`
public struct DragProgressModifier: ViewModifier {

    // MARK: Config

    /// Total drag distance that maps to progress = 1.0.
    public var distance: CGFloat

    /// Drag axis to track.
    public var axis: Axis

    /// When `true`, progress wraps (0 → 1 → 0) rather than clamping.
    public var wraps: Bool

    /// Spring used to settle after gesture ends.
    public var spring: SpringConfiguration

    /// Binding to the driver value consumed by the parent view.
    @Binding public var progress: CGFloat

    // MARK: State

    @State private var startProgress: CGFloat = 0
    @State private var isDragging = false
    private let tracker = VelocityTracker()

    // MARK: Body

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startProgress = progress
                        }
                        tracker.record(value.location)

                        let delta = axisTranslation(value.translation) / distance
                        let raw   = startProgress + delta
                        progress  = wraps
                            ? raw.truncatingRemainder(dividingBy: 1)
                            : rubberBandClamp(raw, min: 0, max: 1)
                    }
                    .onEnded { _ in
                        isDragging = false
                        let vel = velocityAlongAxis(tracker.velocity) / distance
                        tracker.reset()
                        settleProgress(initialVelocity: vel)
                    }
            )
    }

    // MARK: - Settle

    @MainActor
    private func settleProgress(initialVelocity: CGFloat) {
        let target: CGFloat = progress > 0.5 ? 1.0 : 0.0
        withAnimation(spring.swiftUIAnimation(initialVelocity: initialVelocity)) {
            progress = target
        }
    }

    // MARK: - Helpers

    private func axisTranslation(_ size: CGSize) -> CGFloat {
        axis == .horizontal ? size.width : size.height
    }

    private func velocityAlongAxis(_ vector: CGVector) -> CGFloat {
        axis == .horizontal ? vector.dx : vector.dy
    }

    /// Applies rubber-band resistance outside [min, max].
    private func rubberBandClamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        if value >= min && value <= max { return value }
        let overscroll: CGFloat
        let origin: CGFloat
        if value < min {
            overscroll = min - value
            origin = min
        } else {
            overscroll = value - max
            origin = max
        }
        // Rubber-band formula: displacement = overscroll * constant / containerSize
        let rubberBand = overscroll / (1 + overscroll / (distance * 0.5))
        return value < min ? origin - rubberBand : origin + rubberBand
    }
}

// MARK: - View extension

public extension View {
    /// Binds a drag gesture to a normalised progress value in [0, 1].
    ///
    /// - Parameters:
    ///   - progress: Binding driven by the gesture.
    ///   - distance: Drag distance (pts) mapping to progress = 1.0.
    ///   - axis: Which drag axis to track.
    func flowGestureProgress(
        _ progress: Binding<CGFloat>,
        distance: CGFloat,
        axis: Axis = .vertical,
        wraps: Bool = false,
        spring: SpringConfiguration = .snappy
    ) -> some View {
        modifier(
            DragProgressModifier(
                distance: distance,
                axis: axis,
                wraps: wraps,
                spring: spring,
                progress: progress
            )
        )
    }
}
