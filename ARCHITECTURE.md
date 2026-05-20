# FlowMotion Architecture

> A technical walkthrough of how FlowMotion works internally.

---

## Layered architecture

```
┌─────────────────────────────────────────────────────────┐
│  Consumer API (public surface)                          │
│  .flowTransition() .flowInteractiveDismiss() etc.       │
├─────────────────────────────────────────────────────────┤
│  Orchestration (MotionTimeline, MotionScene)            │
├────────────────────────┬────────────────────────────────┤
│  Navigation            │  SharedElements                 │
│  FlowNavigationStack   │  SharedElementRegistry          │
│  TransitionContext     │  SharedElementCoordinator       │
├────────────────────────┼────────────────────────────────┤
│  Transitions           │  Gestures                       │
│  LiquidTransitionEffect│  InteractiveDismissModifier     │
│  CinematicEffect       │  DragProgressModifier           │
│                        │  GestureCoordinator             │
├────────────────────────┼────────────────────────────────┤
│  Physics               │  Rendering                      │
│  SpringSolver          │  FlowRenderer protocol          │
│  VelocityTracker       │  LiquidRenderer                 │
│  DecayFunction         │  FrameBudgetMonitor             │
├────────────────────────┴────────────────────────────────┤
│  Core                                                   │
│  AnimationEngine (token tracker)                        │
│  MotionStyle (preset personalities)                     │
│  TransitionAuditor (lifecycle debugging)                │
└─────────────────────────────────────────────────────────┘
```

---

## Core

### AnimationEngine

`AnimationEngine` is a `@MainActor @Observable` singleton that assigns every in-flight animation a unique `AnimationToken`. This enables:

- **Batch cancellation** by tag (`engine.cancel(tag: "entrance")`)
- **Velocity queries** during interruption (`engine.velocity(for: tag)`)
- **Timeline tracking** so a `MotionTimeline` can check whether it should abort between steps

All state mutations are `@MainActor` — no locks required.

### MotionStyle

`MotionStyle` is a value-type "motion personality" that coordinates springs, timing, liquid intensity, and gesture thresholds in one place. The style propagates through SwiftUI's `Environment`:

```swift
MyView().flowStyle(.cinematic)
// ↓ everywhere inside MyView:
@Environment(\.flowStyle) var style
withAnimation(style.primarySpring.swiftUIAnimation) { ... }
```

Built-in presets: `.cinematic` `.snappy` `.playful` `.minimal` `.accessible`

### TransitionAuditor

Debug-build auditor that tracks every transition lifecycle. Detects "stuck" transitions (those that exceed `stuckTransitionThreshold` without completing), emits `os_log` traces, and surfaces a diagnostic overlay via `.flowDebugOverlay()`.

In release builds all auditor paths are guarded by `#if DEBUG` and compile to nothing.

---

## Physics

### SpringSolver

The analytical closed-form solution to the damped harmonic oscillator:

```
m·x'' + c·x' + k·x = 0
```

Three regimes:
- **Underdamped** (ζ < 1): oscillates, described by `e^(-ζωt) · (A·cos(ωd·t) + B·sin(ωd·t))`
- **Critically damped** (ζ = 1): fastest non-oscillating, `e^(-ωt) · (A + Bt)`
- **Overdamped** (ζ > 1): two exponential decay modes

Because the solution is analytical:
- `displacement(at: t)` and `velocity(at: t)` are O(1) — no integration loop
- `settlingDuration` is computed via 50-iteration binary search to threshold
- Every call with the same inputs returns the same result (**deterministic**)

### VelocityTracker

An 8-sample EWMA ring buffer around `DragGesture.Value`. The raw iOS velocity (`DragGesture.Value.velocity`) can spike at the final frame; the EWMA smoothes this while remaining responsive. The smoothed velocity is what gets handed to `SpringSolver` as `initialVelocity`, ensuring the animation continues the gesture's momentum.

### DecayFunction

Exponential friction model: `position(t) = v0/λ · (1 − e^(-λt))`. Used for momentum scrolling and fling animations where you want natural deceleration rather than a spring bounce.

---

## Orchestration

### MotionTimeline

Result-builder DSL that composes `TimelineStep` values into a sequenced execution plan. Steps are:

| Step | Behaviour |
|---|---|
| `.animate` | Calls `withAnimation`, waits `duration` seconds |
| `.wait` | Blocks for `duration` seconds |
| `.run` | Fires async side effect, does not block |
| `.parallel` | Starts sub-steps simultaneously, waits for longest |
| `.sequence` | Runs sub-steps sequentially (inline nesting) |
| `.timeline` | Embeds a full `MotionTimeline` as a single step |

Execution is `@MainActor` throughout. `await timeline.play()` is cancellation-safe: if the owning `Task` is cancelled between steps, the timeline stops cleanly.

### MotionScene

Higher-level abstraction: multiple `MotionActor` instances (each wrapping a `MotionTimeline`) start with configurable offsets and run concurrently. A `MotionScene` is to a `MotionTimeline` what a film scene is to a single camera shot.

```
MotionScene
├── MotionActor("card",     offset: 0.00) → timeline
├── MotionActor("backdrop", offset: 0.00) → timeline
└── MotionActor("content",  offset: 0.12) → timeline
```

### MotionPresets

A static catalogue of proven choreography patterns. Each preset is a `MotionTimeline` factory — it produces a replayable, style-aware timeline without capturing any state of its own.

---

## SharedElements

### SharedElementRegistry

`@MainActor @Observable` singleton that stores every registered element's global `CGRect`, keyed by `AnyHashable` ID. Views push their geometry via `PreferenceKey` (`SharedElementPreference`), which the `SharedElementRegistrySink` modifier collects and writes to the registry.

### SharedElementCoordinator

Wraps the registry with production-hardening:
1. **Timeout protection** — polls for destination frame up to `frameWaitTimeout` (default 80ms). If not captured, falls back to a fade transition.
2. **Orphan cleanup** — `cancelCurrentHero()` cancels any pending transition when the source view disappears.
3. **Scene lifecycle cleanup** — `SharedElementLifecycleModifier` cleans up on `.background` scene phase.

### HeroTransitionOverlay

Full-screen `ZStack` overlay installed by `.flowMotionSetup()`. Observes `SharedElementRegistry.shared.activeHero` and renders an animated rounded rectangle flying from source → destination frame using the spring configuration from `HeroTransitionState`.

---

## Transitions

All transitions are SwiftUI `ViewModifier` + `Animatable` conformances, which means they work with standard SwiftUI `.transition()` and `withAnimation()`. The `Animatable.animatableData` properties are explicitly `nonisolated` to satisfy Swift 6 strict concurrency.

### LiquidTransitionModifier

Canvas mask approach:
1. A `Path` is constructed with a sinusoidal leading edge (controlled by `progress`).
2. The amplitude = `maxAmplitude × intensity × (1 − progress)` — at `progress=1`, the mask is a clean rectangle.
3. Applied via `.mask` — GPU-composited, no pixel readback.

`LiquidSurface` uses the CSS metaball algorithm: multiple blurred overlapping shapes merge at their boundaries when a `blur + colorMultiply` (simulating contrast boost) is applied via `drawingGroup()`.

### CinematicTransitionModifier

Scale from `baseScale` → 1.0 + opacity 0 → 1 + entry blur 6pt → 0. The iOS 18 native `.zoom()` transition is used when available (iOS only), with the cinematic modifier as the fallback.

---

## Rendering

### FlowRenderer protocol

Abstraction over the rendering backend. Conforming types implement `draw(frame:progress:context:)`. The protocol enables:
- Canvas rendering today (CPU-composited, zero allocation per frame)
- A future Metal conformance via `MTLRenderCommandEncoder`

### FrameBudgetMonitor

`CADisplayLink`-backed frame pacing monitor. Computes a 30-frame rolling average FPS and emits a `QualityTier` (`.ultra` → `.high` → `.medium` → `.low`). The tier is injected into the environment via `frameBudgetQuality`, allowing rendering code to self-adapt:

```swift
@Environment(\.frameBudgetQuality) var quality
Canvas { ... }
    .blur(radius: quality.blurRadius)  // auto-reduces under pressure
```

---

## Gestures

### GestureCoordinator

Priority-based arbitration registry. Each gesture registers with an ID and priority. When multiple gestures compete:
- The first to exceed its `activationThreshold` "wins"
- Subsequent gestures with lower priority are blocked
- Higher-priority gestures can preempt (e.g., dismiss beats scroll)

### InteractiveDismissModifier

Full lifecycle: drag → rubber-band clamping → velocity threshold check → spring snap-back or commit. Velocity is read from `VelocityTracker` (EWMA-smoothed), so a fast flick commits even if drag progress is low. `interactiveDismissProgress` is exposed via environment for child parallax effects.

---

## Known SwiftUI limitations

See [`LIMITATIONS.md`](LIMITATIONS.md) for a complete list of what FlowMotion cannot do due to SwiftUI constraints.

---

## Thread safety model

| Component | Actor |
|---|---|
| `AnimationEngine` | `@MainActor` |
| `SharedElementRegistry` | `@MainActor` |
| `SharedElementCoordinator` | `@MainActor` |
| `FrameBudgetMonitor` | `@MainActor` |
| `TransitionAuditor` | `@MainActor` |
| `GestureCoordinator` | `@unchecked Sendable` (uses internal lock) |
| `SpringSolver` | `Sendable` (pure value type, no shared state) |
| `VelocityTracker` | `@MainActor` |
| `MotionTimeline` | `@unchecked Sendable` (closures inside steps are `@MainActor`) |

---

## Public API surface rules

1. Types in `Core/` — public
2. Types in `Physics/` — public (advanced users need them for custom transitions)
3. Types in `Orchestration/` — public
4. Types in `SharedElements/` — `SharedElementRegistry` internal; `FlowMotionLink` + modifiers public
5. Helper types (PreferenceKeys, private modifiers) — internal or private
6. Debug types (`GestureTracer`, `TransitionAuditor`) — public in debug, stripped in release
