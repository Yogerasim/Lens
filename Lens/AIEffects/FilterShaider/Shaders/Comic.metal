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

fragment float4 fragment_comic(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 pixelSize = 1.0 / texSize;
    float time = uniforms.time;

    float4 color = tex.sample(s, uv);

    float levels = 4.0 + sin(time * 0.5) * 1.5;
    float3 posterized = floor(color.rgb * levels + 0.5) / levels;

    float3 tl = tex.sample(s, uv + float2(-pixelSize.x, -pixelSize.y)).rgb;
    float3 t  = tex.sample(s, uv + float2(0, -pixelSize.y)).rgb;
    float3 tr = tex.sample(s, uv + float2(pixelSize.x, -pixelSize.y)).rgb;
    float3 l  = tex.sample(s, uv + float2(-pixelSize.x, 0)).rgb;
    float3 r  = tex.sample(s, uv + float2(pixelSize.x, 0)).rgb;
    float3 bl = tex.sample(s, uv + float2(-pixelSize.x, pixelSize.y)).rgb;
    float3 b  = tex.sample(s, uv + float2(0, pixelSize.y)).rgb;
    float3 br = tex.sample(s, uv + float2(pixelSize.x, pixelSize.y)).rgb;

    float tlL = dot(tl, float3(0.299, 0.587, 0.114));
    float tL  = dot(t,  float3(0.299, 0.587, 0.114));
    float trL = dot(tr, float3(0.299, 0.587, 0.114));
    float lL  = dot(l,  float3(0.299, 0.587, 0.114));
    float rL  = dot(r,  float3(0.299, 0.587, 0.114));
    float blL = dot(bl, float3(0.299, 0.587, 0.114));
    float bL  = dot(b,  float3(0.299, 0.587, 0.114));
    float brL = dot(br, float3(0.299, 0.587, 0.114));

    float sobelX = -tlL - 2.0*lL - blL + trL + 2.0*rL + brL;
    float sobelY = -tlL - 2.0*tL - trL + blL + 2.0*bL + brL;
    float edge = sqrt(sobelX * sobelX + sobelY * sobelY);

    float edgeThreshold = 0.12 + sin(time * 0.8) * 0.03;
    float edgeStrength = smoothstep(edgeThreshold, edgeThreshold + 0.1, edge);

    float saturationBoost = 1.3 + sin(time * 0.6) * 0.2;
    float cmax = max(posterized.r, max(posterized.g, posterized.b));
    float3 boostedColor = mix(float3(cmax), posterized, saturationBoost);
    boostedColor = clamp(boostedColor, 0.0, 1.0);

    float hueShift = sin(time * 0.3) * 0.1;
    float3 shifted = boostedColor;
    shifted.r = boostedColor.r * (1.0 + hueShift) - boostedColor.g * hueShift * 0.5;
    shifted.g = boostedColor.g * (1.0 + hueShift * 0.5);
    shifted.b = boostedColor.b * (1.0 - hueShift);
    shifted = clamp(shifted, 0.0, 1.0);

    float3 finalColor = mix(shifted, float3(0.0), edgeStrength);

    float4 originalColor = tex.sample(s, uv);
    float3 result = mix(originalColor.rgb, finalColor, uniforms.intensity);

    return float4(result, 1.0);
}
