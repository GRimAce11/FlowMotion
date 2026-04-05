import SwiftUI

// MARK: - GestureCoordinator

/// Arbitrates competing gestures in nested scroll / drag / swipe hierarchies.
///
/// SwiftUI's gesture system can conflict when:
/// - A scroll view competes with a drag-to-dismiss.
/// - A pager swipe competes with a nested card drag.
/// - An interactive transition competes with a tap gesture.
///
/// `GestureCoordinator` implements a priority-based arbitration scheme:
/// the first gesture to exceed its activation threshold "wins" and the others
/// are soft-cancelled until the winning gesture ends.
@Observable
public final class GestureCoordinator: @unchecked Sendable {

    // MARK: State

    public private(set) var activeGestureID: AnyHashable?
    private var registeredGestures: [AnyHashable: GestureRegistration] = [:]

    // MARK: - Registration

    /// Registers a gesture with the coordinator.
    public func register<ID: Hashable>(
        _ id: ID,
        priority: GesturePriority = .normal,
        activationThreshold: CGFloat = 10
    ) {
        registeredGestures[AnyHashable(id)] = GestureRegistration(
            id: AnyHashable(id),
            priority: priority,
            activationThreshold: activationThreshold
        )
    }

    public func unregister<ID: Hashable>(_ id: ID) {
        registeredGestures.removeValue(forKey: AnyHashable(id))
    }

    // MARK: - Arbitration

    /// Called by each gesture's `.onChanged` with the current displacement.
    /// Returns `true` if this gesture is allowed to proceed.
    public func shouldActivate<ID: Hashable>(
        _ id: ID,
        displacement: CGFloat
    ) -> Bool {
        let key = AnyHashable(id)

        // Already active
        if activeGestureID == key { return true }

        // Another gesture is active — check priority
        if let activeID = activeGestureID,
           let active = registeredGestures[activeID],
           let candidate = registeredGestures[key] {
            return candidate.priority > active.priority
        }

        // No active gesture — check threshold
        guard let registration = registeredGestures[key],
              abs(displacement) > registration.activationThreshold else {
            return false
        }

        activeGestureID = key
        return true
    }

    /// Called by each gesture's `.onEnded` to release the lock.
    public func ended<ID: Hashable>(_ id: ID) {
        if activeGestureID == AnyHashable(id) {
            activeGestureID = nil
        }
    }

    /// Returns whether a gesture is currently blocked.
    public func isBlocked<ID: Hashable>(_ id: ID) -> Bool {
        guard let active = activeGestureID else { return false }
        return active != AnyHashable(id)
    }
}

// MARK: - Supporting types

public enum GesturePriority: Int, Comparable, Sendable {
    case low    = 0
    case normal = 1
    case high   = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct GestureRegistration {
    let id: AnyHashable
    let priority: GesturePriority
    let activationThreshold: CGFloat
}

// MARK: - EnvironmentKey

private struct GestureCoordinatorKey: EnvironmentKey {
    static let defaultValue = GestureCoordinator()
}

public extension EnvironmentValues {
    var gestureCoordinator: GestureCoordinator {
        get { self[GestureCoordinatorKey.self] }
        set { self[GestureCoordinatorKey.self] = newValue }
    }
}

// MARK: - View modifier

public extension View {
    /// Installs a `GestureCoordinator` into the environment.
    /// Call once near the root of a gesture-heavy subtree.
    func flowGestureCoordinator() -> some View {
        self.environment(\.gestureCoordinator, GestureCoordinator())
    }
}
