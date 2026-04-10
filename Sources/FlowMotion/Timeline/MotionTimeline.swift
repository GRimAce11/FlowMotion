import SwiftUI

// MARK: - MotionTimeline

/// Declarative, composable animation sequencer built on a `@resultBuilder` DSL.
///
/// `MotionTimeline` is FlowMotion's orchestration engine. It sequences steps
/// — animations, waits, side effects, and parallel groups — with deterministic
/// timing and cancellation-safe execution.
///
/// ## Basic usage
///
/// ```swift
/// await MotionTimeline {
///     Animate(.hero) { cardScale = 1 }
///     Wait(0.06)
///     Parallel {
///         Animate(.snappy) { titleOpacity = 1 }
///         Animate(.snappy, delay: 0.05) { bodyOpacity = 1 }
///     }
///     Run { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
/// }
/// .play(tag: "entrance")
/// ```
///
/// ## Style-aware init
///
/// Pass a `MotionStyle` to scale timing and spring configurations globally:
///
/// ```swift
/// MotionTimeline(.cinematic) {
///     Animate { cardVisible = true }
/// }
/// ```
///
/// ## Chaining
///
/// ```swift
/// let entrance = MotionTimeline { Animate(.hero) { opacity = 1 } }
/// let exit     = MotionTimeline { Animate(.dismiss) { opacity = 0 } }
/// entrance.then { Wait(0.5) }.then(exit)
/// ```
public struct MotionTimeline: @unchecked Sendable {

    // MARK: Steps

    public let steps: [TimelineStep]

    /// Time scale inherited from a `MotionStyle`, applied at play time.
    public let styleTimeScale: Double

    // MARK: Init — result builder

    public init(
        _ style: MotionStyle? = nil,
        @TimelineBuilder _ builder: () -> [TimelineStep]
    ) {
        self.steps          = builder()
        self.styleTimeScale = style?.timeScale ?? 1.0
    }

    // MARK: Init — manual

    public init(steps: [TimelineStep], styleTimeScale: Double = 1.0) {
        self.steps          = steps
        self.styleTimeScale = styleTimeScale
    }

    // MARK: - Playback

    /// Plays all steps sequentially on the main actor, awaiting completion.
    /// Returns an `AnimationToken` for cancellation.
    @MainActor
    @discardableResult
    public func play(
        timeScale: Double = 1,
        tag: String? = nil
    ) async -> AnimationToken {
        let engine = AnimationEngine.shared
        let token  = engine.makeToken()
        engine.register(AnimationRecord(tag: tag), token: token)

        let effectiveScale = timeScale * styleTimeScale
        await executeSteps(steps, timeScale: effectiveScale, token: token, engine: engine)

        engine.complete(token: token)
        return token
    }

    /// Fire-and-forget playback. Returns the token immediately.
    @MainActor
    @discardableResult
    public func playDetached(
        timeScale: Double = 1,
        tag: String? = nil
    ) -> AnimationToken {
        let engine = AnimationEngine.shared
        let token  = engine.makeToken()
        engine.register(AnimationRecord(tag: tag), token: token)

        let effectiveScale = timeScale * styleTimeScale
        Task { @MainActor in
            await executeSteps(steps, timeScale: effectiveScale, token: token, engine: engine)
            engine.complete(token: token)
        }
        return token
    }

    /// Plays in reverse — useful for symmetric exit animations.
    @MainActor
    @discardableResult
    public func playReversed(timeScale: Double = 1, tag: String? = nil) async -> AnimationToken {
        await MotionTimeline(steps: steps.reversed(), styleTimeScale: styleTimeScale)
            .play(timeScale: timeScale, tag: tag.map { "\($0)-reversed" })
    }

    // MARK: - Execution engine

    @MainActor
    private func executeSteps(
        _ steps: [TimelineStep],
        timeScale: Double,
        token: AnimationToken,
        engine: AnimationEngine
    ) async {
        for step in steps {
            guard engine.activeAnimations[token] != nil else { break }
            await executeStep(step, timeScale: timeScale, token: token, engine: engine)
        }
    }

    @MainActor
    private func executeStep(
        _ step: TimelineStep,
        timeScale: Double,
        token: AnimationToken,
        engine: AnimationEngine
    ) async {
        switch step {

        case .animate(let animation, let duration, let delay, let body):
            if delay > 0 {
                try? await Task.sleep(nanoseconds: ns(delay * timeScale))
            }
            withAnimation(animation) { body() }
            try? await Task.sleep(nanoseconds: ns(duration * timeScale))

        case .wait(let duration):
            try? await Task.sleep(nanoseconds: ns(duration * timeScale))

        case .run(let sideEffect):
            await sideEffect()

        case .parallel(let substeps):
            var maxDuration = 0.0
            for substep in substeps {
                maxDuration = max(maxDuration, substep.totalDuration * timeScale)
                applyImmediate(substep, timeScale: timeScale)
            }
            if maxDuration > 0 {
                try? await Task.sleep(nanoseconds: ns(maxDuration))
            }

        case .sequence(let substeps):
            await executeSteps(substeps, timeScale: timeScale, token: token, engine: engine)

        case .timeline(let nested):
            await executeSteps(nested.steps, timeScale: timeScale * nested.styleTimeScale, token: token, engine: engine)
        }
    }

    /// Applies animate/run steps immediately (no waiting) — used inside parallel groups.
    @MainActor
    private func applyImmediate(_ step: TimelineStep, timeScale: Double) {
        switch step {
        case .animate(let animation, _, let delay, let body):
            if delay > 0 {
                withAnimation(animation.delay(delay * timeScale)) { body() }
            } else {
                withAnimation(animation) { body() }
            }
        case .run(let body):
            Task { @MainActor in await body() }
        case .sequence(let substeps):
            // Sequence inside parallel: launch as detached sub-sequence
            let timeline = MotionTimeline(steps: substeps)
            _ = timeline.playDetached(timeScale: timeScale)
        default:
            break
        }
    }

    private func ns(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }
}

// MARK: - Chaining

public extension MotionTimeline {
    /// Appends additional steps, returning a new timeline.
    func then(@TimelineBuilder _ more: () -> [TimelineStep]) -> MotionTimeline {
        MotionTimeline(steps: steps + more(), styleTimeScale: styleTimeScale)
    }

    /// Appends another timeline sequentially.
    func then(_ other: MotionTimeline) -> MotionTimeline {
        MotionTimeline(steps: steps + [.timeline(other)], styleTimeScale: styleTimeScale)
    }

    /// Combines two timelines as a parallel group.
    func concurrently(with other: MotionTimeline) -> MotionTimeline {
        MotionTimeline(steps: [.parallel(steps + other.steps)], styleTimeScale: styleTimeScale)
    }

    /// Returns the timeline with its time scale multiplied by `factor`.
    func timeScaled(by factor: Double) -> MotionTimeline {
        MotionTimeline(steps: steps, styleTimeScale: styleTimeScale * factor)
    }

    /// Total theoretical duration (sum of sequential steps).
    var totalDuration: Double {
        steps.map(\.totalDuration).reduce(0, +) * styleTimeScale
    }
}

// MARK: - TimelineBuilder

/// Result builder that composes `TimelineStep` arrays from a DSL closure.
@resultBuilder
public struct TimelineBuilder {

    public static func buildBlock(_ components: [TimelineStep]...) -> [TimelineStep] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[TimelineStep]]) -> [TimelineStep] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [TimelineStep]?) -> [TimelineStep] {
        component ?? []
    }

    public static func buildEither(first component: [TimelineStep]) -> [TimelineStep] {
        component
    }

    public static func buildEither(second component: [TimelineStep]) -> [TimelineStep] {
        component
    }

    public static func buildExpression(_ expression: TimelineStep) -> [TimelineStep] {
        [expression]
    }

    public static func buildExpression(_ expression: [TimelineStep]) -> [TimelineStep] {
        expression
    }

    public static func buildLimitedAvailability(_ component: [TimelineStep]) -> [TimelineStep] {
        component
    }
}
