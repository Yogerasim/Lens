#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_xraypop(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float3 inv = 1.0 - src.rgb;
    float y = luma(inv);

    float3 coldA = float3(0.05, 0.30, 0.75);
    float3 coldB = float3(0.30, 0.95, 1.00);
    float3 coldC = float3(0.92, 1.00, 1.00);

    float3 xray;
    if (y < 0.35) {
        xray = mix(coldA, coldB, y / 0.35);
    } else {
        xray = mix(coldB, coldC, (y - 0.35) / 0.65);
    }

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 px = 1.0 / texSize;

    float tl = luma(tex.sample(s, uv + float2(-px.x, -px.y)).rgb);
    float t0 = luma(tex.sample(s, uv + float2( 0.0, -px.y)).rgb);
    float tr = luma(tex.sample(s, uv + float2( px.x, -px.y)).rgb);
    float l0 = luma(tex.sample(s, uv + float2(-px.x,  0.0)).rgb);
    float r0 = luma(tex.sample(s, uv + float2( px.x,  0.0)).rgb);
    float bl = luma(tex.sample(s, uv + float2(-px.x,  px.y)).rgb);
    float b0 = luma(tex.sample(s, uv + float2( 0.0,  px.y)).rgb);
    float br = luma(tex.sample(s, uv + float2( px.x,  px.y)).rgb);

    float gx = -tl - 2.0*l0 - bl + tr + 2.0*r0 + br;
    float gy = -tl - 2.0*t0 - tr + bl + 2.0*b0 + br;
    float edge = sqrt(gx * gx + gy * gy);

    float edgeMask = smoothstep(mix(0.10, 0.05, t), mix(0.24, 0.10, t), edge);
    xray += float3(0.55, 0.95, 1.00) * edgeMask * (0.08 + 0.45 * t);

    float shadow = 1.0 - smoothstep(0.0, 0.40, y);
    xray = mix(xray, float3(0.02, 0.08, 0.20), shadow * (0.18 + 0.25 * t));

    xray = gentleTonemap(xray);
    xray = softContrast(xray, 0.14 + 0.22 * t);
    xray = softSaturation(xray, 0.12 + 0.28 * t);

    float3 outC = mix(src.rgb, clamp(xray, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
