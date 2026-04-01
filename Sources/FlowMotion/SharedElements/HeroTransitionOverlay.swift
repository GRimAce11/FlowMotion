import SwiftUI

// MARK: - HeroTransitionOverlay

/// Full-screen overlay view that renders the animated hero element during
/// a shared-element transition.
///
/// Install this once on the root view via `.flowMotionSetup()`.
/// It observes `SharedElementRegistry.shared.activeHero` and renders
/// a hero layer when a transition is in flight.
@MainActor
struct HeroTransitionOverlay: View {

    @State private var engine = AnimationEngine.shared
    private let registry = SharedElementRegistry.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // Rendered only while a hero transition is active
                if let hero = registry.activeHero {
                    HeroLayer(state: hero, containerSize: proxy.size)
                        .transition(.identity)   // we drive the animation ourselves
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(registry.activeHero != nil)
        .ignoresSafeArea()
    }
}

// MARK: - HeroLayer

/// Renders and animates the flying hero rectangle from source → destination.
@MainActor
private struct HeroLayer: View {

    let state: HeroTransitionState
    let containerSize: CGSize

    @State private var animatedFrame: CGRect
    @State private var animatedOpacity: Double = 1
    @State private var didStart = false

    init(state: HeroTransitionState, containerSize: CGSize) {
        self.state = state
        self.containerSize = containerSize
        _animatedFrame = State(initialValue: state.sourceFrame)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Material.ultraThinMaterial)
            .frame(width: animatedFrame.width, height: animatedFrame.height)
            .offset(x: animatedFrame.minX, y: animatedFrame.minY)
            .opacity(animatedOpacity)
            .onAppear {
                guard !didStart else { return }
                didStart = true
                performHeroAnimation()
            }
    }

    private var cornerRadius: CGFloat {
        interpolate(
            from: 16,   // typical card corner radius
            to: 0,
            progress: normalizedProgress
        )
    }

    private var normalizedProgress: CGFloat {
        guard state.sourceFrame != state.destinationFrame else { return 1 }
        let dx = animatedFrame.midX - state.sourceFrame.midX
        let totalDx = state.destinationFrame.midX - state.sourceFrame.midX
        guard totalDx != 0 else { return 1 }
        return min(max(dx / totalDx, 0), 1)
    }

    private func performHeroAnimation() {
        let config   = state.configuration
        let destFrame = state.destinationFrame
        let animation = config.swiftUIAnimation

        withAnimation(animation) {
            animatedFrame = destFrame
        }

        // Schedule completion after spring settles
        let solver = SpringSolver(
            configuration: config,
            from: 0,
            to: 1,
            initialVelocity: 0
        )
        let duration = solver.settlingDuration

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                SharedElementRegistry.shared.completeHero()
            }
        }
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}
