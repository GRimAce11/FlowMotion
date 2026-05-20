#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 flowChromatic(
    float2 position,
    SwiftUI::Layer layer,
    float2 viewSize    [[buffer(0)]],
    float  intensity   [[buffer(1)]],   // aberration strength in pixels
    float2 origin      [[buffer(2)]]    // center of aberration (typically 0.5,0.5 * size)
) {
    float2 dir = normalize(position - origin);
    float  dist = length(position - origin) / length(viewSize);

    float offset = intensity * dist;

    half4 r = layer.sample(position + dir * offset);
    half4 g = layer.sample(position);
    half4 b = layer.sample(position - dir * offset);

    return half4(r.r, g.g, b.b, g.a);
}
