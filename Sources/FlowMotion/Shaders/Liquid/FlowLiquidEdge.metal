#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] float2 flowLiquidEdge(
    float2 position,
    float2 viewSize   [[buffer(0)]],
    float progress    [[buffer(1)]],   // 0=hidden, 1=fully visible
    float frequency   [[buffer(2)]],   // wave spatial frequency
    float amplitude   [[buffer(3)]],   // max pixel displacement
    float phase       [[buffer(4)]]    // animated phase offset
) {
    float normY     = position.y / viewSize.y;
    float edgeX     = progress * viewSize.x;
    float waveFade  = 1.0 - progress;

    // Sinusoidal displacement proportional to distance from the leading edge
    float distFromEdge = (edgeX - position.x) / max(viewSize.x * 0.2, 1.0);
    float influence     = saturate(distFromEdge) * waveFade;

    float wave = amplitude * sin(normY * frequency * M_PI_F + phase) * influence;

    return float2(position.x + wave, position.y);
}
