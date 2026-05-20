import SwiftUI
import FlowMotion

// MARK: - DemoCard

struct DemoCard: View {
    let item: DemoItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: item.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: item.icon)
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(24)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: item.gradient.first?.opacity(0.4) ?? .clear, radius: 20, y: 8)
    }
}

// MARK: - Preview

#Preview {
    DemoCard(item: DemoItem.samples[0])
        .frame(height: 200)
        .padding()
}
