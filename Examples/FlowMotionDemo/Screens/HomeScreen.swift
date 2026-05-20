import SwiftUI
import FlowMotion

// MARK: - HomeScreen

struct HomeScreen: View {

    @Namespace private var heroNamespace
    @Environment(\.flowStyle) private var style

    // Per-card visibility so cards are never in the layout while invisible.
    // opacity(0) preserves layout space; conditional rendering removes it.
    @State private var appeared        = false
    @State private var showHeader      = false
    @State private var showChips       = false
    @State private var showCards       = Array(repeating: false, count: DemoItem.samples.count)
    @State private var showFooter      = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                if showHeader {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if showChips {
                    capabilityChips
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }

                // Cards — each added individually so stagger creates no gap
                cardStack

                if showFooter {
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    systemDemoRow
                    orchestratorCard
                    gestureCard
                }
            }
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("FlowMotion")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            runEntrance()
        }
    }

    @MainActor
    private func runEntrance() {
        Task { @MainActor in
            // 1. Header + chips
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.flowSmooth) { showHeader = true; showChips = true }

            // 2. Cards staggered — 70 ms apart
            for i in 0..<DemoItem.samples.count {
                try? await Task.sleep(nanoseconds: 70_000_000)
                withAnimation(.flowHero) { showCards[i] = true }
            }

            // 3. Footer rows
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.flowSmooth) { showFooter = true }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Text("v\(FlowMotion.version)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Production-grade motion\ninfrastructure for SwiftUI.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Tap any card — it expands with the iOS 18 zoom transition.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Capability chips (plain HStack — no nested ScrollView)

    private var capabilityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Capability.all, id: \.label) { cap in
                    Label(cap.label, systemImage: cap.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(cap.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(cap.color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
        // Explicit height so the horizontal ScrollView doesn't expand
        // vertically and displace the cards below it.
        .frame(height: 38)
    }

    // MARK: - Card stack
    // Each card is conditionally rendered so hidden cards take zero layout space.

    private var cardStack: some View {
        VStack(spacing: 16) {
            ForEach(Array(DemoItem.samples.enumerated()), id: \.element.id) { index, item in
                if index < showCards.count && showCards[index] {
                    FlowMotionLink(id: item.id, namespace: heroNamespace) {
                        DemoCard(item: item)
                            .frame(height: 180)
                    } destination: {
                        CardDetailScreen(item: item, namespace: heroNamespace)
                    }
                    .flowSpringTap(scale: 0.96)
                    .padding(.horizontal, 20)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .center)),
                            removal:   .opacity
                        )
                    )
                }
            }
        }
    }

    // MARK: - System demo row

    private var systemDemoRow: some View {
        HStack(spacing: 12) {
            FlowLink(transition: .slide(), label: {
                systemCard(title: "Presets",    subtitle: "MotionStyle",  icon: "slider.horizontal.3",  colors: [.teal, .cyan])
            }, destination: {
                TransitionShowcaseScreen()
            })

            FlowLink(transition: .cinematic(), label: {
                systemCard(title: "Onboarding", subtitle: "Cinematic",   icon: "play.rectangle.fill",  colors: [.indigo, .purple])
            }, destination: {
                OnboardingScreen()
            })
        }
        .padding(.horizontal, 20)
    }

    private func systemCard(title: String, subtitle: String, icon: String, colors: [Color]) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: icon).font(.title3).foregroundStyle(.white.opacity(0.85))
                Text(title).font(.headline.bold()).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Orchestrator + Gesture cards

    private var orchestratorCard: some View {
        FlowLink(transition: .reveal, label: {
            navRow(icon: "timeline.selection", iconColor: .orange,
                   title: "Timeline Orchestrator",
                   subtitle: "Parallel { }, Group { }, nested timelines")
        }, destination: {
            TimelineOrchestratorScreen()
        })
    }

    private var gestureCard: some View {
        FlowLink(transition: .slide(edge: .trailing), label: {
            navRow(icon: "hand.draw.fill", iconColor: .pink,
                   title: "Gesture Playground",
                   subtitle: "Velocity handoff, spring drag, interactive dismiss")
        }, destination: {
            GesturePlaygroundScreen()
        })
    }

    private func navRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: icon).font(.title3).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }
}

// MARK: - Capability chips data

private struct Capability {
    let label: String
    let icon: String
    let color: Color

    static let all: [Capability] = [
        Capability(label: "Zoom Transition", icon: "arrow.up.left.and.arrow.down.right", color: .blue),
        Capability(label: "Spring Physics",  icon: "waveform.path",      color: .purple),
        Capability(label: "Shared Elements", icon: "star.fill",          color: .orange),
        Capability(label: "Liquid Effects",  icon: "drop.fill",          color: .cyan),
        Capability(label: "Timeline DSL",    icon: "timeline.selection", color: .indigo),
        Capability(label: "Swift 6",         icon: "swift",              color: .orange),
    ]
}

#Preview {
    FlowNavigationStack {
        HomeScreen()
    }
    .flowStyle(.cinematic)
}
