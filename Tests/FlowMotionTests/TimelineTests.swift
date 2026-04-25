import XCTest
import SwiftUI
@testable import FlowMotion

// MARK: - TimelineTests

final class TimelineTests: XCTestCase {

    // MARK: Builder DSL

    func testSingleStep() {
        let timeline = MotionTimeline {
            Animate(.snappy) {}
        }
        XCTAssertEqual(timeline.steps.count, 1)
    }

    func testMultipleSteps() {
        let timeline = MotionTimeline {
            Animate(.hero) {}
            Wait(0.1)
            Animate(.snappy) {}
        }
        XCTAssertEqual(timeline.steps.count, 3)
    }

    func testConditionalStep() {
        let condition = true
        let timeline = MotionTimeline {
            if condition {
                Animate(.snappy) {}
            }
            Wait(0.05)
        }
        XCTAssertEqual(timeline.steps.count, 2)
    }

    func testChaining() {
        let t1 = MotionTimeline { Animate(.snappy) {} }
        let t2 = t1.then { Wait(0.1); Animate(.hero) {} }
        XCTAssertEqual(t2.steps.count, 3)
    }

    // MARK: TimelineStep duration

    func testWaitDuration() {
        let step = TimelineStep.wait(duration: 0.5)
        XCTAssertEqual(step.totalDuration, 0.5, accuracy: 1e-9)
    }

    func testAnimateDuration() {
        let step = TimelineStep.animate(
            animation: .flowSnappy,
            duration: 0.4,
            delay: 0.1,
            body: {}
        )
        XCTAssertEqual(step.totalDuration, 0.5, accuracy: 1e-9)
    }

    func testRunDuration() {
        let step = TimelineStep.run { }
        XCTAssertEqual(step.totalDuration, 0)
    }

    func testParallelDuration() {
        let step = TimelineStep.parallel([
            .wait(duration: 0.3),
            .wait(duration: 0.7),
            .wait(duration: 0.1),
        ])
        XCTAssertEqual(step.totalDuration, 0.7, accuracy: 1e-9)
    }

    // MARK: Execution

    @MainActor
    func testRunExecution() async {
        var executed = false
        let timeline = MotionTimeline {
            Run { executed = true }
        }
        await timeline.play()
        XCTAssertTrue(executed)
    }

    @MainActor
    func testWaitOrdering() async {
        var log: [Int] = []
        let timeline = MotionTimeline {
            Run { log.append(1) }
            Wait(0.01)
            Run { log.append(2) }
            Wait(0.01)
            Run { log.append(3) }
        }
        await timeline.play()
        XCTAssertEqual(log, [1, 2, 3])
    }

    // MARK: Stagger step count

    func testStaggerStepCount() {
        let items = [1, 2, 3, 4, 5]
        let steps: [TimelineStep] = items.indices.map { i in
            .spring(.snappy, delay: Double(i) * 0.06, body: { _ = i })
        }
        XCTAssertEqual(steps.count, 5)
    }
}

// MARK: - DecayFunctionTests

final class DecayFunctionTests: XCTestCase {

    func testPositionAtZero() {
        let decay = DecayFunction.scrollView
        XCTAssertEqual(decay.position(at: 0, initialVelocity: 500), 0, accuracy: 0.001)
    }

    func testVelocityDecreases() {
        let decay = DecayFunction.scrollView
        let v0: Double = 1000
        let v1 = decay.velocity(at: 0.1, initialVelocity: v0)
        let v2 = decay.velocity(at: 0.5, initialVelocity: v0)
        XCTAssertLessThan(v1, v0)
        XCTAssertLessThan(v2, v1)
    }

    func testFiniteSettling() {
        let decay = DecayFunction.fast
        let duration = decay.settlingDuration(initialVelocity: 500)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertLessThan(duration, 30)
    }

    func testZeroVelocitySettling() {
        let decay = DecayFunction.scrollView
        XCTAssertEqual(decay.settlingDuration(initialVelocity: 0), 0)
    }

    func testBoundedDisplacement() {
        let decay = DecayFunction.scrollView
        let disp = decay.totalDisplacement(initialVelocity: 1000)
        XCTAssertGreaterThan(disp, 0)
        XCTAssertLessThan(disp, 100_000)
    }
}
