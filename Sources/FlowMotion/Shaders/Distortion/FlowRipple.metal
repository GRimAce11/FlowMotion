#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] float2 flowRipple(
    float2 position,
    float2 origin     [[buffer(0)]],   // ripple center in view pixels
    float  time       [[buffer(1)]],   // elapsed time (seconds)
    float  amplitude  [[buffer(2)]],   // max pixel displacement
    float  frequency  [[buffer(3)]],   // spatial frequency
    float  decay      [[buffer(4)]]    // distance-based falloff
) {
    float2 d    = position - origin;
    float  dist = length(d);
    if (dist < 0.5) return position;

    float envelope = exp(-dist * decay * 0.01) * exp(-time * 2.5);
    float wave     = amplitude * sin(frequency * dist - time * 10.0) * envelope;
    float2 offset  = normalize(d) * wave;
    return position + offset;
}
