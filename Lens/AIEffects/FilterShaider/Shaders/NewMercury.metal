#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_mercury(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float time = u.time;
    float t = premiumCurve(u.intensity);

    float2 flow;
    flow.x = sin(uv.y * 20.0 + time * 1.3) * (0.002 + 0.010 * t);
    flow.y = cos(uv.x * 18.0 - time * 1.1) * (0.002 + 0.008 * t);

    float2 uv2 = uv + flow;
    float3 src = tex.sample(s, uv).rgb;
    float3 warped = tex.sample(s, clamp(uv2, 0.0, 1.0)).rgb;

    float y = luma(warped);
    float3 metal = mix(float3(y), float3(0.78, 0.83, 0.90) * y + float3(0.04, 0.05, 0.07), 0.78);

    float spec = pow(smoothstep(0.45, 1.0, y), 2.5);
    metal += float3(0.35, 0.40, 0.48) * spec * (0.08 + 0.22 * t);

    metal = gentleTonemap(metal);
    metal = softContrast(metal, 0.10 + 0.20 * t);
    metal = softSaturation(metal, 0.02 + 0.06 * t);

    return float4(clamp(mix(src, metal, t), 0.0, 1.0), 1.0);
}
