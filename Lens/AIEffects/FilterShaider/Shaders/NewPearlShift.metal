#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_pearlshift(
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

    float sheen = sin((uv.x * 0.8 + uv.y * 1.2) * 12.0 + time * 0.9) * 0.5 + 0.5;
    float3 pink = float3(1.00, 0.82, 0.92);
    float3 cyan = float3(0.80, 0.95, 1.00);

    float3 pearl = mix(pink, cyan, sheen);
    float highlight = smoothstep(0.35, 1.0, y);

    float3 col = mix(src, pearl * y + float3(0.08), 0.18 + 0.22 * t);
    col += pearl * highlight * (0.04 + 0.14 * t);

    col = gentleTonemap(col);
    col = softContrast(col, 0.04 + 0.08 * t);
    col = softSaturation(col, 0.06 + 0.12 * t);

    return float4(clamp(mix(src, col, t), 0.0, 1.0), 1.0);
}
