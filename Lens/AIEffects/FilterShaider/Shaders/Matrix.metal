#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float hash12(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static inline float luma709(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

fragment float4 fragment_matrix(
    VertexOut in [[stage_in]],
    texture2d<float> camTex [[texture(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = camTex.sample(s, uv);

    float t = premiumCurve(u.intensity);
    if (t < 0.001) return cam;

    float cellX = mix(90.0, 140.0, t);
    float cellY = cellX * 1.6;

    float2 grid = float2(cellX, cellY);
    float2 p = uv * grid;

    float2 ip = floor(p);
    float2 fp = fract(p);

    
    float colSeed = hash12(float2(ip.x, 17.0));
    float speed = mix(0.45, 1.25, colSeed);

    float head = fract(-u.time * speed + colSeed);
    float dist = abs(fp.y - head);

    
    float headMask = smoothstep(0.10, 0.0, dist);
    float tail = smoothstep(0.55, 0.0, fp.y - head);
    tail *= smoothstep(0.0, 0.95, head - fp.y);

    float trail = max(headMask, tail * 0.55);

    
    float glyphSeed = hash12(ip + float2(3.1, 7.7));
    float2 g = fp - 0.5;
    float gx = 1.0 - smoothstep(0.18, 0.22, abs(g.x + (glyphSeed - 0.5) * 0.12));
    float gy = 1.0 - smoothstep(0.12, 0.16, abs(g.y));
    float glyph = gx * gy;

    float strength = trail * glyph;

    
    float3 green = float3(0.08, 1.0, 0.35);
    float3 neon  = float3(0.55, 1.0, 0.70);
    float3 codeColor = mix(green, neon, headMask);

    
    float camL = luma709(cam.rgb);
    float3 base = float3(camL) * (0.55 + 0.20 * (1.0 - t));

    float3 over = base + codeColor * (0.35 + 0.85 * t) * strength;

    
    over += codeColor * headMask * (0.08 + 0.18 * t);

    float3 outC = mix(cam.rgb, over, t);
    outC = gentleTonemap(outC);
    outC = softContrast(outC, 0.20 * t);

    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
