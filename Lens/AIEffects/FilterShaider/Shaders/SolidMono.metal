#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float luma709(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

fragment float4 fragment_solidmono(
    VertexOut in [[stage_in]],
    texture2d<float> camTex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = camTex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return cam;

    float2 ts = float2(camTex.get_width(), camTex.get_height());
    float2 px = 1.0 / ts;

    float3 cC = cam.rgb;
    float lC = luma709(cC);

    float lL = luma709(camTex.sample(s, uv + float2(-px.x, 0)).rgb);
    float lR = luma709(camTex.sample(s, uv + float2( px.x, 0)).rgb);
    float lU = luma709(camTex.sample(s, uv + float2(0, -px.y)).rgb);
    float lD = luma709(camTex.sample(s, uv + float2(0,  px.y)).rgb);

    float sx = (lR - lL);
    float sy = (lD - lU);

    float3 n = normalize(float3(-sx * 7.5, -sy * 7.5, 1.0));

    float3 L = normalize(float3(-0.22, -0.30, 0.93));
    float diff = clamp(dot(n, L), 0.0, 1.0);

    float edge = abs(lR - lL) + abs(lD - lU);

    float thin = smoothstep(mix(0.06, 0.045, t), mix(0.12, 0.09, t), edge);
    float thick = smoothstep(mix(0.12, 0.09, t), mix(0.22, 0.18, t), edge);

    float base = 0.86;
    float shade = mix(0.48, 1.15, diff);

    float3 solid = float3(base * shade);

    solid = mix(solid, float3(0.58), smoothstep(0.35, 0.95, lC) * 0.45);

    solid *= (1.0 - thick * (0.18 + 0.30 * t));

    solid = mix(solid, float3(0.06), thin * (0.65 + 0.30 * t));

    float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0) * (0.06 + 0.22 * t);
    solid += float3(1.0) * rim;

    float3 outC = mix(cam.rgb, solid, t);
    outC = gentleTonemap(outC);
    outC = softContrast(outC, 0.28 * t);

    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
