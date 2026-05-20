import SwiftUI
import FlowMotion

// MARK: - HomeScreen

struct HomeScreen: View {

    @Namespace private var heroNamespace
    @Environment(\.flowStyle) private var style

    @State private var showAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                capabilityChips
                    .padding(.bottom, 12)

                cardStack

                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)

                    systemDemoRow
                    phase2Row
                    orchestratorCard
                    gestureCard
                    scrollReactionsCard
                    transitionComposeCard
                }
                .opacity(showAll ? 1 : 0)
                .offset(y: showAll ? 0 : 16)
                .animation(.flowHero.delay(0.45), value: showAll)
            }
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("FlowMotion")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .task {
            guard !showAll else { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
            await MainActor.run {
                withAnimation(.flowHero) { showAll = true }
            }
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
        .opacity(showAll ? 1 : 0)
        .offset(y: showAll ? 0 : 8)
        .animation(.flowSmooth, value: showAll)
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
        .opacity(showAll ? 1 : 0)
        .animation(.flowSmooth.delay(0.05), value: showAll)
    }

    // MARK: - Card stack
    //
    // Cards use frame(height:) + padding animation instead of opacity(0) or
    // conditional rendering. When showAll = false, height = 0 and bottom
    // padding = 0 → zero layout space, no gap. When showAll = true, height
    // springs to 180 and padding springs to 16, staggered per card.

    private var cardStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(DemoItem.samples.enumerated()), id: \.element.id) { index, item in
                FlowMotionLink(id: item.id, namespace: heroNamespace) {
                    DemoCard(item: item)
                } destination: {
                    CardDetailScreen(item: item, namespace: heroNamespace)
                }
                .flowSpringTap(scale: 0.96)
                .frame(height: showAll ? 180 : 0)
                .padding(.horizontal, 20)
                .padding(.bottom, showAll ? 16 : 0)
                .opacity(showAll ? 1 : 0)
                .clipped()
                .allowsHitTesting(showAll)
                .animation(
                    .flowHero.delay(Double(index) * 0.07),
                    value: showAll
                )
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

    // MARK: - Phase 2 row

    private var phase2Row: some View {
        HStack(spacing: 12) {
            FlowLink(transition: .reveal, label: {
                systemCard(title: "Scroll",  subtitle: "FlowScrollView", icon: "arrow.up.and.down.circle.fill", colors: [.blue, .cyan])
            }, destination: {
                FlowScrollDemoScreen()
            })

            FlowLink(transition: .slide(edge: .trailing), label: {
                systemCard(title: "Compose", subtitle: "Transitions",    icon: "square.3.layers.3d",            colors: [.orange, .pink])
            }, destination: {
                TransitionComposeScreen()
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

    // MARK: - Orchestrator + Gesture + Phase 2 cards

    private var orchestratorCard: some View {
        FlowLink(transition: .reveal, label: {
            navRow(icon: "timeline.selection", iconColor: .orange,
                   title: "Timeline Orchestrator",
                   subtitle: "Parallel { }, Group { }, Keyframes, Stagger")
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

    private var scrollReactionsCard: some View {
        FlowLink(transition: .slide(edge: .trailing), label: {
            navRow(icon: "arrow.up.and.down.circle.fill", iconColor: .blue,
                   title: "Scroll Reactions",
                   subtitle: "Parallax, fade-edge, scale-on-appear")
        }, destination: {
            FlowScrollDemoScreen()
        })
    }

    private var transitionComposeCard: some View {
        FlowLink(transition: .reveal, label: {
            navRow(icon: "square.3.layers.3d", iconColor: .orange,
                   title: "Compose Transitions",
                   subtitle: "a.combined(with: b) — layer any two effects")
        }, destination: {
            TransitionComposeScreen()
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
        Capability(label: "Zoom Transition",  icon: "arrow.up.left.and.arrow.down.right", color: .blue),
        Capability(label: "Spring Physics",   icon: "waveform.path",                      color: .purple),
        Capability(label: "Shared Elements",  icon: "star.fill",                          color: .orange),
        Capability(label: "Liquid Effects",   icon: "drop.fill",                          color: .cyan),
        Capability(label: "Timeline DSL",     icon: "timeline.selection",                 color: .indigo),
        Capability(label: "Scroll Reactions", icon: "arrow.up.and.down.circle",           color: .teal),
        Capability(label: "Compose",          icon: "square.3.layers.3d",                 color: .pink),
        Capability(label: "Swift 6",          icon: "swift",                              color: .orange),
    ]
}

#Preview {
    FlowNavigationStack {
        HomeScreen()
    }
    .flowStyle(.cinematic)
}
