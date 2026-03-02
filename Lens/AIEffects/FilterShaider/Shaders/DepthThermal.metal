#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static float3 thermalPalette(float t) {
    t = clamp(t, 0.0, 1.0);

    float3 c1 = float3(1.0, 0.1, 0.0);
    float3 c2 = float3(1.0, 0.9, 0.0);
    float3 c3 = float3(0.1, 1.0, 0.2);
    float3 c4 = float3(0.0, 1.0, 1.0);
    float3 c5 = float3(0.0, 0.2, 1.0);

    float x = t * 4.0;
    int seg = (int)floor(x);
    float f = fract(x);

    if (seg <= 0) return mix(c1, c2, f);
    if (seg == 1) return mix(c2, c3, f);
    if (seg == 2) return mix(c3, c4, f);
    return mix(c4, c5, f);
}

fragment float4 fragment_depththermal(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = tex.sample(s, uv);

    if (uniforms.hasDepth < 0.5) {
        return cam;
    }

    float2 depthUV = uv;
    if (uniforms.depthFlipX > 0.5) depthUV.x = 1.0 - depthUV.x;
    if (uniforms.depthFlipY > 0.5) depthUV.y = 1.0 - depthUV.y;

    float depth = depthTex.sample(s, depthUV).r;

    float nearM = 0.2;
    float farM  = 5.0;

    float nd = (depth - nearM) / (farM - nearM);
    nd = clamp(nd, 0.0, 1.0);

    float3 thermal = thermalPalette(nd);

    float2 ds = 1.0 / float2(depthTex.get_width(), depthTex.get_height());
    float dL = depthTex.sample(s, depthUV + float2(-ds.x, 0)).r;
    float dR = depthTex.sample(s, depthUV + float2( ds.x, 0)).r;
    float dU = depthTex.sample(s, depthUV + float2(0, -ds.y)).r;
    float dD = depthTex.sample(s, depthUV + float2(0,  ds.y)).r;

    float edge = abs(dL - dR) + abs(dU - dD);
    float edgeGlow = smoothstep(0.03, 0.18, edge);
    thermal += float3(1.0) * edgeGlow * 0.25;

    float camMix = smoothstep(0.0, 0.35, nd);
    float3 blended = mix(cam.rgb, thermal, camMix);

    float3 result = mix(cam.rgb, blended, uniforms.intensity);
    return float4(clamp(result, 0.0, 1.0), 1.0);
}
