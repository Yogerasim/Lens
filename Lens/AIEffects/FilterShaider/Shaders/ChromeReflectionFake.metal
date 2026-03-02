// ChromeReflectionFake.metal
#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float chrome_hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static inline float3 chrome_iridescent(float x) {
    x = fract(x);
    float3 a = float3(1.00, 0.10, 0.55);
    float3 b = float3(0.10, 0.95, 0.85);
    float3 c = float3(0.95, 0.85, 0.10);
    float3 d = float3(0.30, 0.45, 1.00);

    float t = x * 3.0;
    int seg = (int)floor(t);
    float f = fract(t);

    if (seg <= 0) return mix(a, b, f);
    if (seg == 1) return mix(b, c, f);
    return mix(c, d, f);
}

fragment float4 fragment_chromereflect(
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

    float l = luma(src.rgb);
    float2 g;
    g.x = luma(tex.sample(s, uv + float2(px.x, 0)).rgb) - l;
    g.y = luma(tex.sample(s, uv + float2(0, px.y)).rgb) - l;

    float3 n = normalize(float3(-g.x * 8.0, -g.y * 8.0, 1.0));

    float2 c = uv - 0.5;
    float r = length(c);

    float fres = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.2);
    fres *= (0.35 + 0.65 * smoothstep(0.05, 0.75, r));

    float flow = u.time * 0.18 + uv.x * 0.9 + uv.y * 0.4 + chrome_hash21(floor(uv * texSize)) * 0.15;
    float3 chrome = chrome_iridescent(flow);

    float spec = pow(clamp(dot(n, normalize(float3(-0.25, -0.5, 0.83))), 0.0, 1.0), 48.0);
    spec *= (0.05 + 0.18 * t);

    float3 col = src.rgb;
    col = gentleTonemap(col);
    col = softContrast(col, 0.10 + 0.15 * t);
    col = softSaturation(col, 0.06 + 0.14 * t);

    float3 add = chrome * fres * (0.20 + 0.80 * t) + float3(0.9, 0.95, 1.0) * spec;
    float3 outC = clamp(col + add, 0.0, 1.0);

    float3 mixC = mix(src.rgb, outC, t);
    return float4(mixC, 1.0);
}
