import SwiftUI
import FlowMotion

struct MotionDirectorDemoScreen: View {

    // Animation state for the demo
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 24
    @State private var card1Scale: CGFloat = 0.85
    @State private var card1Opacity: Double = 0
    @State private var card2Scale: CGFloat = 0.85
    @State private var card2Opacity: Double = 0
    @State private var card3Scale: CGFloat = 0.85
    @State private var card3Opacity: Double = 0
    @State private var ctaOpacity: Double = 0
    @State private var bgOpacity: Double = 0
    @State private var isPlaying = false

    @Environment(\.motionDirector) private var director

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                stageSection
                replaySection
                codeSection
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Director")
        .navigationBarTitleDisplayMode(.inline)
        .task { await playNarrative() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MotionDirector")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
            Text("Coordinates multiple MotionScene instances across separate view subtrees. The onboarding narrative below uses 3 scenes played in sequence.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Stage (animated demo)

    private var stageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                    .opacity(bgOpacity)

                VStack(spacing: 16) {
                    // Title
                    VStack(spacing: 4) {
                        Text("Good morning")
                            .font(.title2.bold())
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                        Text("Your motion narrative is ready.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .opacity(titleOpacity)
                    }

                    // Cards
                    HStack(spacing: 12) {
                        miniCard(color: [.blue, .indigo], scale: card1Scale, opacity: card1Opacity)
                        miniCard(color: [.purple, .pink], scale: card2Scale, opacity: card2Opacity)
                        miniCard(color: [.teal, .green], scale: card3Scale, opacity: card3Opacity)
                    }

                    // CTA
                    Text("Begin →")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(ctaOpacity)
                }
                .padding(24)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private func miniCard(color: [Color], scale: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: color, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    // MARK: - Replay

    private var replaySection: some View {
        HStack(spacing: 12) {
            Button {
                Task { await resetAndPlay() }
            } label: {
                Label(isPlaying ? "Playing…" : "Replay Narrative", systemImage: isPlaying ? "clock" : "arrow.clockwise")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .flowSpringTap()
            .disabled(isPlaying)

            if isPlaying {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Code

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Swift Code", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)

            Text("""
            await NarrativeMotion.onboardingReveal(
                heroStages: [
                    { bgOpacity = 1 },
                    { titleOpacity = 1; titleOffset = 0 },
                ],
                contentStages: [
                    { card1Scale = 1; card1Opacity = 1 },
                    { card2Scale = 1; card2Opacity = 1 },
                    { card3Scale = 1; card3Opacity = 1 },
                ],
                ctaStages: [{ ctaOpacity = 1 }]
            )
            """)
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

    // MARK: - Playback

    @MainActor
    private func resetAndPlay() async {
        // Reset
        titleOpacity = 0; titleOffset = 24
        card1Scale = 0.85; card1Opacity = 0
        card2Scale = 0.85; card2Opacity = 0
        card3Scale = 0.85; card3Opacity = 0
        ctaOpacity = 0; bgOpacity = 0
        await playNarrative()
    }

    @MainActor
    private func playNarrative() async {
        guard !isPlaying else { return }
        isPlaying = true

        await NarrativeMotion.onboardingReveal(
            heroStages: [
                { self.bgOpacity = 1 },
                { self.titleOpacity = 1; self.titleOffset = 0 },
            ],
            contentStages: [
                { self.card1Scale = 1; self.card1Opacity = 1 },
                { self.card2Scale = 1; self.card2Opacity = 1 },
                { self.card3Scale = 1; self.card3Opacity = 1 },
            ],
            ctaStages: [{ self.ctaOpacity = 1 }]
        )

        isPlaying = false
    }
}

#Preview {
    FlowNavigationStack {
        MotionDirectorDemoScreen()
    }
}
