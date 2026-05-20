import SwiftUI
import FlowMotion

// MARK: - HomeScreen

struct HomeScreen: View {

    @Namespace private var heroNamespace
    @Environment(\.flowStyle) private var style

    @State private var headerScale:    CGFloat = 0.92
    @State private var headerOpacity:  Double  = 0
    @State private var subtitleOpacity: Double = 0
    @State private var cardsVisible    = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                capabilitySection
                    .padding(.bottom, 8)

                cardGrid
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("FlowMotion")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .onAppear { runEntrance() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Text("v\(FlowMotion.version)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Production-grade motion infrastructure for SwiftUI.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(headerOpacity)
                .scaleEffect(headerScale, anchor: .leading)

            Text("Tap a card to explore. Drag anywhere to feel the spring physics.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .opacity(subtitleOpacity)
        }
    }

    // MARK: - Capability chips

    private var capabilitySection: some View {
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
    }

    // MARK: - Card grid

    private var cardGrid: some View {
        LazyVStack(spacing: 16) {
            // Feature demo cards
            ForEach(Array(DemoItem.samples.enumerated()), id: \.element.id) { index, item in
                FlowMotionLink(id: item.id, namespace: heroNamespace) {
                    DemoCard(item: item)
                        .appear(delay: Double(index) * style.staggerInterval)
                        .frame(height: 180)
                } destination: {
                    CardDetailScreen(item: item, namespace: heroNamespace)
                }
                .flowSpringTap(scale: 0.96)
                .padding(.horizontal, 20)
                .opacity(cardsVisible ? 1 : 0)
                .offset(y: cardsVisible ? 0 : 24)
                .animation(style.primarySpring.swiftUIAnimation.delay(Double(index) * style.staggerInterval), value: cardsVisible)
            }

            Divider().padding(.horizontal, 20).padding(.vertical, 8)

            // System demos
            systemDemoRow

            // Orchestrator section
            orchestratorCard

            // Gesture playground
            gestureCard
        }
        .padding(.bottom, 40)
    }

    // MARK: - System demo row

    private var systemDemoRow: some View {
        HStack(spacing: 12) {
            FlowLink(transition: .slide(), label: {
                systemCard(
                    title: "Presets",
                    subtitle: "MotionStyle",
                    icon: "slider.horizontal.3",
                    colors: [.teal, .cyan]
                )
            }, destination: {
                TransitionShowcaseScreen()
            })

            FlowLink(transition: .cinematic(), label: {
                systemCard(
                    title: "Onboarding",
                    subtitle: "Cinematic",
                    icon: "play.rectangle.fill",
                    colors: [.indigo, .purple]
                )
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
                Image(systemName: icon).font(.title3).foregroundStyle(.white.opacity(0.8))
                Text(title).font(.headline.bold()).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .flowSpringTap()
    }

    // MARK: - Orchestrator card

    private var orchestratorCard: some View {
        FlowLink(transition: .reveal, label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.15)).frame(width: 48, height: 48)
                    Image(systemName: "timeline.selection")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Timeline Orchestrator")
                        .font(.headline)
                    Text("Parallel { }, Group { }, nested timelines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .flowSpringTap()
        }, destination: {
            TimelineOrchestratorScreen()
        })
    }

    // MARK: - Gesture card

    private var gestureCard: some View {
        FlowLink(transition: .slide(edge: .trailing), label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.pink.opacity(0.15)).frame(width: 48, height: 48)
                    Image(systemName: "hand.draw.fill")
                        .font(.title3)
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gesture Playground")
                        .font(.headline)
                    Text("Velocity handoff, spring drag, interactive dismiss")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .flowSpringTap()
        }, destination: {
            GesturePlaygroundScreen()
        })
    }

    // MARK: - Entrance animation

    @MainActor
    private func runEntrance() {
        Task { @MainActor in
            await MotionTimeline(.cinematic) {
                Animate(.hero) {
                    self.headerOpacity  = 1
                    self.headerScale    = 1
                }
                Animate(.smooth, delay: 0.06) { self.subtitleOpacity = 1 }
                Animate(.hero,   delay: 0.12) { self.cardsVisible    = true }
            }.play(tag: "home-entrance")
        }
    }
}

// MARK: - Capability chips data

private struct Capability {
    let label: String
    let icon: String
    let color: Color

    static let all: [Capability] = [
        Capability(label: "Spring Physics",    icon: "waveform.path",           color: .blue),
        Capability(label: "Shared Elements",   icon: "star.fill",               color: .orange),
        Capability(label: "Liquid Transition", icon: "drop.fill",               color: .cyan),
        Capability(label: "Timeline DSL",      icon: "timeline.selection",      color: .purple),
        Capability(label: "Gesture Coord.",    icon: "hand.draw.fill",          color: .pink),
        Capability(label: "Adaptive Quality",  icon: "gauge.with.dots.needle.bottom.50percent", color: .green),
        Capability(label: "Swift 6",           icon: "swift",                   color: .orange),
        Capability(label: "iOS 17+",           icon: "iphone",                  color: .indigo),
    ]
}

#Preview {
    FlowNavigationStack {
        HomeScreen()
    }
    .flowStyle(.cinematic)
}
