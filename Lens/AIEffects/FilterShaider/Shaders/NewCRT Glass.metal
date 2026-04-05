#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_crtglass(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float t = premiumCurve(u.intensity);

    float2 p = uv * 2.0 - 1.0;
    float bend = 0.03 + 0.05 * t;
    p *= 1.0 + dot(p, p) * bend;
    float2 crtUV = p * 0.5 + 0.5;

    float4 src = tex.sample(s, clamp(crtUV, 0.0, 1.0));

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float px = 1.0 / texSize.x;

    float ca = 0.0008 + 0.0025 * t;
    float r = tex.sample(s, clamp(crtUV + float2(ca + px * 0.25, 0.0), 0.0, 1.0)).r;
    float g = tex.sample(s, clamp(crtUV, 0.0, 1.0)).g;
    float b = tex.sample(s, clamp(crtUV - float2(ca + px * 0.25, 0.0), 0.0, 1.0)).b;

    float3 col = float3(r, g, b);

    float scan = sin(crtUV.y * texSize.y * 1.25) * 0.5 + 0.5;
    float scanMask = 1.0 - pow(scan, 10.0) * (0.05 + 0.10 * t);
    col *= scanMask;

    float subpix = sin(crtUV.x * texSize.x * 2.2);
    col *= 0.98 + 0.02 * subpix;

    float glow = smoothstep(0.55, 1.0, luma(src.rgb));
    col += float3(0.10, 0.14, 0.18) * glow * (0.05 + 0.12 * t);

    float vig = dot(uv - 0.5, uv - 0.5);
    col *= 1.0 - smoothstep(0.10, 0.34, vig) * (0.15 + 0.35 * t);

    col = gentleTonemap(col);
    col = softContrast(col, 0.08 + 0.18 * t);
    col = softSaturation(col, 0.04 + 0.08 * t);

    return float4(clamp(mix(src.rgb, col, t), 0.0, 1.0), 1.0);
}
