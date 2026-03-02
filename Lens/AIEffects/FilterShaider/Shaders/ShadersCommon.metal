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

// --- Premium curve: в начале мягко, ближе к 1 — сильнее
inline float premiumCurve(float t) {
    t = clamp(t, 0.0, 1.0);
    // smoothstep + немного “пружины” в середине
    float s = t * t * (3.0 - 2.0 * t);
    return clamp(s, 0.0, 1.0);
}

// --- Luma (Rec.709-ish)
inline float luma(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

// --- Soft contrast around mid-gray
inline float3 softContrast(float3 c, float amount) {
    // amount: 0..1
    float k = mix(1.0, 1.18, amount);    // очень аккуратно
    return clamp((c - 0.5) * k + 0.5, 0.0, 1.0);
}

// --- Soft saturation
inline float3 softSaturation(float3 c, float amount) {
    // amount: 0..1
    float y = luma(c);
    float s = mix(1.0, 1.12, amount);    // аккуратно
    return clamp(mix(float3(y), c, s), 0.0, 1.0);
}

// --- Gentle “filmic-ish” tonemap (очень мягкий, без сильного LUT ощущения)
inline float3 gentleTonemap(float3 x) {
    // простая мягкая компрессия хайлайтов
    return x / (x + 0.6);
}

// --- Bayer 4x4 for subtle halftone/dither (стабильно и дёшево)
inline float bayer4x4(float2 p) {
    // p in pixel coords
    int x = (int)p.x & 3;
    int y = (int)p.y & 3;

    // 4x4 Bayer matrix values 0..15
    const float m[16] = {
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    };
    return m[y * 4 + x] / 15.0;
}
