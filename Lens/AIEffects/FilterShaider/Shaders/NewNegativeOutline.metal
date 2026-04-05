#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_negativeoutline(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float3 c = 1.0 - src.rgb;

    c = gentleTonemap(c);
    c = softContrast(c, 0.18 + 0.35 * t);
    c = softSaturation(c, 0.05 + 0.20 * t);

    float levels = mix(10.0, 5.0, t);
    c = floor(c * levels + 0.5) / levels;

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
    float edge = sqrt(gx*gx + gy*gy);

    float edgeTh = mix(0.20, 0.08, t);
    float edgeSoft = mix(0.08, 0.035, t);
    float edgeMask = smoothstep(edgeTh, edgeTh + edgeSoft, edge);

    float3 whiteInk = float3(1.0);
    c = mix(c, whiteInk, edgeMask * (0.45 + 0.55 * t));

    float glow = pow(edgeMask, 1.2) * (0.04 + 0.12 * t);
    c += glow;

    c = clamp(c, 0.0, 1.0);

    return float4(mix(src.rgb, c, t), 1.0);
}
