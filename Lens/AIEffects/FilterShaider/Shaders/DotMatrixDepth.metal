#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float2 depthUVFix(float2 uv, constant Uniforms &u) {
    if (u.depthFlipX > 0.5) uv.x = 1.0 - uv.x;
    if (u.depthFlipY > 0.5) uv.y = 1.0 - uv.y;
    return uv;
}

static inline float depth01(float d) {
    float nearM = 0.2;
    float farM  = 5.0;
    return clamp((d - nearM) / (farM - nearM), 0.0, 1.0);
}

static inline float luma709(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

static inline float sobelEdge(texture2d<float> tex, sampler s, float2 uv, float2 px) {
    float tl = luma709(tex.sample(s, uv + float2(-px.x, -px.y)).rgb);
    float  t = luma709(tex.sample(s, uv + float2( 0.0, -px.y)).rgb);
    float tr = luma709(tex.sample(s, uv + float2( px.x, -px.y)).rgb);
    float  l = luma709(tex.sample(s, uv + float2(-px.x,  0.0)).rgb);
    float  r = luma709(tex.sample(s, uv + float2( px.x,  0.0)).rgb);
    float bl = luma709(tex.sample(s, uv + float2(-px.x,  px.y)).rgb);
    float  b = luma709(tex.sample(s, uv + float2( 0.0,  px.y)).rgb);
    float br = luma709(tex.sample(s, uv + float2( px.x,  px.y)).rgb);

    float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
    float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
    return sqrt(gx*gx + gy*gy);
}

static inline float boxDot(float2 local, float fill, float feather) {
    float2 d = abs(local - 0.5);
    float m = max(d.x, d.y);
    return 1.0 - smoothstep(fill, fill + feather, m);
}

fragment float4 fragment_dotmatrixdepth(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 px = 1.0 / texSize;

    float edge = sobelEdge(tex, s, uv, px);
    float edgeMask = smoothstep(mix(0.16, 0.10, t), mix(0.26, 0.18, t), edge);

    float nd = 0.5;
    if (u.hasDepth > 0.5) {
        float2 duv = depthUVFix(uv, u);
        float d = depthTex.sample(s, duv).r;
        nd = depth01(d);
    }

    float farMask = smoothstep(0.35, 0.95, nd);

    float cellSmall = mix(5.0, 7.0, t);
    float cellLarge = mix(10.0, 14.0, t);

    float cellPx = mix(cellSmall, cellLarge, clamp(0.55 * farMask + 0.85 * edgeMask, 0.0, 1.0));
    float2 grid = floor(uv * texSize / cellPx);
    float2 cellUV = fract(uv * texSize / cellPx);

    

    float lum = luma709(src.rgb);
    float fill = mix(0.48, 0.18, lum);
    fill = mix(fill, fill * 0.70, edgeMask);

    float dot = boxDot(cellUV, fill, 0.08);

    float3 base = src.rgb * (0.55 + 0.45 * (1.0 - dot));
    float3 ink  = mix(float3(0.05), float3(0.95), pow(lum, 1.15));
    float3 dots = ink * dot;

    float3 col = mix(base, base + dots * (0.65 + 0.55 * t), 0.75);

    col = gentleTonemap(col);
    col = softContrast(col, 0.25 * t);
    col = softSaturation(col, 0.10 * t);

    float3 outC = mix(src.rgb, col, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
