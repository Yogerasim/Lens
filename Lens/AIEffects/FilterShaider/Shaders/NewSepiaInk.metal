#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_sepiaink(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float3 c = gentleTonemap(src.rgb);

    float y = luma(c);
    float3 sepia = float3(
        y * 1.15,
        y * 0.94,
        y * 0.62
    );

    sepia = softContrast(sepia, 0.12 + 0.28 * t);
    sepia = softSaturation(sepia, 0.05 + 0.10 * t);

    float levels = mix(14.0, 6.0, t);
    sepia = floor(sepia * levels + 0.5) / levels;

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

    float edgeTh = mix(0.20, 0.09, t);
    float edgeSoft = mix(0.08, 0.04, t);
    float edgeMask = smoothstep(edgeTh, edgeTh + edgeSoft, edge);

    float3 ink = float3(0.05, 0.03, 0.02);
    sepia = mix(sepia, ink, edgeMask * (0.35 + 0.50 * t));

    float2 p = uv * texSize;
    float b = bayer4x4(p);
    float paper = (b - 0.5) * (0.015 + 0.02 * t);
    sepia += paper;

    sepia = clamp(sepia, 0.0, 1.0);

    return float4(mix(src.rgb, sepia, t), 1.0);
}
