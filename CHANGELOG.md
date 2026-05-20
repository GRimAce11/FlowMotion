# Changelog

All notable changes to FlowMotion are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
FlowMotion uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Metal-backed `MetalRenderer` conformance
- `MotionTimeline` keyframe mode
- `FlowScrollView` with spring-driven content reactions
- visionOS spatial transitions

---

## [0.1.0] — 2026-05-20

### Added

**Physics**
- `SpringSolver` — closed-form analytical spring ODE solver (underdamped, critically-damped, overdamped)
- `SpringSolver2D` — independent x/y spring simulation for 2D motion
- `SpringConfiguration` — stiffness/damping/mass parameters with 8 named presets
- `VelocityTracker` — EWMA ring-buffer gesture velocity smoothing
- `DecayFunction` — exponential friction model for momentum/fling animations

**Orchestration**
- `MotionTimeline` — `@resultBuilder` DSL with sequential, `Parallel {}`, `Group {}`, and nested timeline steps
- `MotionScene` — multi-actor scene choreography with per-actor start offsets
- `MotionPresets` — catalogue of reusable choreography patterns (screenEntrance, cardExpand, staggeredList, etc.)
- `TimelineStep.parallel` — simultaneous step execution
- `TimelineStep.sequence` — inline nested sequencing
- `TimelineStep.timeline` — embed a full `MotionTimeline` as a step

**Motion Styles**
- `MotionStyle` — value-type motion personality coordinating springs, timing, and rendering intensity
- Built-in presets: `.cinematic` `.snappy` `.playful` `.minimal` `.accessible`
- `.flowStyle(_:)` view modifier + `Environment(\.flowStyle)` propagation

**Shared Elements**
- `SharedElementRegistry` — `@Observable` global geometry registry
- `SharedElementCoordinator` — timeout-protected hero transition orchestration with fallback
- `FlowMotionLink` — hero navigation link with spring-interpolated geometry
- `HeroTransitionOverlay` — full-screen overlay for hero animations
- `GeometryInterpolator` — frame and attribute lerp with custom easing

**Transitions**
- `FlowTransitionStyle` enum: `.liquid`, `.cinematic`, `.slide`, `.fade`, `.reveal`, `.custom`
- `LiquidTransitionModifier` — sinusoidal Canvas mask morphing
- `WaveShape` — animatable shape with liquid-edge displacement
- `LiquidSurface` — metaball compositing view
- `CinematicTransitionModifier` — scale + blur entry
- iOS 18 native zoom transition fallback via `.cinematicNavigationTransition`

**Gestures**
- `InteractiveDismissModifier` — velocity-aware drag-to-dismiss with rubber banding
- `DragProgressModifier` — binding a drag gesture to a normalised progress value
- `GestureCoordinator` — priority-based gesture arbitration

**Rendering**
- `FlowRenderer` protocol — rendering backend abstraction
- `LiquidRenderer` — metaball blob renderer
- `ShimmerRenderer` — sweep-highlight renderer
- `RendererView` — Canvas-hosted renderer view
- `FrameBudgetMonitor` — CADisplayLink-backed frame pacing + `QualityTier` adaptive signals
- `.flowFrameBudget()` + `Environment(\.frameBudgetQuality)` 

**Navigation**
- `FlowNavigationStack` — drop-in NavigationStack with overlay + environment setup
- `FlowLink` — NavigationLink with FlowTransitionStyle + haptic feedback
- `.flowDestination(for:transition:destination:)` — typed navigation destination with transition
- `.flowSheet(isPresented:transition:dismissEdge:content:)` — sheet with FlowMotion transitions
- `TransitionContext` — `idle / presenting / dismissing / interactive` enum

**Core**
- `AnimationEngine` — `@Observable` token-based animation tracker
- `MotionConfiguration` — global configuration (springs, quality, reduce-motion)
- `TransitionAuditor` — lifecycle auditing, stuck-state detection, debug overlay
- `FlowMotion.version` — semantic version constant

**Utilities**
- `.flowTransition(_:)` — apply named transition to any view
- `.flowInteractiveDismiss(edge:spring:)` — interactive dismiss
- `.flowGestureProgress(_:distance:axis:)` — gesture-linked progress
- `.flowStyle(_:)` — motion personality injection
- `.flowMotionSetup()` — root overlay installer
- `.flowSpringTap(scale:spring:)` — tactile spring tap response
- `.flowParallax(depth:)` — hover parallax
- `.flowShimmer(active:)` — skeleton shimmer
- `.flowDebugOverlay(enabled:)` — transition state diagnostic overlay
- `.flowFPSOverlay(enabled:)` — FPS + quality indicator
- `.flowGestureTrace(enabled:)` — gesture event log overlay
- Animation extensions: `.flowHero` `.flowSnappy` `.flowBouncy` etc.
- `withFlowAnimation(_:tag:body:)` — tracked animation helper
- `CGRect.lerped(to:t:)` + `CGRect.scaled(by:)` geometry helpers

**Testing**
- 44+ XCTest cases covering SpringSolver, GeometryInterpolator, DecayFunction, Timeline DSL
- `BenchmarkTests` — micro-benchmarks for spring solver, timeline builder, registry throughput
- `StressTests` — numerical stability, large timeline construction, geometry boundary tests

**Documentation**
- `README.md` — full API reference and quick-start guide
- `ARCHITECTURE.md` — internal system design walkthrough
- `LIMITATIONS.md` — candid SwiftUI constraint catalogue
- `CHANGELOG.md` — this file
- `CONTRIBUTING.md` — contribution guidelines

**Example App** (`Examples/FlowMotionDemo/`)
- `HomeScreen` — version chip, capability chips, full navigation
- `CardDetailScreen` — live spring and liquid demos
- `OnboardingScreen` — cinematic multi-page onboarding with `MotionTimeline`
- `TransitionShowcaseScreen` — side-by-side transition comparison
- `TimelineOrchestratorScreen` — interactive orchestration playground
- `GesturePlaygroundScreen` — spring drag, velocity handoff, drag progress demos

### Platform support
- iOS 17.0+
- macOS 14.0+
- visionOS 1.0+
- Swift 6.0+
- Swift Package Manager only

---

[Unreleased]: https://github.com/yourusername/FlowMotion/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/FlowMotion/releases/tag/v0.1.0
