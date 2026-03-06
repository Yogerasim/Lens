#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float2 depthUVFix(float2 uv, constant Uniforms &u) {
    if (u.depthFlipX > 0.5) uv.x = 1.0 - uv.x;
    if (u.depthFlipY > 0.5) uv.y = 1.0 - uv.y;
    return uv;
}

static inline float depth01(float d) {
    float nearM = 0.22;
    float farM  = 2.80;
    float nd = clamp((d - nearM) / (farM - nearM), 0.0, 1.0);
    return pow(nd, 0.85);
}

static inline float3 thermoPremium(float t) {
    t = clamp(t, 0.0, 1.0);

    float3 c0 = float3(0.05, 0.10, 0.25);
    float3 c1 = float3(0.00, 0.65, 1.00);
    float3 c2 = float3(0.10, 1.00, 0.55);
    float3 c3 = float3(1.00, 0.85, 0.10);
    float3 c4 = float3(1.00, 0.25, 0.05);

    float x = t * 4.0;
    int seg = (int)floor(x);
    float f = fract(x);

    if (seg <= 0) return mix(c0, c1, f);
    if (seg == 1) return mix(c1, c2, f);
    if (seg == 2) return mix(c2, c3, f);
    return mix(c3, c4, f);
}

static inline float3 depthNormal(texture2d<float> depthTex, sampler s, float2 duv, float2 dpx) {
    float dC = depthTex.sample(s, duv).r;
    float dR = depthTex.sample(s, duv + float2(dpx.x, 0.0)).r;
    float dD = depthTex.sample(s, duv + float2(0.0, dpx.y)).r;

    float dx = (dR - dC);
    float dy = (dD - dC);

    float k = 22.0;
    return normalize(float3(-dx * k, -dy * k, 1.0));
}

fragment float4 fragment_depthsolidthermal(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = tex.sample(s, uv);

    if (u.hasDepth < 0.5) return cam;

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return cam;

    float2 duv = depthUVFix(uv, u);
    float2 dpx = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float dC = depthTex.sample(s, duv).r;
    float dL = depthTex.sample(s, duv + float2(-dpx.x, 0.0)).r;
    float dR = depthTex.sample(s, duv + float2( dpx.x, 0.0)).r;
    float dU = depthTex.sample(s, duv + float2(0.0, -dpx.y)).r;
    float dD = depthTex.sample(s, duv + float2(0.0,  dpx.y)).r;

    float nd = depth01(dC);

    float3 n = depthNormal(depthTex, s, duv, dpx);

    float3 lightDir = normalize(float3(-0.30, -0.55, 0.78));
    float ndotl = clamp(dot(n, lightDir), 0.0, 1.0);

    float edge = abs(dR - dL) + abs(dD - dU);
    float edgeMask = smoothstep(0.010, 0.045, edge);

    float shadeLevels = mix(18.0, 8.0, t);
    float q = floor(nd * shadeLevels + 0.5) / shadeLevels;

    float2 camSize = float2(tex.get_width(), tex.get_height());
    float dither = (bayer4x4(uv * camSize) - 0.5) * (0.018 * (0.25 + 0.75 * t));
    q = clamp(q + dither, 0.0, 1.0);

    float3 thermo = thermoPremium(q);

    thermo = softSaturation(thermo, 0.65);
    thermo = softContrast(thermo, 0.55);

    float shade = 0.42 + 0.92 * pow(ndotl, 0.90);
    thermo *= shade;

    float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0);
    thermo += float3(0.85, 0.95, 1.0) * rim * (0.10 + 0.22 * t);

    float2 p = uv * camSize;
    float stripeStep = mix(16.0, 10.0, t);
    float v = (p.x + p.y * 0.65);
    float stripes = fract(v / stripeStep);

    float stripeW = 0.11;
    float stripeLine = 1.0 - smoothstep(0.0, stripeW, min(stripes, 1.0 - stripes));
    stripeLine = pow(stripeLine, 1.9);

    float stripeMask = clamp(edgeMask * 1.10 + (1.0 - nd) * 0.20, 0.0, 1.0);
    float3 stripeCol = float3(0.90, 0.97, 1.00);

    thermo += stripeCol * stripeLine * stripeMask * (0.08 + 0.22 * t);

    float edgeBright = edgeMask * (0.10 + 0.35 * t) * (0.35 + 0.65 * ndotl);
    thermo += float3(0.95, 0.98, 1.0) * edgeBright;

    thermo = gentleTonemap(thermo);

    float3 out = mix(cam.rgb, thermo, t);
    return float4(clamp(out, 0.0, 1.0), 1.0);
}
