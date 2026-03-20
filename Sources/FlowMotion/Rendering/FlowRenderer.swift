import SwiftUI

// MARK: - FlowRenderer protocol

/// Abstraction over the rendering backend used for custom effects.
///
/// Conforming types implement `draw(in:context:)` to render frame data
/// to a `GraphicsContext`. The pipeline supports Canvas-based rendering
/// today, with a Metal-backed renderer as a future phase.
public protocol FlowRenderer: Sendable {
    /// Renders the effect into `context` using the provided `frame`.
    @MainActor
    func draw(frame: CGRect, progress: CGFloat, context: inout GraphicsContext)

    /// The renderer's preferred pixel ratio for rasterisation (default: screen scale).
    var preferredScale: CGFloat { get }
}

public extension FlowRenderer {
    var preferredScale: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.scale
        #else
        2.0
        #endif
    }
}

// MARK: - RendererView

/// SwiftUI view that hosts a `FlowRenderer` inside a `Canvas`.
///
/// Useful for standalone rendering of custom effects — e.g., liquid loading,
/// morphing blob, or shimmer overlays.
///
/// ```swift
/// RendererView(renderer: LiquidRenderer(color: .blue), progress: $progress)
///     .frame(height: 240)
/// ```
public struct RendererView<R: FlowRenderer>: View {

    public let renderer: R
    @Binding public var progress: CGFloat

    public init(renderer: R, progress: Binding<CGFloat>) {
        self.renderer  = renderer
        self._progress = progress
    }

    public var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            var mutableCtx = context
            renderer.draw(frame: CGRect(origin: .zero, size: size), progress: progress, context: &mutableCtx)
        }
    }
}

// MARK: - CompositeRenderer

/// Chains multiple renderers, each drawing on top of the previous.
public struct CompositeRenderer: FlowRenderer {

    public let renderers: [any FlowRenderer]

    public init(_ renderers: any FlowRenderer...) {
        self.renderers = renderers
    }

    @MainActor
    public func draw(frame: CGRect, progress: CGFloat, context: inout GraphicsContext) {
        for renderer in renderers {
            renderer.draw(frame: frame, progress: progress, context: &context)
        }
    }
}

// MARK: - AdaptiveQualityController

/// Monitors frame timing and downgrades render quality when the app
/// drops below a target frame rate.
@MainActor
@Observable
public final class AdaptiveQualityController {

    public static let shared = AdaptiveQualityController()

    private(set) var currentQuality: RenderQuality = .high

    private var frameTimings: [CFAbsoluteTime] = []
    private let targetFPS: Double = 55    // allow slight variation before downgrading
    private let samplingWindow: Int = 30  // frames

    private init() {}

    /// Call from a `TimelineView` or `CADisplayLink` on each frame.
    public func recordFrame() {
        let now = CFAbsoluteTimeGetCurrent()
        frameTimings.append(now)
        if frameTimings.count > samplingWindow {
            frameTimings.removeFirst()
        }
        updateQuality()
    }

    private func updateQuality() {
        guard frameTimings.count >= 10 else { return }
        let intervals = zip(frameTimings, frameTimings.dropFirst()).map { $1 - $0 }
        let averageFPS = 1.0 / (intervals.reduce(0, +) / Double(intervals.count))

        let newQuality: RenderQuality
        switch averageFPS {
        case 100...:  newQuality = .ultra
        case 55...:   newQuality = .high
        case 40...:   newQuality = .medium
        default:      newQuality = .low
        }

        if newQuality != currentQuality {
            currentQuality = newQuality
        }
    }
}
