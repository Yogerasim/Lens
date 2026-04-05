#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_holofoil(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float time = u.time;
    float t = premiumCurve(u.intensity);

    float3 src = tex.sample(s, uv).rgb;
    float y = luma(src);

    float band1 = sin((uv.x + uv.y) * 18.0 + time * 1.4) * 0.5 + 0.5;
    float band2 = sin((uv.x - uv.y) * 24.0 - time * 1.1) * 0.5 + 0.5;
    float band3 = sin(uv.y * 36.0 + time * 0.8) * 0.5 + 0.5;

    float3 holo = float3(band1, band2, band3);
    holo = mix(float3(y), holo, 0.50 + 0.35 * t);

    float sheen = smoothstep(0.35, 1.0, y);
    float3 pearl = float3(0.86, 0.92, 1.00);
    float3 col = mix(src, pearl * y, 0.20 + 0.25 * t);
    col += holo * sheen * (0.06 + 0.22 * t);

    col = gentleTonemap(col);
    col = softContrast(col, 0.08 + 0.14 * t);
    col = softSaturation(col, 0.10 + 0.20 * t);

    return float4(clamp(mix(src, col, t), 0.0, 1.0), 1.0);
}
