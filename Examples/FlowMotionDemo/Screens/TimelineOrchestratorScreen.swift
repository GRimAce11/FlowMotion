import SwiftUI
import FlowMotion

// MARK: - TimelineOrchestratorScreen

/// Interactive demonstration of MotionTimeline orchestration.
/// Shows sequential, parallel, and nested timeline execution live.
struct TimelineOrchestratorScreen: View {

    @State private var selectedExample: OrchestratorExample = .screenEntrance
    @Environment(\.flowStyle) private var style

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                examplePicker
                demoCanvas
                codeSnippet
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Orchestrator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Motion Timeline")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Text("A result-builder DSL for coordinating multi-element animations with deterministic sequencing and parallel groups.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Example picker

    private var examplePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(OrchestratorExample.allCases, id: \.self) { example in
                    Button {
                        withAnimation(.flowSnappy) { selectedExample = example }
                    } label: {
                        Text(example.label)
                            .font(.callout.weight(selectedExample == example ? .semibold : .regular))
                            .foregroundStyle(selectedExample == example ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedExample == example ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .flowSpringTap()
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Demo canvas

    @ViewBuilder
    private var demoCanvas: some View {
        switch selectedExample {
        case .screenEntrance: ScreenEntranceDemo(style: style)
        case .parallelGroup:  ParallelGroupDemo(style: style)
        case .cardScene:      CardSceneDemo(style: style)
        case .staggeredList:  StaggeredListDemo(style: style)
        }
    }

    // MARK: - Code snippet

    private var codeSnippet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Swift Code", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(selectedExample.codeSnippet)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - ScreenEntranceDemo

private struct ScreenEntranceDemo: View {
    let style: MotionStyle

    @State private var titleOpacity:  Double  = 0
    @State private var bodyOpacity:   Double  = 0
    @State private var card1Scale:    CGFloat = 0.8
    @State private var card1Opacity:  Double  = 0
    @State private var card2Scale:    CGFloat = 0.8
    @State private var card2Opacity:  Double  = 0
    @State private var ctaOpacity:    Double  = 0

    var body: some View {
        VStack(spacing: 16) {
            demoCanvas
            replayButton { replay() }
        }
        .padding(20)
        .onAppear { replay() }
    }

    private var demoCanvas: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Good morning")
                    .font(.title2.bold())
                    .opacity(titleOpacity)
                Text("Here's what's happening today.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(bodyOpacity)
            }

            HStack(spacing: 12) {
                miniCard(color: .blue, opacity: card1Opacity, scale: card1Scale)
                miniCard(color: .purple, opacity: card2Opacity, scale: card2Scale)
            }

            Text("Get started →")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.accentColor)
                .opacity(ctaOpacity)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func miniCard(color: Color, opacity: Double, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color.gradient)
            .frame(height: 80)
            .opacity(opacity)
            .scaleEffect(scale)
    }

    @MainActor
    private func replay() {
        titleOpacity  = 0; bodyOpacity   = 0
        card1Scale    = 0.8; card1Opacity  = 0
        card2Scale    = 0.8; card2Opacity  = 0
        ctaOpacity    = 0

        Task { @MainActor in
            await MotionPresets.screenEntrance(
                style: style,
                stages: [
                    { self.titleOpacity = 1 },
                    { self.bodyOpacity  = 1 },
                    { self.card1Scale   = 1; self.card1Opacity  = 1 },
                    { self.card2Scale   = 1; self.card2Opacity  = 1 },
                    { self.ctaOpacity   = 1 },
                ]
            ).play()
        }
    }
}

// MARK: - ParallelGroupDemo

private struct ParallelGroupDemo: View {
    let style: MotionStyle

    @State private var aOpacity: Double = 0
    @State private var bOpacity: Double = 0
    @State private var cOpacity: Double = 0
    @State private var dOpacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            demoCanvas
            replayButton { replay() }
        }
        .padding(20)
        .onAppear { replay() }
    }

    private var demoCanvas: some View {
        VStack(spacing: 12) {
            Text("Parallel { } fires A+B+C+D simultaneously:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach([
                    ("A", aOpacity, Color.blue),
                    ("B", bOpacity, Color.purple),
                    ("C", cOpacity, Color.pink),
                    ("D", dOpacity, Color.orange),
                ], id: \.0) { label, opacity, color in
                    VStack {
                        Circle().fill(color).frame(width: 44, height: 44)
                        Text(label).font(.caption2.bold())
                    }
                    .opacity(opacity)
                }
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @MainActor
    private func replay() {
        aOpacity = 0; bOpacity = 0; cOpacity = 0; dOpacity = 0

        Task { @MainActor in
            await MotionTimeline(style) {
                Parallel {
                    Animate(style.primarySpring)            { self.aOpacity = 1 }
                    Animate(style.primarySpring, delay: 0.05) { self.bOpacity = 1 }
                    Animate(style.primarySpring, delay: 0.10) { self.cOpacity = 1 }
                    Animate(style.primarySpring, delay: 0.15) { self.dOpacity = 1 }
                }
            }.play()
        }
    }
}

// MARK: - CardSceneDemo

private struct CardSceneDemo: View {
    let style: MotionStyle

    @State private var cardScale:     CGFloat = 0.85
    @State private var cardOpacity:   Double  = 0
    @State private var backdropOpacity: Double = 0
    @State private var contentOpacity: Double  = 0

    var body: some View {
        VStack(spacing: 16) {
            demoCanvas
            replayButton { replay() }
        }
        .padding(20)
        .onAppear { replay() }
    }

    private var demoCanvas: some View {
        ZStack {
            Color.black.opacity(backdropOpacity * 0.5)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 120)
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)

                Text("Card expanded via MotionScene")
                    .font(.callout)
                    .opacity(contentOpacity)
            }
            .padding(20)
        }
        .frame(height: 200)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @MainActor
    private func replay() {
        cardScale = 0.85; cardOpacity = 0; backdropOpacity = 0; contentOpacity = 0

        Task { @MainActor in
            await MotionScene.cardExpand(
                style: style,
                onCard:     { self.cardScale = 1; self.cardOpacity = 1 },
                onBackdrop: { self.backdropOpacity = 1 },
                onContent:  { self.contentOpacity  = 1 }
            ).play()
        }
    }
}

// MARK: - StaggeredListDemo

private struct StaggeredListDemo: View {
    let style: MotionStyle

    @State private var itemOpacities: [Double] = Array(repeating: 0, count: 6)
    @State private var itemOffsets:   [CGFloat] = Array(repeating: 20, count: 6)

    var body: some View {
        VStack(spacing: 16) {
            demoCanvas
            replayButton { replay() }
        }
        .padding(20)
        .onAppear { replay() }
    }

    private var demoCanvas: some View {
        VStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 36)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 10) {
                            Circle().fill(Color.accentColor.opacity(0.6)).frame(width: 20)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.separator))
                                .frame(width: 120, height: 10)
                        }
                        .padding(.leading, 10)
                    }
                    .opacity(itemOpacities[i])
                    .offset(y: itemOffsets[i])
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @MainActor
    private func replay() {
        itemOpacities = Array(repeating: 0, count: 6)
        itemOffsets   = Array(repeating: 20, count: 6)

        Task { @MainActor in
            await MotionPresets.staggeredList(count: 6, style: style) { i in
                self.itemOpacities[i] = 1
                self.itemOffsets[i]   = 0
            }.play()
        }
    }
}

// MARK: - Helpers

private func replayButton(action: @escaping @MainActor () -> Void) -> some View {
    Button(action: action) {
        Label("Replay", systemImage: "arrow.clockwise")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    .flowSpringTap()
}

// MARK: - OrchestratorExample

enum OrchestratorExample: CaseIterable, Hashable {
    case screenEntrance
    case parallelGroup
    case cardScene
    case staggeredList

    var label: String {
        switch self {
        case .screenEntrance: return "Entrance"
        case .parallelGroup:  return "Parallel {}"
        case .cardScene:      return "Scene"
        case .staggeredList:  return "Stagger"
        }
    }

    var codeSnippet: String {
        switch self {
        case .screenEntrance:
            return """
            await MotionPresets.screenEntrance(
                style: .cinematic,
                stages: [
                    { titleOpacity  = 1 },
                    { bodyOpacity   = 1 },
                    { card1Opacity  = 1 },
                ]
            ).play()
            """
        case .parallelGroup:
            return """
            await MotionTimeline(.cinematic) {
                Parallel {
                    Animate(.hero)            { a = 1 }
                    Animate(.hero, delay: 0.05) { b = 1 }
                    Animate(.hero, delay: 0.10) { c = 1 }
                }
            }.play()
            """
        case .cardScene:
            return """
            await MotionScene.cardExpand(
                style: .cinematic,
                onCard:     { cardScale = 1 },
                onBackdrop: { bgOpacity = 1 },
                onContent:  { textOpacity = 1 }
            ).play()
            """
        case .staggeredList:
            return """
            await MotionPresets.staggeredList(
                count: items.count,
                style: .cinematic
            ) { i in
                itemOpacities[i] = 1
            }.play()
            """
        }
    }
}

#Preview {
    FlowNavigationStack {
        TimelineOrchestratorScreen()
    }
    .flowStyle(.cinematic)
}
