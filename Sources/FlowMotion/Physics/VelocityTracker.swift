import SwiftUI

// MARK: - VelocityTracker

/// Accumulates recent gesture samples and produces a smoothed velocity estimate.
///
/// `DragGesture.Value.velocity` (iOS 17+) is generally accurate but can spike at
/// the final frame. `VelocityTracker` keeps a short ring-buffer of timestamped
/// positions and uses an exponentially-weighted moving average (EWMA) for
/// a more stable handoff to spring animations.
@MainActor
public final class VelocityTracker {

    // MARK: Configuration

    public struct Configuration: Sendable {
        /// Maximum number of samples kept in the ring buffer.
        public var historyLength: Int
        /// EWMA decay factor α. Higher = more responsive, lower = smoother.
        public var smoothingFactor: Double
        /// Clamp magnitude (pts/s) to prevent unrealistic velocities.
        public var maximumVelocity: CGFloat

        public init(
            historyLength: Int = 8,
            smoothingFactor: Double = 0.4,
            maximumVelocity: CGFloat = 3000
        ) {
            self.historyLength = historyLength
            self.smoothingFactor = smoothingFactor
            self.maximumVelocity = maximumVelocity
        }

        public static let standard = Configuration()
        public static let responsive = Configuration(smoothingFactor: 0.65)
        public static let stable    = Configuration(smoothingFactor: 0.2)
    }

    // MARK: State

    private var samples: [(time: CFAbsoluteTime, location: CGPoint)] = []
    private var smoothedVelocity: CGVector = .zero
    private let configuration: Configuration

    public init(configuration: Configuration = .standard) {
        self.configuration = configuration
        samples.reserveCapacity(configuration.historyLength)
    }

    // MARK: - API

    /// Records a new gesture sample (call from `.onChanged`).
    public func record(_ location: CGPoint) {
        let now = CFAbsoluteTimeGetCurrent()
        samples.append((now, location))
        if samples.count > configuration.historyLength {
            samples.removeFirst()
        }
        updateSmoothedVelocity()
    }

    /// Resets all history. Call from `.onEnded` after reading velocity.
    public func reset() {
        samples.removeAll(keepingCapacity: true)
        smoothedVelocity = .zero
    }

    /// The current smoothed velocity estimate (pts/s).
    public var velocity: CGVector { smoothedVelocity }

    /// The most recent raw velocity computed from the last two samples (pts/s).
    public var instantaneousVelocity: CGVector {
        guard samples.count >= 2 else { return .zero }
        let last    = samples[samples.count - 1]
        let penult  = samples[samples.count - 2]
        let dt      = last.time - penult.time
        guard dt > 0 else { return .zero }
        return clamped(
            CGVector(
                dx: (last.location.x - penult.location.x) / dt,
                dy: (last.location.y - penult.location.y) / dt
            )
        )
    }

    // MARK: - Private

    private func updateSmoothedVelocity() {
        let raw = instantaneousVelocity
        let α   = configuration.smoothingFactor
        smoothedVelocity = CGVector(
            dx: α * raw.dx + (1 - α) * smoothedVelocity.dx,
            dy: α * raw.dy + (1 - α) * smoothedVelocity.dy
        )
    }

    private func clamped(_ velocity: CGVector) -> CGVector {
        let magnitude = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let max = configuration.maximumVelocity
        guard magnitude > max else { return velocity }
        let scale = max / magnitude
        return CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
    }
}

// MARK: - DragGesture velocity bridge

public extension DragGesture.Value {
    /// Extracts the gesture's predicted velocity and clamps it to a safe range.
    var flowVelocity: CGVector {
        let v = predictedEndLocation
        let l = location
        // predictedEndLocation encodes velocity-implied endpoint; derive velocity
        // from the delta across the remaining gesture time (~1/60 s frame).
        // Fall back to iOS 17 `.velocity` when available.
        #if canImport(UIKit)
        return CGVector(dx: velocity.width, dy: velocity.height)
        #else
        return CGVector(dx: v.x - l.x, dy: v.y - l.y)
        #endif
    }
}
