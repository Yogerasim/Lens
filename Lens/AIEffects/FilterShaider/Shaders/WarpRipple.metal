#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_ripple(
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

    float2 center = uv - 0.5;
    float r = length(center);

    float wave = sin(r * 20.0 - time * 4.0) * 0.003 * t;

    float2 warpedUV = uv + normalize(center) * wave;

    float3 col = tex.sample(s, warpedUV).rgb;

    col = gentleTonemap(col);
    col = softContrast(col, 0.2 * t);

    float3 outC = mix(src.rgb, col, t);
    return float4(outC, 1.0);
}
