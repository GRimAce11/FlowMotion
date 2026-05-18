import XCTest
import SwiftUI
@testable import FlowMotion

// MARK: - BenchmarkTests
//
// These are reproducible micro-benchmarks using XCTestCase.measure().
// They act as CI regression guards — a 2× slowdown will be caught
// before it ships. Run with: swift test --filter BenchmarkTests
//
// NOTE: These benchmarks run on a headless process. They measure
// computation only (no rendering). Rendering benchmarks require Instruments.

final class BenchmarkTests: XCTestCase {

    // MARK: - SpringSolver benchmarks

    func testSpringSettlingDurationPerformance() {
        // Measures the cost of computing one settling duration
        let config = SpringConfiguration.hero
        measure {
            for _ in 0..<1000 {
                let solver = SpringSolver(configuration: config, from: 0, to: 100)
                _ = solver.settlingDuration
            }
        }
    }

    func testSpringDisplacementSamplingPerformance() {
        // Measures sampling 60 values from a spring (one animation frame budget)
        let config = SpringConfiguration.hero
        measure {
            let solver = SpringSolver(configuration: config, from: 0, to: 1)
            let t = solver.settlingDuration
            for i in 0..<60 {
                _ = solver.displacement(at: Double(i) / 60 * t)
            }
        }
    }

    func testSpring2DSolverPerformance() {
        let config = SpringConfiguration.snappy
        measure {
            for _ in 0..<500 {
                let solver = SpringSolver2D(
                    configuration: config,
                    from: CGPoint(x: 0, y: 0),
                    to:   CGPoint(x: 300, y: 600),
                    initialVelocity: CGVector(dx: 100, dy: 200)
                )
                _ = solver.settlingDuration
            }
        }
    }

    // MARK: - Decay function benchmarks

    func testDecayFunctionPerformance() {
        let decay = DecayFunction.scrollView
        measure {
            for _ in 0..<5000 {
                _ = decay.position(at: 0.5, initialVelocity: 800)
                _ = decay.velocity(at: 0.5, initialVelocity: 800)
            }
        }
    }

    func testDecaySettlingDurationPerformance() {
        let decay = DecayFunction.scrollView
        measure {
            for _ in 0..<1000 {
                _ = decay.settlingDuration(initialVelocity: 1000)
            }
        }
    }

    // MARK: - Geometry interpolation benchmarks

    func testGeometryInterpolatorPerformance() {
        let source = FrameState(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            cornerRadius: 16
        )
        let dest = FrameState(
            frame: CGRect(x: 200, y: 400, width: 400, height: 600),
            cornerRadius: 0
        )
        let interp = GeometryInterpolator(source: source, destination: dest)

        measure {
            for i in 0..<1000 {
                let t = CGFloat(i % 100) / 100
                _ = interp.frame(at: t)
                _ = interp.cornerRadius(at: t)
            }
        }
    }

    // MARK: - Timeline builder benchmarks

    func testTimelineBuilderConstruction() {
        // Measures the cost of building a timeline with 10 steps
        measure {
            for _ in 0..<1000 {
                _ = MotionTimeline {
                    Animate(.hero)    {}
                    Wait(0.05)
                    Parallel {
                        Animate(.snappy) {}
                        Animate(.snappy, delay: 0.04) {}
                        Animate(.snappy, delay: 0.08) {}
                    }
                    Wait(0.1)
                    Run {}
                    Group {
                        Wait(0.02)
                        Animate(.smooth) {}
                    }
                }
            }
        }
    }

    func testTimelineTotalDuration() {
        // Measures the cost of computing total duration for a complex timeline
        let timeline = MotionTimeline {
            for _ in 0..<20 {
                Animate(.hero) {}
            }
        }
        measure {
            for _ in 0..<10000 {
                _ = timeline.totalDuration
            }
        }
    }

    // MARK: - VelocityTracker benchmark

    @MainActor
    func testVelocityTrackerThroughput() {
        // Simulates a full drag gesture (120 samples at 120Hz)
        let tracker = VelocityTracker(configuration: .standard)
        measure {
            for i in 0..<120 {
                tracker.record(CGPoint(x: CGFloat(i) * 2, y: CGFloat(i)))
            }
            _ = tracker.velocity
            tracker.reset()
        }
    }

    // MARK: - AnimationEngine benchmark

    @MainActor
    func testAnimationEngineTokenThroughput() {
        let engine = AnimationEngine.shared
        measure {
            for _ in 0..<10000 {
                let token = engine.makeToken()
                engine.register(AnimationRecord(), token: token)
                engine.complete(token: token)
            }
        }
        engine.cancelAll()
    }

    // MARK: - Registry benchmarks

    @MainActor
    func testSharedElementRegistryThroughput() {
        let registry = SharedElementRegistry.shared
        let ids: [AnyHashable] = (0..<100).map { AnyHashable($0) }

        measure {
            for id in ids {
                registry.register(id: id, frame: CGRect(x: 0, y: 0, width: 100, height: 100), role: .source)
            }
            for id in ids {
                _ = registry.frame(for: id)
            }
            registry.reset()
        }
    }
}

// MARK: - Stress tests

final class StressTests: XCTestCase {

    /// Verifies the spring solver remains numerically stable across a wide
    /// range of stiffness/damping combinations.
    func testSpringNumericalStability() {
        let configs: [(k: Double, c: Double)] = [
            (50, 5), (100, 10), (400, 40), (800, 80), (2000, 200),
            (100, 1), (100, 100), (100, 5),   // near-critically, over, under-damped
        ]
        for (k, c) in configs {
            let config = SpringConfiguration(stiffness: k, damping: c)
            let solver = SpringSolver(configuration: config, from: 0, to: 1)
            let duration = solver.settlingDuration
            XCTAssertTrue(duration.isFinite, "Spring (\(k), \(c)) settling duration is not finite")
            XCTAssertTrue(duration >= 0, "Spring (\(k), \(c)) has negative settling duration")
            let finalDisplacement = solver.displacement(at: duration * 2)
            XCTAssertTrue(abs(finalDisplacement) < 1.0,
                         "Spring (\(k), \(c)) doesn't converge: \(finalDisplacement)")
        }
    }

    /// Verifies geometry interpolation is numerically stable at boundaries.
    func testGeometryInterpolationBoundaries() {
        let source = FrameState(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let dest   = FrameState(frame: CGRect(x: 10000, y: 10000, width: 10000, height: 10000))
        let interp = GeometryInterpolator(source: source, destination: dest)

        for t in [CGFloat(-0.5), 0, 0.5, 1, 1.5] {
            let f = interp.frame(at: t)
            XCTAssertTrue(f.minX.isFinite)
            XCTAssertTrue(f.minY.isFinite)
        }
    }

    /// Verifies the timeline builder handles large step counts without crash.
    func testLargeTimelineConstruction() {
        let steps: [TimelineStep] = (0..<500).map { _ in .wait(duration: 0.001) }
        let timeline = MotionTimeline(steps: steps)
        XCTAssertEqual(timeline.steps.count, 500)
        XCTAssertEqual(timeline.totalDuration, 0.5, accuracy: 0.001)
    }
}
