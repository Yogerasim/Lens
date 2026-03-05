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

static inline float luma709(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

static inline float sobelEdgeCam(texture2d<float> tex, sampler s, float2 uv, float2 px) {
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

fragment float4 fragment_depthcomicthermal(
    VertexOut in [[stage_in]],
    texture2d<float> camTex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = camTex.sample(s, uv);

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

    float depthEdge = abs(dR - dL) + abs(dD - dU);
    float objEdge = smoothstep(0.010, 0.045, depthEdge);

    // --- DepthSolidThermal base (с квантизацией глубины как “постер”)
    float shadeLevels = mix(18.0, 8.0, t);
    float q = floor(nd * shadeLevels + 0.5) / shadeLevels;

    float2 camSize = float2(camTex.get_width(), camTex.get_height());
    float dither = (bayer4x4(uv * camSize) - 0.5) * (0.018 * (0.25 + 0.75 * t));
    q = clamp(q + dither, 0.0, 1.0);

    float3 thermo = thermoPremium(q);
    thermo = softSaturation(thermo, 0.65);
    thermo = softContrast(thermo, 0.55);

    float shade = 0.42 + 0.92 * pow(ndotl, 0.90);
    thermo *= shade;

    float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0);
    thermo += float3(0.85, 0.95, 1.0) * rim * (0.10 + 0.22 * t);

    float edgeBright = objEdge * (0.10 + 0.35 * t) * (0.35 + 0.65 * ndotl);
    thermo += float3(0.95, 0.98, 1.0) * edgeBright;

    // --- Comic layer (по камере)
    float3 comic = cam.rgb;
    comic = gentleTonemap(comic);
    comic = softContrast(comic, 0.55 * t);
    comic = softSaturation(comic, 0.40 * t);

    float levels = mix(12.0, 6.0, t);
    float3 poster = floor(comic * levels + 0.5) / levels;
    comic = mix(comic, poster, 0.55 * t);

    float2 px = 1.0 / camSize;
    float e = sobelEdgeCam(camTex, s, uv, px);
    float eTh = mix(0.22, 0.10, t);
    float eSoft = mix(0.10, 0.06, t);
    float eMask = smoothstep(eTh, eTh + eSoft, e);
    float anti = smoothstep(0.02, 0.12, e);
    eMask *= anti;

    float3 ink = float3(0.02, 0.03, 0.05);
    comic = mix(comic, ink, eMask * (0.10 + 0.42 * t));

    // --- Mix strategy: термо отвечает за “геометрию”, комик за “читабельность”
    float thermoMix = (0.55 + 0.25 * t);
    float3 out = mix(comic, thermo, thermoMix);

    out = gentleTonemap(out);
    out = softContrast(out, 0.12 + 0.18 * t);
    out = softSaturation(out, 0.10 + 0.12 * t);

    float3 outC = mix(cam.rgb, out, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
