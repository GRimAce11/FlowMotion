import SwiftUI
import FlowMotion

// MARK: - HomeScreen

struct HomeScreen: View {

    @Namespace private var heroNamespace
    @Environment(\.flowStyle) private var style

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

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
        .onAppear {
            guard !appeared else { return }
            appeared = true
            // Short delay so NavigationStack's own appear animation finishes first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showAll = true
                }
            }
        }
    }

    @State private var showAll = false

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

            Text("Tap any card to see it expand with a zoom transition.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .opacity(showAll ? 1 : 0)
        .offset(y: showAll ? 0 : 10)
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
        .opacity(showAll ? 1 : 0)
    }

    // MARK: - Card grid

    private var cardGrid: some View {
        LazyVStack(spacing: 16) {
            // Feature demo cards — each uses the native zoom transition
            ForEach(Array(DemoItem.samples.enumerated()), id: \.element.id) { index, item in
                FlowMotionLink(id: item.id, namespace: heroNamespace) {
                    DemoCard(item: item)
                        .frame(height: 180)
                } destination: {
                    CardDetailScreen(item: item, namespace: heroNamespace)
                }
                .flowSpringTap(scale: 0.96)
                .padding(.horizontal, 20)
                .opacity(showAll ? 1 : 0)
                .scaleEffect(showAll ? 1 : 0.93)
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.82)
                        .delay(0.1 + Double(index) * 0.06),
                    value: showAll
                )
            }

            Divider().padding(.horizontal, 20).padding(.vertical, 8)

            systemDemoRow

            orchestratorCard

            gestureCard
        }
        .padding(.bottom, 40)
    }

    // MARK: - System demo row

    private var systemDemoRow: some View {
        HStack(spacing: 12) {
            FlowLink(transition: .slide(), label: {
                systemCard(title: "Presets", subtitle: "MotionStyle", icon: "slider.horizontal.3", colors: [.teal, .cyan])
            }, destination: {
                TransitionShowcaseScreen()
            })

            FlowLink(transition: .cinematic(), label: {
                systemCard(title: "Onboarding", subtitle: "Cinematic", icon: "play.rectangle.fill", colors: [.indigo, .purple])
            }, destination: {
                OnboardingScreen()
            })
        }
        .padding(.horizontal, 20)
        .opacity(showAll ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.5), value: showAll)
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
    }

    // MARK: - Orchestrator card

    private var orchestratorCard: some View {
        FlowLink(transition: .reveal, label: {
            navRow(
                icon: "timeline.selection", iconColor: .orange,
                title: "Timeline Orchestrator",
                subtitle: "Parallel { }, Group { }, nested timelines"
            )
        }, destination: {
            TimelineOrchestratorScreen()
        })
        .opacity(showAll ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.55), value: showAll)
    }

    // MARK: - Gesture card

    private var gestureCard: some View {
        FlowLink(transition: .slide(edge: .trailing), label: {
            navRow(
                icon: "hand.draw.fill", iconColor: .pink,
                title: "Gesture Playground",
                subtitle: "Velocity handoff, spring drag, interactive dismiss"
            )
        }, destination: {
            GesturePlaygroundScreen()
        })
        .opacity(showAll ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.60), value: showAll)
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

// MARK: - Capability chips

private struct Capability {
    let label: String
    let icon: String
    let color: Color

    static let all: [Capability] = [
        Capability(label: "Zoom Transition", icon: "arrow.up.left.and.arrow.down.right", color: .blue),
        Capability(label: "Spring Physics",  icon: "waveform.path",          color: .purple),
        Capability(label: "Shared Elements", icon: "star.fill",              color: .orange),
        Capability(label: "Liquid",          icon: "drop.fill",              color: .cyan),
        Capability(label: "Timeline DSL",    icon: "timeline.selection",     color: .indigo),
        Capability(label: "Swift 6",         icon: "swift",                  color: .orange),
    ]
}

#Preview {
    FlowNavigationStack {
        HomeScreen()
    }
    .flowStyle(.cinematic)
}
