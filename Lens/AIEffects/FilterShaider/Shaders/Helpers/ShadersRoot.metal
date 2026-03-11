#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.metalh"

vertex VertexOut vertex_main(
    uint vid [[vertex_id]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 basePos[4] = {
        {-1.0, -1.0}, { 1.0, -1.0},
        {-1.0,  1.0}, { 1.0,  1.0}
    };

    float2 baseUV[4] = {
        {0.0, 0.0}, {1.0, 0.0},
        {0.0, 1.0}, {1.0, 1.0}
    };

    float2 uv = baseUV[vid];

    uv = (uv - 0.5) * float2(uniforms.uvScaleX, uniforms.uvScaleY) + 0.5;

    float2 centered = uv - 0.5;
    float cosR = cos(uniforms.rotation);
    float sinR = sin(uniforms.rotation);

    float2 rotUV;
    rotUV.x = centered.x * cosR - centered.y * sinR;
    rotUV.y = centered.x * sinR + centered.y * cosR;
    rotUV += 0.5;

    if (uniforms.mirror > 0.5) {
        rotUV.x = 1.0 - rotUV.x;
    }

    VertexOut out;
    out.position = float4(basePos[vid], 0.0, 1.0);
    out.uv = rotUV;
    return out;
}

fragment float4 fragment_passthrough(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    return tex.sample(s, in.uv);
}
