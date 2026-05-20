# FlowMotion

**Production-grade motion infrastructure for SwiftUI.**

FlowMotion is a Swift Package Manager library that delivers cinematic, physics-accurate, gesture-driven animations for iOS 17+, macOS 14+, and visionOS 1+. It goes far beyond wrapper libraries — FlowMotion is motion *infrastructure*: an analytical spring solver, a shared-element registry, a Canvas-based liquid renderer, a result-builder timeline DSL, and a gesture arbitration system, all composable and built for Swift 6.

```
"FlowMotion is to SwiftUI what Framer Motion is to React."
```

---

## Features at a glance

| Subsystem | What it does |
|---|---|
| **SpringSolver** | Analytical closed-form spring physics — velocity at any `t`, exact settling duration, deterministic |
| **Shared Elements** | Hero animations across `NavigationStack` boundaries — geometry captured, spring-interpolated, interruptible |
| **Liquid Transitions** | Canvas-based sinusoidal edge morphing with the CSS metaball algorithm |
| **Cinematic Transitions** | Scale + blur entry — iOS App Store card quality |
| **MotionTimeline** | Result-builder DSL for multi-element choreography, parallel steps, async-safe |
| **Interactive Dismiss** | Drag-to-dismiss with velocity thresholds, rubber-banding, spring settle |
| **Gesture Coordinator** | Priority-based arbitration for nested gesture hierarchies |
| **LiquidRenderer** | `FlowRenderer` protocol — Canvas today, Metal-ready tomorrow |
| **Physics presets** | Eight named spring presets calibrated to Apple's motion design language |
| **Adaptive quality** | Frame-rate monitor that downgrades render quality on slow devices |

---

## Requirements

- **iOS** 17.0+ · **macOS** 14.0+ · **visionOS** 1.0+
- **Swift** 6.0+
- **Xcode** 16.0+
- Distribution: Swift Package Manager only

---

## Installation

### Swift Package Manager

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/GRimAce11/FlowMotion", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: ["FlowMotion"])
]
```

Or in Xcode: **File → Add Package Dependencies** and paste the repository URL.

---

## Quick start

### 1. Install the overlay infrastructure

Call `.flowMotionSetup()` once on your root view. This installs the shared-element overlay and injects environment values.

```swift
@main struct App: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
            FlowNavigationStack {
                HomeView()
            }
        }
    }
}
```

`FlowNavigationStack` is a drop-in `NavigationStack` replacement that handles setup automatically.

### 2. Hero / shared-element transitions

```swift
@Namespace var ns

// Source card
FlowMotionLink(id: item.id, namespace: ns) {
    CardView(item)
        .sharedElement(id: item.id, namespace: ns)
} destination: {
    DetailView(item)
        .sharedElementDestination(id: item.id, namespace: ns)
}
```

The card expands into the detail view with a spring-physics hero animation. The animation is:
- **Interruptible** — back-gesture cancels mid-flight
- **Velocity-aware** — gesture velocity transfers to spring initial velocity
- **Geometry-accurate** — source and destination frames captured via `PreferenceKey`

### 3. Apply a built-in transition

```swift
DetailView()
    .flowTransition(.liquid(intensity: 0.8))

// or
DetailView()
    .flowTransition(.cinematic(scale: 0.92))
```

### 4. Interactive dismiss

```swift
ModalView()
    .flowInteractiveDismiss(edge: .bottom)
```

Drag down to dismiss. A fast flick commits at any progress. A slow drag rubber-bands if released early.

### 5. Motion Timeline

```swift
@State var cardScale:    CGFloat = 0.8
@State var titleOpacity: Double  = 0
@State var bodyOffset:   CGFloat = 20

// In a Task or .onAppear:
await MotionTimeline {
    Animate(.hero) {
        cardScale = 1.0
    }
    Wait(0.06)
    Animate(.smooth) {
        titleOpacity = 1
    }
    Animate(.snappy, delay: 0.04) {
        bodyOffset = 0
    }
}.play()
```

---

## Architecture

```
Sources/FlowMotion/
├── Core/
│   ├── FlowMotion.swift          — Namespace, .flowMotionSetup()
│   ├── MotionConfiguration.swift — Global config, spring presets, quality levels
│   ├── AnimationEngine.swift     — @Observable token-based animation tracker
│   └── FlowEnvironment.swift     — EnvironmentKey definitions
│
├── Physics/
│   ├── SpringConfiguration.swift — Stiffness/damping parameters, named presets
│   ├── SpringSolver.swift        — Analytical closed-form spring solver (1D + 2D)
│   ├── VelocityTracker.swift     — EWMA velocity smoothing from DragGesture
│   └── DecayFunction.swift       — Exponential decay / friction model
│
├── SharedElements/
│   ├── SharedElementRegistry.swift  — @Observable geometry store
│   ├── GeometryCapture.swift        — PreferenceKey pipeline
│   ├── HeroTransitionOverlay.swift  — Full-screen hero layer
│   ├── FlowMotionLink.swift         — Hero navigation link
│   └── GeometryInterpolator.swift   — Frame/attribute interpolation
│
├── Transitions/
│   ├── FlowTransition.swift          — FlowTransitionStyle enum, .flowTransition()
│   ├── LiquidTransitionEffect.swift  — Canvas liquid morphing, WaveShape
│   └── CinematicTransitionEffect.swift — Scale+blur, iOS 18 zoom fallback
│
├── Gestures/
│   ├── InteractiveDismissModifier.swift — .flowInteractiveDismiss()
│   ├── DragProgressModifier.swift       — .flowGestureProgress()
│   └── GestureCoordinator.swift         — Priority arbitration, .flowGestureCoordinator()
│
├── Timeline/
│   ├── TimelineStep.swift      — Step enum: animate/wait/run/parallel
│   ├── MotionTimeline.swift    — @resultBuilder DSL, async execution
│   └── SequencedAnimation.swift — SwiftUI view driver for timelines
│
├── Navigation/
│   ├── TransitionContext.swift       — Enum: idle/presenting/dismissing/interactive
│   ├── FlowNavigationStack.swift     — Drop-in NavigationStack
│   └── FlowNavigationLink.swift      — FlowLink, .flowDestination(), FeedbackStyle
│
├── Rendering/
│   ├── FlowRenderer.swift    — Protocol + RendererView + CompositeRenderer
│   └── LiquidRenderer.swift  — Metaball blob renderer + ShimmerRenderer
│
└── Utilities/
    ├── View+FlowMotion.swift        — .flowParallax() .flowShimmer() .flowPulse() .flowSpringTap()
    ├── Animation+FlowMotion.swift   — .flowHero .flowSnappy withFlowAnimation()
    └── CGRect+Interpolation.swift   — lerp, scaled(by:), readFrame()
```

---

## Spring physics in depth

FlowMotion uses an **analytical** spring solver, not numerical integration. This matters for:

### Exact settling duration

```swift
let solver = SpringSolver(configuration: .hero, from: 0, to: 200, initialVelocity: 50)
let duration = solver.settlingDuration  // precise, not a heuristic
```

### Velocity at any time t

```swift
let v = solver.velocity(at: 0.15)  // for gesture interruption handoff
```

### Spring presets

| Preset | Response | Damping | Use case |
|---|---|---|---|
| `.snappy` | 0.28s | 0.82 | Card taps, quick interactions |
| `.smooth` | 0.40s | 0.90 | Sheet presentations |
| `.bouncy` | 0.50s | 0.65 | Playful onboarding |
| `.hero` | 0.42s | 0.86 | Shared-element transitions |
| `.heroElastic` | 0.48s | 0.72 | Hero with subtle bounce |
| `.dismiss` | 0.30s | 0.88 | Interactive dismiss snap-back |
| `.gentle` | 0.70s | 0.95 | Slow cinematic reveals |
| `.stiff` | k=800 | c=60 | Haptic feedback micro-animations |

Custom springs:

```swift
let config = SpringConfiguration(stiffness: 400, damping: 38, mass: 1.0)
// or
let config = SpringConfiguration.from(response: 0.35, dampingFraction: 0.8)
```

---

## Liquid transition

The liquid effect uses a two-stage Canvas technique:

1. A sinusoidal wave is computed along the leading edge of the clip mask.
2. The wave amplitude scales with `(1 − progress)` — at `progress=1` the mask is a clean rectangle.
3. For the standalone `LiquidSurface` compositing mode, a Gaussian blur + `colorMultiply` simulates the CSS `filter: contrast(20) blur(10px)` metaball trick.

```swift
// Standalone liquid surface (morphing blobs)
LiquidSurface(blurRadius: 12, contrastBoost: 18) {
    Circle().frame(width: 60).offset(x: xOffset)
    Circle().frame(width: 60)
}

// Animated loading indicator
LiquidLoadingView(configuration: .sunset)
    .frame(height: 80)

// As a navigation transition
DetailView()
    .flowTransition(.liquid(intensity: 1.0))
```

---

## Motion Timeline DSL

```swift
MotionTimeline {
    // Sequential
    Animate(.hero, delay: 0)   { headerScale  = 1;  headerOpacity = 1  }
    Wait(0.06)
    Animate(.snappy, delay: 0) { bodyOpacity  = 1;  bodyOffset    = 0  }

    // Parallel steps
    TimelineStep.parallel([
        .spring(.bouncy, delay: 0.0) { badge1Visible = true },
        .spring(.bouncy, delay: 0.05) { badge2Visible = true },
        .spring(.bouncy, delay: 0.10) { badge3Visible = true },
    ])

    // Side effects
    Run { await haptics.impact(.medium) }
}
.play(tag: "entrance")
```

Timeline features:
- **`@resultBuilder`** DSL — conditional steps, loops, optionals all work.
- **`play()`** — async, awaitable, returns `AnimationToken` for cancellation.
- **`playDetached()`** — fire-and-forget.
- **`cancel(tag:)`** — cancel all animations with a given tag.
- **`.then()`** and `.concurrently(with:)` — timeline composition.

---

## Gesture coordination

Nested gesture hierarchies (scroll + card drag + dismiss) need arbitration:

```swift
// Install coordinator in a subtree
MyComplexView()
    .flowGestureCoordinator()

// In a custom gesture modifier:
@Environment(\.gestureCoordinator) var coordinator

DragGesture()
    .onChanged { v in
        guard coordinator.shouldActivate("myDrag", displacement: v.translation.height) else { return }
        // ... handle drag
    }
    .onEnded { _ in
        coordinator.ended("myDrag")
    }
```

---

## Configuration

Override the global configuration before rendering your root view:

```swift
FlowMotion.configuration = MotionConfiguration(
    heroSpring: .heroElastic,
    timeScale: 1.2,                  // slow everything down 20%
    renderQuality: .ultra,            // max quality for ProMotion
    respectsReduceMotion: true
)
```

Or pass it per-view:

```swift
MyView()
    .flowTransition(.liquid(), configuration: .highFidelity)
```

---

## Performance notes

### What's fast

- `SpringSolver` — pure value math, zero allocations after construction.
- `LiquidTransitionModifier` — clips via a canvas mask; no pixel readback.
- `SharedElementRegistry` — `@Observable` with granular dependency tracking.
- `VelocityTracker` — 8-sample ring buffer, EWMA, no heap allocation per frame.

### What to watch

- `LiquidSurface` with high `blurRadius` causes a multi-pass GPU blit. Use `drawingGroup()` to confine it to a single Metal layer (already applied in `LiquidLoadingView`).
- `HeroTransitionOverlay` uses `GeometryReader` — avoid nesting inside `LazyVStack` where possible.
- Timelines with many concurrent `Task` continuations can pile up. Use `play(tag:)` + `AnimationEngine.cancel(tag:)` to avoid orphaned tasks.

### Reduce motion

All transitions check `UIAccessibility.isReduceMotionEnabled` when `MotionConfiguration.respectsReduceMotion` is `true` (default). They automatically substitute `.opacity` for every motion-heavy effect.

---

## Roadmap

### Phase 1 — Current
- Shared element hero transitions
- Liquid, cinematic, slide, reveal transitions
- Interactive dismiss with velocity handoff
- Spring physics analytical solver
- Motion Timeline DSL

### Phase 2 — Next
- `MotionTimeline` keyframe mode (discrete + continuous mixing)
- Advanced spring presets with real device calibration data
- `FlowScrollView` — scroll position → spring-driven content reactions
- Transition composition (`a.combined(with: b)`)
- macOS + visionOS gesture support

### Phase 3 — Future
- Metal-backed `MetalRenderer` conformance
- Custom GLSL/Metal shaders via `LayerEffect` (iOS 17+)
- Shader-based liquid morphing (true per-pixel metaball)
- Cinematic scene choreography (multiple view trees)

### Phase 4 — Vision
- visionOS spatial transitions (depth, parallax, immersive anchoring)
- RealityKit bridge for `ModelEntity` hero animations
- Haptic choreography tied to animation progress

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgements

FlowMotion draws architectural inspiration from:
- **Framer Motion** (React) — result-builder choreography philosophy
- **UIKit's UIViewPropertyAnimator** — interruptible, velocity-preserving design
- **Apple's Human Interface Guidelines** — spring physics feel and timing calibration
- **Pop (Facebook)** — analytical spring solver approach
