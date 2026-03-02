#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms (from Swift)
struct Uniforms {
    float time;
    float viewAspect;
    float textureAspect;
    float rotation;                 // radians
    float mirror;                   // 0 or 1 (reserved)
    float hasDepth;                 // 0 or 1
    float depthFlipX;               // 1 = flip X for depth UV
    float depthFlipY;               // 1 = flip Y for depth UV
    float intensity;                // 0 passthrough .. 1 full
    float effectiveTextureAspect;   // aspect with rotation (computed in Swift)
    float uvScaleX;                 // aspect-fill UV crop scale <= 1
    float uvScaleY;                 // aspect-fill UV crop scale <= 1
};

// MARK: - Vertex Output
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Vertex Shader
vertex VertexOut vertex_main(
    uint vid [[vertex_id]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 basePos[4] = {
        {-1, -1}, { 1, -1},
        {-1,  1}, { 1,  1}
    };

    float2 baseUV[4] = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    };

    float2 uv = baseUV[vid];

    // 1) Aspect-FILL via UV-crop around center
    uv = (uv - 0.5) * float2(uniforms.uvScaleX, uniforms.uvScaleY) + 0.5;

    // 2) Rotate UV around center
    float2 centeredUV = uv - 0.5;
    float cosR = cos(uniforms.rotation);
    float sinR = sin(uniforms.rotation);

    float2 rotUV;
    rotUV.x = centeredUV.x * cosR - centeredUV.y * sinR;
    rotUV.y = centeredUV.x * sinR + centeredUV.y * cosR;
    rotUV += 0.5;

    VertexOut out;
    out.position = float4(basePos[vid], 0, 1);
    out.uv = rotUV;
    return out;
}

// MARK: - Passthrough
fragment float4 fragment_passthrough(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    return tex.sample(s, in.uv);
}
