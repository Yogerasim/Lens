#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_electricaura(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float time = u.time;
    float t = premiumCurve(u.intensity);

    float3 src = tex.sample(s, uv).rgb;
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
    float edgeMask = smoothstep(0.07, 0.20, edge);

    float pulse = 0.5 + 0.5 * sin(time * 3.0);
    float3 aura = float3(
        0.5 + 0.5 * sin(time * 0.8 + uv.x * 4.0 + 0.0),
        0.5 + 0.5 * sin(time * 0.8 + uv.x * 4.0 + 2.0),
        0.5 + 0.5 * sin(time * 0.8 + uv.x * 4.0 + 4.0)
    );

    float3 darkBase = src * (0.20 + 0.22 * (1.0 - t));
    float3 col = darkBase + aura * edgeMask * (0.20 + 0.85 * t) * (0.75 + 0.25 * pulse);

    col = gentleTonemap(col);
    col = softContrast(col, 0.10 + 0.20 * t);
    col = softSaturation(col, 0.16 + 0.30 * t);

    return float4(clamp(mix(src, col, t), 0.0, 1.0), 1.0);
}
