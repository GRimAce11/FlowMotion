import SwiftUI

// MARK: - DemoItem

struct DemoItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let gradient: [Color]
    let icon: String
    let detail: String

    static let samples: [DemoItem] = [
        DemoItem(
            id: UUID(),
            title: "Liquid Transitions",
            subtitle: "Surfaces that flow",
            gradient: [Color(red: 0.3, green: 0.6, blue: 1), Color(red: 0.5, green: 0.2, blue: 0.9)],
            icon: "drop.fill",
            detail: "Liquid transitions morph the surface between routes, creating a continuous fluid feel. Powered by Canvas and sinusoidal edge displacement."
        ),
        DemoItem(
            id: UUID(),
            title: "Hero Animations",
            subtitle: "Shared element magic",
            gradient: [Color(red: 1, green: 0.4, blue: 0.3), Color(red: 1, green: 0.6, blue: 0.2)],
            icon: "star.fill",
            detail: "Shared elements transition seamlessly between source and destination views. The geometry is captured at the moment of navigation and interpolated using spring physics."
        ),
        DemoItem(
            id: UUID(),
            title: "Spring Physics",
            subtitle: "Deterministic motion",
            gradient: [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.1, green: 0.6, blue: 0.9)],
            icon: "waveform.path",
            detail: "Every animation is backed by an analytical spring solver. This means exact velocity handoff from gestures, perfect interruptibility, and no jitter."
        ),
        DemoItem(
            id: UUID(),
            title: "Interactive Dismiss",
            subtitle: "Velocity-aware gestures",
            gradient: [Color(red: 0.9, green: 0.3, blue: 0.7), Color(red: 0.6, green: 0.2, blue: 0.9)],
            icon: "hand.draw.fill",
            detail: "Drag to dismiss with velocity awareness. A fast flick commits even at low progress. A slow drag rubber-bands and snaps back if released early."
        ),
        DemoItem(
            id: UUID(),
            title: "Motion Timeline",
            subtitle: "Choreographed sequences",
            gradient: [Color(red: 0.1, green: 0.5, blue: 0.8), Color(red: 0.3, green: 0.8, blue: 0.7)],
            icon: "timeline.selection",
            detail: "Orchestrate complex multi-element animations using the MotionTimeline DSL. Steps run sequentially, in parallel, or with staggered delays."
        ),
        DemoItem(
            id: UUID(),
            title: "Cinematic Zoom",
            subtitle: "App Store-style reveals",
            gradient: [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.3, green: 0.2, blue: 0.5)],
            icon: "play.rectangle.fill",
            detail: "The cinematic transition scales the incoming view from slightly-reduced size with a gentle depth blur — exactly the feel of opening an App Store card."
        ),
    ]
}
