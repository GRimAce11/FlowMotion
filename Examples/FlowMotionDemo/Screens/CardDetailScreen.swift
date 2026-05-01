import SwiftUI
import FlowMotion

// MARK: - CardDetailScreen

struct CardDetailScreen: View {

    let item: DemoItem
    let namespace: Namespace.ID

    @State private var titleVisible   = false
    @State private var bodyVisible    = false
    @State private var actionsVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroHeader

                VStack(alignment: .leading, spacing: 24) {
                    descriptionSection
                    featureHighlights
                    demoSection
                    actionsRow
                }
                .padding(24)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .flowInteractiveDismiss(edge: .bottom)
        .onAppear { runEntranceAnimation() }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: item.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)
            .sharedElementDestination(id: item.id, namespace: namespace)

            // Icon
            Image(systemName: item.icon)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 40)

            // Title overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.title3.bold())
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 10)

            Text(item.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .opacity(bodyVisible ? 1 : 0)
                .offset(y: bodyVisible ? 0 : 8)
        }
    }

    // MARK: - Feature highlights

    private var featureHighlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Features")
                .font(.title3.bold())
                .opacity(bodyVisible ? 1 : 0)

            ForEach(featurePoints, id: \.self) { point in
                Label(point, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .opacity(bodyVisible ? 1 : 0)
            }
        }
    }

    private var featurePoints: [String] {
        switch item.icon {
        case "drop.fill":
            return ["Sinusoidal edge displacement", "Canvas-based rendering", "60fps/120fps capable", "Reduce-motion compatible"]
        case "star.fill":
            return ["Geometry captured at nav moment", "Spring-interpolated flight", "Interruptible mid-flight", "Navigation-stack aware"]
        case "waveform.path":
            return ["Closed-form analytical solver", "Exact velocity at any time t", "Deterministic — same input → same output", "Configurable presets"]
        case "hand.draw.fill":
            return ["Velocity threshold commit", "Rubber-band resistance", "Environment progress binding", "Cancellation-safe"]
        case "timeline.selection":
            return ["Result-builder DSL", "Parallel execution support", "async/await safe", "Per-step spring configuration"]
        default:
            return ["Scale + blur entry", "iOS 18 native zoom fallback", "Depth separation", "App Store quality feel"]
        }
    }

    // MARK: - Live demo section

    @ViewBuilder
    private var demoSection: some View {
        if item.icon == "waveform.path" {
            SpringDemoView()
                .opacity(actionsVisible ? 1 : 0)
        } else if item.icon == "drop.fill" {
            LiquidDemoView()
                .opacity(actionsVisible ? 1 : 0)
        }
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button {
                // open docs
            } label: {
                Label("Docs", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .flowSpringTap()

            Button {
                // open source
            } label: {
                Label("Source", systemImage: "chevron.left.forwardslash.chevron.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .flowSpringTap()
        }
        .opacity(actionsVisible ? 1 : 0)
        .offset(y: actionsVisible ? 0 : 16)
    }

    // MARK: - Entrance animation

    private func runEntranceAnimation() {
        withAnimation(.flowHero.delay(0.05))  { titleVisible   = true }
        withAnimation(.flowSmooth.delay(0.15)) { bodyVisible    = true }
        withAnimation(.flowSnappy.delay(0.25)) { actionsVisible = true }
    }
}

// MARK: - SpringDemoView

/// Interactive spring visualiser for the physics demo card.
struct SpringDemoView: View {

    @State private var selectedPreset = 0
    @State private var ballX: CGFloat = 0
    @State private var isDragging = false

    private let presets: [(name: String, config: SpringConfiguration)] = [
        ("Snappy",  .snappy),
        ("Bouncy",  .bouncy),
        ("Hero",    .hero),
        ("Gentle",  .gentle),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Demo")
                .font(.title3.bold())

            // Ball track
            GeometryReader { proxy in
                ZStack {
                    // Track
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: 6)

                    // Ball
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: .blue.opacity(0.4), radius: 8)
                        .offset(x: ballX)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    isDragging = true
                                    ballX = v.translation.width
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    let config = presets[selectedPreset].config
                                    withAnimation(config.swiftUIAnimation) {
                                        ballX = 0
                                    }
                                }
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 44)

            // Preset picker
            Picker("Spring", selection: $selectedPreset) {
                ForEach(presets.indices, id: \.self) { i in
                    Text(presets[i].name).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - LiquidDemoView

struct LiquidDemoView: View {

    @State private var progress: CGFloat = 0.3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Demo")
                .font(.title3.bold())

            LiquidLoadingView(configuration: .ocean)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Slider(value: $progress, in: 0...1)
                .tint(.blue)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    FlowNavigationStack {
        CardDetailScreen(item: DemoItem.samples[0], namespace: Namespace().wrappedValue)
    }
}
