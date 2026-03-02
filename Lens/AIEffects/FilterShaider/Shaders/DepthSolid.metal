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

fragment float4 fragment_depthsolid(
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

    float2 dUV = uv;
    if (u.depthFlipX > 0.5) dUV.x = 1.0 - dUV.x;
    if (u.depthFlipY > 0.5) dUV.y = 1.0 - dUV.y;

    float2 ds = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float dC = depthTex.sample(s, dUV).r;
    float dL = depthTex.sample(s, dUV + float2(-ds.x, 0)).r;
    float dR = depthTex.sample(s, dUV + float2( ds.x, 0)).r;
    float dU = depthTex.sample(s, dUV + float2(0, -ds.y)).r;
    float dD = depthTex.sample(s, dUV + float2(0,  ds.y)).r;

    float nd = clamp((dC - 0.25) / (5.0 - 0.25), 0.0, 1.0);

    float sx = (dR - dL);
    float sy = (dD - dU);
    float3 n = normalize(float3(-sx * 95.0, -sy * 95.0, 1.0));

    float3 L = normalize(float3(-0.25, -0.35, 0.90));
    float diff = clamp(dot(n, L), 0.0, 1.0);

    float edge = abs(dR - dL) + abs(dD - dU);

    float thinTh  = mix(0.010, 0.007, t);
    float thickTh = mix(0.028, 0.020, t);

    float thinMask  = smoothstep(thinTh,  thinTh  + 0.020, edge);
    float thickMask = smoothstep(thickTh, thickTh + 0.030, edge);

    float3 cLight = float3(0.86);
    float3 cMid   = float3(0.66);
    float3 cDark  = float3(0.40);

    float shade = mix(0.55, 1.05, diff);
    float depthShade = mix(1.0, 0.62, smoothstep(0.15, 0.95, nd));

    float3 solid = cLight * shade * depthShade;

    solid = mix(solid, cMid,  smoothstep(0.25, 0.85, nd) * 0.55);
    solid = mix(solid, cDark, smoothstep(0.45, 1.00, nd) * 0.40);

    float outlineStrong = thickMask * (0.35 + 0.55 * t);
    solid *= (1.0 - outlineStrong);

    float ink = 0.10;
    float thinInk = thinMask * (0.55 + 0.40 * t);
    solid = mix(solid, float3(ink), thinInk);

    float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0);
    rim *= (0.10 + 0.45 * t);
    solid += float3(1.0) * rim;

    float3 outC = mix(cam.rgb, solid, t);
    outC = gentleTonemap(outC);
    outC = softContrast(outC, 0.35 * t);

    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
