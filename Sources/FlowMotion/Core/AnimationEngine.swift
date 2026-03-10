import SwiftUI
import Observation

// MARK: - AnimationEngine

/// Central coordinator for all FlowMotion animations.
///
/// Tracks in-flight animations, manages cancellation tokens, and provides
/// a single point of truth for animation state across the view hierarchy.
/// All methods must be called on the main actor.
@MainActor
@Observable
public final class AnimationEngine {

    // MARK: Shared instance

    public static let shared = AnimationEngine()

    // MARK: State

    private(set) var activeAnimations: [AnimationToken: AnimationRecord] = [:]
    private(set) var isRunningTimeline: Bool = false

    private var tokenCounter: UInt64 = 0

    private init() {}

    // MARK: - Token management

    /// Generates a new unique animation token.
    public func makeToken() -> AnimationToken {
        tokenCounter &+= 1
        return AnimationToken(id: tokenCounter)
    }

    // MARK: - Registration

    /// Registers an in-flight animation for tracking.
    @discardableResult
    public func register(
        _ record: AnimationRecord,
        token: AnimationToken
    ) -> AnimationToken {
        activeAnimations[token] = record
        return token
    }

    /// Marks an animation as complete and removes it from tracking.
    public func complete(token: AnimationToken) {
        activeAnimations.removeValue(forKey: token)
    }

    // MARK: - Cancellation

    /// Cancels a specific in-flight animation.
    public func cancel(token: AnimationToken) {
        if let record = activeAnimations.removeValue(forKey: token) {
            record.onCancel?()
        }
    }

    /// Cancels all active animations. Useful for scene resets.
    public func cancelAll() {
        let records = activeAnimations.values
        activeAnimations.removeAll()
        for record in records {
            record.onCancel?()
        }
        isRunningTimeline = false
    }

    /// Cancels all animations with a given tag.
    public func cancel(tag: String) {
        let tagged = activeAnimations.filter { $0.value.tag == tag }
        for key in tagged.keys {
            cancel(token: key)
        }
    }

    // MARK: - Queries

    /// Whether any animation with `tag` is currently in flight.
    public func isAnimating(tag: String) -> Bool {
        activeAnimations.values.contains { $0.tag == tag }
    }

    /// The current velocity state for a tagged animation, if available.
    public func velocity(for tag: String) -> CGVector? {
        activeAnimations.values.first { $0.tag == tag }?.currentVelocity
    }

    // MARK: - Velocity mutation (called by gesture coordinators)

    public func updateVelocity(_ velocity: CGVector, for token: AnimationToken) {
        activeAnimations[token]?.currentVelocity = velocity
    }
}

// MARK: - Supporting types

/// Opaque token identifying a single in-flight animation.
public struct AnimationToken: Hashable, Sendable {
    let id: UInt64
}

/// Metadata about a registered animation.
public struct AnimationRecord: @unchecked Sendable {
    /// Human-readable grouping tag for batch cancellation.
    public var tag: String?
    /// Last-known velocity — updated by gesture coordinators.
    public var currentVelocity: CGVector?
    /// Called when the animation is cancelled before completion.
    public var onCancel: (@MainActor () -> Void)?

    public init(
        tag: String? = nil,
        currentVelocity: CGVector? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.tag = tag
        self.currentVelocity = currentVelocity
        self.onCancel = onCancel
    }
}
