import SwiftUI
import FlowMotion

// MARK: - TransitionComposeScreen

struct TransitionComposeScreen: View {

    @State private var selectedA: ComposeChoice = .liquid
    @State private var selectedB: ComposeChoice = .reveal
    @State private var showingComposed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                pickerSection
                previewCard
                codeCard
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Compose")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transition Composition")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)

            Text("Layer any two FlowMotion transitions simultaneously using `a.combined(with: b)`.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Pickers

    private var pickerSection: some View {
        VStack(spacing: 16) {
            pickerRow(label: "Transition A", selection: $selectedA, accent: .blue)
            pickerRow(label: "Transition B", selection: $selectedB, accent: .purple)
        }
        .padding(.horizontal, 20)
    }

    private func pickerRow(label: String, selection: Binding<ComposeChoice>, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ComposeChoice.allCases, id: \.self) { choice in
                        Button {
                            withAnimation(.flowSnappy) { selection.wrappedValue = choice }
                        } label: {
                            Text(choice.label)
                                .font(.caption.weight(selection.wrappedValue == choice ? .semibold : .regular))
                                .foregroundStyle(selection.wrappedValue == choice ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selection.wrappedValue == choice ? accent : Color(.secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .flowSpringTap(scale: 0.95)
                    }
                }
            }
        }
    }

    // MARK: - Preview card

    private var previewCard: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))

                if showingComposed {
                    composedContent
                        .flowTransition(selectedA.style.combined(with: selectedB.style))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    Button {
                        withAnimation(.flowHero) { showingComposed = true }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("Tap to preview")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .flowSpringTap()
                }
            }
            .frame(height: 200)
            .onTapGesture {
                if showingComposed {
                    withAnimation(.flowHero) { showingComposed = false }
                }
            }
            .onChange(of: selectedA) { _, _ in showingComposed = false }
            .onChange(of: selectedB) { _, _ in showingComposed = false }
        }
        .padding(.horizontal, 20)
    }

    private var composedContent: some View {
        ZStack {
            LinearGradient(
                colors: [selectedA.color, selectedB.color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                Text("\(selectedA.label) + \(selectedB.label)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("Tap to reset")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Code card

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Swift Code", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)

            Text(codeSnippet)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var codeSnippet: String {
        """
        let composed = FlowTransitionStyle
            .\(selectedA.rawValue)
            .combined(with: .\(selectedB.rawValue))

        MyView()
            .flowTransition(composed)
        """
    }
}

// MARK: - ComposeChoice

enum ComposeChoice: String, CaseIterable, Hashable {
    case liquid, cinematic, slide, fade, reveal

    var label: String { rawValue.capitalized }

    var style: FlowTransitionStyle {
        switch self {
        case .liquid:    return .liquid()
        case .cinematic: return .cinematic()
        case .slide:     return .slide()
        case .fade:      return .fade
        case .reveal:    return .reveal
        }
    }

    var color: Color {
        switch self {
        case .liquid:    return .blue
        case .cinematic: return .purple
        case .slide:     return .green
        case .fade:      return .orange
        case .reveal:    return .pink
        }
    }
}

#Preview {
    FlowNavigationStack {
        TransitionComposeScreen()
    }
}
