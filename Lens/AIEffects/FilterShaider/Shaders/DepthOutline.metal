#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float viewAspect;
    float textureAspect;
    float rotation;
    float mirror;
    float hasDepth;
    float depthFlipX;
    float depthFlipY;
    float intensity;
    float effectiveTextureAspect;
    float uvScaleX;
    float uvScaleY;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

fragment float4 fragment_depthoutline(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float time = uniforms.time;

    float2 depthUV = uv;
    if (uniforms.depthFlipX > 0.5) depthUV.x = 1.0 - depthUV.x;
    if (uniforms.depthFlipY > 0.5) depthUV.y = 1.0 - depthUV.y;

    float4 color = tex.sample(s, uv);

    if (uniforms.hasDepth < 0.5) {
        return color;
    }

    float depth = depthTex.sample(s, depthUV).r;
    float normalizedDepth = clamp(depth / 5.0, 0.0, 1.0);

    float2 texSize = float2(depthTex.get_width(), depthTex.get_height());
    float2 ps = 1.0 / texSize;

    float tl = depthTex.sample(s, depthUV + float2(-ps.x, -ps.y)).r;
    float t  = depthTex.sample(s, depthUV + float2(0, -ps.y)).r;
    float tr = depthTex.sample(s, depthUV + float2(ps.x, -ps.y)).r;
    float l  = depthTex.sample(s, depthUV + float2(-ps.x, 0)).r;
    float r  = depthTex.sample(s, depthUV + float2(ps.x, 0)).r;
    float bl = depthTex.sample(s, depthUV + float2(-ps.x, ps.y)).r;
    float b  = depthTex.sample(s, depthUV + float2(0, ps.y)).r;
    float br = depthTex.sample(s, depthUV + float2(ps.x, ps.y)).r;

    float sobelX = -tl - 2.0*l - bl + tr + 2.0*r + br;
    float sobelY = -tl - 2.0*t - tr + bl + 2.0*b + br;
    float edge = sqrt(sobelX * sobelX + sobelY * sobelY);

    float edgeStrength = smoothstep(0.03, 0.15, edge);

    float3 lineColor = float3(
        1.0 - normalizedDepth,
        0.5 + 0.5 * sin(time + normalizedDepth * 3.0),
        normalizedDepth
    );

    float3 finalColor = mix(float3(0.02), lineColor, edgeStrength);
    finalColor = mix(finalColor, color.rgb * 0.3, (1.0 - normalizedDepth) * 0.4);

    float3 result = mix(color.rgb, finalColor, uniforms.intensity);
    return float4(result, 1.0);
}
