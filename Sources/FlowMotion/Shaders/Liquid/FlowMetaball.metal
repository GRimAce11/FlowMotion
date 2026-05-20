#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Metaball field contribution from a single blob.
// blobData layout: 8 blobs × 4 floats each = 32 floats
// Per blob: [centerX, centerY, radius, active(0 or 1)]
static float blobInfluence(float2 pos, float cx, float cy, float radius) {
    float2 d = pos - float2(cx, cy);
    float dist2 = dot(d, d);
    return (radius * radius) / max(dist2, 0.5);
}

[[ stitchable ]] half4 flowMetaball(
    float2 position,
    half4 currentColor,
    float2 viewSize           [[buffer(0)]],
    device const float *blobs [[buffer(1)]],  // 32 floats: 8×(cx,cy,r,active)
    float blobCount           [[buffer(2)]],
    float threshold           [[buffer(3)]],
    float softness            [[buffer(4)]],
    float4 colorA             [[buffer(5)]],
    float4 colorB             [[buffer(6)]]
) {
    float field = 0.0;
    int count = min(int(blobCount), 8);
    for (int i = 0; i < count; i++) {
        float active = blobs[i * 4 + 3];
        if (active < 0.5) continue;
        float cx = blobs[i * 4 + 0];
        float cy = blobs[i * 4 + 1];
        float r  = blobs[i * 4 + 2];
        field += blobInfluence(position, cx, cy, r);
    }

    float alpha = smoothstep(threshold - softness, threshold + softness, field);
    if (alpha < 0.002) return half4(0.0);

    float t = saturate((field - threshold) / max(threshold, 0.001));
    float4 col = mix(colorA, colorB, t);
    col.a *= alpha;
    return half4(col);
}

// Low-quality fallback: fewer iterations, coarser threshold
[[ stitchable ]] half4 flowMetaballLow(
    float2 position,
    half4 currentColor,
    float2 viewSize           [[buffer(0)]],
    device const float *blobs [[buffer(1)]],
    float blobCount           [[buffer(2)]],
    float threshold           [[buffer(3)]],
    float4 colorA             [[buffer(4)]],
    float4 colorB             [[buffer(5)]]
) {
    float field = 0.0;
    int count = min(int(blobCount), 4);  // max 4 blobs in low-quality mode
    for (int i = 0; i < count; i++) {
        float cx = blobs[i * 4 + 0];
        float cy = blobs[i * 4 + 1];
        float r  = blobs[i * 4 + 2];
        float2 d = position - float2(cx, cy);
        float dist2 = dot(d, d);
        field += (r * r) / max(dist2, 1.0);
    }
    float alpha = step(threshold, field);
    float4 col = mix(colorA, colorB, saturate(field / (threshold * 2.0)));
    col.a *= alpha;
    return half4(col);
}
