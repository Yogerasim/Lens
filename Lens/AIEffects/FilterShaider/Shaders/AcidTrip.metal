#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_acidtrip(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float time = uniforms.time;
    float2 uv = in.uv;

    float2 warpedUV = uv;
    warpedUV.x += sin(uv.y * 15.0 + time * 4.0) * 0.02;
    warpedUV.y += cos(uv.x * 15.0 + time * 3.5) * 0.02;

    warpedUV.x += sin(uv.y * 30.0 - time * 6.0) * 0.01;
    warpedUV.y += cos(uv.x * 25.0 + time * 5.0) * 0.01;

    float aberrationAmount = 0.012 + sin(time * 3.0) * 0.008;
    float2 aberrationDir = float2(sin(time * 2.0), cos(time * 2.5));

    float4 colorR = tex.sample(s, warpedUV + aberrationDir * aberrationAmount);
    float4 colorG = tex.sample(s, warpedUV);
    float4 colorB = tex.sample(s, warpedUV - aberrationDir * aberrationAmount);

    float3 color = float3(colorR.r, colorG.g, colorB.b);

    float hueRotation = time * 1.5 + uv.x * 2.0 + uv.y * 2.0;
    float cosH = cos(hueRotation);
    float sinH = sin(hueRotation);

    float3x3 hueMatrix = float3x3(
        float3(0.299 + 0.701*cosH + 0.168*sinH, 0.587 - 0.587*cosH + 0.330*sinH, 0.114 - 0.114*cosH - 0.497*sinH),
        float3(0.299 - 0.299*cosH - 0.328*sinH, 0.587 + 0.413*cosH + 0.035*sinH, 0.114 - 0.114*cosH + 0.292*sinH),
        float3(0.299 - 0.300*cosH + 1.250*sinH, 0.587 - 0.588*cosH - 1.050*sinH, 0.114 + 0.886*cosH - 0.203*sinH)
    );

    color = hueMatrix * color;

    float luma = dot(color, float3(0.299, 0.587, 0.114));
    float saturation = 2.2 + sin(time * 1.5) * 0.6;
    color = mix(float3(luma), color, saturation);

    float stripes1 = sin(uv.x * 40.0 + uv.y * 20.0 + time * 8.0) * 0.5 + 0.5;
    float stripes2 = sin(uv.x * 25.0 - uv.y * 40.0 - time * 6.0) * 0.5 + 0.5;
    float stripes3 = sin((uv.x + uv.y) * 35.0 + time * 10.0) * 0.5 + 0.5;

    float3 rainbow = float3(stripes1, stripes2, stripes3);

    float patternIntensity = 0.12 + sin(time * 2.0) * 0.08;
    color = mix(color, color * (1.0 + rainbow * 0.4), patternIntensity);

    float waves = sin(uv.y * 25.0 - time * 6.0) * 0.5 + 0.5;
    waves = pow(waves, 4.0) * 0.2;
    color += float3(waves * sin(time), waves * sin(time + 2.0), waves * sin(time + 4.0));

    float strobe = 0.9 + sin(time * 12.0) * 0.1;
    color *= strobe;

    color = (color - 0.5) * 1.25 + 0.5;
    color = clamp(color, 0.0, 1.0);

    float noise = fract(sin(dot(uv + time, float2(12.9898, 78.233))) * 43758.5453);
    color += (noise - 0.5) * 0.04;

    float4 originalColor = tex.sample(s, uv);
    float3 result = mix(originalColor.rgb, color, uniforms.intensity);

    return float4(result, 1.0);
}
