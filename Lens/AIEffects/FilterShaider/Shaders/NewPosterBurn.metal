#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_posterburn(
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

    float3 deepPurple = float3(0.18, 0.00, 0.28);
    float3 magenta    = float3(1.00, 0.08, 0.62);
    float3 cyan       = float3(0.00, 0.88, 1.00);
    float3 acidGreen  = float3(0.45, 1.00, 0.12);
    float3 orange     = float3(1.00, 0.42, 0.05);
    float3 yellow     = float3(1.00, 0.92, 0.18);

    float3 poster;
    if (y < 0.16) {
        poster = deepPurple;
    } else if (y < 0.32) {
        poster = magenta;
    } else if (y < 0.50) {
        poster = cyan;
    } else if (y < 0.68) {
        poster = acidGreen;
    } else if (y < 0.84) {
        poster = orange;
    } else {
        poster = yellow;
    }

    float levels = mix(10.0, 4.0, t);
    poster = floor(poster * levels + 0.5) / levels;

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

    float edgeMask = smoothstep(mix(0.18, 0.08, t), mix(0.26, 0.12, t), edge);
    poster = mix(poster, float3(0.02, 0.01, 0.02), edgeMask * (0.45 + 0.45 * t));

    poster = softContrast(poster, 0.10 + 0.25 * t);
    poster = softSaturation(poster, 0.20 + 0.45 * t);

    float3 outC = mix(src.rgb, clamp(poster, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
