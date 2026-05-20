import SwiftUI
import FlowMotion

// MARK: - GesturePlaygroundScreen

/// Interactive playground for FlowMotion gesture primitives.
/// Demonstrates spring-backed velocity handoff, interactive dismiss,
/// and drag progress — all the ingredient a production app needs.
struct GesturePlaygroundScreen: View {

    @State private var selectedDemo: GestureDemo = .springDrag
    @Environment(\.flowStyle) private var style

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                demoSection

                VStack(spacing: 0) {
                    demoPicker
                }

                instructionCard

                if selectedDemo == .interactiveDismiss {
                    interactiveDismissNote
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Gestures")
        .navigationBarTitleDisplayMode(.inline)
        .flowGestureCoordinator()
    }

    // MARK: - Demo

    @ViewBuilder
    private var demoSection: some View {
        switch selectedDemo {
        case .springDrag:       SpringDragDemo(style: style)
        case .velocityHandoff:  VelocityHandoffDemo(style: style)
        case .dragProgress:     DragProgressDemo(style: style)
        case .interactiveDismiss: InteractiveDismissDemo()
        }
    }

    // MARK: - Picker

    private var demoPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(GestureDemo.allCases, id: \.self) { demo in
                    Button {
                        withAnimation(.flowSnappy) { selectedDemo = demo }
                    } label: {
                        Label(demo.label, systemImage: demo.icon)
                            .font(.caption.weight(selectedDemo == demo ? .semibold : .regular))
                            .foregroundStyle(selectedDemo == demo ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedDemo == demo ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .flowSpringTap()
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Instruction card

    private var instructionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(selectedDemo.instructions)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var interactiveDismissNote: some View {
        Text("The dismiss demo is best seen via the card tap on the Home screen.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 20)
    }
}

// MARK: - SpringDragDemo

/// A circle that springs back to center when released.
private struct SpringDragDemo: View {
    let style: MotionStyle

    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var selectedSpring: SpringPreset = .hero

    private let springs: [SpringPreset] = SpringPreset.allCases

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Grid
                gridBackground

                // Spring ball
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 4)
                    .offset(offset)
                    .scaleEffect(isDragging ? 1.15 : 1)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                isDragging = true
                                offset = v.translation
                            }
                            .onEnded { v in
                                isDragging = false
                                let velocity = v.flowVelocity
                                let spring   = selectedSpring.config
                                withAnimation(spring.swiftUIAnimation(initialVelocity: velocity.dy)) {
                                    offset = .zero
                                }
                            }
                    )
            }
            .frame(height: 200)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Spring picker
            Picker("Spring", selection: $selectedSpring) {
                ForEach(springs, id: \.self) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    private var gridBackground: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            let lineColor = Color(.separator).opacity(0.4)
            var x: CGFloat = 0
            while x < size.width {
                context.stroke(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }, with: .color(lineColor), lineWidth: 0.5)
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                context.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }, with: .color(lineColor), lineWidth: 0.5)
                y += step
            }
        }
    }
}

// MARK: - VelocityHandoffDemo

/// Shows how gesture velocity transfers to a spring animation.
private struct VelocityHandoffDemo: View {
    let style: MotionStyle

    @State private var position: CGFloat = 0
    @State private var flingCount = 0
    private let tracker = VelocityTracker(configuration: .responsive)

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { proxy in
                let width = proxy.size.width - 60

                ZStack {
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: 6)

                    Circle()
                        .fill(Color.accentColor.gradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 8)
                        .offset(x: position * width / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    tracker.record(v.location)
                                    position = max(-1, min(1, v.translation.width / (width / 2)))
                                }
                                .onEnded { _ in
                                    let vel = tracker.velocity.dx / (width / 2)
                                    tracker.reset()
                                    flingCount += 1
                                    let target: CGFloat = vel > 0 ? 1 : -1
                                    withAnimation(style.primarySpring.swiftUIAnimation(initialVelocity: vel)) {
                                        position = target
                                    }
                                }
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Text("Flings: \(flingCount) — drag and release to hand off velocity")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - DragProgressDemo

private struct DragProgressDemo: View {
    let style: MotionStyle
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { proxy in
                VStack(spacing: 16) {
                    // Progress bar
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemGroupedBackground)).frame(height: 8)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: proxy.size.width * progress, height: 8)
                    }

                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.numericText())
                        .animation(.flowSnappy, value: progress)
                }
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(height: 140)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .flowGestureProgress($progress, distance: 240, axis: .horizontal, spring: style.primarySpring)
        }
    }
}

// MARK: - InteractiveDismissDemo

private struct InteractiveDismissDemo: View {
    @State private var showSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Button {
                showSheet = true
            } label: {
                Label("Show Dismissible Sheet", systemImage: "arrow.up.square")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .flowSpringTap()
            .flowSheet(isPresented: $showSheet) {
                VStack(spacing: 16) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text("Drag down to dismiss")
                        .font(.title3.bold())
                    Text("Velocity-aware — a fast flick commits even at low drag progress.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Supporting types

private enum SpringPreset: CaseIterable, Hashable {
    case snappy, hero, bouncy, gentle

    var label: String {
        switch self {
        case .snappy:  return "Snappy"
        case .hero:    return "Hero"
        case .bouncy:  return "Bouncy"
        case .gentle:  return "Gentle"
        }
    }

    var config: SpringConfiguration {
        switch self {
        case .snappy:  return .snappy
        case .hero:    return .hero
        case .bouncy:  return .bouncy
        case .gentle:  return .gentle
        }
    }
}

enum GestureDemo: CaseIterable, Hashable {
    case springDrag
    case velocityHandoff
    case dragProgress
    case interactiveDismiss

    var label: String {
        switch self {
        case .springDrag:       return "Spring"
        case .velocityHandoff:  return "Velocity"
        case .dragProgress:     return "Progress"
        case .interactiveDismiss: return "Dismiss"
        }
    }

    var icon: String {
        switch self {
        case .springDrag:       return "circle.fill"
        case .velocityHandoff:  return "arrow.right"
        case .dragProgress:     return "slider.horizontal.3"
        case .interactiveDismiss: return "arrow.down"
        }
    }

    var instructions: String {
        switch self {
        case .springDrag:       return "Drag the ball anywhere. Release to see it spring back using gesture velocity."
        case .velocityHandoff:  return "Flick the puck left or right. Notice how velocity carries into the landing spring."
        case .dragProgress:     return "Drag horizontally across the card to scrub the progress value."
        case .interactiveDismiss: return "Tap to present the sheet, then drag down to dismiss."
        }
    }
}

#Preview {
    FlowNavigationStack {
        GesturePlaygroundScreen()
    }
    .flowStyle(.cinematic)
}
