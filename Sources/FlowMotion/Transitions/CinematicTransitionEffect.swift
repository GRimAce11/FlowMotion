import SwiftUI

// MARK: - CinematicTransitionModifier

/// Replicates the iOS App Store card-expansion aesthetic:
/// scale in from a slightly-reduced size, fade, with a subtle
/// gaussian blur on the background layer during transition.
///
/// Parametrised by `progress` (0 = entering/exiting, 1 = presented).
public struct CinematicTransitionModifier: ViewModifier, Animatable {

    public var progress: CGFloat
    public var baseScale: CGFloat

    nonisolated public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // MARK: - Body

    public func body(content: Content) -> some View {
        content
            .scaleEffect(currentScale, anchor: .center)
            .opacity(Double(currentOpacity))
            .blur(radius: blurRadius)
            .transformEffect(.identity)   // force layer rasterisation boundary
    }

    // MARK: - Derived values

    private var currentScale: CGFloat {
        baseScale + (1 - baseScale) * easeOut(progress)
    }

    private var currentOpacity: CGFloat {
        min(1, progress * 1.6)     // fade in faster than scale completes
    }

    private var blurRadius: CGFloat {
        max(0, (1 - progress) * 4)  // subtle entry blur, gone at progress=1
    }

    private func easeOut(_ t: CGFloat) -> CGFloat {
        1 - pow(1 - t, 3)
    }
}

// MARK: - CinematicBackdrop

/// Background blur effect that ramps up as a cinematic transition fires.
/// Place behind the presenting view for depth separation.
///
/// ```swift
/// ZStack {
///     CinematicBackdrop(progress: transitionProgress)
///     PresentedView()
/// }
/// ```
public struct CinematicBackdrop: View {

    public var progress: CGFloat

    public init(progress: CGFloat) {
        self.progress = progress
    }

    public var body: some View {
        Rectangle()
            .fill(Material.ultraThinMaterial)
            .opacity(Double(progress * 0.6))
            .blur(radius: progress * 8)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: - ZoomTransition (iOS 18 wrapper / back-compat shim)

/// Convenience wrapper that picks the best available implementation:
/// - iOS 18+ uses the native `.zoom` navigation transition.
/// - iOS 17 falls back to the cinematic ViewModifier.
public extension View {
    @ViewBuilder
    func cinematicNavigationTransition<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID
    ) -> some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self.flowTransition(.cinematic())
        }
        #else
        self.flowTransition(.cinematic())
        #endif
    }
}

// MARK: - ScaleBlurTransition

/// Combines scale + blur as a SwiftUI `AnyTransition`.
/// Exported for use with plain SwiftUI `.transition()` calls.
public extension AnyTransition {
    static func scaleBlur(scale: CGFloat = 0.9, blurRadius: CGFloat = 6) -> AnyTransition {
        .modifier(
            active: ScaleBlurModifier(scale: scale, opacity: 0, blur: blurRadius),
            identity: ScaleBlurModifier(scale: 1, opacity: 1, blur: 0)
        )
    }
}

struct ScaleBlurModifier: ViewModifier, Animatable {
    var scale: CGFloat
    var opacity: Double
    var blur: CGFloat

    nonisolated var animatableData: AnimatablePair<CGFloat, AnimatablePair<Double, CGFloat>> {
        get { AnimatablePair(scale, AnimatablePair(opacity, blur)) }
        set {
            scale   = newValue.first
            opacity = newValue.second.first
            blur    = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blur)
    }
}
