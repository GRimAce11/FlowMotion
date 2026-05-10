import SwiftUI

// MARK: - MotionPresets

/// A catalogue of reusable `MotionTimeline` factory functions.
///
/// Each preset encapsulates a proven animation pattern. Presets are stateless
/// factories — they produce a `MotionTimeline` you drive with your own state:
///
/// ```swift
/// // In your view:
/// @State var titleOpacity: Double = 0
/// @State var bodyOpacity:  Double = 0
/// @State var ctaOpacity:   Double = 0
///
/// // On appear:
/// await MotionPresets.screenEntrance(
///     style: .cinematic,
///     stages: [
///         { self.titleOpacity = 1 },
///         { self.bodyOpacity  = 1 },
///         { self.ctaOpacity   = 1 },
///     ]
/// ).play()
/// ```
public enum MotionPresets {

    // MARK: - Screen entrance

    /// Staggers a list of state mutations in from 0, with configurable style.
    public static func screenEntrance(
        style: MotionStyle = .cinematic,
        stages: [@MainActor () -> Void],
        stagger: Double? = nil
    ) -> MotionTimeline {
        let interval = stagger ?? style.staggerInterval
        let steps: [TimelineStep] = stages.enumerated().map { i, stage in
            .spring(style.primarySpring, delay: Double(i) * interval, body: stage)
        }
        return MotionTimeline(steps: [.parallel(steps)], styleTimeScale: style.timeScale)
    }

    // MARK: - Card expand

    /// Coordinates a card expansion: hero scale, backdrop, then content reveal.
    public static func cardExpand(
        style: MotionStyle = .cinematic,
        onHero: @MainActor @escaping () -> Void,
        onBackdrop: @MainActor @escaping () -> Void,
        onContent:  @MainActor @escaping () -> Void
    ) -> MotionTimeline {
        MotionTimeline(style) {
            Parallel {
                Animate(style.primarySpring, body: onHero)
                Animate(style.secondarySpring, body: onBackdrop)
            }
            Wait(0.1 * style.timeScale)
            Animate(style.secondarySpring, body: onContent)
        }
    }

    // MARK: - Card dismiss

    /// Reverses a card expansion: content fades, then hero + backdrop clear.
    public static func cardDismiss(
        style: MotionStyle = .cinematic,
        onContent:  @MainActor @escaping () -> Void,
        onHero:     @MainActor @escaping () -> Void,
        onBackdrop: @MainActor @escaping () -> Void
    ) -> MotionTimeline {
        MotionTimeline(style) {
            Animate(style.snapSpring, body: onContent)
            Wait(0.06 * style.timeScale)
            Parallel {
                Animate(style.dismissSpring, body: onHero)
                Animate(style.secondarySpring, body: onBackdrop)
            }
        }
    }

    // MARK: - Staggered list

    /// Staggers `count` items into view, calling `itemBody(i)` for each.
    public static func staggeredList(
        count: Int,
        style: MotionStyle = .cinematic,
        itemBody: @MainActor @escaping (Int) -> Void
    ) -> MotionTimeline {
        let steps: [TimelineStep] = (0..<count).map { i in
            .spring(style.primarySpring, delay: Double(i) * style.staggerInterval, body: { itemBody(i) })
        }
        return MotionTimeline(steps: [.parallel(steps)], styleTimeScale: style.timeScale)
    }

    // MARK: - Modal presentation

    /// Coordinates a full-screen modal: backdrop in, sheet up, content revealed.
    public static func modalPresent(
        style: MotionStyle = .cinematic,
        onBackdrop: @MainActor @escaping () -> Void,
        onSheet:    @MainActor @escaping () -> Void,
        onContent:  @MainActor @escaping () -> Void
    ) -> MotionTimeline {
        MotionTimeline(style) {
            Animate(style.secondarySpring, body: onBackdrop)
            Wait(0.04 * style.timeScale)
            Animate(style.primarySpring, body: onSheet)
            Wait(0.08 * style.timeScale)
            Animate(style.secondarySpring, body: onContent)
        }
    }

    // MARK: - Attention pulse

    /// Draws attention to a view with a brief scale pulse, then settles.
    public static func attentionPulse(
        style: MotionStyle = .playful,
        onPulseOut: @MainActor @escaping () -> Void,
        onPulseIn:  @MainActor @escaping () -> Void
    ) -> MotionTimeline {
        MotionTimeline(style) {
            Animate(.bouncy, body: onPulseOut)
            Animate(.snappy, body: onPulseIn)
        }
    }

    // MARK: - Success celebration

    /// A brief, satisfying entry burst — good for completion states.
    public static func successCelebration(
        style: MotionStyle = .playful,
        stages: [@MainActor () -> Void]
    ) -> MotionTimeline {
        let interval = style.staggerInterval * 0.8
        let steps: [TimelineStep] = stages.enumerated().map { i, s in
            .spring(.bouncy, delay: Double(i) * interval, body: s)
        }
        return MotionTimeline {
            TimelineStep.parallel(steps)
        }
    }
}
