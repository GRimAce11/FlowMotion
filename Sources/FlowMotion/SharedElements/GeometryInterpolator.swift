import SwiftUI

// MARK: - GeometryInterpolator

/// Interpolates between two `CGRect` frames and their associated visual
/// attributes (corner radius, opacity, scale) using a given spring progress.
///
/// Used by `HeroLayer` and custom transition renderers to compute the animated
/// state at any point during a hero transition.
public struct GeometryInterpolator: Sendable {

    public let source: FrameState
    public let destination: FrameState

    public init(source: FrameState, destination: FrameState) {
        self.source = source
        self.destination = destination
    }

    // MARK: - Interpolation

    /// Interpolated frame at normalised `progress` (0 = source, 1 = destination).
    public func frame(at progress: CGFloat) -> CGRect {
        let t = easeInOut(progress)
        return CGRect(
            x:      lerp(source.frame.minX, destination.frame.minX, t),
            y:      lerp(source.frame.minY, destination.frame.minY, t),
            width:  lerp(source.frame.width, destination.frame.width, t),
            height: lerp(source.frame.height, destination.frame.height, t)
        )
    }

    /// Interpolated corner radius.
    public func cornerRadius(at progress: CGFloat) -> CGFloat {
        lerp(source.cornerRadius, destination.cornerRadius, easeOut(progress))
    }

    /// Interpolated opacity.
    public func opacity(at progress: CGFloat) -> CGFloat {
        lerp(source.opacity, destination.opacity, progress)
    }

    /// Interpolated scale factor (applied around center).
    public func scale(at progress: CGFloat) -> CGFloat {
        lerp(source.scale, destination.scale, progress)
    }

    // MARK: - Path morphing

    /// Produces an interpolated `Path` between source and destination rounded
    /// rectangles by sampling corner bezier control points.
    public func path(at progress: CGFloat) -> Path {
        let t = easeInOut(progress)
        let r = cornerRadius(at: t)
        let f = frame(at: progress)
        return Path(
            roundedRect: f,
            cornerRadius: r,
            style: .continuous
        )
    }

    // MARK: - Easing functions

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5
            ? 2 * t * t
            : -1 + (4 - 2 * t) * t
    }

    private func easeOut(_ t: CGFloat) -> CGFloat {
        1 - (1 - t) * (1 - t)
    }

    // MARK: - Math

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

// MARK: - FrameState

/// Describes a view's visual state at a transition boundary.
public struct FrameState: Sendable {
    public let frame: CGRect
    public let cornerRadius: CGFloat
    public let opacity: CGFloat
    public let scale: CGFloat

    public init(
        frame: CGRect,
        cornerRadius: CGFloat = 0,
        opacity: CGFloat = 1,
        scale: CGFloat = 1
    ) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.scale = scale
    }
}

// MARK: - CGRect extensions

public extension CGRect {
    /// Linear interpolation between two rects.
    func lerped(to other: CGRect, t: CGFloat) -> CGRect {
        let interp = GeometryInterpolator(
            source: FrameState(frame: self),
            destination: FrameState(frame: other)
        )
        return interp.frame(at: t)
    }

    /// The center point of the rect.
    var center: CGPoint { CGPoint(x: midX, y: midY) }

    /// Returns a rect scaled around its center by `factor`.
    func scaled(by factor: CGFloat) -> CGRect {
        let newWidth  = width  * factor
        let newHeight = height * factor
        return CGRect(
            x: center.x - newWidth  / 2,
            y: center.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
    }
}
