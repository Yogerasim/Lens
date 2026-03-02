#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_depthfog(
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
        float border = 0.02;
        if (uv.x < border || uv.x > 1.0 - border || uv.y < border || uv.y > 1.0 - border) {
            return float4(1.0, 0.2, 0.2, 1.0);
        }
        return color;
    }

    float depth = depthTex.sample(s, depthUV).r;
    float normalizedDepth = clamp(depth / 5.0, 0.0, 1.0);

    float fogAmount = smoothstep(0.1, 0.8, normalizedDepth);

    float3 fogColor = float3(
        0.5 + 0.2 * sin(time * 0.3),
        0.6 + 0.2 * sin(time * 0.4 + 1.0),
        0.8 + 0.2 * sin(time * 0.5 + 2.0)
    );

    float3 finalColor = mix(color.rgb, fogColor, fogAmount * 0.7);

    float2 texSize = float2(depthTex.get_width(), depthTex.get_height());
    float2 pixelSize = 1.0 / texSize;

    float depthL = depthTex.sample(s, depthUV + float2(-pixelSize.x, 0)).r;
    float depthR = depthTex.sample(s, depthUV + float2( pixelSize.x, 0)).r;
    float depthU = depthTex.sample(s, depthUV + float2(0, -pixelSize.y)).r;
    float depthD = depthTex.sample(s, depthUV + float2(0,  pixelSize.y)).r;

    float depthEdge = abs(depthL - depthR) + abs(depthU - depthD);
    float edgeStrength = smoothstep(0.05, 0.2, depthEdge);

    float3 edgeColor = float3(0.0, 1.0, 0.8) * edgeStrength;
    finalColor += edgeColor * 0.5;

    if (uv.x < 0.15 && uv.y > 0.85) {
        float depthVis = normalizedDepth;
        return float4(depthVis, depthVis * 0.5, 1.0 - depthVis, 1.0);
    }

    float3 result = mix(color.rgb, finalColor, uniforms.intensity);
    return float4(result, 1.0);
}
