import CoreFoundation
import SwiftUI

// MARK: - CGRect interpolation

public extension CGRect {

    /// Produces a CGRect interpolated between `self` (t=0) and `other` (t=1).
    func interpolated(to other: CGRect, t: CGFloat) -> CGRect {
        CGRect(
            x:      self.minX    + (other.minX    - self.minX)    * t,
            y:      self.minY    + (other.minY    - self.minY)    * t,
            width:  self.width   + (other.width   - self.width)   * t,
            height: self.height  + (other.height  - self.height)  * t
        )
    }

    /// Returns whether two rects are approximately equal within `tolerance`.
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX   - other.minX)   < tolerance &&
        abs(minY   - other.minY)   < tolerance &&
        abs(width  - other.width)  < tolerance &&
        abs(height - other.height) < tolerance
    }
}

// MARK: - CGPoint helpers

public extension CGPoint {
    /// Linearly interpolates between `self` and `other`.
    func lerped(to other: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t
        )
    }

    func distance(to other: CGPoint) -> CGFloat {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
}

// MARK: - CGVector helpers

public extension CGVector {
    var magnitude: CGFloat { sqrt(dx * dx + dy * dy) }

    var normalised: CGVector {
        let m = magnitude
        guard m > 0 else { return .zero }
        return CGVector(dx: dx / m, dy: dy / m)
    }

    func dot(_ other: CGVector) -> CGFloat {
        dx * other.dx + dy * other.dy
    }

    func scaled(by factor: CGFloat) -> CGVector {
        CGVector(dx: dx * factor, dy: dy * factor)
    }
}

// MARK: - CGSize helpers

public extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    var aspectRatio: CGFloat {
        guard height != 0 else { return 1 }
        return width / height
    }
}

// MARK: - UnitPoint helpers

public extension UnitPoint {
    /// Converts a `UnitPoint` to a `CGPoint` within `rect`.
    func point(in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width  * x,
            y: rect.minY + rect.height * y
        )
    }
}

// MARK: - SwiftUI coordinate space conversion

public extension View {
    /// Reads this view's frame in the given `coordinateSpace`.
    func readFrame(
        in coordinateSpace: CoordinateSpace = .global,
        onChange: @escaping @MainActor (CGRect) -> Void
    ) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: SingleRectKey.self,
                        value: proxy.frame(in: coordinateSpace)
                    )
            }
        )
        .onPreferenceChange(SingleRectKey.self) { frame in
            Task { @MainActor in onChange(frame) }
        }
    }
}

private struct SingleRectKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
