#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_blueprintink(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
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
    float edgeMask = smoothstep(0.08, 0.18, edge);

    float gridX = step(0.98, fract(uv.x * 24.0));
    float gridY = step(0.98, fract(uv.y * 24.0));
    float grid = max(gridX, gridY) * (0.10 + 0.08 * t);

    float3 paper = float3(0.06, 0.20, 0.55);
    float3 ink = float3(0.90, 0.96, 1.00);

    float y = luma(src);
    float fill = 1.0 - smoothstep(0.20, 0.85, y);
    float3 col = paper + float3(grid);
    col = mix(col, ink, edgeMask * (0.55 + 0.35 * t));
    col = mix(col, ink * 0.85, fill * 0.08);

    return float4(clamp(mix(src, col, t), 0.0, 1.0), 1.0);
}
