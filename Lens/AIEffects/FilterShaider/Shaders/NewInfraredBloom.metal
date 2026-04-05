#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_infraredbloom(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float3 c = src.rgb;
    float y = luma(c);

    float hotMask = smoothstep(0.45, 0.95, y);
    float shadowMask = 1.0 - smoothstep(0.08, 0.45, y);

    float3 irBase = float3(
        y * 1.15 + c.r * 0.20,
        y * 0.65 + c.g * 0.10,
        y * 0.95 + c.b * 0.20
    );

    float3 hotGlow = float3(1.00, 0.45, 0.85) * hotMask;
    float3 coolShadow = mix(float3(0.10, 0.75, 0.95), float3(0.70, 0.20, 0.95), uv.y * 0.5 + 0.5);

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 px = 1.0 / texSize;

    float3 blur =
        tex.sample(s, uv + float2( px.x, 0.0)).rgb +
        tex.sample(s, uv + float2(-px.x, 0.0)).rgb +
        tex.sample(s, uv + float2(0.0,  px.y)).rgb +
        tex.sample(s, uv + float2(0.0, -px.y)).rgb;
    blur *= 0.25;

    float bloomMask = smoothstep(0.55, 1.0, luma(blur));
    irBase += hotGlow * bloomMask * (0.15 + 0.55 * t);
    irBase = mix(irBase, coolShadow, shadowMask * (0.18 + 0.35 * t));

    irBase = gentleTonemap(irBase);
    irBase = softContrast(irBase, 0.10 + 0.22 * t);
    irBase = softSaturation(irBase, 0.12 + 0.35 * t);

    float3 outC = mix(src.rgb, clamp(irBase, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
