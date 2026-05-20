import SwiftUI

// MARK: - Platform gesture modifiers

public extension View {

    // MARK: macOS hover spring

    /// On macOS, applies a spring-driven scale and lift effect on hover.
    /// No-op on other platforms.
    func flowHoverSpring(
        scale: CGFloat = 1.04,
        shadowRadius: CGFloat = 12,
        spring: SpringConfiguration = .snappy
    ) -> some View {
        modifier(HoverSpringModifier(scale: scale, shadowRadius: shadowRadius, spring: spring))
    }

    // MARK: Scroll velocity binding

    /// Exposes the vertical scroll wheel velocity as a `Binding<CGFloat>`.
    /// Useful for macOS scroll-driven animations.
    func flowScrollVelocity(_ velocity: Binding<CGFloat>) -> some View {
        modifier(ScrollVelocityModifier(velocity: velocity))
    }

    // MARK: Focus spring (visionOS / iPadOS)

    /// Applies a spring scale when this view receives focus.
    func flowFocusSpring(
        scale: CGFloat = 1.06,
        spring: SpringConfiguration = .snappy
    ) -> some View {
        modifier(FocusSpringModifier(scale: scale, spring: spring))
    }
}

// MARK: - HoverSpringModifier

struct HoverSpringModifier: ViewModifier {
    let scale: CGFloat
    let shadowRadius: CGFloat
    let spring: SpringConfiguration

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1)
            .shadow(color: .black.opacity(isHovered ? 0.18 : 0), radius: isHovered ? shadowRadius : 0, y: isHovered ? 6 : 0)
            .animation(spring.swiftUIAnimation, value: isHovered)
            #if os(macOS) || targetEnvironment(macCatalyst)
            .onHover { isHovered = $0 }
            #endif
    }
}

// MARK: - ScrollVelocityModifier

struct ScrollVelocityModifier: ViewModifier {
    @Binding var velocity: CGFloat
    @State private var lastOffset: CGFloat = 0
    @State private var lastTime: Date = .now

    func body(content: Content) -> some View {
        #if os(macOS) || targetEnvironment(macCatalyst)
        if #available(macOS 15, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newOffset in
                let now = Date.now
                let dt = now.timeIntervalSince(lastTime)
                if dt > 0 {
                    velocity = CGFloat((newOffset - lastOffset) / dt)
                }
                lastOffset = newOffset
                lastTime = now
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - FocusSpringModifier

struct FocusSpringModifier: ViewModifier {
    let scale: CGFloat
    let spring: SpringConfiguration

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? scale : 1)
            .animation(spring.swiftUIAnimation, value: isFocused)
            .focusable()
    }
}
