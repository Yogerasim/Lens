#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float signal_hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

fragment float4 fragment_signalloss(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float time = u.time;
    float t = premiumCurve(u.intensity);

    float row = floor(uv.y * 180.0);
    float shiftRnd = signal_hash21(float2(row, floor(time * 8.0)));
    float shift = (shiftRnd - 0.5) * (0.010 + 0.040 * t);

    float stripe = step(0.92 - 0.12 * t, signal_hash21(float2(floor(time * 5.0), row * 0.17)));
    float2 uvShift = uv + float2(shift * stripe, 0.0);

    float ca = 0.001 + 0.004 * t;
    float3 col;
    col.r = tex.sample(s, clamp(uvShift + float2(ca, 0.0), 0.0, 1.0)).r;
    col.g = tex.sample(s, clamp(uvShift, 0.0, 1.0)).g;
    col.b = tex.sample(s, clamp(uvShift - float2(ca, 0.0), 0.0, 1.0)).b;

    float packet = step(0.975 - 0.03 * t, signal_hash21(float2(floor(uv.y * 55.0), floor(time * 9.0))));
    col = mix(col, col.bgr * float3(0.8, 1.0, 1.2), packet * 0.35);

    float noise = signal_hash21(floor(uv * float2(tex.get_width(), tex.get_height())) + floor(time * 24.0));
    col += (noise - 0.5) * (0.03 + 0.08 * t);

    col = gentleTonemap(col);
    col = softContrast(col, 0.06 + 0.18 * t);

    float3 src = tex.sample(s, uv).rgb;
    return float4(clamp(mix(src, col, t), 0.0, 1.0), 1.0);
}
