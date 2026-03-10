import SwiftUI

// MARK: - MotionConfiguration

/// Global configuration for the FlowMotion system.
///
/// Configure spring presets, quality levels, and accessibility behaviour
/// before attaching `.flowMotionSetup()` to the root view.
public struct MotionConfiguration: Sendable {

    // MARK: Spring presets

    /// Spring used for standard UI interactions (card taps, sheet presentation).
    public var interactionSpring: SpringConfiguration

    /// Spring used for hero/shared-element transitions.
    public var heroSpring: SpringConfiguration

    /// Spring used for interactive dismiss / drag-to-close gestures.
    public var dismissSpring: SpringConfiguration

    /// Spring used for snapping during gesture cancellation.
    public var snapSpring: SpringConfiguration

    // MARK: Timing

    /// Duration multiplier applied to all timeline animations (default: 1.0).
    public var timeScale: Double

    /// Minimum velocity (pts/s) required to commit an interactive transition.
    public var commitVelocityThreshold: CGFloat

    /// Drag progress (0–1) required to commit if velocity is below threshold.
    public var commitProgressThreshold: CGFloat

    // MARK: Quality

    /// Target rendering quality. Lower values improve CPU/GPU headroom.
    public var renderQuality: RenderQuality

    // MARK: Accessibility

    /// When `true`, the system checks `UIAccessibility.isReduceMotionEnabled`
    /// and substitutes fade transitions for all motion.
    public var respectsReduceMotion: Bool

    // MARK: Init

    public init(
        interactionSpring: SpringConfiguration = .snappy,
        heroSpring: SpringConfiguration = .hero,
        dismissSpring: SpringConfiguration = .dismiss,
        snapSpring: SpringConfiguration = .snappy,
        timeScale: Double = 1.0,
        commitVelocityThreshold: CGFloat = 300,
        commitProgressThreshold: CGFloat = 0.45,
        renderQuality: RenderQuality = .high,
        respectsReduceMotion: Bool = true
    ) {
        self.interactionSpring = interactionSpring
        self.heroSpring = heroSpring
        self.dismissSpring = dismissSpring
        self.snapSpring = snapSpring
        self.timeScale = timeScale
        self.commitVelocityThreshold = commitVelocityThreshold
        self.commitProgressThreshold = commitProgressThreshold
        self.renderQuality = renderQuality
        self.respectsReduceMotion = respectsReduceMotion
    }
}

// MARK: - Presets

public extension MotionConfiguration {
    /// Default production configuration — balanced quality and performance.
    static let `default` = MotionConfiguration()

    /// Performance-tuned configuration for older devices.
    static let performance = MotionConfiguration(
        interactionSpring: .smooth,
        heroSpring: .smooth,
        renderQuality: .medium
    )

    /// High-fidelity configuration targeting ProMotion displays (120 Hz).
    static let highFidelity = MotionConfiguration(
        interactionSpring: .bouncy,
        heroSpring: .heroElastic,
        renderQuality: .ultra
    )
}

// MARK: - RenderQuality

/// Controls detail level of Canvas/Metal rendering passes.
public enum RenderQuality: Int, Sendable, Comparable {
    case low    = 0
    case medium = 1
    case high   = 2
    case ultra  = 3

    public static func < (lhs: RenderQuality, rhs: RenderQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Suggested Gaussian blur radius for liquid transitions at this quality level.
    var liquidBlurRadius: CGFloat {
        switch self {
        case .low:    return 4
        case .medium: return 8
        case .high:   return 12
        case .ultra:  return 18
        }
    }

    /// Number of intermediate shape samples for morphing at this quality level.
    var morphSampleCount: Int {
        switch self {
        case .low:    return 32
        case .medium: return 64
        case .high:   return 128
        case .ultra:  return 256
        }
    }
}

// MARK: - EnvironmentKey

private struct MotionConfigurationKey: EnvironmentKey {
    static let defaultValue = MotionConfiguration.default
}

public extension EnvironmentValues {
    var flowMotionConfiguration: MotionConfiguration {
        get { self[MotionConfigurationKey.self] }
        set { self[MotionConfigurationKey.self] = newValue }
    }
}
