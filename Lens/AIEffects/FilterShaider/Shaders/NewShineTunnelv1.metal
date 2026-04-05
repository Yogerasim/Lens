#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float2 rotate2d_tunnel(float2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static inline float3 oil_palette(float x) {
    x = fract(x);

    float3 c0 = float3(0.08, 0.02, 0.18); // deep violet
    float3 c1 = float3(0.00, 0.75, 1.00); // cyan
    float3 c2 = float3(0.35, 1.00, 0.18); // acid green
    float3 c3 = float3(1.00, 0.25, 0.72); // magenta
    float3 c4 = float3(1.00, 0.72, 0.10); // amber

    if (x < 0.25) return mix(c0, c1, smoothstep(0.00, 0.25, x));
    if (x < 0.50) return mix(c1, c2, smoothstep(0.25, 0.50, x));
    if (x < 0.75) return mix(c2, c3, smoothstep(0.50, 0.75, x));
    return mix(c3, c4, smoothstep(0.75, 1.00, x));
}

fragment float4 fragment_shinetunnel(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= u.viewAspect;

    float3 src = tex.sample(s, uv).rgb;
    float t = premiumCurve(u.intensity);
    if (t < 0.001) return float4(src, 1.0);

    float time = u.time;

    float3 dir = normalize(float3(centered * 1.15, 1.25));
    float3 p = float3(0.0, 0.0, time * 1.4);

    float accum = 0.0;
    float ridgeAccum = 0.0;
    float colorAccum = 0.0;
    float centerEnergy = 0.0;

    for (int i = 0; i < 20; i++) {
        float fi = float(i);
        float depth = fi * (0.28 + 0.06 * t);

        float3 q = p + dir * depth;
        float2 xy = rotate2d_tunnel(q.xy, -q.z * 0.22 - time * 0.30);

        float radius = length(xy);

        float ringRadius = 0.42 + 0.10 * sin(q.z * 0.9 + time * 1.1);
        float ring = abs(radius - ringRadius);

        float sideWave = sin(q.z * 2.1 - xy.x * 3.2 + time * 1.3);
        float detail = sin(q.z * 4.5 + xy.y * 5.0 - time * 2.1);

        float density = 1.0 / (1.0 + ring * 36.0);
        density += max(0.0, sideWave) * 0.08;
        density += max(0.0, detail) * 0.05;

        float ridge = 1.0 - smoothstep(0.00, 0.08, ring);
        ridge = pow(ridge, 1.8);

        accum += density;
        ridgeAccum += ridge;
        colorAccum += density * (0.5 + 0.5 * sin(q.z * 0.7 + fi * 0.15));
        centerEnergy += smoothstep(0.20, 0.0, ring) * 0.035;
    }

    accum /= 20.0;
    ridgeAccum /= 20.0;
    colorAccum /= 20.0;

    float radial = length(centered);

    float paletteIndex =
        colorAccum * 2.4 +
        ridgeAccum * 0.8 +
        radial * 0.55 -
        time * 0.05;

    float3 slick = oil_palette(paletteIndex);

    float sheen = 0.5 + 0.5 * sin(centered.x * 22.0 - centered.y * 15.0 + time * 1.2);
    float3 sheenCol = oil_palette(paletteIndex + sheen * 0.18 + radial * 0.2);

    float structure = pow(clamp(accum * 1.9, 0.0, 1.0), 1.15);
    float ridges = pow(clamp(ridgeAccum * 2.8, 0.0, 1.0), 0.85);

    float3 fx = src * (1.0 - 0.22 * t);
    fx += slick * structure * (0.38 + 1.10 * t);
    fx += sheenCol * ridges * (0.18 + 0.75 * t);

    float centerGlow = smoothstep(1.05, 0.05, radial);
    fx += float3(1.00, 0.55, 0.95) * centerGlow * centerEnergy * (0.10 + 0.35 * t);

    float vignette = 1.0 - smoothstep(0.45, 1.20, radial);
    fx = mix(src, fx, vignette);

    fx = gentleTonemap(fx);
    fx = softContrast(fx, 0.18 + 0.28 * t);
    fx = softSaturation(fx, 0.20 + 0.35 * t);

    float blend = 0.28 + 0.68 * t;
    return float4(clamp(mix(src, fx, blend), 0.0, 1.0), 1.0);
}
