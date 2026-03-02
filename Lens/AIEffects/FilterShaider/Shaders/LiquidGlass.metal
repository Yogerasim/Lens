#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

inline float hash12(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

inline float3 iridescent(float x) {
    x = fract(x);
    float3 a = float3(1.00, 0.10, 0.55);
    float3 b = float3(0.10, 0.95, 0.85);
    float3 c = float3(0.95, 0.85, 0.10);
    float3 d = float3(0.30, 0.45, 1.00);

    float t = x * 3.0;
    int seg = (int)floor(t);
    float f = fract(t);

    if (seg <= 0) return mix(a, b, f);
    if (seg == 1) return mix(b, c, f);
    return mix(c, d, f);
}

inline float boxMask(float2 local, float fill) {
    float2 d = abs(local - 0.5);
    float m = max(d.x, d.y);
    return 1.0 - smoothstep(fill, fill + 0.05, m);
}

inline float heightFast(float2 uv, float time) {
    float2 p = uv * 32.0 + float2(time * 0.12, -time * 0.10);
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash12(i);
    float b = hash12(i + float2(1.0, 0.0));
    float c = hash12(i + float2(0.0, 1.0));
    float d = hash12(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fragment float4 fragment_liquidglass(
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

    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 px = 1.0 / texSize;
    float2 p = uv * texSize;

    float hC = heightFast(uv, time);
    float hX = heightFast(uv + float2(px.x, 0.0), time);
    float hY = heightFast(uv + float2(0.0, px.y), time);
    float2 g = float2(hX - hC, hY - hC);

    float3 n = normalize(float3(-g.x * 3.2, -g.y * 3.2, 1.0));

    float edgeN = length(fwidth(n.xy)) * 30.0;
    float edgeMask = smoothstep(0.10, 0.38, edgeN);
    edgeMask *= (0.25 + 0.75 * t);

    float strength = clamp(edgeMask, 0.0, 1.0);

    float cellBase = mix(2.0, 6.0, smoothstep(0.15, 0.90, strength));
    float2 coarseCell = floor(p / 10.0);
    float jitter = hash12(coarseCell + 7.3);
    float cellSize = clamp(floor(cellBase + jitter * 2.0), 2.0, 6.0);

    float2 cell = floor(p / cellSize);
    float2 local = fract(p / cellSize);

    float fill = mix(0.44, 0.20, smoothstep(0.10, 0.85, strength));
    fill += (hash12(cell + 19.7) - 0.5) * 0.08;
    fill = clamp(fill, 0.12, 0.48);

    float sq = boxMask(local, fill);

    float appear = step(0.55, hash12(cell + 3.1));
    float blockMask = sq * strength * appear;

    float hue = hash12(cell) + time * 0.22 + (n.x + n.y) * 0.9;
    float3 rimColor = iridescent(hue);

    float3 outC = src.rgb;

    float darkStrength = (0.10 + 0.28 * t) * strength;
    outC *= (1.0 - darkStrength);

    float rimStrength = (0.18 + 0.85 * t) * strength;
    outC += rimColor * rimStrength;

    float3 coldWhite = float3(0.82, 0.95, 1.0);
    float sparkle = pow(strength, 2.0) * (0.05 + 0.18 * t);
    outC += coldWhite * sparkle;

    float blockStrength = (0.20 + 0.80 * t);
    outC = mix(outC, rimColor, clamp(blockMask * blockStrength, 0.0, 1.0));
    outC += coldWhite * (blockMask * (0.03 + 0.09 * t));

    outC = gentleTonemap(outC);
    outC = softContrast(outC, 0.20 + 0.18 * t);
    outC = softSaturation(outC, 0.14 + 0.16 * t);

    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
