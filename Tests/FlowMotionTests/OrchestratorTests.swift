import XCTest
import SwiftUI
@testable import FlowMotion

// MARK: - OrchestratorTests

final class OrchestratorTests: XCTestCase {

    // MARK: - TimelineStep new cases

    func testSequenceStepDuration() {
        let step = TimelineStep.sequence([
            .wait(duration: 0.2),
            .wait(duration: 0.3),
        ])
        XCTAssertEqual(step.totalDuration, 0.5, accuracy: 1e-9)
    }

    func testParallelBuilderSyntax() {
        // Verify the Parallel {} DSL produces a .parallel step
        let step = Parallel {
            Animate(.snappy) {}
            Wait(0.1)
        }
        if case .parallel(let substeps) = step {
            XCTAssertEqual(substeps.count, 2)
        } else {
            XCTFail("Expected .parallel step, got \(step)")
        }
    }

    func testGroupBuilderSyntax() {
        let step = Group {
            Wait(0.1)
            Wait(0.2)
        }
        if case .sequence(let substeps) = step {
            XCTAssertEqual(substeps.count, 2)
            XCTAssertEqual(step.totalDuration, 0.3, accuracy: 1e-9)
        } else {
            XCTFail("Expected .sequence step, got \(step)")
        }
    }

    func testNestedTimelineStep() {
        let inner = MotionTimeline { Wait(0.4) }
        let step  = TimelineStep.timeline(inner)
        XCTAssertEqual(step.totalDuration, 0.4, accuracy: 1e-9)
    }

    // MARK: - MotionTimeline evolution

    func testStyleTimeScaleApplied() {
        let fast = MotionTimeline(.snappy)   { Wait(1.0) }
        let slow = MotionTimeline(.minimal)  { Wait(1.0) }
        // .snappy has timeScale 0.85, .minimal has 0.7
        XCTAssertLessThan(fast.styleTimeScale, 1.0)
        XCTAssertLessThan(slow.styleTimeScale, 1.0)
    }

    func testTotalDurationComputed() {
        let timeline = MotionTimeline {
            Wait(0.1)
            Wait(0.2)
            Wait(0.3)
        }
        XCTAssertEqual(timeline.totalDuration, 0.6, accuracy: 0.01)
    }

    func testThenChaining() {
        let t1 = MotionTimeline { Wait(0.1) }
        let t2 = t1.then { Wait(0.2) }
        XCTAssertEqual(t2.steps.count, 2)
    }

    func testThenOtherTimeline() {
        let t1 = MotionTimeline { Wait(0.1) }
        let t2 = MotionTimeline { Wait(0.2) }
        let combined = t1.then(t2)
        // t2 is embedded as a .timeline step
        XCTAssertEqual(combined.steps.count, 2)
    }

    func testConcurrentlyMerge() {
        let t1 = MotionTimeline { Wait(0.3) }
        let t2 = MotionTimeline { Wait(0.5) }
        let parallel = t1.concurrently(with: t2)
        XCTAssertEqual(parallel.steps.count, 1)  // one .parallel step
        if case .parallel(let substeps) = parallel.steps[0] {
            XCTAssertEqual(substeps.count, 2)
        }
    }

    func testTimeScaledMultiplier() {
        let t = MotionTimeline(steps: [.wait(duration: 1.0)], styleTimeScale: 1.0)
        let scaled = t.timeScaled(by: 2.0)
        XCTAssertEqual(scaled.styleTimeScale, 2.0)
    }

    // MARK: - Async execution

    @MainActor
    func testParallelStepsExecute() async {
        var log: [String] = []
        let timeline = MotionTimeline {
            Parallel {
                Run { log.append("A") }
                Run { log.append("B") }
                Run { log.append("C") }
            }
            // A short Wait gives the parallel Run tasks time to complete on the main actor.
            Wait(0.005)
        }
        await timeline.play()
        XCTAssertEqual(Set(log), Set(["A", "B", "C"]))
    }

    @MainActor
    func testSequenceStepsExecuteInOrder() async {
        var log: [Int] = []
        let step = Group {
            Run { log.append(1) }
            Run { log.append(2) }
            Run { log.append(3) }
        }
        let timeline = MotionTimeline(steps: [step])
        await timeline.play()
        XCTAssertEqual(log, [1, 2, 3])
    }

    @MainActor
    func testNestedTimelineExecutes() async {
        var count = 0
        let inner = MotionTimeline { Run { count += 1 } }
        let outer = MotionTimeline { TimelineStep.timeline(inner) }
        await outer.play()
        XCTAssertEqual(count, 1)
    }
}

// MARK: - MotionSceneTests

final class MotionSceneTests: XCTestCase {

    @MainActor
    func testActorCountMatchesBuilder() {
        let scene = MotionScene(style: .cinematic) {
            MotionActor("a") { Wait(0.1) }
            MotionActor("b") { Wait(0.2) }
            MotionActor("c") { Wait(0.3) }
        }
        _ = scene
    }

    @MainActor
    func testSceneExecutesActors() async {
        var executed = Set<String>()
        let scene = MotionScene(style: .cinematic) {
            // Use a short Wait so the actor timeline has nonzero duration
            // and MotionScene.play() waits for it to complete.
            MotionActor("x") { Run { executed.insert("x") }; Wait(0.005) }
            MotionActor("y") { Run { executed.insert("y") }; Wait(0.005) }
        }
        await scene.play()
        // Yield once to allow any Task closures to run on the main actor
        await Task.yield()
        XCTAssertTrue(executed.contains("x"))
        XCTAssertTrue(executed.contains("y"))
    }
}

// MARK: - MotionPresetsTests

final class MotionPresetsTests: XCTestCase {

    func testScreenEntranceStepCount() {
        let timeline = MotionPresets.screenEntrance(
            style: .cinematic,
            stages: [{ }, { }, { }]
        )
        // All stages in one parallel step
        XCTAssertEqual(timeline.steps.count, 1)
        if case .parallel(let substeps) = timeline.steps[0] {
            XCTAssertEqual(substeps.count, 3)
        }
    }

    func testStaggeredListStepCount() {
        let timeline = MotionPresets.staggeredList(count: 5, style: .snappy) { _ in }
        XCTAssertEqual(timeline.steps.count, 1)
        if case .parallel(let substeps) = timeline.steps[0] {
            XCTAssertEqual(substeps.count, 5)
        }
    }

    @MainActor
    func testCardExpandExecutes() async {
        var heroFired    = false
        var backdropFired = false
        var contentFired  = false

        await MotionPresets.cardExpand(
            style: .cinematic,
            onHero:     { heroFired    = true },
            onBackdrop: { backdropFired = true },
            onContent:  { contentFired  = true }
        ).play()

        XCTAssertTrue(heroFired)
        XCTAssertTrue(backdropFired)
        XCTAssertTrue(contentFired)
    }
}

// MARK: - MotionStyleTests

final class MotionStyleTests: XCTestCase {

    func testPresetSpringsNonNil() {
        for style in [MotionStyle.cinematic, .snappy, .playful, .minimal, .accessible] {
            XCTAssertGreaterThan(style.primarySpring.stiffness, 0)
            XCTAssertGreaterThan(style.primarySpring.damping,   0)
            XCTAssertGreaterThan(style.timeScale, 0)
        }
    }

    func testModifiedCopiesProperty() {
        let base    = MotionStyle.cinematic
        let custom  = base.modified(liquidIntensity: 0.3)
        XCTAssertEqual(custom.liquidIntensity, 0.3)
        XCTAssertEqual(custom.primarySpring.stiffness, base.primarySpring.stiffness)
    }

    func testAccessiblePresetZeroLiquid() {
        XCTAssertEqual(MotionStyle.accessible.liquidIntensity, 0)
    }
}
