#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float dotm_luma709(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

static inline float dotm_circle(float2 p, float r) {
    float d = length(p - 0.5);
    return 1.0 - smoothstep(r, r + 0.02, d);
}

fragment float4 fragment_dotmatrix(
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

    float cell = mix(10.0, 5.0, t);
    float2 grid = uv * (texSize / cell);

    float2 id = floor(grid);
    float2 f = fract(grid);

    float2 uvC = (id + 0.5) / (texSize / cell);
    float3 c = tex.sample(s, uvC).rgb;

    float y = dotm_luma709(c);
    float r = mix(0.10, 0.48, y);

    float m = dotm_circle(f, r);

    float3 ink = mix(float3(0.02, 0.02, 0.03), c, 0.85);
    float3 col = mix(float3(0.02, 0.02, 0.03), ink, m);

    col = gentleTonemap(col);
    col = softContrast(col, 0.10 + 0.20 * t);
    col = softSaturation(col, 0.06 + 0.10 * t);

    float3 outC = mix(src.rgb, clamp(col, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
