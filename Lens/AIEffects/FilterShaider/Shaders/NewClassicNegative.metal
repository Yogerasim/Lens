#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_classicnegative(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float3 neg = 1.0 - src.rgb;
    neg = gentleTonemap(neg);
    neg = softContrast(neg, 0.10 + 0.20 * t);
    neg = softSaturation(neg, 0.02 + 0.08 * t);

    float3 outC = mix(src.rgb, clamp(neg, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
