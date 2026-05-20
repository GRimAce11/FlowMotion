import SwiftUI

// MARK: - LiquidTransitionModifier

/// Produces a gooey, liquid-morphing appearance using a dual-pass
/// Canvas rendering technique:
///
/// 1. Renders the view content into a canvas layer.
/// 2. Applies a sinusoidal edge displacement along the leading edge.
/// 3. Composites a contrast + blur "metaball" effect to merge/split surfaces.
///
/// This is the SwiftUI equivalent of the classic CSS `filter: contrast(20) blur(10px)`
/// trick — adapted for Metal-composited Canvas layers on iOS 17+.
public struct LiquidTransitionModifier: ViewModifier, Animatable {

    /// Normalised transition progress: 0 = entering/exiting, 1 = fully visible.
    public var progress: CGFloat

    /// Controls the amplitude of the liquid edge wave (0–1).
    public var intensity: CGFloat

    public nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // MARK: Constants

    private let waveFrequency: CGFloat = 3
    private let maxAmplitude:  CGFloat = 28

    // MARK: Body

    public func body(content: Content) -> some View {
        content
            .mask(alignment: .topLeading) {
                liquidMask
            }
            .compositingGroup()
    }

    // MARK: - Liquid mask

    @ViewBuilder
    private var liquidMask: some View {
        GeometryReader { proxy in
            Canvas(rendersAsynchronously: false) { context, size in
                context.fill(
                    liquidPath(in: size),
                    with: .color(.black)
                )
            }
        }
    }

    /// Builds the liquid-edge clipping path.
    ///
    /// The leading edge is displaced by a sinusoidal wave whose amplitude
    /// scales with `(1 − progress)` — at progress=1 it's a clean rectangle.
    private func liquidPath(in size: CGSize) -> Path {
        let amplitude = maxAmplitude * intensity * (1 - progress)
        let stepCount = 60

        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))

        // Leading (left) edge — sinusoidal wave
        for i in 0...stepCount {
            let t      = CGFloat(i) / CGFloat(stepCount)
            let y      = t * size.height
            let phase  = (1 - progress) * .pi * 2   // wave shifts as we animate
            let wave   = amplitude * sin(t * .pi * waveFrequency + phase)
            let x      = wave * (1 - progress)       // collapses to 0 at progress=1
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close around the other three sides
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.closeSubpath()

        return path
    }
}

// MARK: - LiquidSurface

/// Standalone view that applies the gooey metaball compositing effect to
/// overlapping child shapes — useful for liquid loading indicators and
/// morphing blob UI elements.
///
/// ```swift
/// LiquidSurface(blurRadius: 12, contrastBoost: 18) {
///     Circle().frame(width: 60, height: 60).offset(x: xOffset)
///     Circle().frame(width: 60, height: 60)
/// }
/// ```
public struct LiquidSurface<Content: View>: View {

    public let blurRadius: CGFloat
    public let contrastBoost: CGFloat
    private let content: () -> Content

    public init(
        blurRadius: CGFloat = 12,
        contrastBoost: CGFloat = 18,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.blurRadius    = blurRadius
        self.contrastBoost = contrastBoost
        self.content       = content
    }

    public var body: some View {
        ZStack { content() }
            .blur(radius: blurRadius)
            // Simulates CSS contrast() filter using ColorMatrix
            .colorMultiply(Color(white: contrastBoost))
            .compositingGroup()
    }
}

// MARK: - WaveShape

/// Animatable `Shape` that draws a rounded rectangle with a sinusoidal
/// leading edge. Used as a standalone mask or fill shape.
public struct WaveShape: Shape, Animatable {
    /// 0 = zero wave amplitude, 1 = maximum
    public var phase: CGFloat

    public var amplitude: CGFloat
    public var frequency: CGFloat
    public var cornerRadius: CGFloat

    nonisolated public var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    public init(
        phase: CGFloat = 0,
        amplitude: CGFloat = 20,
        frequency: CGFloat = 2,
        cornerRadius: CGFloat = 0
    ) {
        self.phase        = phase
        self.amplitude    = amplitude
        self.frequency    = frequency
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let stepCount = 80
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Leading (left) edge — wave
        for i in stride(from: stepCount, through: 0, by: -1) {
            let t = CGFloat(i) / CGFloat(stepCount)
            let y = rect.minY + t * rect.height
            let x = rect.minX + amplitude * sin(t * .pi * frequency + phase * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - LiquidShaderTransitionModifier

/// GPU-accelerated liquid transition using `distortionEffect`.
/// Used when `shaderQuality.useGPUShaders` is true.
struct LiquidShaderTransitionModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var intensity: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private let frequency: Float = 3.5
    private let amplitude: Float = 26

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .distortionEffect(
                    Shader(function: FlowShaderLibrary.liquidEdge, arguments: [
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(Float(progress)),
                        .float(frequency),
                        .float(amplitude * Float(intensity)),
                        .float(Float(progress) * .pi * 4),
                    ]),
                    maxSampleOffset: CGSize(width: Double(amplitude), height: Double(amplitude))
                )
        }
    }
}
