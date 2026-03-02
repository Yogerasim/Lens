#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_comic(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;

    float4 src = tex.sample(s, uv);
    float3 c = src.rgb;

    float t = premiumCurve(u.intensity);

    c = gentleTonemap(c);
    c = softContrast(c, t);
    c = softSaturation(c, t);

    float levels = mix(12.0, 5.5, t);
    float3 q = floor(c * levels + 0.5) / levels;

    float posterMix = smoothstep(0.05, 0.85, t) * 0.70;
    c = mix(c, q, posterMix);

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

    float edgeTh = mix(0.22, 0.10, t);
    float edgeSoft = mix(0.10, 0.06, t);
    float edgeMask = smoothstep(edgeTh, edgeTh + edgeSoft, edge);

    float antiGrime = smoothstep(0.02, 0.12, edge);
    edgeMask *= antiGrime;

    float lineAmount = edgeMask * (0.12 + 0.43 * t);
    float3 ink = float3(0.02, 0.03, 0.05);
    c = mix(c, ink, lineAmount);

    float halftoneOn = smoothstep(0.35, 1.0, t);
    if (halftoneOn > 0.001) {
        float2 p = uv * texSize;
        float b = bayer4x4(p);

        float amp = 0.006 + 0.010 * halftoneOn;

        float y = luma(c);
        float midMask = smoothstep(0.10, 0.35, y) * (1.0 - smoothstep(0.70, 0.95, y));

        c += (b - 0.5) * amp * midMask;
        c = clamp(c, 0.0, 1.0);
    }

    float3 outC = mix(src.rgb, c, t);
    return float4(outC, 1.0);
}
