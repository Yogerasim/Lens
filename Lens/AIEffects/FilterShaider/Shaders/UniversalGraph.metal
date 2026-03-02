#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

// Grain
float3 applyGrain(float3 color, float2 uv, float time, float intensity) {
    float noise = fract(sin(dot(uv * 1000.0, float2(12.9898, 78.233)) + time) * 43758.5453);
    noise = (noise - 0.5) * 0.3 * intensity;
    return color + float3(noise);
}

// Outline
float3 applyOutline(float3 color, float2 uv, texture2d<float> tex, sampler s, float intensity) {
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 ps = 1.0 / texSize;

    float tl = dot(tex.sample(s, uv + float2(-ps.x, -ps.y)).rgb, float3(0.299, 0.587, 0.114));
    float t  = dot(tex.sample(s, uv + float2(0, -ps.y)).rgb, float3(0.299, 0.587, 0.114));
    float tr = dot(tex.sample(s, uv + float2(ps.x, -ps.y)).rgb, float3(0.299, 0.587, 0.114));
    float l  = dot(tex.sample(s, uv + float2(-ps.x, 0)).rgb, float3(0.299, 0.587, 0.114));
    float r  = dot(tex.sample(s, uv + float2(ps.x, 0)).rgb, float3(0.299, 0.587, 0.114));
    float bl = dot(tex.sample(s, uv + float2(-ps.x, ps.y)).rgb, float3(0.299, 0.587, 0.114));
    float b  = dot(tex.sample(s, uv + float2(0, ps.y)).rgb, float3(0.299, 0.587, 0.114));
    float br = dot(tex.sample(s, uv + float2(ps.x, ps.y)).rgb, float3(0.299, 0.587, 0.114));

    float sobelX = -tl - 2.0*l - bl + tr + 2.0*r + br;
    float sobelY = -tl - 2.0*t - tr + bl + 2.0*b + br;
    float edge = sqrt(sobelX * sobelX + sobelY * sobelY);

    float edgeMask = smoothstep(0.1, 0.3, edge) * intensity;
    return mix(color, float3(0.0), edgeMask);
}

// Blur (5-tap)
float3 applyBlur(float2 uv, texture2d<float> tex, sampler s, float intensity) {
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 ps = 1.0 / texSize * intensity * 3.0;

    float3 sum = tex.sample(s, uv).rgb;
    sum += tex.sample(s, uv + float2(-ps.x, 0)).rgb;
    sum += tex.sample(s, uv + float2( ps.x, 0)).rgb;
    sum += tex.sample(s, uv + float2(0, -ps.y)).rgb;
    sum += tex.sample(s, uv + float2(0,  ps.y)).rgb;

    return sum / 5.0;
}

// Color shift
float3 applyColorShift(float3 color, float time, float intensity) {
    float shift = time * 0.5 * intensity;

    float maxC = max(max(color.r, color.g), color.b);
    float minC = min(min(color.r, color.g), color.b);
    float delta = maxC - minC;

    float h = 0.0;
    if (delta > 0.0001) {
        if (maxC == color.r)      h = fmod((color.g - color.b) / delta, 6.0);
        else if (maxC == color.g) h = (color.b - color.r) / delta + 2.0;
        else                      h = (color.r - color.g) / delta + 4.0;
        h /= 6.0;
    }

    float s = (maxC > 0.0001) ? delta / maxC : 0.0;
    float v = maxC;

    h = fract(h + shift);

    float c = v * s;
    float x = c * (1.0 - abs(fmod(h * 6.0, 2.0) - 1.0));
    float m = v - c;

    float3 rgb;
    if (h < 1.0/6.0)      rgb = float3(c, x, 0);
    else if (h < 2.0/6.0) rgb = float3(x, c, 0);
    else if (h < 3.0/6.0) rgb = float3(0, c, x);
    else if (h < 4.0/6.0) rgb = float3(0, x, c);
    else if (h < 5.0/6.0) rgb = float3(x, 0, c);
    else                  rgb = float3(c, 0, x);

    return rgb + m;
}

// Vignette
float3 applyVignette(float3 color, float2 uv, float intensity) {
    float2 center = uv - 0.5;
    float dist = length(center);
    float vignette = 1.0 - smoothstep(0.3, 0.8, dist) * intensity;
    return color * vignette;
}

// MARK: - Universal Graph Fragment
fragment float4 fragment_universalgraph(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &uniforms [[buffer(0)]],
    constant int *nodeTypes [[buffer(1)]],
    constant float *nodeIntensities [[buffer(2)]],
    constant int &nodeCount [[buffer(3)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float2 uv = in.uv;
    float4 originalColor = tex.sample(s, uv);
    float3 color = originalColor.rgb;
    float time = uniforms.time;

    for (int i = 0; i < nodeCount && i < 8; i++) {
        int nodeType = nodeTypes[i];
        float nodeIntensity = nodeIntensities[i];
        if (nodeIntensity <= 0.0) continue;

        switch (nodeType) {
            case 1: color = applyGrain(color, uv, time, nodeIntensity); break;
            case 2: color = applyOutline(color, uv, tex, s, nodeIntensity); break;
            case 3: color = applyBlur(uv, tex, s, nodeIntensity); break;
            case 4: color = applyColorShift(color, time, nodeIntensity); break;
            case 5: color = applyVignette(color, uv, nodeIntensity); break;

            case 6: // fogDepth
                if (uniforms.hasDepth > 0.5) {
                    float2 depthUV = uv;
                    if (uniforms.depthFlipX > 0.5) depthUV.x = 1.0 - depthUV.x;
                    if (uniforms.depthFlipY > 0.5) depthUV.y = 1.0 - depthUV.y;

                    float depth = depthTex.sample(s, depthUV).r;
                    float normalizedDepth = clamp(depth * 2.0, 0.0, 1.0);
                    float3 fogColor = float3(0.7, 0.8, 0.9);
                    color = mix(color, fogColor, normalizedDepth * nodeIntensity);
                }
                break;

            case 7: { // stripes
                float frequency = 20.0;
                float angle = time * 0.5;
                float2 rotatedUV = float2(
                    uv.x * cos(angle) - uv.y * sin(angle),
                    uv.x * sin(angle) + uv.y * cos(angle)
                );
                float stripe = sin(rotatedUV.x * frequency * 3.14159) * 0.5 + 0.5;
                stripe = smoothstep(0.3, 0.7, stripe);
                color = mix(color, color * (0.7 + stripe * 0.3), nodeIntensity);
            } break;

            default: break;
        }
    }

    float3 result = mix(originalColor.rgb, color, uniforms.intensity);
    return float4(result, 1.0);
}
