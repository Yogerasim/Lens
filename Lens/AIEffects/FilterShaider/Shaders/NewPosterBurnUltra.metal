#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float3 posterburn_ultra_palette(float x) {
    x = clamp(x, 0.0, 1.0);

    float3 c0 = float3(0.16, 0.00, 0.26); // deep purple
    float3 c1 = float3(1.00, 0.08, 0.62); // magenta
    float3 c2 = float3(0.00, 0.88, 1.00); // cyan
    float3 c3 = float3(0.45, 1.00, 0.12); // acid green
    float3 c4 = float3(1.00, 0.42, 0.05); // orange
    float3 c5 = float3(1.00, 0.94, 0.20); // yellow

    if (x < 0.20) return mix(c0, c1, smoothstep(0.00, 0.20, x));
    if (x < 0.40) return mix(c1, c2, smoothstep(0.20, 0.40, x));
    if (x < 0.60) return mix(c2, c3, smoothstep(0.40, 0.60, x));
    if (x < 0.80) return mix(c3, c4, smoothstep(0.60, 0.80, x));
    return mix(c4, c5, smoothstep(0.80, 1.00, x));
}

fragment float4 fragment_posterburnultra(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 src = tex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return src;

    float3 base = gentleTonemap(src.rgb);
    float y = luma(base);

    // Немного усиливаем separation тонов, чтобы палитра читалась ярче
    float shaped = pow(clamp(y, 0.0, 1.0), mix(1.15, 0.82, t));

    float3 poster = posterburn_ultra_palette(shaped);

    // Легкая дополнительная постеризация поверх smooth palette
    float levels = mix(12.0, 6.0, t);
    poster = floor(poster * levels + 0.5) / levels;

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 px = 1.0 / texSize;

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

    float edgeMask = smoothstep(mix(0.18, 0.08, t), mix(0.28, 0.12, t), edge);

    // Черные комикс-контуры
    float3 ink = float3(0.015, 0.01, 0.02);
    poster = mix(poster, ink, edgeMask * (0.48 + 0.42 * t));

    // Легкий glow по ярким зонам
    float glowMask = smoothstep(0.62, 1.0, shaped);
    poster += float3(1.0, 0.35, 0.55) * glowMask * (0.02 + 0.10 * t);

    poster = softContrast(poster, 0.12 + 0.28 * t);
    poster = softSaturation(poster, 0.24 + 0.55 * t);

    float3 outC = mix(src.rgb, clamp(poster, 0.0, 1.0), t);
    return float4(outC, 1.0);
}
