# Contributing to FlowMotion

Thank you for considering a contribution. FlowMotion is a production-grade
motion infrastructure library — contributions must meet a high quality bar.

---

## Philosophy

FlowMotion values:

1. **Determinism** — same inputs must always produce same outputs. No randomness, no time-dependent logic outside of explicit timing APIs.
2. **Robustness over features** — a partial transition that never gets stuck is better than a complete transition that occasionally deadlocks.
3. **Swifty APIs** — modifiers, result builders, property wrappers. Avoid raw closures as primary API surface.
4. **Honest limitations** — if something doesn't work in edge cases, document it in `LIMITATIONS.md` instead of hiding it.

---

## Development setup

```bash
# Clone
git clone https://github.com/GRimAce11/FlowMotion
cd FlowMotion

# Build
swift build

# Test
swift test

# Benchmarks only
swift test --filter BenchmarkTests

# Stress tests only  
swift test --filter StressTests
```

Xcode: open `Package.swift` directly. The `Examples/` folder requires building
as a standalone Xcode project (it is not a SPM target).

---

## Contribution types

### Bug reports

Open an issue with:
- FlowMotion version
- iOS/macOS version
- Minimal reproducible case (preferably a `#Preview` or test)
- Whether the issue is deterministic or intermittent

### Performance regressions

Run `swift test --filter BenchmarkTests` on `main` and on your branch.
Paste both outputs in the PR. A regression > 15% on any benchmark requires
explanation.

### New features

Before implementing, open an issue describing:
- What problem it solves (with concrete user scenarios)
- What the API looks like (`let` snippet, not a spec document)
- Which existing subsystem it lives in, or what new subsystem it creates

Features that pass the bar:
- Strengthen robustness or reliability
- Improve orchestration composability
- Add missing physics accuracy
- Support additional accessibility scenarios

Features that don't:
- New visual transition styles for their own sake
- Abstraction layers over existing public APIs
- Plugin/extension registration systems
- Anything that requires dynamic Objective-C dispatch

---

## Code standards

### Swift 6 strict concurrency

All new code must compile with `-strict-concurrency=complete`. Run:

```bash
swift build -Xswiftc -strict-concurrency=complete
```

Key rules:
- `@MainActor` on all UI-touching classes and methods
- `Sendable` on anything passed across actor boundaries
- `@unchecked Sendable` only for types containing `AnyHashable` or closures, with a comment explaining why
- `nonisolated var animatableData` on any `ViewModifier + Animatable` conformance

### Testing requirements

- **Every new public API** must have at least one XCTest case
- **Every bug fix** must have a regression test that would have caught the bug
- Benchmark tests are optional for non-performance-critical paths

### Documentation requirements

- Public types: full documentation comment with at least one code example
- Internal types: one-line purpose summary
- Limitations: if a public API has known edge cases, add them to `LIMITATIONS.md`

---

## Pull request checklist

- [ ] `swift build` succeeds with zero warnings
- [ ] `swift test` passes all 44+ existing tests
- [ ] New tests added for new functionality
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] If limitations exist, `LIMITATIONS.md` updated
- [ ] No changes to `Package.swift` platform requirements without discussion

---

## Architectural decisions

Before making changes to core subsystems, read `ARCHITECTURE.md`. Changes to:

- `SpringSolver` — require a correctness proof or citation to an authoritative reference
- `AnimationEngine` — require concurrency safety analysis
- `SharedElementRegistry` — require testing under rapid push/pop sequences
- `MotionTimeline` executor — require `StressTests` coverage

---

## Licence

By contributing you agree that your contribution is MIT-licensed, consistent
with the project licence.
