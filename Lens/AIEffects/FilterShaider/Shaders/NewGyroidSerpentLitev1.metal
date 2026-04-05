#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float gyroid_field(float3 p) {
    return dot(cos(p), sin(p.zxy));
}

static inline float gyroid_layer(float3 p, float scale, float time) {
    p *= scale;
    p.z += time;
    return gyroid_field(p);
}

static inline float3 oil_slick_palette(float x) {
    x = fract(x);

    float3 c0 = float3(0.06, 0.02, 0.16); // deep indigo
    float3 c1 = float3(0.00, 0.82, 1.00); // cyan
    float3 c2 = float3(0.42, 1.00, 0.14); // acid green
    float3 c3 = float3(1.00, 0.22, 0.68); // magenta
    float3 c4 = float3(1.00, 0.78, 0.12); // amber
    float3 c5 = float3(0.90, 0.95, 1.00); // pearl

    if (x < 0.20) return mix(c0, c1, smoothstep(0.00, 0.20, x));
    if (x < 0.40) return mix(c1, c2, smoothstep(0.20, 0.40, x));
    if (x < 0.60) return mix(c2, c3, smoothstep(0.40, 0.60, x));
    if (x < 0.80) return mix(c3, c4, smoothstep(0.60, 0.80, x));
    return mix(c4, c5, smoothstep(0.80, 1.00, x));
}

fragment float4 fragment_gyroidserpent(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float2 p = uv * 2.0 - 1.0;
    p.x *= u.viewAspect;

    float3 src = tex.sample(s, uv).rgb;
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return float4(src, 1.0);

    float time = u.time * 0.9;
    float3 pos = float3(p * (1.5 + 0.55 * t), time * 0.9);

    float g1 = gyroid_layer(pos + float3(0.0, 0.0, 0.0), 2.8, time * 0.8);
    float g2 = gyroid_layer(pos + float3(1.7, 0.8, 1.2), 4.0, -time * 0.5);
    float g3 = gyroid_layer(pos + float3(-1.0, 1.5, -0.6), 5.4, time * 0.3);

    float field = g1 * 0.55 + g2 * 0.30 + g3 * 0.15;

    float bands  = 1.0 - smoothstep(0.10, 0.28, abs(field));
    float core   = 1.0 - smoothstep(0.00, 0.07, abs(field));
    float veins  = 1.0 - smoothstep(0.22, 0.34, abs(field + 0.08 * sin(pos.z * 3.0)));

    float eps = 0.035;
    float fx = gyroid_layer(pos + float3(eps, 0.0, 0.0), 2.8, time * 0.8)
             - gyroid_layer(pos - float3(eps, 0.0, 0.0), 2.8, time * 0.8);
    float fy = gyroid_layer(pos + float3(0.0, eps, 0.0), 2.8, time * 0.8)
             - gyroid_layer(pos - float3(0.0, eps, 0.0), 2.8, time * 0.8);

    float3 n = normalize(float3(fx, fy, 0.30));
    float3 L = normalize(float3(-0.45, 0.55, 0.70));

    float diff = clamp(dot(n, L), 0.0, 1.0);
    float fres = pow(1.0 - clamp(n.z * 0.5 + 0.5, 0.0, 1.0), 2.5);
    float spec = pow(max(0.0, dot(reflect(-L, n), float3(0.0, 0.0, 1.0))), 12.0);

    float paletteIndex =
        field * 0.45 +
        time * 0.05 +
        length(p) * 0.22 +
        diff * 0.12;

    float3 slick = oil_slick_palette(paletteIndex);
    float3 slick2 = oil_slick_palette(paletteIndex + 0.15 + core * 0.2);

    float lum = luma(src);
    float attach = smoothstep(0.08, 0.95, lum) * 0.55 + 0.45;

    float3 baseDark = src * (0.84 - 0.24 * t);
    float3 glossy = slick * (0.28 + 0.95 * diff);
    glossy += slick2 * veins * (0.10 + 0.35 * t);
    glossy += float3(0.95, 0.98, 1.0) * fres * (0.10 + 0.30 * t);
    glossy += float3(1.0) * spec * (0.08 + 0.22 * t);

    float mask = bands * (0.40 + 0.95 * t) + core * (0.12 + 0.25 * t);
    mask = clamp(mask, 0.0, 1.0);

    float3 fxCol = baseDark;
    fxCol += glossy * mask * attach;

    fxCol = gentleTonemap(fxCol);
    fxCol = softContrast(fxCol, 0.18 + 0.30 * t);
    fxCol = softSaturation(fxCol, 0.20 + 0.32 * t);

    float blend = 0.26 + 0.66 * t;
    return float4(clamp(mix(src, fxCol, blend), 0.0, 1.0), 0.0 + 1.0);
}
