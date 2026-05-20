import SwiftUI
import FlowMotion

struct FlowScrollDemoScreen: View {
    var body: some View {
        FlowScrollView {
            VStack(spacing: 0) {
                heroSection
                cardsSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scroll Reactions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.3, blue: 0.8), Color(red: 0.5, green: 0.2, blue: 0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 260)
            .flowScrollEffect(.parallax(depth: 60))

            VStack(spacing: 8) {
                Image(systemName: "arrow.up.and.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                Text("FlowScrollView")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Scroll to see spring reactions")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(height: 260)
        .clipped()
    }

    private var cardsSection: some View {
        VStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { i in
                reactionCard(index: i)
                    .flowScrollEffect(.scaleOnAppear(from: 0.88, spring: .hero))
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 24)
    }

    private func reactionCard(index: Int) -> some View {
        let colors: [[Color]] = [
            [.blue, .purple], [.orange, .pink], [.green, .teal],
            [.red, .orange], [.indigo, .blue], [.pink, .purple],
            [.teal, .green], [.yellow, .orange]
        ]
        let titles = ["Parallax Header", "Scale On Appear", "Fade on Edge",
                      "Spring Physics", "Velocity Handoff", "Hero Transitions",
                      "Liquid Effects", "Timeline DSL"]
        return ZStack(alignment: .leading) {
            LinearGradient(colors: colors[index % colors.count], startPoint: .leading, endPoint: .trailing)
            Text(titles[index % titles.count])
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(20)
        }
        .frame(height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    FlowNavigationStack {
        FlowScrollDemoScreen()
    }
}
