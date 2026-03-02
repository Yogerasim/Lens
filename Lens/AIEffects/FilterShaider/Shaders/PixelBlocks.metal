#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_pixelblocks(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float2 texSize = float2(tex.get_width(), tex.get_height());

    float blockSize = mix(1.0, 30.0, t);

    float2 grid = floor(uv * texSize / blockSize) * blockSize;
    float2 uvBlock = grid / texSize;

    float3 col = tex.sample(s, uvBlock).rgb;

    col = gentleTonemap(col);
    col = softContrast(col, 0.25 * t);

    float3 outC = mix(src.rgb, col, t);
    return float4(outC, 1.0);
}
