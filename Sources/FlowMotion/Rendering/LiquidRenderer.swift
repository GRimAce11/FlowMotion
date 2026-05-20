import SwiftUI

// MARK: - LiquidRenderer

/// Canvas-based renderer that draws a liquid/gooey morphing effect between
/// two geometric states using the metaball compositing algorithm.
///
/// The "liquid" visual is produced by:
/// 1. Drawing filled circles (blobs) at computed positions.
/// 2. Applying a Gaussian blur to the composite.
/// 3. Using `blendMode(.luminosity)` or threshold-clipping to harden edges.
///
/// This produces the characteristic "merging liquid" look without Metal.
public struct LiquidRenderer: FlowRenderer, Sendable {

    // MARK: Configuration

    public struct Configuration: Sendable {
        public var primaryColor: Color
        public var secondaryColor: Color
        public var blurRadius: CGFloat
        public var blobCount: Int

        public init(
            primaryColor: Color = .blue,
            secondaryColor: Color = .purple,
            blurRadius: CGFloat = 12,
            blobCount: Int = 5
        ) {
            self.primaryColor   = primaryColor
            self.secondaryColor = secondaryColor
            self.blurRadius     = blurRadius
            self.blobCount      = blobCount
        }

        public static let ocean    = Configuration(primaryColor: .blue,   secondaryColor: .cyan)
        public static let sunset   = Configuration(primaryColor: .orange, secondaryColor: .pink)
        public static let midnight = Configuration(primaryColor: .indigo, secondaryColor: .purple)
    }

    public let configuration: Configuration

    public init(configuration: Configuration = .ocean) {
        self.configuration = configuration
    }

    // MARK: - FlowRenderer

    @MainActor
    public func draw(frame: CGRect, progress: CGFloat, context: inout GraphicsContext) {
        let blobs = computeBlobs(in: frame, progress: progress)

        // Draw each blob as a soft circle with gradient fill
        for blob in blobs {
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [configuration.primaryColor, configuration.secondaryColor]),
                startPoint: CGPoint(x: blob.center.x - blob.radius, y: blob.center.y),
                endPoint:   CGPoint(x: blob.center.x + blob.radius, y: blob.center.y)
            )
            context.fill(
                Path(ellipseIn: blob.boundingRect),
                with: gradient
            )
        }
    }

    // MARK: - Blob computation

    private func computeBlobs(in frame: CGRect, progress: CGFloat) -> [Blob] {
        let count = configuration.blobCount
        return (0..<count).map { i in
            let t        = CGFloat(i) / CGFloat(count - 1)
            let phase    = t * .pi * 2
            let wobble   = sin(phase + progress * .pi * 4) * 0.15

            // Blobs migrate from the leading edge to the trailing edge as progress goes 0→1
            let xFraction = (t + progress * (1 - t)) + wobble
            let yFraction = 0.5 + 0.3 * cos(phase + progress * .pi * 2)

            let center = CGPoint(
                x: frame.minX + frame.width  * min(max(xFraction, 0), 1),
                y: frame.minY + frame.height * min(max(yFraction, 0), 1)
            )

            let baseRadius = min(frame.width, frame.height) * 0.18
            let radiusScale = 1 + 0.3 * sin(phase * 2 + progress * .pi)
            let radius = baseRadius * radiusScale

            return Blob(center: center, radius: radius)
        }
    }

    struct Blob: Sendable {
        let center: CGPoint
        let radius: CGFloat

        var boundingRect: CGRect {
            CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width:  radius * 2,
                height: radius * 2
            )
        }
    }
}

// MARK: - LiquidLoadingView

/// Standalone animated liquid loading indicator using `LiquidRenderer`.
///
/// ```swift
/// LiquidLoadingView(configuration: .sunset)
///     .frame(width: 200, height: 80)
/// ```
public struct LiquidLoadingView: View {

    public let configuration: LiquidRenderer.Configuration

    @State private var phase: CGFloat = 0

    public init(configuration: LiquidRenderer.Configuration = .ocean) {
        self.configuration = configuration
    }

    public var body: some View {
        // Use GPU shader when quality permits; fall back to Canvas on low-end devices
        ShaderAwareLiquidView(configuration: configuration)
    }
}

// MARK: - ShaderAwareLiquidView

private struct ShaderAwareLiquidView: View {
    let configuration: LiquidRenderer.Configuration
    @Environment(\.shaderQuality) private var quality

    var body: some View {
        if quality.useGPUShaders {
            MetaballShaderView(config: MetaballShaderConfig(
                blobCount: quality.metaballBlobCount,
                threshold: 1.2,
                softness: quality.metaballSoftness,
                primaryColor: configuration.primaryColor,
                secondaryColor: configuration.secondaryColor
            ))
        } else {
            // Canvas fallback — original implementation
            canvasFallback
        }
    }

    private var canvasFallback: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2)) / 2
            Canvas(rendersAsynchronously: false) { context, size in
                var mutableCtx = context
                let renderer = LiquidRenderer(configuration: configuration)
                renderer.draw(frame: CGRect(origin: .zero, size: size), progress: progress, context: &mutableCtx)
            }
        }
        .blur(radius: configuration.blurRadius)
        .drawingGroup()
    }
}

// MARK: - ShimmerRenderer

/// A renderer that draws a shimmer highlight sweep — useful for skeleton loaders.
public struct ShimmerRenderer: FlowRenderer {

    public let color: Color
    public let angle: Angle

    public init(color: Color = .white.opacity(0.6), angle: Angle = .degrees(-45)) {
        self.color = color
        self.angle = angle
    }

    @MainActor
    public func draw(frame: CGRect, progress: CGFloat, context: inout GraphicsContext) {
        let sweep = frame.width * 2
        let xStart = frame.minX - sweep + (sweep + frame.width) * progress
        let xEnd   = xStart + sweep

        let gradient = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: color, location: 0.4),
                .init(color: color, location: 0.6),
                .init(color: .clear, location: 1),
            ]),
            startPoint: CGPoint(x: xStart, y: frame.midY),
            endPoint:   CGPoint(x: xEnd,   y: frame.midY)
        )

        context.fill(Path(frame), with: gradient)
    }
}
