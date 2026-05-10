import SwiftUI

// MARK: - MotionScene

/// A named, reusable choreography sequence that coordinates multiple
/// `MotionTimeline` instances as a single directed execution graph.
///
/// `MotionScene` is the highest-level abstraction in the FlowMotion
/// orchestration hierarchy:
///
/// ```
/// MotionScene
///   └── MotionTimeline (per actor/layer)
///         └── TimelineStep (atomic step)
/// ```
///
/// Use it when multiple distinct view subtrees need precisely synchronised
/// animations — e.g., a card expanding while a backdrop dims and a toolbar
/// slides in simultaneously.
///
/// ```swift
/// let scene = MotionScene(style: .cinematic) {
///     MotionActor("card")  { Animate(.hero) { cardScale = 1 } }
///     MotionActor("backdrop") { Animate(.smooth) { bgOpacity = 0.6 } }
///     MotionActor("toolbar", offset: 0.1) {
///         Animate(.snappy) { toolbarOffset = 0 }
///     }
/// }
///
/// await scene.play()
/// ```
@MainActor
public final class MotionScene {

    // MARK: Properties

    public let style: MotionStyle
    private let actors: [MotionActor]

    // MARK: Init

    public init(
        style: MotionStyle = .cinematic,
        @MotionSceneBuilder _ builder: () -> [MotionActor]
    ) {
        self.style  = style
        self.actors = builder()
    }

    // MARK: - Playback

    /// Plays all actors, respecting their offsets, then waits for all to complete.
    @discardableResult
    public func play(timeScale: Double = 1) async -> [AnimationToken] {
        let effectiveScale = timeScale * style.timeScale
        var tokens: [AnimationToken] = []

        // Sort actors by offset so the earliest-starting fires first
        let sorted = actors.sorted { $0.offset < $1.offset }

        // Launch all actors concurrently, each after its offset delay
        for actor in sorted {
            if actor.offset > 0 {
                try? await Task.sleep(nanoseconds: UInt64(actor.offset * effectiveScale * 1_000_000_000))
            }
            let token = actor.timeline.playDetached(
                timeScale: effectiveScale,
                tag: actor.name
            )
            tokens.append(token)
        }

        // Wait for the last actor to complete
        let maxDuration = actors.map { $0.offset + $0.timeline.totalDuration }.max() ?? 0
        try? await Task.sleep(nanoseconds: UInt64(maxDuration * effectiveScale * 1_000_000_000))

        return tokens
    }

    /// Cancels all running actors.
    public func cancel() {
        for actor in actors {
            AnimationEngine.shared.cancel(tag: actor.name)
        }
    }
}

// MARK: - MotionActor

/// A named participant in a `MotionScene`, representing a single view layer
/// with its own `MotionTimeline` and start offset.
public struct MotionActor {
    /// Identifies the actor for cancellation and diagnostics.
    public let name: String
    /// Seconds after scene start before this actor begins.
    public let offset: Double
    /// The timeline this actor executes.
    public let timeline: MotionTimeline

    public init(
        _ name: String,
        offset: Double = 0,
        style: MotionStyle? = nil,
        @TimelineBuilder steps: () -> [TimelineStep]
    ) {
        self.name     = name
        self.offset   = offset
        self.timeline = MotionTimeline(style, steps)
    }

    public init(_ name: String, offset: Double = 0, timeline: MotionTimeline) {
        self.name     = name
        self.offset   = offset
        self.timeline = timeline
    }
}

// MARK: - MotionSceneBuilder

@resultBuilder
public struct MotionSceneBuilder {
    public static func buildBlock(_ components: [MotionActor]...) -> [MotionActor] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[MotionActor]]) -> [MotionActor] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [MotionActor]?) -> [MotionActor] {
        component ?? []
    }

    public static func buildEither(first component: [MotionActor]) -> [MotionActor] {
        component
    }

    public static func buildEither(second component: [MotionActor]) -> [MotionActor] {
        component
    }

    public static func buildExpression(_ expression: MotionActor) -> [MotionActor] {
        [expression]
    }
}

// MARK: - Preset scene factory

public extension MotionScene {

    /// A standard card-expand scene: card scales up, backdrop fades in, then content reveals.
    @MainActor
    static func cardExpand(
        style: MotionStyle = .cinematic,
        onCard:     @MainActor @escaping () -> Void,
        onBackdrop: @MainActor @escaping () -> Void,
        onContent:  @MainActor @escaping () -> Void
    ) -> MotionScene {
        MotionScene(style: style) {
            MotionActor("card", offset: 0) {
                Animate(style.primarySpring) { onCard() }
            }
            MotionActor("backdrop", offset: 0) {
                Animate(style.secondarySpring) { onBackdrop() }
            }
            MotionActor("content", offset: 0.12) {
                Animate(style.secondarySpring) { onContent() }
            }
        }
    }

    /// A standard dismiss scene: content fades, card scales down, backdrop clears.
    @MainActor
    static func cardDismiss(
        style: MotionStyle = .cinematic,
        onCard:     @MainActor @escaping () -> Void,
        onBackdrop: @MainActor @escaping () -> Void,
        onContent:  @MainActor @escaping () -> Void
    ) -> MotionScene {
        MotionScene(style: style) {
            MotionActor("content", offset: 0) {
                Animate(style.snapSpring) { onContent() }
            }
            MotionActor("card", offset: 0.06) {
                Animate(style.dismissSpring) { onCard() }
            }
            MotionActor("backdrop", offset: 0.06) {
                Animate(style.secondarySpring) { onBackdrop() }
            }
        }
    }
}
