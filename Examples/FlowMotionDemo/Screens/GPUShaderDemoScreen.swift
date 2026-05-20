import SwiftUI
import FlowMotion

struct GPUShaderDemoScreen: View {

    @State private var selectedDemo: ShaderDemo = .metaball
    @State private var rippleTrigger = false
    @State private var chromaticIntensity: Float = 4
    @Environment(\.shaderQuality) private var quality

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                demoPicker
                demoCanvas
                qualityBadge
                codeCard
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("GPU Shaders")
        .navigationBarTitleDisplayMode(.inline)
        .flowFPSOverlay(enabled: true)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPU Shader Effects")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)

            Text("True per-pixel effects via Metal fragment shaders — layerEffect, colorEffect, and distortionEffect.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Picker

    private var demoPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShaderDemo.allCases, id: \.self) { demo in
                    Button {
                        withAnimation(.flowSnappy) { selectedDemo = demo }
                    } label: {
                        Label(demo.label, systemImage: demo.icon)
                            .font(.caption.weight(selectedDemo == demo ? .semibold : .regular))
                            .foregroundStyle(selectedDemo == demo ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedDemo == demo ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .flowSpringTap(scale: 0.95)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Demo canvas

    @ViewBuilder
    private var demoCanvas: some View {
        switch selectedDemo {
        case .metaball:     metaballDemo
        case .ripple:       rippleDemo
        case .chromatic:    chromaticDemo
        }
    }

    // MARK: Metaball demo

    private var metaballDemo: some View {
        VStack(spacing: 16) {
            Text("True Per-Pixel Metaball")
                .font(.headline)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(["Ocean", "Sunset", "Midnight"], id: \.self) { name in
                    MetaballShaderView(config: configForName(name))
                        .frame(height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .leading) {
                            Text(name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                        }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func configForName(_ name: String) -> MetaballShaderConfig {
        switch name {
        case "Sunset":   return .sunset
        case "Midnight": return .midnight
        default:         return .ocean
        }
    }

    // MARK: Ripple demo

    private var rippleDemo: some View {
        VStack(spacing: 16) {
            Text("Touch Ripple Distortion")
                .font(.headline)
                .padding(.horizontal, 20)

            ZStack {
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 8) {
                    Image(systemName: "wave.3.right").font(.system(size: 32)).foregroundStyle(.white)
                    Text("Tap for ripple").font(.callout.bold()).foregroundStyle(.white)
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .flowRipple(trigger: rippleTrigger, amplitude: 22)
            .padding(.horizontal, 20)
            .onTapGesture { rippleTrigger.toggle() }
        }
    }

    // MARK: Chromatic demo

    private var chromaticDemo: some View {
        VStack(spacing: 16) {
            Text("Chromatic Aberration")
                .font(.headline)
                .padding(.horizontal, 20)

            ZStack {
                LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)

                VStack(spacing: 8) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text("RGB Split")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .flowShader(.chromatic(intensity: chromaticIntensity, origin: CGPoint(x: 0.5, y: 0.5)))
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                Text("Intensity: \(Int(chromaticIntensity))px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: .init(get: { Double(chromaticIntensity) }, set: { chromaticIntensity = Float($0) }), in: 0...16)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Quality badge

    private var qualityBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(quality.useGPUShaders ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(quality.useGPUShaders ? "GPU shaders active" : "Canvas fallback (low quality mode)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Code card

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Swift Code", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)

            Text(selectedDemo.codeSnippet)
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
}

// MARK: - ShaderDemo

private enum ShaderDemo: CaseIterable, Hashable {
    case metaball, ripple, chromatic

    var label: String {
        switch self {
        case .metaball:  return "Metaball"
        case .ripple:    return "Ripple"
        case .chromatic: return "Chromatic"
        }
    }

    var icon: String {
        switch self {
        case .metaball:  return "drop.fill"
        case .ripple:    return "wave.3.right"
        case .chromatic: return "camera.aperture"
        }
    }

    var codeSnippet: String {
        switch self {
        case .metaball:
            return """
            MetaballShaderView(config: .ocean)
                .frame(height: 80)
            // GPU fragment shader — true per-pixel
            // metaball field, no Canvas approximation
            """
        case .ripple:
            return """
            MyView()
                .flowRipple(
                    trigger: tapped,
                    amplitude: 22
                )
            """
        case .chromatic:
            return """
            MyView()
                .flowShader(.chromatic(
                    intensity: 4,
                    origin: CGPoint(x: 0.5, y: 0.5)
                ))
            """
        }
    }
}

#Preview {
    FlowNavigationStack {
        GPUShaderDemoScreen()
    }
}
