#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float3 holo_holo(float x) {
    return 0.5 + 0.5 * cos(6.28318 * (x + float3(0.0, 0.33, 0.67)));
}

fragment float4 fragment_hologram(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float time = u.time;

    float band = uv.y * 2.2 + sin(time * 0.7 + uv.x * 7.0) * 0.22;
    float3 hcol = holo_holo(band);

    float y = luma(src.rgb);
    float3 col = mix(src.rgb, hcol, (0.35 + 0.45 * y));

    float scan = sin((uv.y * 900.0) + time * 10.0) * 0.5 + 0.5;
    scan = pow(scan, 10.0) * (0.03 + 0.08 * t);
    col += float3(0.2, 0.9, 1.0) * scan;

    col = gentleTonemap(col);
    col = softContrast(col, 0.20 + 0.15 * t);
    col = softSaturation(col, 0.20 + 0.10 * t);

    float3 outC = mix(src.rgb, col, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
