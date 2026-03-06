#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float vhs_hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

fragment float4 fragment_vhsanalog(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float time = u.time;

    float wob = (sin(time * 1.7 + uv.y * 35.0) + sin(time * 2.9 + uv.y * 12.0)) * 0.5;
    float2 uvW = uv + float2(wob, 0.0) * (0.001 + 0.004 * t);

    float ca = (0.0006 + 0.0028 * t);
    float3 col;
    col.r = tex.sample(s, uvW + float2( ca, 0.0)).r;
    col.g = tex.sample(s, uvW).g;
    col.b = tex.sample(s, uvW + float2(-ca, 0.0)).b;

    float scan = sin(uv.y * 1100.0 + time * 10.0) * 0.5 + 0.5;
    scan = pow(scan, 10.0) * (0.02 + 0.10 * t);

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float n = vhs_hash21(float2(floor(uv.x * texSize.x), floor((uv.y + time * 0.15) * texSize.y)));
    float noise = (n - 0.5) * (0.02 + 0.08 * t);

    float drop = smoothstep(0.85, 1.0, vhs_hash21(float2(floor(time * 12.0), floor(uv.y * 80.0))));
    float yoff = drop * (0.002 + 0.010 * t);

    float3 col2;
    col2.r = tex.sample(s, uvW + float2( ca,  yoff)).r;
    col2.g = tex.sample(s, uvW + float2(0.0, yoff)).g;
    col2.b = tex.sample(s, uvW + float2(-ca, yoff)).b;

    col = mix(col, col2, drop);

    col += float3(scan) + float3(noise);

    col = gentleTonemap(col);
    col = softContrast(col, 0.08 + 0.22 * t);
    col = softSaturation(col, 0.06 + 0.10 * t);

    float3 outC = mix(src.rgb, clamp(col, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
