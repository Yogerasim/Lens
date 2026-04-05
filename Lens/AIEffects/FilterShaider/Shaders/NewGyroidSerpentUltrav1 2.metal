#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float gyroid_field_ultra(float3 p) {
    return dot(cos(p), sin(p.zxy));
}

static inline float gyroid_mix_layer(float3 p, float time) {
    float g1 = gyroid_field_ultra(p * 2.8 + float3(0.0, 0.0, time * 0.9));
    float g2 = gyroid_field_ultra(p * 4.4 + float3(1.7, -0.8, -time * 0.6));
    float g3 = gyroid_field_ultra(p * 6.2 + float3(-1.1, 1.2, time * 0.35));
    return g1 * 0.56 + g2 * 0.29 + g3 * 0.15;
}

static inline float3 oil_ultra_palette(float x) {
    x = fract(x);

    float3 c0 = float3(0.03, 0.02, 0.12); // deep indigo
    float3 c1 = float3(0.00, 0.78, 1.00); // cyan
    float3 c2 = float3(0.34, 1.00, 0.18); // acid green
    float3 c3 = float3(1.00, 0.22, 0.70); // magenta
    float3 c4 = float3(1.00, 0.74, 0.08); // amber
    float3 c5 = float3(0.92, 0.96, 1.00); // pearl

    if (x < 0.18) return mix(c0, c1, smoothstep(0.00, 0.18, x));
    if (x < 0.36) return mix(c1, c2, smoothstep(0.18, 0.36, x));
    if (x < 0.56) return mix(c2, c3, smoothstep(0.36, 0.56, x));
    if (x < 0.78) return mix(c3, c4, smoothstep(0.56, 0.78, x));
    return mix(c4, c5, smoothstep(0.78, 1.00, x));
}

fragment float4 fragment_gyroidserpentultra(
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

    float time = u.time * 0.95;

    float3 pos = float3(p * (1.65 + 0.75 * t), time * 0.85);

    float field = gyroid_mix_layer(pos, time);

    float bands = 1.0 - smoothstep(0.08, 0.26, abs(field));
    float core  = 1.0 - smoothstep(0.00, 0.06, abs(field));
    float veins = 1.0 - smoothstep(0.16, 0.30, abs(field + 0.10 * sin(pos.z * 3.4 + pos.x * 1.5)));
    float shell = 1.0 - smoothstep(0.26, 0.40, abs(field));

    float eps = 0.035;
    float fx = gyroid_mix_layer(pos + float3(eps, 0.0, 0.0), time) - gyroid_mix_layer(pos - float3(eps, 0.0, 0.0), time);
    float fy = gyroid_mix_layer(pos + float3(0.0, eps, 0.0), time) - gyroid_mix_layer(pos - float3(0.0, eps, 0.0), time);
    float fz = gyroid_mix_layer(pos + float3(0.0, 0.0, eps), time) - gyroid_mix_layer(pos - float3(0.0, 0.0, eps), time);

    float3 n = normalize(float3(fx, fy, 0.42 + 0.25 * fz));
    float3 L = normalize(float3(-0.45, 0.58, 0.68));
    float3 V = float3(0.0, 0.0, 1.0);

    float diff = clamp(dot(n, L), 0.0, 1.0);
    float fres = pow(1.0 - clamp(dot(n, V) * 0.5 + 0.5, 0.0, 1.0), 2.8);
    float spec = pow(max(0.0, dot(reflect(-L, n), V)), 18.0);

    float lum = luma(src);
    float attach = smoothstep(0.04, 0.95, lum) * 0.55 + 0.45;

    float phase = field * 0.55 + length(p) * 0.24 + time * 0.05 + diff * 0.18 + lum * 0.15;
    float3 slickA = oil_ultra_palette(phase);
    float3 slickB = oil_ultra_palette(phase + 0.16 + veins * 0.18);
    float3 slickC = oil_ultra_palette(phase + shell * 0.22 - time * 0.03);

    float micro = sin(pos.x * 8.0 + time * 1.3) * sin(pos.y * 7.0 - time * 1.1);
    micro = 0.5 + 0.5 * micro;

    float3 baseDark = mix(
        float3(0.015, 0.012, 0.028),
        float3(lum) * float3(0.10, 0.11, 0.14),
        0.30 + 0.20 * attach
    );

    float3 glossy = slickA * (0.70 + 1.40 * diff);
    glossy += slickB * veins * (0.24 + 0.50 * t);
    glossy += slickC * shell * (0.14 + 0.34 * t);
    glossy += float3(0.96, 0.98, 1.00) * fres * (0.16 + 0.42 * t);
    glossy += float3(1.0) * spec * (0.14 + 0.34 * t);
    glossy += slickA.bgr * micro * core * (0.08 + 0.18 * t);

    float mask = bands * (0.90 + 1.30 * t);
    mask += core * (0.22 + 0.38 * t);
    mask += veins * (0.10 + 0.22 * t);
    mask = clamp(mask, 0.0, 1.0);

    float rim = smoothstep(1.10, 0.10, length(p));

    float3 fxCol = baseDark;
    fxCol += glossy * mask * attach * rim;

    fxCol = gentleTonemap(fxCol);
    fxCol = softContrast(fxCol, 0.26 + 0.36 * t);
    fxCol = softSaturation(fxCol, 0.28 + 0.42 * t);

    return float4(clamp(fxCol, 0.0, 1.0), 1.0);
}
