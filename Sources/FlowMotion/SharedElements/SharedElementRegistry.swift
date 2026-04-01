import SwiftUI
import Observation

// MARK: - SharedElementRegistry

/// Thread-safe, `@MainActor`-isolated registry of shared-element geometries.
///
/// Views register their frames on appear and update them during layout. When a
/// hero transition fires, the `HeroAnimationController` queries both the source
/// and destination frames to interpolate between them.
@MainActor
@Observable
public final class SharedElementRegistry {

    // MARK: Shared

    public static let shared = SharedElementRegistry()

    // MARK: State

    /// Current frames keyed by element ID.
    private(set) var frames: [AnyHashable: ElementRecord] = [:]

    /// Currently active hero transition, if any.
    private(set) var activeHero: HeroTransitionState?

    private init() {}

    // MARK: - Registration

    /// Records the global frame for a shared element.
    func register(id: AnyHashable, frame: CGRect, role: ElementRole) {
        frames[id] = ElementRecord(id: id, frame: frame, role: role)
    }

    func unregister(id: AnyHashable) {
        frames.removeValue(forKey: id)
    }

    // MARK: - Hero transition control

    /// Initiates a hero transition from source → destination.
    func beginHero(
        id: AnyHashable,
        sourceFrame: CGRect,
        destinationFrame: CGRect,
        configuration: SpringConfiguration,
        onCompletion: @escaping @MainActor () -> Void
    ) {
        activeHero = HeroTransitionState(
            id: id,
            phase: .preparing,
            sourceFrame: sourceFrame,
            destinationFrame: destinationFrame,
            configuration: configuration,
            onCompletion: onCompletion
        )
    }

    func advanceHero(to phase: HeroTransitionState.Phase) {
        activeHero?.phase = phase
    }

    func completeHero() {
        let completion = activeHero?.onCompletion
        activeHero = nil
        completion?()
    }

    func cancelHero() {
        activeHero = nil
    }

    // MARK: - Queries

    func frame(for id: AnyHashable) -> CGRect? {
        frames[id]?.frame
    }

    // MARK: - Reset

    func reset() {
        frames.removeAll()
        activeHero = nil
    }
}

// MARK: - Supporting types

/// A snapshot of a shared element's geometry and role.
public struct ElementRecord: @unchecked Sendable {
    public let id: AnyHashable
    public var frame: CGRect
    public var role: ElementRole
}

public enum ElementRole: Sendable {
    case source
    case destination
    case neutral
}

/// The current state of a hero/shared-element transition.
public struct HeroTransitionState: @unchecked Sendable {

    public enum Phase: Sendable {
        case preparing
        case animating(progress: CGFloat)
        case completing
        case done
    }

    public let id: AnyHashable
    public var phase: Phase
    public let sourceFrame: CGRect
    public let destinationFrame: CGRect
    public let configuration: SpringConfiguration
    let onCompletion: @MainActor () -> Void
}
