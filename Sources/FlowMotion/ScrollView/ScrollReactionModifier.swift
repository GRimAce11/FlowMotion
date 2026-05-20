import SwiftUI

// MARK: - FlowScrollReaction

public enum FlowScrollReaction: Sendable {
    /// Offset the view at a fraction of the scroll speed — creates depth.
    case parallax(depth: CGFloat)
    /// Fade the view out as it approaches a scroll edge.
    case fadeOnEdge(threshold: CGFloat)
    /// Spring-scale the view in when it first enters the viewport.
    case scaleOnAppear(from: CGFloat, spring: SpringConfiguration)
}

// MARK: - View extension

public extension View {
    /// React to the enclosing `FlowScrollView`'s scroll position.
    func flowScrollEffect(_ reaction: FlowScrollReaction) -> some View {
        modifier(ScrollReactionModifier(reaction: reaction))
    }
}

// MARK: - ScrollReactionModifier

struct ScrollReactionModifier: ViewModifier {
    let reaction: FlowScrollReaction
    @Environment(\.flowScrollProxy) private var proxy

    func body(content: Content) -> some View {
        switch reaction {
        case .parallax(let depth):
            content.modifier(ParallaxReactionModifier(depth: depth, proxy: proxy))
        case .fadeOnEdge(let threshold):
            content.modifier(FadeEdgeModifier(threshold: threshold, proxy: proxy))
        case .scaleOnAppear(let fromScale, let spring):
            content.modifier(ScaleOnAppearModifier(fromScale: fromScale, spring: spring))
        }
    }
}

// MARK: - ParallaxReactionModifier

private struct ParallaxReactionModifier: ViewModifier {
    let depth: CGFloat
    let proxy: FlowScrollProxy?

    func body(content: Content) -> some View {
        let offsetY = (proxy?.offset.y ?? 0) * (depth / 100)
        content.offset(y: offsetY)
    }
}

// MARK: - FadeEdgeModifier

private struct FadeEdgeModifier: ViewModifier {
    let threshold: CGFloat
    let proxy: FlowScrollProxy?

    func body(content: Content) -> some View {
        let progress = proxy?.verticalProgress ?? 0
        let opacity = progress < threshold
            ? Double(progress / threshold)
            : progress > (1 - threshold)
                ? Double((1 - progress) / threshold)
                : 1.0
        content.opacity(max(0, min(1, opacity)))
    }
}

// MARK: - ScaleOnAppearModifier

private struct ScaleOnAppearModifier: ViewModifier {
    let fromScale: CGFloat
    let spring: SpringConfiguration
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : fromScale)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                guard !appeared else { return }
                withAnimation(spring.swiftUIAnimation) { appeared = true }
            }
    }
}
