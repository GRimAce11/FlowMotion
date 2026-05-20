import SwiftUI

// MARK: - FlowShaderLibrary

/// Manages the Metal shader library compiled from the FlowMotion package bundle.
///
/// Shaders are compiled from `Sources/FlowMotion/Shaders/**/*.metal` at build
/// time by Xcode into `default.metallib` inside `Bundle.module`.
///
/// Usage:
/// ```swift
/// let fn: ShaderFunction = FlowShaderLibrary.metaball
/// ```
public enum FlowShaderLibrary {

    /// The shader library loaded from the FlowMotion package bundle.
    ///
    /// Uses `ShaderLibrary(url:)` to load `default.metallib` from `Bundle.module`,
    /// which is compiled by Xcode from the `.metal` files in `Sources/FlowMotion/Shaders/`.
    /// Falls back to `ShaderLibrary.default` during command-line `swift build` where
    /// Xcode's Metal compiler is not invoked.
    public static let bundle: ShaderLibrary = {
        if let url = Bundle.module.url(forResource: "default", withExtension: "metallib") {
            return ShaderLibrary(url: url)
        }
        return .default
    }()

    // MARK: - Shader function accessors

    /// True per-pixel metaball field — high quality.
    public static var metaball: ShaderFunction { bundle["flowMetaball"] }

    /// Metaball field — reduced quality for low-tier devices.
    public static var metaballLow: ShaderFunction { bundle["flowMetaballLow"] }

    /// Sinusoidal liquid-edge distortion for transitions.
    public static var liquidEdge: ShaderFunction { bundle["flowLiquidEdge"] }

    /// Expanding ripple distortion.
    public static var ripple: ShaderFunction { bundle["flowRipple"] }

    /// RGB chromatic aberration lens effect.
    public static var chromatic: ShaderFunction { bundle["flowChromatic"] }
}

// MARK: - ShaderLibrary convenience subscript

extension ShaderLibrary {
    /// Access a named function using a subscript.
    subscript(name: String) -> ShaderFunction {
        ShaderFunction(library: self, name: name)
    }
}
