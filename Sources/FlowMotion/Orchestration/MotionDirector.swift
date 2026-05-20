import SwiftUI

// MARK: - MotionDirector

/// Coordinates multiple `MotionScene` instances across separate view subtrees.
///
/// `MotionDirector` acts as a conductor: it holds named scenes and can play
/// them sequentially, in parallel, or as part of a named `DirectorSequence`.
///
/// Unlike `MotionScene` (which coordinates elements *within* one view), the
/// director synchronises animations *between* independently owned views — e.g.
/// a header scene + card scene + background scene all animating in concert.
///
/// ```swift
/// @Environment(\.motionDirector) var director
///
/// // Play scenes together:
/// await director.playTogether([headerScene, cardScene, bgScene])
///
/// // Play a named sequence:
/// await director.play(onboardingSequence)
/// ```
@Observable
@MainActor
public final class MotionDirector {

    // MARK: - Shared instance

    public static let shared = MotionDirector()

    // MARK: - State

    private(set) public var activeSceneNames: Set<String> = []
    private(set) public var isPlaying: Bool = false

    private var namedScenes: [String: MotionScene] = [:]
    private var runningTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Scene registry

    /// Register a scene under a name so it can be referenced by `DirectorSequence`.
    public func register(_ scene: MotionScene, as name: String) {
        namedScenes[name] = scene
    }

    // MARK: - Playback

    /// Play a single scene and await completion.
    @discardableResult
    public func play(_ scene: MotionScene, timeScale: Double = 1) async -> Void {
        let name = UUID().uuidString
        isPlaying = true
        activeSceneNames.insert(name)
        await scene.play(timeScale: timeScale)
        activeSceneNames.remove(name)
        if activeSceneNames.isEmpty { isPlaying = false }
    }

    /// Play multiple scenes simultaneously and wait for all to complete.
    public func playTogether(_ scenes: [MotionScene], timeScale: Double = 1) async {
        isPlaying = true
        let names = scenes.map { _ in UUID().uuidString }
        for name in names { activeSceneNames.insert(name) }

        await withTaskGroup(of: Void.self) { group in
            for scene in scenes {
                group.addTask {
                    await scene.play(timeScale: timeScale)
                }
            }
        }

        for name in names { activeSceneNames.remove(name) }
        if activeSceneNames.isEmpty { isPlaying = false }
    }

    /// Play scenes sequentially — each starts after the previous completes.
    public func playSequence(_ scenes: [MotionScene], timeScale: Double = 1) async {
        isPlaying = true
        for scene in scenes {
            let name = UUID().uuidString
            activeSceneNames.insert(name)
            await scene.play(timeScale: timeScale)
            activeSceneNames.remove(name)
        }
        if activeSceneNames.isEmpty { isPlaying = false }
    }

    /// Play a named `DirectorSequence` registered in the director.
    public func play(_ sequence: DirectorSequence, timeScale: Double = 1) async {
        isPlaying = true
        for chapter in sequence.chapters {
            let scenesToPlay = chapter.sceneNames.compactMap { namedScenes[$0] }
            if chapter.playTogether {
                await playTogether(scenesToPlay, timeScale: timeScale)
            } else {
                await playSequence(scenesToPlay, timeScale: timeScale)
            }
            if chapter.pauseAfter > 0 {
                try? await Task.sleep(nanoseconds: UInt64(chapter.pauseAfter * Double(NSEC_PER_SEC)))
            }
        }
        isPlaying = false
    }

    /// Play scenes from registered names.
    public func play(named names: [String], together: Bool = true, timeScale: Double = 1) async {
        let scenes = names.compactMap { namedScenes[$0] }
        if together {
            await playTogether(scenes, timeScale: timeScale)
        } else {
            await playSequence(scenes, timeScale: timeScale)
        }
    }

    // MARK: - Non-blocking play (fire and forget)

    /// Start playing a sequence without awaiting — returns immediately.
    public func playDetached(_ sequence: DirectorSequence, timeScale: Double = 1) {
        Task { @MainActor in
            await play(sequence, timeScale: timeScale)
        }
    }

    /// Start playing scenes without awaiting.
    public func playDetached(_ scenes: [MotionScene], together: Bool = true, timeScale: Double = 1) {
        Task { @MainActor in
            if together {
                await playTogether(scenes, timeScale: timeScale)
            } else {
                await playSequence(scenes, timeScale: timeScale)
            }
        }
    }

    // MARK: - Cancellation

    /// Cancel all running scene animations.
    public func cancelAll() {
        for task in runningTasks.values { task.cancel() }
        runningTasks.removeAll()
        activeSceneNames.removeAll()
        isPlaying = false
    }
}

// MARK: - DirectorSequence

/// A named sequence of choreography chapters for `MotionDirector`.
///
/// ```swift
/// let onboarding = DirectorSequence(name: "onboarding") {
///     DirectorChapter(["background", "hero"], together: true)
///     DirectorChapter(["content"], together: false, pauseAfter: 0.1)
///     DirectorChapter(["cta"], together: false)
/// }
/// ```
public struct DirectorSequence: Sendable {
    public let name: String
    public let chapters: [DirectorChapter]

    public init(name: String, @DirectorChapterBuilder chapters: () -> [DirectorChapter]) {
        self.name     = name
        self.chapters = chapters()
    }

    public init(name: String, chapters: [DirectorChapter]) {
        self.name     = name
        self.chapters = chapters
    }
}

// MARK: - DirectorChapter

/// One step in a `DirectorSequence` — a set of scenes to play simultaneously or in order.
public struct DirectorChapter: Sendable {
    public let sceneNames: [String]
    public let playTogether: Bool
    public let pauseAfter: Double

    public init(_ sceneNames: [String], together: Bool = true, pauseAfter: Double = 0) {
        self.sceneNames   = sceneNames
        self.playTogether = together
        self.pauseAfter   = pauseAfter
    }
}

// MARK: - DirectorChapterBuilder

@resultBuilder
public enum DirectorChapterBuilder {
    public static func buildBlock(_ chapters: DirectorChapter...) -> [DirectorChapter] {
        chapters
    }
    public static func buildArray(_ chapters: [[DirectorChapter]]) -> [DirectorChapter] {
        chapters.flatMap { $0 }
    }
    public static func buildOptional(_ component: [DirectorChapter]?) -> [DirectorChapter] {
        component ?? []
    }
    public static func buildEither(first component: [DirectorChapter]) -> [DirectorChapter] {
        component
    }
    public static func buildEither(second component: [DirectorChapter]) -> [DirectorChapter] {
        component
    }
    public static func buildExpression(_ expression: DirectorChapter) -> [DirectorChapter] {
        [expression]
    }
}

// MARK: - Environment
//
// `MotionDirector` is `@MainActor`, so it cannot be used as a nonisolated
// `EnvironmentKey` defaultValue. Use `Optional` with `nil` default; inject
// via `.environment(\.motionDirector, director)` at the root where the
// MainActor is available. Access via `.shared` when not injected.

private struct MotionDirectorKey: EnvironmentKey {
    static let defaultValue: MotionDirector? = nil
}

public extension EnvironmentValues {
    /// The ambient `MotionDirector`. Inject with `.motionDirector(_:)` at
    /// the root; falls back to `MotionDirector.shared` when not set.
    var motionDirector: MotionDirector? {
        get { self[MotionDirectorKey.self] }
        set { self[MotionDirectorKey.self] = newValue }
    }
}

// MARK: - View convenience

public extension View {
    /// Injects a `MotionDirector` into the environment.
    func motionDirector(_ director: MotionDirector) -> some View {
        environment(\.motionDirector, director)
    }
}
