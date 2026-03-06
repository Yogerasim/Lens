#include "Helpers/ShaderTypes.metalh"
#include "Helpers/ShadersCommon.metalh"

static inline float3 thermalPaletteSmooth(float t) {
    t = clamp(t, 0.0, 1.0);

    
    float3 a = float3(0.10, 0.10, 0.12); // почти черный
    float3 b = float3(0.10, 0.35, 0.90); // deep blue
    float3 c = float3(0.00, 0.95, 0.95); // cyan
    float3 d = float3(1.00, 0.85, 0.05); // amber
    float3 e = float3(1.00, 0.20, 0.05); // hot red

    
    float x = t * 4.0;
    int seg = (int)floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f); // smooth

    if (seg <= 0) return mix(a, b, f);
    if (seg == 1) return mix(b, c, f);
    if (seg == 2) return mix(c, d, f);
    return mix(d, e, f);
}

static inline float sampleDepthEdgeAware(
    float2 uv,
    texture2d<float> depthTex,
    texture2d<float> camTex,
    sampler s
) {
    
    float2 ds = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float3 camC = camTex.sample(s, uv).rgb;
    float baseY = luma(camC);

    float depthCenter = depthTex.sample(s, uv).r;

    
    
    if (!(depthCenter > 0.00001)) {
        return depthCenter;
    }

    float sum = 0.0;
    float wsum = 0.0;

    
    const int2 offs[9] = {
        int2(0,0),
        int2(1,0), int2(-1,0),
        int2(0,1), int2(0,-1),
        int2(1,1), int2(-1,1),
        int2(1,-1), int2(-1,-1)
    };

    for (int i = 0; i < 9; i++) {
        float2 o = float2(offs[i]) * ds;
        float2 u = uv + o;

        float d = depthTex.sample(s, u).r;

        
        float wd = exp(-abs(d - depthCenter) * 12.0);

        
        float y = luma(camTex.sample(s, u).rgb);
        float wy = exp(-abs(y - baseY) * 25.0);

        float w = wd * wy;

        sum += d * w;
        wsum += w;
    }

    return (wsum > 0.0) ? (sum / wsum) : depthCenter;
}

static inline float3 normalFromDepth(float2 uv, float depthM, texture2d<float> depthTex, sampler s) {
    
    float2 ds = 1.0 / float2(depthTex.get_width(), depthTex.get_height());

    float dL = depthTex.sample(s, uv + float2(-ds.x, 0)).r;
    float dR = depthTex.sample(s, uv + float2( ds.x, 0)).r;
    float dU = depthTex.sample(s, uv + float2(0, -ds.y)).r;
    float dD = depthTex.sample(s, uv + float2(0,  ds.y)).r;

    
    if (!(dL > 0.00001)) dL = depthM;
    if (!(dR > 0.00001)) dR = depthM;
    if (!(dU > 0.00001)) dU = depthM;
    if (!(dD > 0.00001)) dD = depthM;

    
    float sx = (dR - dL) * 1.8;
    float sy = (dD - dU) * 1.8;

    
    float3 n = normalize(float3(-sx, -sy, 1.0));
    return n;
}

fragment float4 fragment_depththermal(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &u [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 cam = tex.sample(s, uv);

    if (u.hasDepth < 0.5) {
        return cam;
    }

    
    float2 duv = uv;
    if (u.depthFlipX > 0.5) duv.x = 1.0 - duv.x;
    if (u.depthFlipY > 0.5) duv.y = 1.0 - duv.y;

    
    float depthM = sampleDepthEdgeAware(duv, depthTex, tex, s);

    
    
    float nearM = 0.35;
    float farM  = 4.00;

    float nd = (depthM - nearM) / (farM - nearM);
    nd = clamp(nd, 0.0, 1.0);

    
    float3 thermal = thermalPaletteSmooth(nd);

    
    {
        float2 p = uv * float2(tex.get_width(), tex.get_height());
        float b = bayer4x4(p);
        float amp = 0.010; // очень мягко
        float mid = smoothstep(0.10, 0.35, nd) * (1.0 - smoothstep(0.70, 0.98, nd));
        thermal += (b - 0.5) * amp * mid;
        thermal = clamp(thermal, 0.0, 1.0);
    }

    
    float3 n = normalFromDepth(duv, depthM, depthTex, s);

    
    float3 lightDir = normalize(float3(-0.45, -0.55, 0.70));
    float ndotl = clamp(dot(n, lightDir), 0.0, 1.0);

    
    float ambient = 0.35;
    float diffuse = 0.65 * ndotl;

    
    float depthShadingBoost = mix(0.90, 1.15, nd);
    float shade = (ambient + diffuse) * depthShadingBoost;

    thermal *= shade;

    
    float2 ds = 1.0 / float2(depthTex.get_width(), depthTex.get_height());
    float dL = depthTex.sample(s, duv + float2(-ds.x, 0)).r;
    float dR = depthTex.sample(s, duv + float2( ds.x, 0)).r;
    float dU = depthTex.sample(s, duv + float2(0, -ds.y)).r;
    float dD = depthTex.sample(s, duv + float2(0,  ds.y)).r;

    float edge = abs(dL - dR) + abs(dU - dD);

    
    float edgeGlow = smoothstep(0.06, 0.22, edge);

    
    thermal += float3(0.85, 0.95, 1.0) * edgeGlow * 0.20;

    
    
    float camMix = smoothstep(0.10, 0.55, nd);

    
    thermal = gentleTonemap(thermal);
    thermal = softContrast(thermal, 0.45);
    thermal = softSaturation(thermal, 0.35);

    float3 blended = mix(cam.rgb, thermal, camMix);

    
    float t = premiumCurve(u.intensity);
    float3 outC = mix(cam.rgb, blended, t);

    return float4(clamp(outC, 0.0, 1.0), 1.0);
}
