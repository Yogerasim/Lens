#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_newsprint(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float t = premiumCurve(u.intensity);

    float3 src = tex.sample(s, uv).rgb;
    float y = luma(src);

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 p = uv * texSize * mix(0.20, 0.42, t);

    float angle = 0.55;
    float2 rp = float2(
        cos(angle) * p.x - sin(angle) * p.y,
        sin(angle) * p.x + cos(angle) * p.y
    );

    float halftone = sin(rp.x) * sin(rp.y) * 0.5 + 0.5;
    float inkDots = step(halftone, y);

    float paperNoise = (bayer4x4(uv * texSize * 0.75) - 0.5) * (0.03 + 0.02 * t);
    float3 paper = float3(0.93, 0.90, 0.82) + paperNoise;

    float2 px = 1.0 / texSize;
    float edge = 0.0;
    {
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
        edge = sqrt(gx * gx + gy * gy);
    }

    float edgeMask = smoothstep(0.12, 0.24, edge);
    float3 outC = mix(paper, float3(0.08, 0.07, 0.06), 1.0 - inkDots);
    outC = mix(outC, float3(0.02), edgeMask * (0.45 + 0.35 * t));

    return float4(clamp(mix(src, outC, t), 0.0, 1.0), 1.0);
}
