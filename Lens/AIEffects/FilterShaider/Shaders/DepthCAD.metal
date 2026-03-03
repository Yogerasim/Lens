#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float depth01(float d) {
    float nearM = 0.2;
    float farM  = 5.0;
    return clamp((d - nearM) / (farM - nearM), 0.0, 1.0);
}

static inline float2 depthUVFix(float2 uv, constant Uniforms &u) {
    if (u.depthFlipX > 0.5) uv.x = 1.0 - uv.x;
    if (u.depthFlipY > 0.5) uv.y = 1.0 - uv.y;
    return uv;
}

static inline float3 depthNormal(texture2d<float> depthTex, sampler s, float2 duv, float2 dpx) {
    float dC = depthTex.sample(s, duv).r;
    float dR = depthTex.sample(s, duv + float2(dpx.x, 0.0)).r;
    float dU = depthTex.sample(s, duv + float2(0.0, dpx.y)).r;

    float dx = (dR - dC);
    float dy = (dU - dC);

    float k = 18.0;
    return normalize(float3(-dx * k, -dy * k, 1.0));
}

static inline float ao4(texture2d<float> depthTex, sampler s, float2 duv, float2 dpx, float dC) {
    float r = depthTex.sample(s, duv + float2( dpx.x, 0.0)).r;
    float l = depthTex.sample(s, duv + float2(-dpx.x, 0.0)).r;
    float u = depthTex.sample(s, duv + float2(0.0,  dpx.y)).r;
    float d = depthTex.sample(s, duv + float2(0.0, -dpx.y)).r;

    float occ = 0.0;
    occ += smoothstep(0.0, 0.08, r - dC);
    occ += smoothstep(0.0, 0.08, l - dC);
    occ += smoothstep(0.0, 0.08, u - dC);
    occ += smoothstep(0.0, 0.08, d - dC);
    return clamp(1.0 - occ * 0.22, 0.0, 1.0);
}

static inline float contours(float nd, float bands, float thickness) {
    float x = nd * bands;
    float f = abs(fract(x) - 0.5) * 2.0;
    return 1.0 - smoothstep(thickness, thickness + 0.08, f);
}

fragment float4 fragment_depthcad(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return cam;

    if (u.hasDepth < 0.5) return cam;

    float2 duv = depthUVFix(uv, u);
    float2 dpx = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float dC = depthTex.sample(s, duv).r;
    float nd = depth01(dC);

    float3 n = depthNormal(depthTex, s, duv, dpx);

    float3 lightDir = normalize(float3(-0.25, -0.65, 0.72));
    float ndotl = clamp(dot(n, lightDir), 0.0, 1.0);

    float base = mix(0.95, 0.12, nd);
    float shade = 0.45 + 0.75 * pow(ndotl, 0.85);

    float ao = ao4(depthTex, s, duv, dpx * 2.0, dC);

    float bandCount = mix(42.0, 64.0, t);
    float line = contours(nd, bandCount, 0.10);

    float3 col = float3(base) * shade * ao;

    float3 lineCol = float3(0.02);
    col = mix(col, lineCol, line * (0.70 + 0.25 * t));

    float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0);
    col += float3(0.90) * rim * (0.06 + 0.10 * t);

    col = gentleTonemap(col);
    col = softContrast(col, 0.45 * t);

    float3 outC = mix(cam.rgb, col, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
