// DepthGrid.metal
#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float depth01(float dMeters, float nearM, float farM) {
    return clamp((dMeters - nearM) / (farM - nearM), 0.0, 1.0);
}

static inline float2 depthUVFromCameraUV(float2 uv, constant Uniforms& u) {
    float2 d = uv;
    if (u.depthFlipX > 0.5) d.x = 1.0 - d.x;
    if (u.depthFlipY > 0.5) d.y = 1.0 - d.y;
    return d;
}

static inline float bayerDither(float2 uv, float2 texSize, float amp) {
    float b = bayer4x4(uv * texSize);
    return (b - 0.5) * amp;
}

fragment float4 fragment_depthgrid(
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

    float2 dUV = depthUVFromCameraUV(uv, u);

    float2 ds = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float dC = depthTex.sample(s, dUV).r;
    float dL = depthTex.sample(s, dUV + float2(-ds.x, 0)).r;
    float dR = depthTex.sample(s, dUV + float2( ds.x, 0)).r;
    float dU = depthTex.sample(s, dUV + float2(0, -ds.y)).r;
    float dD = depthTex.sample(s, dUV + float2(0,  ds.y)).r;

    float nd = depth01(dC, 0.25, 5.0);

    float sx = (dR - dL);
    float sy = (dD - dU);
    float3 n = normalize(float3(-sx * 95.0, -sy * 95.0, 1.0));

    float3 L = normalize(float3(-0.25, -0.35, 0.90));
    float diff = clamp(dot(n, L), 0.0, 1.0);

    float edge = abs(dR - dL) + abs(dD - dU);
    float objEdge = smoothstep(0.010, 0.040, edge);

    float density = mix(55.0, 115.0, nd);
    density = mix(density, density * 1.25, t);

    float2 gp = uv * density;
    float2 f = fract(gp);

    float lineW = mix(0.028, 0.016, t);
    float gx = smoothstep(0.0, lineW, f.x) + (1.0 - smoothstep(1.0 - lineW, 1.0, f.x));
    float gy = smoothstep(0.0, lineW, f.y) + (1.0 - smoothstep(1.0 - lineW, 1.0, f.y));
    float grid = clamp(gx + gy, 0.0, 1.0);

    float glow = (0.14 + 0.55 * t) * (0.35 + 0.65 * diff);
    float depthFade = mix(1.0, 0.55, nd);

    float3 neonGreen = float3(0.10, 1.0, 0.35);
    float3 cyanBoost = float3(0.30, 1.0, 0.70);

    float scan = 0.7 + 0.3 * sin(u.time * 2.2 + uv.y * 9.0);
    float3 gridCol = mix(neonGreen, cyanBoost, 0.35 * scan);

    float3 whiteEdge = float3(0.92, 0.98, 1.0);
    float edgeGlow = objEdge * (0.20 + 0.90 * t) * (0.35 + 0.65 * diff) * depthFade;

    float fres = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0);
    float rim = fres * (0.06 + 0.20 * t);

    float2 camSize = float2(camTex.get_width(), camTex.get_height());
    float dither = bayerDither(uv, camSize, 0.010 * (0.25 + 0.75 * t));

    float3 out = cam.rgb;

    float gridMask = grid * (1.0 - objEdge * 0.55);
    out += gridCol * gridMask * glow * depthFade;

    float bloom = pow(grid, 6.0) * (0.10 + 0.25 * t) * depthFade * (0.35 + 0.65 * diff);
    out += gridCol * bloom;

    out += whiteEdge * edgeGlow;
    out += float3(0.75, 1.0, 0.90) * rim;

    float shadeLevels = mix(18.0, 9.0, t);
    float diffQ = floor(diff * shadeLevels + 0.5) / shadeLevels;
    diffQ = clamp(diffQ + dither, 0.0, 1.0);

    float3 geoTint = mix(float3(0.06), float3(0.18), diffQ);
    out = mix(out, out + geoTint * (0.18 + 0.18 * t), (0.25 + 0.35 * t) * (1.0 - nd) * (1.0 - objEdge));

    out = gentleTonemap(out);
    out = softContrast(out, 0.18 + 0.22 * t);
    out = softSaturation(out, 0.10 + 0.10 * t);

    float3 outC = mix(cam.rgb, out, t);
    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
