import SwiftUI

// MARK: - TimelineStep

/// A single step in a `MotionTimeline` sequence.
///
/// Steps are the atomic unit of motion orchestration. They compose into
/// timelines, scenes, and nested sequences. Every step is deterministic:
/// given the same input, execution always takes the same path.
///
/// ## Step types
/// - `.animate` — calls `withAnimation` and waits for the animation to settle.
/// - `.wait` — blocks for a fixed duration (useful for pacing).
/// - `.run` — fire-and-forget async side effect (haptics, logging, data loads).
/// - `.parallel` — starts sub-steps simultaneously and waits for the longest.
/// - `.sequence` — runs sub-steps sequentially (inline nesting).
/// - `.timeline` — embeds a full `MotionTimeline` as a single step.
public enum TimelineStep: @unchecked Sendable {

    /// Animate a block of state changes with the given animation.
    case animate(
        animation: Animation,
        duration: Double,
        delay: Double,
        body: @MainActor () -> Void
    )

    /// Block execution for `duration` seconds.
    case wait(duration: Double)

    /// Fire a side-effect closure — does not block the sequence.
    case run(@MainActor () async -> Void)

    /// Execute sub-steps simultaneously; wait for the longest to finish.
    case parallel([TimelineStep])

    /// Execute sub-steps sequentially (inline nested sequence).
    case sequence([TimelineStep])

    /// Embed a complete `MotionTimeline` as a single step.
    case timeline(MotionTimeline)
}

// MARK: - Duration

extension TimelineStep {
    /// Wall-clock duration this step occupies (including its delay).
    var totalDuration: Double {
        switch self {
        case .animate(_, let dur, let delay, _):
            return dur + delay
        case .wait(let dur):
            return dur
        case .run:
            return 0
        case .parallel(let steps):
            return steps.map(\.totalDuration).max() ?? 0
        case .sequence(let steps):
            return steps.map(\.totalDuration).reduce(0, +)
        case .timeline(let t):
            return t.steps.map(\.totalDuration).reduce(0, +)
        }
    }
}

// MARK: - Factory helpers

public extension TimelineStep {

    /// Spring-animated step using a named `SpringConfiguration`.
    static func spring(
        _ spring: SpringConfiguration = .snappy,
        delay: Double = 0,
        body: @MainActor @escaping () -> Void
    ) -> TimelineStep {
        let solver = SpringSolver(configuration: spring, from: 0, to: 1)
        return .animate(
            animation: spring.swiftUIAnimation,
            duration:  solver.settlingDuration,
            delay:     delay,
            body:      body
        )
    }

    /// Timing-curve animated step with explicit duration.
    static func curve(
        _ animation: Animation,
        duration: Double,
        delay: Double = 0,
        body: @MainActor @escaping () -> Void
    ) -> TimelineStep {
        .animate(animation: animation, duration: duration, delay: delay, body: body)
    }

    /// Creates a parallel group from a `@TimelineBuilder` closure.
    static func parallelGroup(@TimelineBuilder _ content: () -> [TimelineStep]) -> TimelineStep {
        .parallel(content())
    }

    /// Creates a sequential sub-timeline from a `@TimelineBuilder` closure.
    static func group(@TimelineBuilder _ content: () -> [TimelineStep]) -> TimelineStep {
        .sequence(content())
    }
}

// MARK: - DSL top-level functions

/// Spring-animated step in the `@TimelineBuilder` DSL.
public func Animate(
    _ spring: SpringConfiguration = .snappy,
    delay: Double = 0,
    body: @MainActor @escaping () -> Void
) -> TimelineStep {
    .spring(spring, delay: delay, body: body)
}

/// Wait step in the `@TimelineBuilder` DSL.
public func Wait(_ duration: Double) -> TimelineStep {
    .wait(duration: duration)
}

/// Side-effect run step in the `@TimelineBuilder` DSL.
public func Run(_ body: @MainActor @escaping () async -> Void) -> TimelineStep {
    .run(body)
}

/// Parallel group step in the `@TimelineBuilder` DSL.
///
/// All steps inside the block start simultaneously. The group completes
/// when the longest step finishes.
///
/// ```swift
/// MotionTimeline {
///     Animate(.hero) { cardScale = 1 }
///     Parallel {
///         Animate(.snappy) { titleOpacity = 1 }
///         Animate(.snappy, delay: 0.05) { bodyOpacity = 1 }
///     }
/// }
/// ```
public func Parallel(@TimelineBuilder _ content: () -> [TimelineStep]) -> TimelineStep {
    .parallel(content())
}

/// Sequential group step in the `@TimelineBuilder` DSL.
/// Embeds a sub-sequence without creating a full `MotionTimeline`.
public func Group(@TimelineBuilder _ content: () -> [TimelineStep]) -> TimelineStep {
    .sequence(content())
}

/// Animate a state change with an explicit timing curve and duration.
/// Use this when you need precise timing control rather than spring physics.
///
/// ```swift
/// MotionTimeline {
///     Animate(curve: .easeOut, duration: 0.3) { titleOpacity = 1 }
///     Animate(curve: .spring(.bouncy), duration: 0.5) { cardScale = 1 }
/// }
/// ```
public func Animate(
    curve animation: Animation,
    duration: Double,
    delay: Double = 0,
    body: @MainActor @escaping () -> Void
) -> TimelineStep {
    .animate(animation: animation, duration: duration, delay: delay, body: body)
}
