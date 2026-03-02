#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 5; i++) {
        value += amplitude * noise2D(p * frequency + time * 0.1);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

fragment float4 fragment_neuralpainter(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float time = uniforms.time;
    float2 uv = in.uv;
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 pixelSize = 1.0 / texSize;

    float4 originalColor = tex.sample(s, uv);
    float luma = dot(originalColor.rgb, float3(0.299, 0.587, 0.114));

    float3 tl = tex.sample(s, uv + float2(-pixelSize.x, -pixelSize.y)).rgb;
    float3 t  = tex.sample(s, uv + float2(0, -pixelSize.y)).rgb;
    float3 tr = tex.sample(s, uv + float2(pixelSize.x, -pixelSize.y)).rgb;
    float3 l  = tex.sample(s, uv + float2(-pixelSize.x, 0)).rgb;
    float3 r  = tex.sample(s, uv + float2(pixelSize.x, 0)).rgb;
    float3 bl = tex.sample(s, uv + float2(-pixelSize.x, pixelSize.y)).rgb;
    float3 b  = tex.sample(s, uv + float2(0, pixelSize.y)).rgb;
    float3 br = tex.sample(s, uv + float2(pixelSize.x, pixelSize.y)).rgb;

    float tlL = dot(tl, float3(0.299, 0.587, 0.114));
    float tL  = dot(t,  float3(0.299, 0.587, 0.114));
    float trL = dot(tr, float3(0.299, 0.587, 0.114));
    float lL  = dot(l,  float3(0.299, 0.587, 0.114));
    float rL  = dot(r,  float3(0.299, 0.587, 0.114));
    float blL = dot(bl, float3(0.299, 0.587, 0.114));
    float bL  = dot(b,  float3(0.299, 0.587, 0.114));
    float brL = dot(br, float3(0.299, 0.587, 0.114));

    float sobelX = -tlL - 2.0*lL - blL + trL + 2.0*rL + brL;
    float sobelY = -tlL - 2.0*tL - trL + blL + 2.0*bL + brL;
    float edge = sqrt(sobelX * sobelX + sobelY * sobelY);
    float edgeAngle = atan2(sobelY, sobelX);

    float brushScale = 40.0 + sin(time * 0.3) * 8.0;
    float2 brushUV = uv * brushScale;

    float brushNoise = fbm(brushUV + float2(time * 0.2, time * 0.15), time);
    float brushNoise2 = fbm(brushUV * 1.3 - float2(time * 0.15, time * 0.25), time * 0.8);

    float2 brushDir = float2(cos(edgeAngle + brushNoise * 2.0), sin(edgeAngle + brushNoise * 2.0));

    float flowAmount = 0.006 + edge * 0.012;
    float2 flowOffset = brushDir * flowAmount * sin(time * 1.5 + brushNoise * 4.0);
    float2 flowedUV = uv + flowOffset;

    float4 flowedColor = tex.sample(s, flowedUV);

    float waveFreq = 25.0;
    float wave1 = sin(uv.x * waveFreq + uv.y * waveFreq * 0.5 + time * 2.0 + brushNoise * 8.0);
    float wave2 = sin(uv.y * waveFreq * 0.7 - uv.x * waveFreq * 0.3 + time * 1.8 + brushNoise2 * 6.0);
    float generativePattern = (wave1 * wave2) * 0.5 + 0.5;
    generativePattern *= smoothstep(0.1, 0.4, edge);

    float edgeGlow = edge * (0.6 + 0.4 * sin(time * 2.0 + uv.y * 10.0));
    float glow = pow(luma, 2.5) * (0.4 + 0.3 * sin(time * 1.5));

    float3 finalColor = flowedColor.rgb;
    finalColor = mix(finalColor, originalColor.rgb, 0.2);

    float3 patternColor = float3(
        sin(time * 0.8 + generativePattern * 3.0) * 0.5 + 0.5,
        sin(time * 1.1 + generativePattern * 4.0 + 2.0) * 0.5 + 0.5,
        sin(time * 0.6 + generativePattern * 5.0 + 4.0) * 0.5 + 0.5
    );
    finalColor = mix(finalColor, patternColor, generativePattern * 0.35);

    float3 edgeColor = float3(0.4, 0.7, 1.0) * edgeGlow;
    finalColor += edgeColor * 0.25;

    float3 glowColor = float3(1.0, 0.95, 0.85) * glow * 0.25;
    finalColor += glowColor;

    finalColor = (finalColor - 0.5) * 1.1 + 0.5;

    float finalLuma = dot(finalColor, float3(0.299, 0.587, 0.114));
    finalColor = mix(float3(finalLuma), finalColor, 1.25);

    float3 result = mix(originalColor.rgb, clamp(finalColor, 0.0, 1.0), uniforms.intensity);
    return float4(result, 1.0);
}
