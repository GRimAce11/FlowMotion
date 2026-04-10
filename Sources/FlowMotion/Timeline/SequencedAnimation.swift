import SwiftUI

// MARK: - SequencedAnimation

/// A SwiftUI view that drives a `MotionTimeline` from view lifecycle events.
///
/// Use this when you want timeline-driven animations to fire on `onAppear`,
/// on a state change, or on a custom trigger — all declaratively within a view.
///
/// ```swift
/// SequencedAnimation(trigger: isPresented) {
///     Animate(.hero, delay: 0)   { headerScale = 1 }
///     Animate(.snappy, delay: 0.06) { bodyOpacity = 1 }
///     Animate(.gentle, delay: 0.12) { footerOffset = 0 }
/// }
/// ```
public struct SequencedAnimation: View {

    private let trigger: Bool
    private let steps: [TimelineStep]
    private let playOnAppear: Bool
    private let reverseOnDisappear: Bool
    private let timeScale: Double

    @State private var currentToken: AnimationToken?

    // MARK: Init

    public init(
        trigger: Bool = true,
        playOnAppear: Bool = true,
        reverseOnDisappear: Bool = false,
        timeScale: Double = 1,
        @TimelineBuilder steps: () -> [TimelineStep]
    ) {
        self.trigger            = trigger
        self.playOnAppear       = playOnAppear
        self.reverseOnDisappear = reverseOnDisappear
        self.timeScale          = timeScale
        self.steps              = steps()
    }

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                guard playOnAppear else { return }
                play()
            }
            .onChange(of: trigger) { _, newValue in
                if newValue { play() } else if reverseOnDisappear { playReversed() }
            }
            .onDisappear {
                guard let token = currentToken else { return }
                AnimationEngine.shared.cancel(token: token)
            }
    }

    // MARK: - Playback

    @MainActor
    private func play() {
        if let token = currentToken {
            AnimationEngine.shared.cancel(token: token)
        }
        let timeline = MotionTimeline(steps: steps)
        let token = timeline.playDetached(timeScale: timeScale)
        currentToken = token
    }

    @MainActor
    private func playReversed() {
        let reversed = MotionTimeline(steps: steps.reversed())
        let token = reversed.playDetached(timeScale: timeScale)
        currentToken = token
    }
}

// MARK: - StaggeredAnimation

/// Convenience view that staggers the same animation across N items.
///
/// ```swift
/// StaggeredAnimation(items: cards, stagger: 0.06, spring: .snappy) { i in
///     cards[i].opacity = 1
///     cards[i].offset = 0
/// }
/// ```
public struct StaggeredAnimation<Item>: View {
    private let items: [Item]
    private let stagger: Double
    private let spring: SpringConfiguration
    private let trigger: Bool
    private let body_: @MainActor (Int) -> Void

    public init(
        items: [Item],
        stagger: Double = 0.06,
        spring: SpringConfiguration = .snappy,
        trigger: Bool = true,
        body: @MainActor @escaping (Int) -> Void
    ) {
        self.items   = items
        self.stagger = stagger
        self.spring  = spring
        self.trigger = trigger
        self.body_   = body
    }

    public var body: some View {
        // Compute staggered steps: all run in parallel, each with its own delay.
        let staggeredSteps: [TimelineStep] = items.indices.map { i in
            .spring(spring, delay: Double(i) * stagger, body: { [body_] in body_(i) })
        }
        let timelineSteps: [TimelineStep] = staggeredSteps.isEmpty
            ? []
            : [.parallel(staggeredSteps)]

        SequencedAnimation(trigger: trigger, playOnAppear: true, timeScale: 1) {
            for step in timelineSteps { step }
        }
    }
}
