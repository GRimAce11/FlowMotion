import SwiftUI
import FlowMotion

// MARK: - CardDetailScreen

struct CardDetailScreen: View {

    let item: DemoItem
    let namespace: Namespace.ID

    // Driven entirely by a single Bool so SwiftUI has one clear
    // dependency to animate against — simpler and more reliable than
    // separate state per element.
    @State private var contentVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroHeader
                contentBody
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        // Interactive dismiss so users can drag back
        .flowInteractiveDismiss(edge: .bottom)
        .onAppear {
            // Small delay lets the zoom/push animation finish before
            // content starts animating in, so both play cleanly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    contentVisible = true
                }
            }
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: item.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 300)

            // Large icon
            Image(systemName: item.icon)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 48)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Content body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 24) {
            overviewSection
            featuresSection
            liveDemoSection
            actionsSection
        }
        .padding(24)
    }

    // Each section offsets from below and fades in, staggered.

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.title3.bold())
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 20)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.0), value: contentVisible)

            Text(item.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 16)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.05), value: contentVisible)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Features")
                .font(.title3.bold())
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 16)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.10), value: contentVisible)

            ForEach(Array(featurePoints.enumerated()), id: \.offset) { index, point in
                Label(point, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 12)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(0.12 + Double(index) * 0.04),
                        value: contentVisible
                    )
            }
        }
    }

    @ViewBuilder
    private var liveDemoSection: some View {
        if item.icon == "waveform.path" {
            SpringDemoView()
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.30), value: contentVisible)
        } else if item.icon == "drop.fill" {
            LiquidDemoView()
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.30), value: contentVisible)
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 12) {
            actionButton(label: "Docs", icon: "doc.text", primary: true) {}
            actionButton(label: "Source", icon: "chevron.left.forwardslash.chevron.right", primary: false) {}
        }
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 16)
        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.40), value: contentVisible)
    }

    private func actionButton(label: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(primary ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(primary ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .flowSpringTap()
    }

    // MARK: - Feature points

    private var featurePoints: [String] {
        switch item.icon {
        case "drop.fill":
            return ["Sinusoidal Canvas mask morphing", "Metaball compositing (blur + contrast)", "60 / 120 fps capable", "Reduce-motion safe fallback"]
        case "star.fill":
            return ["Geometry captured via PreferenceKey", "iOS 18 native zoom transition", "Spring-interpolated hero overlay", "Works inside any scroll container"]
        case "waveform.path":
            return ["Closed-form analytical ODE solver", "Exact velocity at any time t", "Deterministic — same input → same output", "8 named spring presets"]
        case "hand.draw.fill":
            return ["Velocity-threshold commit logic", "Rubber-band resistance past edge", "interactiveDismissProgress environment key", "Cancellation-safe spring settle"]
        case "timeline.selection":
            return ["@resultBuilder Parallel { } syntax", "Nested timelines as single steps", "async/await cancellation-safe", "MotionStyle time-scale support"]
        default:
            return ["iOS 18 native zoom transition", "matchedTransitionSource integration", "Depth separation via blur", "App Store–quality feel"]
        }
    }
}

// MARK: - SpringDemoView

private struct SpringDemoView: View {
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var selectedIndex = 0

    private let presets: [(String, SpringConfiguration)] = [
        ("Snappy", .snappy), ("Bouncy", .bouncy), ("Hero", .hero), ("Gentle", .gentle)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Demo — Drag the ball")
                .font(.title3.bold())

            ZStack {
                backgroundGrid
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .shadow(color: .blue.opacity(0.4), radius: 12, y: 4)
                    .scaleEffect(isDragging ? 1.12 : 1)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { v in isDragging = true; offset = v.translation }
                            .onEnded { v in
                                isDragging = false
                                let vel = v.flowVelocity
                                let cfg = presets[selectedIndex].1
                                withAnimation(cfg.swiftUIAnimation(initialVelocity: vel.dy)) {
                                    offset = .zero
                                }
                            }
                    )
            }
            .frame(height: 160)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Picker("Spring", selection: $selectedIndex) {
                ForEach(presets.indices, id: \.self) { i in
                    Text(presets[i].0).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backgroundGrid: some View {
        Canvas { context, size in
            let step: CGFloat = 20
            let c = Color(.separator).opacity(0.35)
            var x: CGFloat = 0
            while x <= size.width  { context.stroke(Path { p in p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height)) }, with: .color(c), lineWidth: 0.5); x += step }
            var y: CGFloat = 0
            while y <= size.height { context.stroke(Path { p in p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y)) }, with: .color(c), lineWidth: 0.5); y += step }
        }
    }
}

// MARK: - LiquidDemoView

private struct LiquidDemoView: View {
    @State private var config = LiquidRenderer.Configuration.ocean

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Demo — Liquid Loader")
                .font(.title3.bold())

            LiquidLoadingView(configuration: config)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                ForEach(["Ocean", "Sunset", "Midnight"], id: \.self) { name in
                    Button(name) {
                        withAnimation(.flowSnappy) {
                            switch name {
                            case "Ocean":    config = .ocean
                            case "Sunset":   config = .sunset
                            default:         config = .midnight
                            }
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .flowSpringTap(scale: 0.94)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CardDetailScreen(item: DemoItem.samples[0], namespace: Namespace().wrappedValue)
    }
}
