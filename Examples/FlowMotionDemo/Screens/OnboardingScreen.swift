import SwiftUI
import FlowMotion

// MARK: - OnboardingScreen

/// Cinematic multi-page onboarding using MotionTimeline choreography.
struct OnboardingScreen: View {

    @State private var currentPage = 0
    @State private var isComplete  = false

    // Per-element animation state
    @State private var iconScale:    CGFloat = 0.5
    @State private var iconOpacity:  Double  = 0
    @State private var titleOpacity: Double  = 0
    @State private var bodyOpacity:  Double  = 0
    @State private var dotsOpacity:  Double  = 0

    private let pages = OnboardingPage.all
    private var page: OnboardingPage { pages[currentPage] }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: page.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.flowSmooth, value: currentPage)

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 140, height: 140)

                    Image(systemName: page.icon)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                Spacer().frame(height: 48)

                // Title
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)

                Spacer().frame(height: 16)

                // Body
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(bodyOpacity)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.white : Color.white.opacity(0.4))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.flowSnappy, value: currentPage)
                    }
                }
                .opacity(dotsOpacity)

                Spacer().frame(height: 32)

                // CTA
                Button(action: advance) {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(page.gradient.first ?? .blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 32)
                }
                .flowSpringTap(scale: 0.97)
                .opacity(dotsOpacity)

                Spacer().frame(height: 48)
            }
        }
        .onAppear { playEntrance() }
        .onChange(of: currentPage) { _, _ in playEntrance() }
    }

    // MARK: - Entrance animation

    @MainActor
    private func playEntrance() {
        // Reset
        iconScale   = 0.5
        iconOpacity = 0
        titleOpacity = 0
        bodyOpacity  = 0

        Task { @MainActor in
            await MotionTimeline {
                Animate(.hero) {
                    iconScale   = 1
                    iconOpacity = 1
                }
                Wait(0.08)
                Animate(.smooth) { titleOpacity = 1 }
                Wait(0.06)
                Animate(.gentle) {
                    bodyOpacity  = 1
                    dotsOpacity  = 1
                }
            }.play()
        }
    }

    private func advance() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif

        withAnimation(.flowSnappy) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            } else {
                isComplete = true
            }
        }
    }
}

// MARK: - OnboardingPage model

struct OnboardingPage {
    let title: String
    let body: String
    let icon: String
    let gradient: [Color]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            title: "Liquid Motion",
            body:  "Every transition flows naturally — surfaces merge, split, and morph like liquid.",
            icon:  "drop.fill",
            gradient: [Color(red: 0.3, green: 0.6, blue: 1), Color(red: 0.5, green: 0.2, blue: 0.9)]
        ),
        OnboardingPage(
            title: "Hero Animations",
            body:  "Elements travel seamlessly from card to detail — no jump cuts, just continuity.",
            icon:  "star.fill",
            gradient: [Color(red: 1, green: 0.4, blue: 0.3), Color(red: 1, green: 0.6, blue: 0.2)]
        ),
        OnboardingPage(
            title: "Physics-Backed",
            body:  "Springs, momentum, and inertia — the same physical laws Apple uses, engineered from scratch.",
            icon:  "waveform.path",
            gradient: [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.1, green: 0.6, blue: 0.9)]
        ),
        OnboardingPage(
            title: "Yours to Extend",
            body:  "Open protocols, composable modifiers, result-builder DSLs. Build any motion imaginable.",
            icon:  "puzzlepiece.extension.fill",
            gradient: [Color(red: 0.15, green: 0.15, blue: 0.25), Color(red: 0.3, green: 0.2, blue: 0.5)]
        ),
    ]
}

#Preview {
    OnboardingScreen()
}
