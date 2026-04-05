#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float2 rot2_oil(float2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static inline float3 tunnel_oil_palette(float x) {
    x = fract(x);

    float3 c0 = float3(0.04, 0.02, 0.14);
    float3 c1 = float3(0.00, 0.74, 1.00);
    float3 c2 = float3(0.35, 1.00, 0.18);
    float3 c3 = float3(1.00, 0.20, 0.72);
    float3 c4 = float3(1.00, 0.76, 0.12);
    float3 c5 = float3(0.92, 0.96, 1.00);

    if (x < 0.18) return mix(c0, c1, smoothstep(0.00, 0.18, x));
    if (x < 0.38) return mix(c1, c2, smoothstep(0.18, 0.38, x));
    if (x < 0.58) return mix(c2, c3, smoothstep(0.38, 0.58, x));
    if (x < 0.80) return mix(c3, c4, smoothstep(0.58, 0.80, x));
    return mix(c4, c5, smoothstep(0.80, 1.00, x));
}

fragment float4 fragment_shinetunneloilslick(
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
    float lum = luma(src);

    float3 dir = normalize(float3(centered * (1.18 + 0.08 * t), 1.28));
    float3 ro = float3(0.0, 0.0, time * 1.45);

    float densityAcc = 0.0;
    float ridgeAcc = 0.0;
    float bandAcc = 0.0;
    float centerAcc = 0.0;

    for (int i = 0; i < 22; i++) {
        float fi = float(i);
        float z = fi * (0.26 + 0.05 * t);

        float3 q = ro + dir * z;
        float2 xy = rot2_oil(q.xy, -q.z * 0.20 - time * 0.28);

        float radius = length(xy);
        float ringRadius = 0.40 + 0.12 * sin(q.z * 0.95 + time * 1.0);
        float ring = abs(radius - ringRadius);

        float bandWave = sin(q.z * 2.6 - xy.x * 3.0 + time * 1.4);
        float microWave = sin(q.z * 5.4 + xy.y * 5.8 - time * 2.0);

        float density = 1.0 / (1.0 + ring * 42.0);
        density += max(0.0, bandWave) * 0.08;
        density += max(0.0, microWave) * 0.04;

        float ridge = 1.0 - smoothstep(0.00, 0.06, ring);
        ridge = pow(ridge, 2.0);

        densityAcc += density;
        ridgeAcc += ridge;
        bandAcc += density * (0.5 + 0.5 * sin(q.z * 0.85 + fi * 0.13));
        centerAcc += smoothstep(0.18, 0.0, ring) * 0.04;
    }

    densityAcc /= 22.0;
    ridgeAcc /= 22.0;
    bandAcc /= 22.0;

    float radial = length(centered);
    float phase = bandAcc * 2.6 + ridgeAcc * 1.0 + radial * 0.55 - time * 0.06 + lum * 0.18;

    float3 slickA = tunnel_oil_palette(phase);
    float3 slickB = tunnel_oil_palette(phase + 0.14 + densityAcc * 0.20);
    float3 slickC = tunnel_oil_palette(phase - 0.10 + radial * 0.18);

    float structure = pow(clamp(densityAcc * 2.4, 0.0, 1.0), 1.02);
    float ridges = pow(clamp(ridgeAcc * 3.2, 0.0, 1.0), 0.80);

    float sweep = sin(centered.x * 24.0 - centered.y * 17.0 + time * 1.25) * 0.5 + 0.5;

    float3 baseDark = mix(
        float3(0.012, 0.010, 0.020),
        float3(lum) * float3(0.10, 0.11, 0.14),
        0.22 + 0.20 * smoothstep(0.05, 0.95, lum)
    );

    float3 fx = baseDark;
    fx += slickA * structure * (0.72 + 1.35 * t);
    fx += slickB * ridges * (0.34 + 0.95 * t);
    fx += slickC.bgr * sweep * ridges * (0.10 + 0.24 * t);

    float centerGlow = smoothstep(1.05, 0.06, radial);
    fx += float3(1.0, 0.62, 0.96) * centerGlow * centerAcc * (0.16 + 0.42 * t);

    float ca = (0.002 + 0.006 * t) * ridges;
    float3 disp;
    disp.r = tex.sample(s, clamp(uv + float2( ca, 0.0), 0.0, 1.0)).r;
    disp.g = tex.sample(s, clamp(uv, 0.0, 1.0)).g;
    disp.b = tex.sample(s, clamp(uv - float2( ca, 0.0), 0.0, 1.0)).b;

    fx += disp * slickA * (0.08 + 0.16 * t);

    float vignette = smoothstep(1.20, 0.10, radial);
    fx *= vignette;

    fx = gentleTonemap(fx);
    fx = softContrast(fx, 0.24 + 0.34 * t);
    fx = softSaturation(fx, 0.28 + 0.40 * t);

    return float4(clamp(fx, 0.0, 1.0), 1.0);
}
