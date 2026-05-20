import SwiftUI

// MARK: - FlowShaderEffect

/// Named GPU shader effects available in FlowMotion.
///
/// Apply to any SwiftUI view using `.flowShader(_:)`:
///
/// ```swift
/// CardView()
///     .flowShader(.ripple(amplitude: 20))
///
/// LoadingView()
///     .flowShader(.metaball())
/// ```
public enum FlowShaderEffect: Sendable {

    /// True per-pixel metaball field.
    case metaball(config: MetaballShaderConfig = .init())

    /// Expanding ripple distortion from a touch origin.
    case ripple(origin: CGPoint = .zero, amplitude: Float = 24, frequency: Float = 15, decay: Float = 8)

    /// RGB chromatic aberration — cinematic lens split.
    case chromatic(intensity: Float = 4, origin: CGPoint? = nil)

    /// Liquid edge distortion (used by transition system internally).
    case liquidEdge(progress: Float, frequency: Float = 3, amplitude: Float = 28, phase: Float = 0)
}

// MARK: - CGPoint + Sendable

extension CGPoint: @unchecked Sendable {}

// MARK: - MetaballShaderConfig

public struct MetaballShaderConfig: Sendable {
    public var blobCount: Int
    public var threshold: Float
    public var softness: Float
    public var primaryColor: Color
    public var secondaryColor: Color

    public init(
        blobCount: Int = 5,
        threshold: Float = 1.2,
        softness: Float = 0.35,
        primaryColor: Color = .blue,
        secondaryColor: Color = .purple
    ) {
        self.blobCount      = blobCount
        self.threshold      = threshold
        self.softness       = softness
        self.primaryColor   = primaryColor
        self.secondaryColor = secondaryColor
    }

    public static let ocean    = MetaballShaderConfig(primaryColor: .blue,   secondaryColor: .cyan)
    public static let sunset   = MetaballShaderConfig(primaryColor: .orange, secondaryColor: .pink)
    public static let midnight = MetaballShaderConfig(primaryColor: .indigo, secondaryColor: .purple)
}

// MARK: - View extension

public extension View {

    /// Applies a GPU shader effect to this view.
    ///
    /// Gracefully no-ops on unsupported configurations.
    func flowShader(_ effect: FlowShaderEffect, isEnabled: Bool = true) -> some View {
        modifier(FlowShaderModifier(effect: effect, isEnabled: isEnabled))
    }
}

// MARK: - FlowShaderModifier

struct FlowShaderModifier: ViewModifier {
    let effect: FlowShaderEffect
    let isEnabled: Bool

    @Environment(\.frameBudgetQuality) private var quality

    func body(content: Content) -> some View {
        guard isEnabled else { return AnyView(content) }

        switch effect {
        case .ripple(let origin, let amplitude, let frequency, let decay):
            return AnyView(
                content.distortionEffect(
                    Shader(function: FlowShaderLibrary.ripple, arguments: [
                        .float2(Float(origin.x), Float(origin.y)),
                        .float(0),          // time — use TimelineView for animation
                        .float(amplitude),
                        .float(frequency),
                        .float(decay),
                    ]),
                    maxSampleOffset: CGSize(width: Double(amplitude), height: Double(amplitude)),
                    isEnabled: isEnabled
                )
            )

        case .chromatic(let intensity, let origin):
            return AnyView(
                GeometryReader { proxy in
                    let center = origin.map {
                        CGPoint(x: $0.x * proxy.size.width, y: $0.y * proxy.size.height)
                    } ?? CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    content.layerEffect(
                        Shader(function: FlowShaderLibrary.chromatic, arguments: [
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(intensity),
                            .float2(Float(center.x), Float(center.y)),
                        ]),
                        maxSampleOffset: CGSize(width: Double(intensity), height: Double(intensity)),
                        isEnabled: isEnabled
                    )
                }
            )

        case .liquidEdge(let progress, let frequency, let amplitude, let phase):
            return AnyView(
                GeometryReader { proxy in
                    content.distortionEffect(
                        Shader(function: FlowShaderLibrary.liquidEdge, arguments: [
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(progress),
                            .float(frequency),
                            .float(amplitude),
                            .float(phase),
                        ]),
                        maxSampleOffset: CGSize(width: Double(amplitude), height: Double(amplitude)),
                        isEnabled: isEnabled
                    )
                }
            )

        case .metaball:
            // Metaball is handled by MetaballShaderView directly
            return AnyView(content)
        }
    }
}

// MARK: - Animated ripple modifier

public extension View {
    /// Applies an animated ripple effect that expands from the given origin.
    func flowRipple(
        trigger: some Equatable,
        origin: CGPoint = .zero,
        amplitude: Float = 24,
        frequency: Float = 15,
        decay: Float = 8
    ) -> some View {
        modifier(AnimatedRippleModifier(
            trigger: trigger,
            origin: origin,
            amplitude: amplitude,
            frequency: frequency,
            decay: decay
        ))
    }
}

private struct AnimatedRippleModifier<T: Equatable>: ViewModifier {
    let trigger: T
    let origin: CGPoint
    let amplitude: Float
    let frequency: Float
    let decay: Float

    @State private var startDate: Date = .now
    @State private var isActive = false

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !isActive)) { context in
            let elapsed = Float(context.date.timeIntervalSince(startDate))
            content.distortionEffect(
                Shader(function: FlowShaderLibrary.ripple, arguments: [
                    .float2(Float(origin.x), Float(origin.y)),
                    .float(isActive ? elapsed : 0),
                    .float(amplitude),
                    .float(frequency),
                    .float(decay),
                ]),
                maxSampleOffset: CGSize(width: Double(amplitude), height: Double(amplitude)),
                isEnabled: isActive
            )
        }
        .onChange(of: trigger) { _, _ in
            startDate = .now
            isActive = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                isActive = false
            }
        }
    }
}
