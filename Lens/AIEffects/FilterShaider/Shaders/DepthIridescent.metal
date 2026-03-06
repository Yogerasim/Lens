#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float2 depthUVFix(float2 uv, constant Uniforms &u) {
    if (u.depthFlipX > 0.5) uv.x = 1.0 - uv.x;
    if (u.depthFlipY > 0.5) uv.y = 1.0 - uv.y;
    return uv;
}

static inline float depth01(float dMeters) {
    const float nearM = 0.20;
    const float farM  = 5.00;
    return clamp((dMeters - nearM) / (farM - nearM), 0.0, 1.0);
}

static inline float3 iridescentCos(float x) {
    x = fract(x);
    float3 phase = float3(0.0, 0.33, 0.67);
    return clamp(0.5 + 0.5 * cos(6.2831853 * (x + phase)), 0.0, 1.0);
}

static inline float3 depthNormal5(texture2d<float> depthTex, sampler s, float2 duv, float2 dpx) {
    float dL = depthTex.sample(s, duv + float2(-dpx.x, 0.0)).r;
    float dR = depthTex.sample(s, duv + float2( dpx.x, 0.0)).r;
    float dU = depthTex.sample(s, duv + float2(0.0, -dpx.y)).r;
    float dD = depthTex.sample(s, duv + float2(0.0,  dpx.y)).r;

    float dx = (dR - dL);
    float dy = (dD - dU);

    float k = 90.0;
    return normalize(float3(-dx * k, -dy * k, 1.0));
}

static inline float curvature5(texture2d<float> depthTex, sampler s, float2 duv, float2 dpx) {
    float dC = depthTex.sample(s, duv).r;
    float dL = depthTex.sample(s, duv + float2(-dpx.x, 0.0)).r;
    float dR = depthTex.sample(s, duv + float2( dpx.x, 0.0)).r;
    float dU = depthTex.sample(s, duv + float2(0.0, -dpx.y)).r;
    float dD = depthTex.sample(s, duv + float2(0.0,  dpx.y)).r;
    return abs(dL + dR + dU + dD - 4.0 * dC);
}

fragment float4 fragment_depthiridescent(
    VertexOut in [[stage_in]],
    texture2d<float> camTex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = camTex.sample(s, uv);

    if (u.hasDepth < 0.5) return cam;

    float a = clamp(u.intensity, 0.0, 1.0);
    float t = premiumCurve(a);

    float2 duv = depthUVFix(uv, u);
    float2 dpx = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float d = depthTex.sample(s, duv).r;

    float holeMask = 1.0 - smoothstep(0.00002, 0.00025, d);

    float nd = depth01(max(d, 0.00030));

    float3 n = depthNormal5(depthTex, s, duv, dpx);

    float3 L = normalize(float3(-0.35, -0.55, 0.75));
    float diff = clamp(dot(n, L), 0.0, 1.0);

    float3 V = float3(0.0, 0.0, 1.0);
    float3 H = normalize(L + V);
    float spec = pow(clamp(dot(n, H), 0.0, 1.0), 64.0);

    float fres = pow(1.0 - clamp(n.z, 0.0, 1.0), 3.0);

    float curv = curvature5(depthTex, s, duv, dpx);
    float edge = smoothstep(0.004, 0.018, curv);

    float amp   = mix(0.55, 1.75, t);

    float timeScaled = u.demoPhase;

    float hue = timeScaled
              + nd * (1.25 + 1.10 * amp)
              + (n.x * 0.55 + n.y * 0.45) * (0.70 + 0.85 * amp)
              + edge * (0.65 + 0.95 * amp);

    float3 base = iridescentCos(hue);
    float3 base2 = iridescentCos(hue + (0.20 + 0.40 * t));
    float3 iri = mix(base, base2, 0.35 + 0.25 * fres);

    float shade = (0.30 + 1.05 * diff);
    float3 col = iri * shade;

    float ao = clamp(1.0 - edge * (0.60 + 0.40 * amp), 0.28, 1.0);
    col *= ao;

    float3 rimCol = iridescentCos(hue + 0.45);
    col += rimCol * (fres * (0.18 + 0.70 * amp));

    col += float3(0.90, 0.95, 1.00) * (spec * (0.06 + 0.30 * amp));

    float2 p = uv * float2(camTex.get_width(), camTex.get_height());
    float dither = (bayer4x4(p) - 0.5) * (0.006 + 0.016 * t);
    col = clamp(col + dither, 0.0, 1.0);

    col = gentleTonemap(col);
    col = softContrast(col, 0.18 + 0.48 * t);
    col = softSaturation(col, 0.18 + 0.50 * t);

    float rampT =
        uv.y * 2.35 +
        uv.x * 0.95 +
        timeScaled * (0.90 + 2.10 * t) +
        sin((uv.x + timeScaled * 0.25) * 10.0) * 0.10 +
        sin((uv.y - timeScaled * 0.22) * 12.0) * 0.10;

    float3 ramp = 0.5 + 0.5 * cos(6.28318 * (fract(rampT) + float3(0.00, 0.33, 0.67)));

    ramp = clamp(ramp, 0.0, 1.0);

    float glow = (0.45 + 0.55 * t);
    float3 fill = ramp * glow;

    float3 outC = mix(col, fill, holeMask);

    float holeEdge = smoothstep(0.010, 0.060, curv) * holeMask;
    outC += fill * holeEdge * (0.12 + 0.55 * t);

    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
