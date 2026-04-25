import XCTest
import SwiftUI
@testable import FlowMotion

// MARK: - SpringSolverTests

final class SpringSolverTests: XCTestCase {

    // MARK: Basic correctness

    func testInitialPosition() {
        let solver = SpringSolver(configuration: .snappy, from: 0, to: 1)
        // displacement from target at t=0 = from - to = -1
        XCTAssertEqual(solver.displacement(at: 0), -1, accuracy: 1e-9)
    }

    func testConvergence() {
        let solver = SpringSolver(configuration: .snappy, from: 0, to: 100)
        let late = solver.displacement(at: 5)
        XCTAssertLessThan(abs(late), 0.01, "Displacement after 5s should be < 0.01 pt")
    }

    func testSettlingDurationFinite() {
        let solver = SpringSolver(configuration: .hero, from: -50, to: 0)
        let duration = solver.settlingDuration
        XCTAssertGreaterThan(duration, 0)
        XCTAssertLessThan(duration, 10)
    }

    func testZeroDisplacementSettles() {
        let solver = SpringSolver(configuration: .snappy, from: 0, to: 0)
        XCTAssertEqual(solver.settlingDuration, 0)
    }

    func testProgressAtStart() {
        let solver = SpringSolver(configuration: .snappy, from: 0, to: 1)
        XCTAssertEqual(solver.progress(at: 0), 0, accuracy: 1e-6)
    }

    func testProgressAtSettling() {
        let solver = SpringSolver(configuration: .snappy, from: 0, to: 1)
        let t = solver.settlingDuration
        XCTAssertEqual(solver.progress(at: t), 1, accuracy: 0.01)
    }

    // MARK: Initial velocity

    func testSlowedEntry() {
        let fast = SpringSolver(configuration: .snappy, from: 0, to: 1)
        let slow = SpringSolver(configuration: .snappy, from: 0, to: 1, initialVelocity: -5)
        XCTAssertGreaterThan(slow.settlingDuration, fast.settlingDuration)
    }

    // MARK: Velocity queries

    func testVelocityAtStart() {
        let initialV: Double = 30
        let solver = SpringSolver(configuration: .smooth, from: 0, to: 1, initialVelocity: initialV)
        XCTAssertEqual(solver.velocity(at: 0), initialV, accuracy: 1e-6)
    }

    func testVelocityAtSettling() {
        let solver = SpringSolver(configuration: .hero, from: -100, to: 0)
        let t = solver.settlingDuration
        XCTAssertLessThan(abs(solver.velocity(at: t)), 0.1)
    }

    // MARK: Presets

    func testAllPresetsValidSettlingDurations() {
        let configs: [SpringConfiguration] = [
            .snappy, .smooth, .bouncy, .hero, .heroElastic, .dismiss, .gentle, .stiff
        ]
        for config in configs {
            let solver = SpringSolver(configuration: config, from: 0, to: 1)
            let duration = solver.settlingDuration
            XCTAssertGreaterThan(duration, 0, "Preset settling duration should be positive")
            XCTAssertLessThan(duration, 20, "Preset settling duration should be < 20s")
        }
    }

    // MARK: 2D Spring

    func testSpring2DConvergence() {
        let solver = SpringSolver2D(
            configuration: .hero,
            from: CGPoint(x: 0, y: 0),
            to:   CGPoint(x: 100, y: 200)
        )
        let t   = solver.settlingDuration
        let pos = solver.position(at: t, to: CGPoint(x: 100, y: 200))
        XCTAssertEqual(Double(pos.x), 100, accuracy: 0.5)
        XCTAssertEqual(Double(pos.y), 200, accuracy: 0.5)
    }

    // MARK: Determinism

    func testDeterminism() {
        let config = SpringConfiguration.from(response: 0.35, dampingFraction: 0.78)
        let s1 = SpringSolver(configuration: config, from: 0, to: 100, initialVelocity: 50)
        let s2 = SpringSolver(configuration: config, from: 0, to: 100, initialVelocity: 50)
        XCTAssertEqual(s1.displacement(at: 0.25), s2.displacement(at: 0.25))
    }

    // MARK: Sampling

    func testSamplingCount() {
        let solver = SpringSolver(configuration: .snappy, from: 0, to: 1)
        let samples = solver.sample(count: 10, duration: 1.0)
        XCTAssertEqual(samples.count, 10)
    }
}

// MARK: - SpringConfigurationTests

final class SpringConfigurationTests: XCTestCase {

    func testResponseRoundTrip() {
        let config = SpringConfiguration.from(response: 0.4, dampingFraction: 0.85)
        XCTAssertEqual(config.dampingRatio, 0.85, accuracy: 0.001)
    }

    func testUnderdamped() {
        let config = SpringConfiguration.snappy
        XCTAssertLessThan(config.dampingRatio, 1)
        XCTAssertGreaterThan(config.dampedOmega, 0)
    }

    func testCriticallyDamped() {
        let ω = 10.0
        let config = SpringConfiguration(stiffness: ω * ω, damping: 2 * ω)
        XCTAssertEqual(config.dampingRatio, 1.0, accuracy: 0.001)
    }
}
