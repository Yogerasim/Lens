#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_chromeghost(
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
    float2 px = 1.0 / texSize;

    float ca = 0.0008 + 0.0025 * t;
    float r = tex.sample(s, uv + float2( ca, 0.0)).r;
    float g = tex.sample(s, uv).g;
    float b = tex.sample(s, uv + float2(-ca, 0.0)).b;
    float3 split = float3(r, g, b);

    float y = luma(split);
    float3 chrome = mix(float3(y), float3(0.72, 0.82, 0.92) * y + float3(0.08, 0.10, 0.14), 0.75);

    float tl = luma(tex.sample(s, uv + float2(-px.x, -px.y)).rgb);
    float t0 = luma(tex.sample(s, uv + float2( 0.0, -px.y)).rgb);
    float tr = luma(tex.sample(s, uv + float2( px.x, -px.y)).rgb);
    float l0 = luma(tex.sample(s, uv + float2(-px.x,  0.0)).rgb);
    float r0 = luma(tex.sample(s, uv + float2( px.x,  0.0)).rgb);
    float bl = luma(tex.sample(s, uv + float2(-px.x,  px.y)).rgb);
    float b0 = luma(tex.sample(s, uv + float2( 0.0,  px.y)).rgb);
    float br = luma(tex.sample(s, uv + float2( px.x,  px.y)).rgb);

    float gx = -tl - 2.0*l0 - bl + tr + 2.0*r0 + br;
    float gy = -tl - 2.0*t0 - tr + bl + 2.0*b0 + br;
    float edge = sqrt(gx * gx + gy * gy);

    float glow = smoothstep(mix(0.10, 0.05, t), mix(0.26, 0.12, t), edge);
    float3 rimColor = float3(0.70, 0.95, 1.00);

    chrome += rimColor * glow * (0.10 + 0.60 * t);

    float coldShadow = 1.0 - smoothstep(0.0, 0.5, y);
    chrome = mix(chrome, float3(0.06, 0.09, 0.14), coldShadow * (0.15 + 0.30 * t));

    chrome = gentleTonemap(chrome);
    chrome = softContrast(chrome, 0.12 + 0.25 * t);
    chrome = softSaturation(chrome, 0.04 + 0.10 * t);

    float3 outC = mix(src.rgb, clamp(chrome, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
