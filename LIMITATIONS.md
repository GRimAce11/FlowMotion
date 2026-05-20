# FlowMotion — Known Limitations

This document is a candid catalogue of what FlowMotion cannot guarantee due to
constraints in SwiftUI, UIKit bridging, and the iOS rendering pipeline. Being
explicit about limitations is more useful than hiding them.

---

## SwiftUI rendering limitations

### 1. `matchedGeometryEffect` scope

SwiftUI's built-in `matchedGeometryEffect` only works within a shared
`Namespace` that spans a single view tree. FlowMotion's `SharedElementRegistry`
extends this with a global coordinate registry, but it still relies on the
framework injecting correct geometry — which may lag by one layout pass in
complex scroll views.

**Mitigation:** `SharedElementCoordinator` polls for destination geometry up to
80ms before falling back to a fade. Increase `frameWaitTimeout` for deeply
nested layouts.

### 2. `NavigationStack` transition hooks

SwiftUI does not expose hooks into the internal push/pop animation transaction.
FlowMotion cannot:
- Know the exact frame the navigation transition starts rendering.
- Synchronise the hero overlay frame-perfectly with the native slide transition.
- Prevent the native slide transition from briefly showing behind the hero layer.

**What we do:** We time hero animations against spring settling duration, which
approximates the navigation timing well in practice (typically within one frame).

**Impact:** On very fast push/pop sequences (< 100ms apart), geometry may
desync by 1–2 frames.

### 3. Hero animations in `LazyVStack` / `LazyHStack`

Lazy containers defer view creation until the cell enters the viewport.
If the source card is below the fold at the moment of navigation, its geometry
was never captured and the hero will fall back to a fade.

**Mitigation:** Use `List` or `ScrollView + VStack` for hero-eligible cells,
or eagerly capture geometry with `.captureGeometry(id:)` on scroll.

### 4. `@State` in modal presentation chains

In a `sheet → sheet` chain, SwiftUI re-renders the root view during each
presentation. This can invalidate geometry registrations from earlier in the
chain. `forceCleanAll()` should be called before each new sheet presentation
in deeply chained flows.

### 5. Canvas compositing overhead

`LiquidSurface` applies `blur + colorMultiply` to produce the metaball
effect. On A12 (iPhone XS) and older, a 80pt blur radius combined with
large overlapping shapes may drop below 60fps. `FrameBudgetMonitor` will
downgrade `blurRadius` automatically, but the visual fidelity degrades.

**Recommended approach:** On devices below `.high` quality, prefer the
`CinematicTransitionModifier` instead of liquid.

### 6. `geometryGroup()` and animation batching

SwiftUI 5.1+ `geometryGroup()` improves multi-element layout coordination
during animations. FlowMotion uses it on the hero overlay. However, on
iOS 17.0–17.2, there were `geometryGroup()` regressions that caused flicker
in some `NavigationStack` push/pop sequences. Minimum tested stable version
is iOS 17.4.

---

## Gesture coordination limitations

### 7. UIScrollView vs SwiftUI `ScrollView` gesture conflict

The native `UIScrollView` (used inside SwiftUI `ScrollView`) holds a pan
gesture that is not fully accessible to SwiftUI gesture modifiers. This means:

- `simultaneousGesture` may lose to the scroll view on fast vertical scrolls.
- The `GestureCoordinator` arbitration only applies to gestures declared in
  SwiftUI — it cannot preempt the UIKit pan recogniser.

**Mitigation:** For interactive-dismiss-inside-scroll patterns, use the
`.scrollDisabled(isDragging)` modifier controlled by your gesture state.

### 8. Multi-touch gesture arbitration

`GestureCoordinator` resolves single-axis gesture conflicts well. For
multi-touch scenarios (two simultaneous drags), arbitration becomes
non-deterministic. FlowMotion does not currently support multi-user
(shared screen) gesture routing.

---

## Concurrency limitations

### 9. `MotionTimeline` and `Task` cancellation

`MotionTimeline.play()` respects `Task` cancellation between steps. However,
an animation already started with `withAnimation` cannot be cancelled by
`Task` cancellation — SwiftUI animations complete independently. If you need
mid-animation interruption, use `AnimationEngine.cancel(token:)` and start a
new animation from the current animated value.

### 10. `MotionScene` actor offset granularity

`MotionScene` uses `Task.sleep` for actor offset timing. The minimum reliable
offset is ~16ms (one frame). Sub-frame offsets (< 1/60s) are effectively
treated as zero.

---

## Unsupported transition scenarios

### 11. Cross-window hero transitions

Hero animations between two different `UIWindow` instances (e.g., a floating
panel and the main window) are not supported. The `SharedElementRegistry` is
per-app but geometry is always relative to the root window.

### 12. `WKWebView` content transitions

Web content inside `WKWebView` cannot be captured for hero animations. The
web rendering is GPU-composited separately and its geometry is opaque to
SwiftUI.

### 13. `UIViewRepresentable` geometry

`UIViewRepresentable` views can report a global frame via `GeometryReader`,
but their internal rendering is not rasterisable for snapshot-based hero
effects. Use `UIView.snapshotView(afterScreenUpdates:)` via a UIKit bridge
if you need to snapshot UIKit content for a hero transition.

### 14. Tab bar animations

SwiftUI `TabView` transition animations bypass FlowMotion's overlay system.
For custom tab transitions, replace `TabView` with a manual `ZStack` +
`MotionTimeline` combination.

---

## Performance ceilings

| Scenario | Expected device minimum |
|---|---|
| Liquid transitions (full intensity) | iPhone 12 (A14) |
| Hero animations (complex geometry) | iPhone XS (A12) |
| 120Hz ProMotion aware transitions | iPhone 13 Pro (A15) |
| `LiquidSurface` with blurRadius > 20 | iPhone 14 (A15) |
| Large staggered lists (> 50 items)   | Any A12+ |

---

## What FlowMotion guarantees

1. `SpringSolver` results are **deterministic** — same input always produces same output.
2. `MotionTimeline` execution is **cancellation-safe** — cancelling the owning `Task` always stops sequencing cleanly.
3. `TransitionAuditor` will **detect** stuck transitions, even if it cannot automatically recover them.
4. `SharedElementCoordinator` will **never leave an orphaned overlay** visible — it always either completes, cancels, or falls back to a fade.
5. All public APIs respect `isReduceMotionEnabled` when `MotionConfiguration.respectsReduceMotion` is `true`.
