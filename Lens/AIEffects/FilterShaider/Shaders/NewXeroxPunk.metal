#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float xerox_noise(float2 p) {
    return fract(sin(dot(p, float2(91.7, 143.1))) * 43758.5453);
}

fragment float4 fragment_xeroxpunk(
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
    float y = luma(src.rgb);

    float n = xerox_noise(floor(uv * texSize) + floor(u.time * 12.0));
    y += (n - 0.5) * (0.04 + 0.12 * t);

    float threshold = mix(0.52, 0.60, t);
    float bw = step(threshold, y);

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

    float edgeMask = smoothstep(0.12, 0.22, edge);

    float dirt = step(0.985 - 0.03 * t, xerox_noise(floor(uv * texSize * 0.6) + 19.0));
    float scratches = step(0.992, xerox_noise(float2(floor(uv.x * texSize.x * 0.15), floor(uv.y * 20.0 + u.time * 6.0))));

    float base = bw;
    base = mix(base, 0.0, edgeMask * (0.55 + 0.35 * t));
    base = mix(base, 0.0, dirt * 0.25);
    base = mix(base, 0.0, scratches * 0.6);

    float3 outC = float3(clamp(base, 0.0, 1.0));
    return float4(mix(src.rgb, outC, t), 1.0);
}
