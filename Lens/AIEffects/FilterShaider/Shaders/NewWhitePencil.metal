#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_whitepencil(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

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

    float edgeMask = smoothstep(mix(0.08, 0.04, t), mix(0.22, 0.10, t), edge);

    float y = luma(src.rgb);
    float darkBase = 1.0 - smoothstep(0.0, 0.9, y);
    darkBase *= 0.20 + 0.25 * t;

    float hatch1 = sin((uv.x + uv.y) * 900.0) * 0.5 + 0.5;
    float hatch2 = sin((uv.x - uv.y) * 700.0) * 0.5 + 0.5;
    float hatch = mix(hatch1, hatch2, 0.5);

    float grain = bayer4x4(uv * texSize * 0.8);
    float pencil = edgeMask * (0.70 + 0.25 * hatch + 0.10 * grain);

    float base = clamp(darkBase + pencil, 0.0, 1.0);
    float3 effect = float3(base);

    effect = softContrast(effect, 0.10 + 0.15 * t);

    float3 outC = mix(src.rgb, effect, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
