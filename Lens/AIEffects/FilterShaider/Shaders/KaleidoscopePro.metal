// KaleidoscopePro.metal
#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float2 kalei_rot(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

fragment float4 fragment_kaleidoscope(
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

    float2 p = uv - 0.5;
    float r = length(p);
    float ang = atan2(p.y, p.x);

    float seg = mix(10.0, 6.0, t);
    float a = 6.28318 / seg;

    float angM = fmod(ang + 6.28318, a);
    angM = abs(angM - a * 0.5);

    float2 q = float2(cos(angM), sin(angM)) * r;

    q = kalei_rot(q, sin(time * 0.35) * 0.25 * t);

    float2 uvK = q + 0.5;

    float3 col = tex.sample(s, uvK).rgb;

    float vign = 1.0 - smoothstep(0.35, 0.75, r) * (0.15 + 0.35 * t);
    col *= vign;

    col = gentleTonemap(col);
    col = softContrast(col, 0.10 + 0.18 * t);
    col = softSaturation(col, 0.08 + 0.14 * t);

    float3 outC = mix(src.rgb, clamp(col, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
