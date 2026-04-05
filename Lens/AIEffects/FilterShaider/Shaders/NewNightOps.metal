#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float night_hash21(float2 p) {
    return fract(sin(dot(p, float2(91.3, 173.7))) * 43758.5453);
}

fragment float4 fragment_nightops(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float time = u.time;
    float t = premiumCurve(u.intensity);

    float3 src = tex.sample(s, uv).rgb;
    float y = luma(src);

    float3 green = float3(0.10, 0.95, 0.35) * y;
    float3 amber = float3(1.00, 0.72, 0.20) * y;
    float mode = step(0.5, fract(u.demoPhase * 0.37)); // если хочешь потом переключать
    float3 mono = mix(green, amber, mode * 0.0); // сейчас всегда green

    float glow = smoothstep(0.55, 1.0, y);
    mono += float3(0.10, 0.20, 0.08) * glow * (0.04 + 0.12 * t);

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
    mono += float3(0.05, 0.18, 0.05) * smoothstep(0.08, 0.22, edge) * (0.15 + 0.30 * t);

    float noise = night_hash21(floor(uv * texSize) + floor(time * 20.0));
    mono += (noise - 0.5) * (0.03 + 0.08 * t);

    float vig = dot(uv - 0.5, uv - 0.5);
    mono *= 1.0 - smoothstep(0.08, 0.34, vig) * (0.20 + 0.35 * t);

    return float4(clamp(mix(src, mono, t), 0.0, 1.0), 1.0);
}
