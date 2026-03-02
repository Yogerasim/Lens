#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_scanlines(
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

    float scan = sin(uv.y * 800.0 + time * 6.0) * 0.5 + 0.5;
    scan = pow(scan, 3.0);

    float glow = sin(time * 2.0) * 0.5 + 0.5;

    float3 col = src.rgb;
    col += float3(0.0, 0.8, 1.0) * scan * 0.15 * (0.4 + glow);

    col = softContrast(col, 0.25 * t);

    float3 outC = mix(src.rgb, col, t);
    return float4(outC, 1.0);
}
