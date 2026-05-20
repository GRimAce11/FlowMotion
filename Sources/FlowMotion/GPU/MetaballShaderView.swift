import SwiftUI

// MARK: - MetaballShaderView

/// GPU-accelerated liquid loading indicator using true per-pixel metaball shaders.
///
/// This replaces the Canvas blur/contrast approximation with a fragment shader
/// that computes the exact metaball field at each pixel — eliminating artifacts
/// at blob boundaries and supporting smooth edge softness control.
///
/// ```swift
/// MetaballShaderView(config: .ocean)
///     .frame(height: 80)
/// ```
public struct MetaballShaderView: View {
    public let config: MetaballShaderConfig

    @Environment(\.frameBudgetQuality) private var quality

    public init(config: MetaballShaderConfig = .ocean) {
        self.config = config
    }

    public var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4)) / 4
                metaballCanvas(size: proxy.size, time: t)
            }
        }
    }

    private func metaballCanvas(size: CGSize, time: Float) -> some View {
        let blobs = computeBlobs(in: size, time: time)
        let blobFloats = packBlobs(blobs)
        let useHighQuality = quality >= .high

        return Rectangle()
            .colorEffect(
                Shader(
                    function: useHighQuality ? FlowShaderLibrary.metaball : FlowShaderLibrary.metaballLow,
                    arguments: useHighQuality
                        ? [
                            .float2(Float(size.width), Float(size.height)),
                            .floatArray(blobFloats),
                            .float(Float(min(blobs.count, 8))),
                            .float(config.threshold),
                            .float(config.softness),
                            .color(config.primaryColor),
                            .color(config.secondaryColor),
                        ]
                        : [
                            .float2(Float(size.width), Float(size.height)),
                            .floatArray(blobFloats),
                            .float(Float(min(blobs.count, 4))),
                            .float(config.threshold),
                            .color(config.primaryColor),
                            .color(config.secondaryColor),
                        ]
                )
            )
    }

    // MARK: - Blob animation

    private struct AnimatedBlob {
        var center: CGPoint
        var radius: CGFloat
    }

    private func computeBlobs(in size: CGSize, time: Float) -> [AnimatedBlob] {
        let count = min(config.blobCount, 8)
        return (0..<count).map { i in
            let t     = Float(i) / Float(max(count - 1, 1))
            let phase = t * .pi * 2
            let wobbleX = sin(phase + time * .pi * 2) * 0.12
            let wobbleY = cos(phase * 1.3 + time * .pi * 1.5) * 0.10

            let cx = (t + wobbleX) * Float(size.width)
            let cy = (0.5 + 0.3 * cos(phase + time * .pi)) * Float(size.height) + Float(size.height) * wobbleY
            let baseR = min(Float(size.width), Float(size.height)) * 0.22
            let r = baseR * (1 + 0.25 * sin(phase * 2 + time * .pi * 3))

            return AnimatedBlob(
                center: CGPoint(x: CGFloat(cx), y: CGFloat(cy)),
                radius: CGFloat(r)
            )
        }
    }

    private func packBlobs(_ blobs: [AnimatedBlob]) -> [Float] {
        var result = [Float](repeating: 0, count: 32)
        for (i, blob) in blobs.prefix(8).enumerated() {
            result[i * 4 + 0] = Float(blob.center.x)
            result[i * 4 + 1] = Float(blob.center.y)
            result[i * 4 + 2] = Float(blob.radius)
            result[i * 4 + 3] = 1.0
        }
        return result
    }
}
