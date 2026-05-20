import SwiftUI

// MARK: - FlowKeyframeValues

/// Value holder for keyframe-animated properties.
/// Conform your own type to carry multiple animated values.
public protocol FlowKeyframeValues {
    init()
}

// MARK: - Default values type

/// Built-in keyframe values for common single-axis animations.
public struct FlowKeyframe2D: FlowKeyframeValues {
    public var offset: CGSize = .zero
    public var scale: CGFloat = 1
    public var opacity: Double = 1
    public var rotation: Double = 0
    public init() {}
}

// MARK: - View modifier

public extension View {
    /// Animate this view through a SwiftUI keyframe sequence.
    /// Wraps `KeyframeAnimator` with MotionStyle awareness.
    ///
    /// ```swift
    /// Circle()
    ///     .flowKeyframes(trigger: appeared) { values in
    ///         Circle()
    ///             .scaleEffect(values.scale)
    ///             .opacity(values.opacity)
    ///     } keyframes: { _ in
    ///         KeyframeTrack(\.scale) {
    ///             SpringKeyframe(1.2, duration: 0.25, spring: .bouncy)
    ///             SpringKeyframe(1.0, duration: 0.3, spring: .snappy)
    ///         }
    ///         KeyframeTrack(\.opacity) {
    ///             LinearKeyframe(1.0, duration: 0.1)
    ///         }
    ///     }
    /// ```
    @available(iOS 17, macOS 14, *)
    func flowKeyframes<V: FlowKeyframeValues & Animatable>(
        trigger: some Equatable,
        @ViewBuilder content: @escaping (V) -> some View,
        @KeyframesBuilder<V> keyframes: @escaping (V) -> some Keyframes<V>
    ) -> some View {
        KeyframeAnimator(initialValue: V(), trigger: trigger, content: content, keyframes: keyframes)
    }
}

// MARK: - Stagger helper

public extension TimelineStep {
    /// Create a staggered sequence of spring-animated steps.
    static func stagger(
        count: Int,
        delay: Double = 0.06,
        spring: SpringConfiguration = .hero,
        body: @MainActor @escaping (Int) -> Void
    ) -> TimelineStep {
        let steps = (0..<count).map { i in
            TimelineStep.spring(spring, delay: Double(i) * delay) { body(i) }
        }
        return .parallel(steps)
    }
}

/// DSL function for staggered parallel animations in a timeline.
public func Stagger(
    count: Int,
    delay: Double = 0.06,
    spring: SpringConfiguration = .hero,
    body: @MainActor @escaping (Int) -> Void
) -> TimelineStep {
    .stagger(count: count, delay: delay, spring: spring, body: body)
}
