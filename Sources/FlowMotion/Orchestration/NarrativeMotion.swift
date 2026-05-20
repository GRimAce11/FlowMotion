import SwiftUI

// MARK: - NarrativeMotion

/// A library of Apple-style cinematic motion narratives built on `MotionDirector`.
///
/// Narratives are high-level choreography patterns — each describes *how* a
/// UI story should unfold, not just which elements animate. They are distinct
/// from `MotionPresets` (which target single-scene patterns) in that they
/// coordinate multiple scenes across a full user journey.
///
/// ```swift
/// // Onboarding reveal:
/// await NarrativeMotion.onboardingReveal(
///     heroStages:    [{ heroVisible = true }],
///     contentStages: [{ titleOpacity = 1 }, { bodyOpacity = 1 }],
///     ctaStages:     [{ ctaOpacity = 1 }]
/// )
///
/// // Card detail expand:
/// await NarrativeMotion.cardDetailExpand(
///     headerStages: [{ headerScale = 1 }],
///     bodyStages:   [{ bodyOpacity = 1 }, { footerOpacity = 1 }]
/// )
/// ```
public enum NarrativeMotion {

    // MARK: - Stage closure type

    /// A single animation-state mutation running on the main actor.
    public typealias Stage = @MainActor () -> Void

    // MARK: - Onboarding reveal

    /// Three-beat onboarding sequence: hero → content → CTA.
    /// Modelled on App Store's "Today" story card expansion.
    @MainActor
    public static func onboardingReveal(
        heroStages:    [Stage],
        contentStages: [Stage],
        ctaStages:     [Stage],
        style: MotionStyle = .cinematic
    ) async {
        // Beat 1: Hero springs in
        await MotionPresets.screenEntrance(style: style, stages: heroStages).play()

        // Beat 2: Content cascades in (slight overlap)
        try? await Task.sleep(nanoseconds: 80_000_000)
        await MotionPresets.staggeredList(count: contentStages.count, style: style) { i in
            contentStages[i]()
        }.play()

        // Beat 3: CTA fades up
        try? await Task.sleep(nanoseconds: 60_000_000)
        await MotionPresets.screenEntrance(style: style, stages: ctaStages).play()
    }

    // MARK: - Card detail expand

    /// Two-beat card expansion: header image → scrollable body.
    /// Matches the feel of App Store card opening.
    @MainActor
    public static func cardDetailExpand(
        headerStages: [Stage],
        bodyStages:   [Stage],
        style: MotionStyle = .cinematic
    ) async {
        // Header snaps in with hero spring
        await MotionTimeline(style) {
            Parallel {
                for stage in headerStages {
                    Animate(style.primarySpring) { stage() }
                }
            }
        }.play()

        // Body cascades up
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MotionPresets.staggeredList(count: bodyStages.count, style: style) { i in
            bodyStages[i]()
        }.play()
    }

    // MARK: - Screen chapter reveal

    /// Progressive chapter reveal — elements in each chapter appear after the previous.
    /// Used for scroll-triggered storytelling sections.
    @MainActor
    public static func chapterReveal(
        chapters: [[Stage]],
        chapterDelay: Double = 0.12,
        style: MotionStyle = .cinematic
    ) async {
        for (i, chapter) in chapters.enumerated() {
            if i > 0 {
                try? await Task.sleep(nanoseconds: UInt64(chapterDelay * Double(NSEC_PER_SEC)))
            }
            await MotionPresets.screenEntrance(style: style, stages: chapter).play()
        }
    }

    // MARK: - Tab switch

    /// Fast, snappy tab-switch narrative: outgoing fades while incoming springs in.
    @MainActor
    public static func tabSwitch(
        outgoingStages: [Stage],
        incomingStages: [Stage],
        style: MotionStyle = .snappy
    ) async {
        await MotionTimeline(style) {
            Parallel {
                for stage in outgoingStages {
                    Animate(.snappy) { stage() }
                }
            }
        }.play()

        await MotionPresets.staggeredList(
            count: incomingStages.count,
            style: style
        ) { i in
            incomingStages[i]()
        }.play()
    }

    // MARK: - Modal present

    /// Sheet-style modal presentation narrative: backdrop dims, content springs up.
    ///
    /// Calls `MotionPresets.modalPresent` which expects three phases:
    /// backdrop, sheet reveal, then content. `contentStages` are merged
    /// into the content phase; an empty no-op satisfies the sheet phase.
    @MainActor
    public static func modalPresent(
        backdropStages: [Stage],
        contentStages:  [Stage],
        style: MotionStyle = .cinematic
    ) async {
        await MotionPresets.modalPresent(
            style: style,
            onBackdrop: { backdropStages.forEach { $0() } },
            onSheet:    {},
            onContent:  { contentStages.forEach { $0() } }
        ).play()
    }

    // MARK: - Scroll chapter

    /// Drives narrative reveals as a user scrolls through sections.
    /// Returns a closure to call when a section becomes visible.
    ///
    /// The returned closure is idempotent — calling it more than once has
    /// no effect after the first invocation.
    @MainActor
    public static func scrollChapterTrigger(
        stages: [Stage],
        style: MotionStyle = .cinematic
    ) -> @MainActor () -> Void {
        // Use a class-based box for mutable state that is safe on the main actor.
        final class PlayedBox {
            var played = false
        }
        let box = PlayedBox()
        return {
            guard !box.played else { return }
            box.played = true
            Task { @MainActor in
                await MotionPresets.staggeredList(count: stages.count, style: style) { i in
                    stages[i]()
                }.play()
            }
        }
    }
}

// MARK: - NarrativeScene

/// A self-contained narrative unit with its own animation state and playback.
///
/// Attach to a view to participate in a `MotionDirector`-coordinated narrative.
/// Register animation stages then trigger playback via `.narrativeScene(_:)`:
///
/// ```swift
/// @State var heroScene = NarrativeScene(name: "hero")
///
/// MyHeroView()
///     .onAppear { heroScene.addStage { heroOpacity = 1 } }
///     .narrativeScene(heroScene)
/// ```
@Observable
@MainActor
public final class NarrativeScene {

    // MARK: - Properties

    public let name: String
    private(set) public var hasPlayed = false
    private(set) public var isPlaying = false

    private var stages: [@MainActor () -> Void] = []
    private let style: MotionStyle

    // MARK: - Init

    public init(name: String, style: MotionStyle = .cinematic) {
        self.name  = name
        self.style = style
    }

    // MARK: - Stage registration

    /// Register an animation stage. Stages are invoked in order when the scene plays.
    public func addStage(_ stage: @escaping @MainActor () -> Void) {
        stages.append(stage)
    }

    // MARK: - Playback

    /// Play all registered stages as a staggered entrance.
    /// No-ops if the scene has already played; call `reset()` to replay.
    public func play() async {
        guard !hasPlayed else { return }
        isPlaying = true
        await MotionPresets.staggeredList(count: stages.count, style: style) { [stages] i in
            stages[i]()
        }.play()
        isPlaying = false
        hasPlayed = true
    }

    /// Reset so the scene can play again.
    public func reset() {
        hasPlayed = false
    }

    // MARK: - MotionScene interop

    /// Convert to a `MotionScene` for use with `MotionDirector`.
    ///
    /// Each registered stage becomes an `Animate` step inside a single actor
    /// whose name matches this scene's name.
    public func asMotionScene() -> MotionScene {
        let capturedStages = stages
        let capturedStyle  = style
        return MotionScene(style: capturedStyle) {
            MotionActor(name) {
                for stage in capturedStages {
                    Animate(capturedStyle.primarySpring) { stage() }
                }
            }
        }
    }
}

// MARK: - View modifier

public extension View {
    /// Triggers a `NarrativeScene` to play when this view appears.
    func narrativeScene(_ scene: NarrativeScene) -> some View {
        modifier(NarrativeSceneModifier(scene: scene))
    }
}

private struct NarrativeSceneModifier: ViewModifier {
    let scene: NarrativeScene

    func body(content: Content) -> some View {
        content.task {
            await scene.play()
        }
    }
}
