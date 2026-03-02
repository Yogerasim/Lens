#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

fragment float4 fragment_techlines(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 pixelSize = 1.0 / texSize;
    float time = uniforms.time;

    float4 color = tex.sample(s, uv);
    float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));

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

    float edgeThreshold = 0.08;
    float lineStrength = smoothstep(edgeThreshold, edgeThreshold + 0.05, edge);

    float pulse = 0.7 + sin(time * 2.0) * 0.3;
    float colorShift = time * 0.5;

    float3 neonColor1 = float3(
        0.2 + 0.8 * sin(colorShift),
        0.9,
        0.2 + 0.8 * cos(colorShift)
    );

    float3 neonColor2 = float3(
        0.9,
        0.2 + 0.6 * sin(colorShift + 1.5),
        0.8
    );

    float colorMix = sin(uv.x * 3.14159 + uv.y * 2.0 + time) * 0.5 + 0.5;
    float3 lineColor = mix(neonColor1, neonColor2, colorMix) * pulse;

    float scanLine = sin(uv.y * texSize.y * 0.5 + time * 3.0) * 0.5 + 0.5;
    scanLine = pow(scanLine, 8.0) * 0.15;

    float scanWave = fmod(time * 0.3, 1.0);
    float scanDist = abs(uv.y - scanWave);
    float scanHighlight = smoothstep(0.05, 0.0, scanDist) * 0.4;

    float depth = luma * 0.3;

    float3 finalColor = float3(0.02, 0.02, 0.05);
    finalColor += lineColor * lineStrength;
    finalColor += float3(0.0, scanLine * 0.5, scanLine);
    finalColor += float3(scanHighlight * 0.3, scanHighlight, scanHighlight * 0.8);
    finalColor += float3(depth * 0.1, depth * 0.15, depth * 0.2);

    float3 result = mix(color.rgb, finalColor, uniforms.intensity);
    return float4(result, 1.0);
}
