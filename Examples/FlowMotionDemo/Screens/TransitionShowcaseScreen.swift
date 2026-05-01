import SwiftUI
import FlowMotion

// MARK: - TransitionShowcaseScreen

/// Side-by-side showcase of every FlowMotition transition style.
struct TransitionShowcaseScreen: View {

    @State private var selectedTransition: ShowcaseTransition = .liquid
    @State private var isShowingExample = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                transitionPicker
                    .padding(.horizontal, 20)

                livePreview
                    .padding(.horizontal, 20)

                metadataCard
                    .padding(.horizontal, 20)

                configurationView
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Showcase")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Transition picker

    private var transitionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ShowcaseTransition.allCases, id: \.self) { t in
                    Button {
                        withAnimation(.flowSnappy) {
                            selectedTransition = t
                        }
                    } label: {
                        Text(t.displayName)
                            .font(.callout.weight(selectedTransition == t ? .semibold : .regular))
                            .foregroundStyle(selectedTransition == t ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTransition == t ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .flowSpringTap()
                }
            }
        }
    }

    // MARK: - Live preview card

    private var livePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(height: 220)

            if isShowingExample {
                exampleContent
                    .flowTransition(selectedTransition.flowStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Button("Tap to preview") {
                    withAnimation(selectedTransition.animation) {
                        isShowingExample = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onTapGesture {
            if isShowingExample {
                withAnimation(selectedTransition.animation) {
                    isShowingExample = false
                }
            }
        }
        .onChange(of: selectedTransition) { _, _ in
            isShowingExample = false
        }
    }

    private var exampleContent: some View {
        ZStack {
            LinearGradient(
                colors: selectedTransition.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: selectedTransition.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text(selectedTransition.displayName)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Metadata card

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(selectedTransition.displayName, systemImage: selectedTransition.icon)
                .font(.headline)

            Text(selectedTransition.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                metaTag("iOS 17+")
                metaTag("60fps")
                metaTag("Reduce-motion safe")
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metaTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }

    // MARK: - Configuration view

    private var configurationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Swift Code")
                .font(.headline)

            Text(selectedTransition.codeSnippet)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ShowcaseTransition

enum ShowcaseTransition: CaseIterable, Hashable {
    case liquid
    case cinematic
    case slide
    case fade
    case reveal

    var displayName: String {
        switch self {
        case .liquid:    return "Liquid"
        case .cinematic: return "Cinematic"
        case .slide:     return "Slide"
        case .fade:      return "Fade"
        case .reveal:    return "Reveal"
        }
    }

    var icon: String {
        switch self {
        case .liquid:    return "drop.fill"
        case .cinematic: return "play.rectangle.fill"
        case .slide:     return "arrow.right.circle.fill"
        case .fade:      return "circle.fill"
        case .reveal:    return "rectangle.bottomhalf.filled"
        }
    }

    var colors: [Color] {
        switch self {
        case .liquid:    return [.blue, .purple]
        case .cinematic: return [.black, .gray]
        case .slide:     return [.green, .teal]
        case .fade:      return [.orange, .yellow]
        case .reveal:    return [.pink, .purple]
        }
    }

    var description: String {
        switch self {
        case .liquid:
            return "Surfaces melt between routes using sinusoidal edge displacement with Canvas rendering."
        case .cinematic:
            return "Scale + blur entry modelled on iOS App Store card expansion. Depth-separates foreground and background."
        case .slide:
            return "Spring-powered directional slide with natural overshoot. Configurable edge and spring preset."
        case .fade:
            return "Simple opacity transition — the fallback for Reduce Motion. Pairs with any spring timing."
        case .reveal:
            return "Vertical unmask with scale — the bottom-sheet expand feel. Combines scale and offset for depth."
        }
    }

    var flowStyle: FlowTransitionStyle {
        switch self {
        case .liquid:    return .liquid()
        case .cinematic: return .cinematic()
        case .slide:     return .slide()
        case .fade:      return .fade
        case .reveal:    return .reveal
        }
    }

    var animation: Animation {
        switch self {
        case .liquid:    return .flowHero
        case .cinematic: return .flowHero
        case .slide:     return .flowSnappy
        case .fade:      return .flowSmooth
        case .reveal:    return .flowBouncy
        }
    }

    var codeSnippet: String {
        switch self {
        case .liquid:
            return """
            MyView()
                .flowTransition(.liquid(intensity: 1.0))
            """
        case .cinematic:
            return """
            MyView()
                .flowTransition(.cinematic(scale: 0.92))
            // Or with native zoom (iOS 18+):
            .cinematicNavigationTransition(id: item.id, namespace: ns)
            """
        case .slide:
            return """
            MyView()
                .flowTransition(.slide(edge: .trailing))
            """
        case .fade:
            return """
            MyView()
                .flowTransition(.fade)
            """
        case .reveal:
            return """
            MyView()
                .flowTransition(.reveal)
            // Great for sheet presentations:
            .flowSheet(isPresented: $isPresented) { MyView() }
            """
        }
    }
}

#Preview {
    FlowNavigationStack {
        TransitionShowcaseScreen()
    }
}
