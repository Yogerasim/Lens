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

static inline float edgeFromNormal(float3 n, float2 duv, float2 dpx, texture2d<float> depthTex, sampler s, constant Uniforms &u) {
    float3 nR = depthNormal(depthTex, s, duv + float2(dpx.x, 0.0), dpx);
    float3 nU = depthNormal(depthTex, s, duv + float2(0.0, dpx.y), dpx);
    float e = length(nR - n) + length(nU - n);
    float th = 0.18;
    float soft = 0.20;
    return smoothstep(th, th + soft, e);
}

fragment float4 fragment_depthsolidmono(
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

    float d = depthTex.sample(s, duv).r;
    float nd = depth01(d);

    float3 n = depthNormal(depthTex, s, duv, dpx);

    float3 lightDir = normalize(float3(-0.35, -0.55, 0.75));
    float ndotl = clamp(dot(n, lightDir), 0.0, 1.0);

    float base = mix(0.92, 0.18, nd);
    float diffuse = pow(ndotl, 0.85);

    float3 viewDir = float3(0.0, 0.0, 1.0);
    float3 h = normalize(lightDir + viewDir);
    float spec = pow(clamp(dot(n, h), 0.0, 1.0), 70.0) * 0.65;

    float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.1) * 0.55;

    float edge = edgeFromNormal(n, duv, dpx, depthTex, s, u);
    float thinBlack = edge * (0.55 + 0.40 * t);

    float3 solid = float3(base);
    solid *= (0.55 + 0.65 * diffuse);
    solid += float3(1.0) * spec;
    solid += float3(0.95) * rim * 0.35;

    solid = clamp(solid, 0.0, 1.0);

    solid = mix(solid, float3(0.0), thinBlack);

    solid = gentleTonemap(solid);
    solid = softContrast(solid, 0.35 * t);
    solid = softSaturation(solid, 0.06 * t);

    float3 outC = mix(cam.rgb, solid, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
