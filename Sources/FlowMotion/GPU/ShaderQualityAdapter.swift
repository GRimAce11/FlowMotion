import SwiftUI

// MARK: - ShaderQualityAdapter

/// Translates `QualityTier` signals from `FrameBudgetMonitor` into
/// concrete shader configuration parameters.
///
/// Views read this via the environment to self-configure:
///
/// ```swift
/// @Environment(\.shaderQuality) var shaderQuality
/// // shaderQuality.metaballBlobCount → Int
/// // shaderQuality.useGPUShaders     → Bool
/// ```
public struct ShaderQualityParameters: Sendable {

    public let tier: QualityTier

    /// Whether to use GPU shaders or fall back to Canvas rendering.
    public var useGPUShaders: Bool {
        tier >= .medium
    }

    /// Maximum blob count for metaball shader.
    public var metaballBlobCount: Int {
        switch tier {
        case .ultra:  return 8
        case .high:   return 6
        case .medium: return 4
        case .low:    return 3
        }
    }

    /// Metaball edge softness — higher = softer (more GPU cost).
    public var metaballSoftness: Float {
        switch tier {
        case .ultra:  return 0.40
        case .high:   return 0.35
        case .medium: return 0.25
        case .low:    return 0.10
        }
    }

    /// Chromatic aberration intensity — reduced under load.
    public var chromaticIntensity: Float {
        switch tier {
        case .ultra:  return 6.0
        case .high:   return 4.0
        case .medium: return 2.0
        case .low:    return 0.0
        }
    }

    /// Ripple amplitude scaling factor.
    public var rippleAmplitudeScale: Float {
        switch tier {
        case .ultra, .high: return 1.0
        case .medium:       return 0.7
        case .low:          return 0.4
        }
    }

    public static let high = ShaderQualityParameters(tier: .high)
}

// MARK: - EnvironmentKey

private struct ShaderQualityKey: EnvironmentKey {
    static let defaultValue = ShaderQualityParameters(tier: .high)
}

public extension EnvironmentValues {
    /// Current shader quality parameters — derived from `frameBudgetQuality`.
    var shaderQuality: ShaderQualityParameters {
        get { self[ShaderQualityKey.self] }
        set { self[ShaderQualityKey.self] = newValue }
    }
}

// MARK: - View modifier

public extension View {
    /// Injects shader quality parameters derived from the current frame budget tier.
    func flowShaderQuality() -> some View {
        modifier(ShaderQualityModifier())
    }
}

private struct ShaderQualityModifier: ViewModifier {
    @Environment(\.frameBudgetQuality) private var tier

    func body(content: Content) -> some View {
        content.environment(\.shaderQuality, ShaderQualityParameters(tier: tier))
    }
}
