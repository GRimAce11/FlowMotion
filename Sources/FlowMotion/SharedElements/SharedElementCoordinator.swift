import SwiftUI

// MARK: - SharedElementCoordinator

/// High-level coordinator for shared-element transitions.
///
/// `SharedElementCoordinator` wraps `SharedElementRegistry` with:
/// - **Timeout protection** — if the destination frame is not captured
///   within `frameWaitTimeout`, the transition falls back to a fade.
/// - **Orphan cleanup** — incomplete transitions are cancelled if the
///   source view disappears before the animation starts.
/// - **Interruption recovery** — rapid route changes cancel the
///   in-flight hero and start fresh without leaving orphaned overlays.
/// - **Auditor integration** — every lifecycle event is reported to
///   `TransitionAuditor` for debugging.
@MainActor
public final class SharedElementCoordinator {

    // MARK: Shared

    public static let shared = SharedElementCoordinator()

    // MARK: Configuration

    /// How long (seconds) to wait for the destination frame before falling back.
    public var frameWaitTimeout: TimeInterval = 0.08

    /// Whether to fall back to a fade transition when geometry is unavailable.
    public var useFadeOnGeometryFailure: Bool = true

    private let registry = SharedElementRegistry.shared
    private let auditor  = TransitionAuditor.shared

    private var pendingTransitionTask: Task<Void, Never>?

    private init() {}

    // MARK: - Transition initiation

    /// Initiates a hero transition with timeout protection and fallback.
    ///
    /// - Parameters:
    ///   - id: The shared-element identifier.
    ///   - sourceFrame: The captured source view frame (global coordinates).
    ///   - configuration: Spring configuration for the hero animation.
    ///   - onCompletion: Called when the transition finishes or falls back.
    public func beginHero(
        id: AnyHashable,
        sourceFrame: CGRect,
        configuration: SpringConfiguration,
        onCompletion: @escaping @MainActor () -> Void = {}
    ) {
        // Cancel any previous in-flight transition for this element
        registry.cancelHero()
        pendingTransitionTask?.cancel()

        let transitionID = TransitionID.hero(id)
        auditor.began(id: transitionID, kind: .hero, elementID: id)

        pendingTransitionTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Wait for destination frame (registered by destination view's geometry capture)
            let destinationFrame = await waitForDestinationFrame(id: id)

            guard !Task.isCancelled else {
                self.auditor.cancelled(id: transitionID)
                return
            }

            guard let destFrame = destinationFrame else {
                // Geometry unavailable — fall back gracefully
                self.auditor.cancelled(id: transitionID)
                if self.useFadeOnGeometryFailure {
                    self.applyFadeFallback(onCompletion: onCompletion)
                } else {
                    onCompletion()
                }
                return
            }

            self.registry.beginHero(
                id: id,
                sourceFrame: sourceFrame,
                destinationFrame: destFrame,
                configuration: configuration,
                onCompletion: {
                    self.auditor.completed(id: transitionID)
                    onCompletion()
                }
            )
        }
    }

    /// Cancels the current hero transition cleanly.
    public func cancelCurrentHero() {
        pendingTransitionTask?.cancel()
        pendingTransitionTask = nil
        registry.cancelHero()
    }

    // MARK: - Frame waiting

    /// Polls the registry for the destination frame up to `frameWaitTimeout`.
    private func waitForDestinationFrame(id: AnyHashable) async -> CGRect? {
        let start     = Date()
        let pollInterval: UInt64 = 8_000_000  // 8ms ≈ half a 60Hz frame

        while Date().timeIntervalSince(start) < frameWaitTimeout {
            guard !Task.isCancelled else { return nil }

            if let frame = registry.frame(for: id) {
                return frame
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return registry.frame(for: id)  // one last attempt
    }

    // MARK: - Fallback

    private func applyFadeFallback(onCompletion: @MainActor @escaping () -> Void) {
        Task { @MainActor in
            // A simple delay matching a typical spring settle duration
            try? await Task.sleep(nanoseconds: 300_000_000)
            onCompletion()
        }
    }

    // MARK: - Cleanup

    /// Cleans up all shared-element state. Call on root navigation reset or
    /// `scenePhase` change to `.background`.
    public func cleanAll() {
        pendingTransitionTask?.cancel()
        pendingTransitionTask = nil
        registry.reset()
    }
}

// MARK: - Scene lifecycle modifier

public extension View {
    /// Registers a cleanup handler that cancels orphaned hero transitions
    /// when the scene enters the background.
    func flowSharedElementLifecycle() -> some View {
        modifier(SharedElementLifecycleModifier())
    }
}

private struct SharedElementLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    SharedElementCoordinator.shared.cleanAll()
                }
            }
    }
}
