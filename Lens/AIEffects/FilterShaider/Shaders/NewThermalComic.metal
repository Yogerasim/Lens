#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float3 thermal_palette(float x) {
    x = clamp(x, 0.0, 1.0);

    float3 c0 = float3(0.05, 0.00, 0.20);
    float3 c1 = float3(0.20, 0.00, 0.60);
    float3 c2 = float3(0.00, 0.60, 1.00);
    float3 c3 = float3(0.00, 1.00, 0.45);
    float3 c4 = float3(1.00, 1.00, 0.10);
    float3 c5 = float3(1.00, 0.35, 0.00);
    float3 c6 = float3(1.00, 1.00, 1.00);

    if (x < 0.16) return mix(c0, c1, x / 0.16);
    if (x < 0.33) return mix(c1, c2, (x - 0.16) / 0.17);
    if (x < 0.50) return mix(c2, c3, (x - 0.33) / 0.17);
    if (x < 0.68) return mix(c3, c4, (x - 0.50) / 0.18);
    if (x < 0.84) return mix(c4, c5, (x - 0.68) / 0.16);
    return mix(c5, c6, (x - 0.84) / 0.16);
}

fragment float4 fragment_thermalcomic(
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
    float3 thermal = thermal_palette(y);

    float levels = mix(14.0, 6.0, t);
    thermal = floor(thermal * levels + 0.5) / levels;

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

    float edgeMask = smoothstep(mix(0.18, 0.08, t), mix(0.28, 0.12, t), edge);
    thermal = mix(thermal, float3(0.03, 0.01, 0.02), edgeMask * (0.40 + 0.50 * t));

    thermal = softContrast(thermal, 0.12 + 0.22 * t);
    thermal = softSaturation(thermal, 0.10 + 0.28 * t);

    float3 outC = mix(src.rgb, clamp(thermal, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
