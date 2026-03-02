#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_rgbsplit(
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

    float amount = (0.002 + 0.02 * t);

    float2 shift = float2(
        sin(time * 1.7 + uv.y * 12.0),
        cos(time * 1.3 + uv.x * 10.0)
    ) * amount;

    float3 col;
    col.r = tex.sample(s, uv + shift).r;
    col.g = tex.sample(s, uv).g;
    col.b = tex.sample(s, uv - shift).b;

    col = gentleTonemap(col);
    col = softContrast(col, 0.3 * t);

    float3 outC = mix(src.rgb, col, t);
    return float4(outC, 1.0);
}
