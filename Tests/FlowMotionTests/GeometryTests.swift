import XCTest
import SwiftUI
@testable import FlowMotion

// MARK: - GeometryInterpolatorTests

final class GeometryInterpolatorTests: XCTestCase {

    var source: FrameState {
        FrameState(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            cornerRadius: 16,
            opacity: 1,
            scale: 1
        )
    }

    var destination: FrameState {
        FrameState(
            frame: CGRect(x: 200, y: 400, width: 400, height: 600),
            cornerRadius: 0,
            opacity: 0.9,
            scale: 1
        )
    }

    var interpolator: GeometryInterpolator {
        GeometryInterpolator(source: source, destination: destination)
    }

    // MARK: Frame

    func testFrameAtStart() {
        let f = interpolator.frame(at: 0)
        XCTAssertTrue(f.isApproximatelyEqual(to: source.frame))
    }

    func testFrameAtEnd() {
        let f = interpolator.frame(at: 1)
        XCTAssertTrue(f.isApproximatelyEqual(to: destination.frame))
    }

    func testFrameAtMidpoint() {
        let f = interpolator.frame(at: 0.5)
        XCTAssertGreaterThan(f.minX, source.frame.minX)
        XCTAssertLessThan(f.minX, destination.frame.minX)
    }

    // MARK: Corner radius

    func testCornerRadiusAtStart() {
        XCTAssertEqual(Double(interpolator.cornerRadius(at: 0)), Double(source.cornerRadius), accuracy: 0.01)
    }

    func testCornerRadiusAtEnd() {
        XCTAssertEqual(Double(interpolator.cornerRadius(at: 1)), Double(destination.cornerRadius), accuracy: 0.01)
    }

    func testCornerRadiusDecreases() {
        var prev = interpolator.cornerRadius(at: 0)
        for i in 1...10 {
            let t = CGFloat(i) / 10
            let next = interpolator.cornerRadius(at: t)
            XCTAssertLessThanOrEqual(next, prev + 0.01, "Corner radius should decrease or stay flat")
            prev = next
        }
    }

    // MARK: Opacity

    func testOpacityAtStart() {
        XCTAssertEqual(Double(interpolator.opacity(at: 0)), Double(source.opacity), accuracy: 0.001)
    }

    func testOpacityAtEnd() {
        XCTAssertEqual(Double(interpolator.opacity(at: 1)), Double(destination.opacity), accuracy: 0.001)
    }
}

// MARK: - CGRectInterpolationTests

final class CGRectInterpolationTests: XCTestCase {

    func testLerpAtZero() {
        let a = CGRect(x: 10, y: 20, width: 100, height: 200)
        let b = CGRect(x: 50, y: 80, width: 300, height: 400)
        XCTAssertTrue(a.lerped(to: b, t: 0).isApproximatelyEqual(to: a))
    }

    func testLerpAtOne() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 500, y: 500, width: 200, height: 200)
        XCTAssertTrue(a.lerped(to: b, t: 1).isApproximatelyEqual(to: b))
    }

    func testLerpAtMidpoint() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 100, y: 100, width: 100, height: 100)
        let result = a.lerped(to: b, t: 0.5)
        XCTAssertEqual(Double(result.minX), 50, accuracy: 0.01)
        XCTAssertEqual(Double(result.minY), 50, accuracy: 0.01)
    }

    func testScaledPreservesCenter() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 60)
        let scaled = rect.scaled(by: 2)
        XCTAssertEqual(Double(scaled.center.x), Double(rect.center.x), accuracy: 0.01)
        XCTAssertEqual(Double(scaled.center.y), Double(rect.center.y), accuracy: 0.01)
    }
}
