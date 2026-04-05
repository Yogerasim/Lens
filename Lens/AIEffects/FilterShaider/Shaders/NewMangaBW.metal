#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_mangabw(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float y = luma(src.rgb);
    float bw = smoothstep(0.42, 0.58, y);

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

    float edgeMask = smoothstep(mix(0.22, 0.09, t), mix(0.30, 0.14, t), edge);

    float2 p = uv * texSize * mix(0.55, 0.85, t);
    float halftone = bayer4x4(p);

    float shade = smoothstep(0.18, 0.85, y);
    float dots = step(halftone, 1.0 - shade);

    float base = mix(bw, dots, 0.35 + 0.40 * t);
    base = mix(base, 0.0, edgeMask * (0.45 + 0.45 * t));

    float3 outC = float3(clamp(base, 0.0, 1.0));
    return float4(mix(src.rgb, outC, t), 1.0);
}
