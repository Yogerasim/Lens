// NeonEdge.metal
#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float neon_hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static inline float3 neon_rainbow(float t) {
    t = fract(t);
    float3 a = float3(0.55, 0.85, 1.00);
    float3 b = float3(1.00, 0.35, 0.85);
    float3 c = float3(0.20, 1.00, 0.85);
    float3 d = float3(1.00, 0.95, 0.35);
    float k = t * 3.0;
    if (k < 1.0) return mix(a, b, k);
    if (k < 2.0) return mix(b, c, k - 1.0);
    return mix(c, d, k - 2.0);
}

static inline float neon_sobel(texture2d<float> tex, sampler s, float2 uv, float2 px) {
    float tl = luma(tex.sample(s, uv + float2(-px.x, -px.y)).rgb);
    float  t = luma(tex.sample(s, uv + float2( 0.0, -px.y)).rgb);
    float tr = luma(tex.sample(s, uv + float2( px.x, -px.y)).rgb);
    float  l = luma(tex.sample(s, uv + float2(-px.x,  0.0)).rgb);
    float  r = luma(tex.sample(s, uv + float2( px.x,  0.0)).rgb);
    float bl = luma(tex.sample(s, uv + float2(-px.x,  px.y)).rgb);
    float  b = luma(tex.sample(s, uv + float2( 0.0,  px.y)).rgb);
    float br = luma(tex.sample(s, uv + float2( px.x,  px.y)).rgb);

    float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
    float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
    return sqrt(gx*gx + gy*gy);
}

fragment float4 fragment_neonedge(
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

    float e = neon_sobel(tex, s, uv, px);

    float th = mix(0.16, 0.08, t);
    float soft = mix(0.08, 0.04, t);
    float edge = smoothstep(th, th + soft, e);

    float glow = smoothstep(0.0, 1.0, edge);
    glow = pow(glow, 0.65);

    float n = neon_hash21(floor(uv * texSize));
    float hue = u.time * 0.25 + uv.x * 0.9 + uv.y * 0.6 + (n - 0.5) * 0.08;
    float3 neon = neon_rainbow(hue);

    float3 col = src.rgb;
    float3 base = gentleTonemap(col);
    base = softContrast(base, 0.10 + 0.18 * t);
    base = softSaturation(base, 0.06 + 0.16 * t);

    float3 add = neon * (0.22 + 0.95 * t) * glow;
    float dark = glow * (0.05 + 0.22 * t);

    float3 outC = base * (1.0 - dark) + add;
    outC = clamp(outC, 0.0, 1.0);

    float3 mixC = mix(src.rgb, outC, t);
    return float4(mixC, 1.0);
}
