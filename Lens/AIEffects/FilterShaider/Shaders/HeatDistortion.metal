// HeatDistortion.metal
#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float heat_hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

fragment float4 fragment_heatdistort(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float time = u.time;

    float band = sin((uv.y * 24.0 + time * 2.6)) * 0.5 + 0.5;
    band = pow(band, 2.0);

    float jitter = sin(uv.y * 90.0 + time * 7.0) * (0.0008 + 0.0045 * t);
    float micro = (heat_hash21(float2(floor(uv.x * 240.0), floor((uv.y + time * 0.4) * 240.0))) - 0.5) * (0.0008 + 0.0035 * t);

    float2 uvW = uv + float2(jitter + micro, 0.0) * (0.25 + 0.75 * band);

    float3 col = tex.sample(s, uvW).rgb;

    float hot = smoothstep(0.15, 0.85, band) * t;
    col = mix(col, col + float3(0.08, 0.03, -0.02) * hot, 0.7);

    col = gentleTonemap(col);
    col = softContrast(col, 0.06 + 0.16 * t);
    col = softSaturation(col, 0.06 + 0.10 * t);

    float3 outC = mix(src.rgb, clamp(col, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
