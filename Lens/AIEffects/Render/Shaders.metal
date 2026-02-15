#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms (передаём из Swift)
struct Uniforms {
    float time;
    float viewAspect;
    float textureAspect;
    float rotation;    // поворот в радианах
    float mirror;      // зеркалирование (0.0 или 1.0)
    float hasDepth;    // есть ли depth данные (0.0 или 1.0)
    float depthFlipX;  // 1.0 = flip X для depth UV
    float depthFlipY;  // 1.0 = flip Y для depth UV
    float intensity;   // сила эффекта (0.0 = passthrough, 1.0 = полный эффект)
};

// MARK: - Vertex Output
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Vertex Shader (главный)
vertex VertexOut vertex_main(
    uint vid [[vertex_id]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    // Базовый fullscreen quad (-1..1)
    float2 basePos[4] = {
        {-1, -1}, {1, -1},
        {-1,  1}, {1,  1}
    };

    // Базовые UV (0..1)
    float2 baseUV[4] = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    };

    // 1) Поворот UV вокруг центра (mirroring делается через AVCapture)
    float2 uv = baseUV[vid];
    float2 centeredUV = uv - 0.5;
    float cosR = cos(uniforms.rotation);
    float sinR = sin(uniforms.rotation);
    float2 rotUV;
    rotUV.x = centeredUV.x * cosR - centeredUV.y * sinR;
    rotUV.y = centeredUV.x * sinR + centeredUV.y * cosR;
    rotUV += 0.5;
    // ✅ FIX: Manual mirror убран - mirroring происходит на уровне AVCapture

    // 2) Aspect-fill через масштаб геометрии (позиции), НЕ UV
    // Эффективное соотношение сторон текстуры с учётом поворота: если повёрнута на 90°/270°, меняем местами
    float effectiveTextureAspect = uniforms.textureAspect;
    
    // Надёжная проверка на поворот 90°/270° через sin
    // sin(π/2) = 1, sin(-π/2) = -1, sin(3π/2) = -1, sin(0) = 0, sin(π) = 0
    // Если |sin(rotation)| > 0.9 — значит повёрнуто на ~90°
    bool isRotated90 = abs(sin(uniforms.rotation)) > 0.9f;
    if (isRotated90) {
        effectiveTextureAspect = 1.0 / effectiveTextureAspect;
    }

    float viewAspect = uniforms.viewAspect;
    float2 scale = float2(1.0, 1.0);
    if (effectiveTextureAspect > viewAspect) {
        scale.y = effectiveTextureAspect / viewAspect;  // scale > 1, заполняет по Y
    } else {
        scale.x = viewAspect / effectiveTextureAspect;  // scale > 1, заполняет по X
    }

    float2 pos = basePos[vid] * scale;

    VertexOut out;
    out.position = float4(pos, 0, 1);
    out.uv = rotUV;
    return out;
}

// ============================================================================
// MARK: - COMIC STYLE SHADER (с анимацией)
// ============================================================================
fragment float4 fragment_comic(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float2 uv = in.uv;
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 pixelSize = 1.0 / texSize;
    float time = uniforms.time;
    
    // --- 1. Получаем оригинальный цвет ---
    float4 color = tex.sample(s, uv);
    
    // --- 2. Posterization с анимацией (уровни плавно меняются) ---
    float levels = 4.0 + sin(time * 0.5) * 1.5; // от 2.5 до 5.5 уровней
    float3 posterized = floor(color.rgb * levels + 0.5) / levels;
    
    // --- 3. Edge Detection (Sobel) ---
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
    
    // --- 4. Анимированный порог краёв ---
    float edgeThreshold = 0.12 + sin(time * 0.8) * 0.03;
    float edgeStrength = smoothstep(edgeThreshold, edgeThreshold + 0.1, edge);
    
    // --- 5. Анимированная насыщенность ---
    float saturationBoost = 1.3 + sin(time * 0.6) * 0.2;
    float cmax = max(posterized.r, max(posterized.g, posterized.b));
    float3 boostedColor = mix(float3(cmax), posterized, saturationBoost);
    boostedColor = clamp(boostedColor, 0.0, 1.0);
    
    // --- 6. Анимированный цветовой сдвиг (hue shift) ---
    float hueShift = sin(time * 0.3) * 0.1;
    float3 shifted = boostedColor;
    shifted.r = boostedColor.r * (1.0 + hueShift) - boostedColor.g * hueShift * 0.5;
    shifted.g = boostedColor.g * (1.0 + hueShift * 0.5);
    shifted.b = boostedColor.b * (1.0 - hueShift);
    shifted = clamp(shifted, 0.0, 1.0);
    
    // --- 7. Комбинируем ---
    float3 finalColor = mix(shifted, float3(0.0), edgeStrength);
    
    // --- 8. Apply intensity (mix с оригиналом) ---
    float4 originalColor = tex.sample(s, uv);
    float3 result = mix(originalColor.rgb, finalColor, uniforms.intensity);
    
    return float4(result, 1.0);
}

// ============================================================================
// MARK: - TECH LINES SHADER (wireframe/tech design эффект)
// ============================================================================
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
    
    // --- 1. Получаем оригинальный цвет и яркость ---
    float4 color = tex.sample(s, uv);
    float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
    
    // --- 2. Edge Detection (Sobel) - более чувствительный ---
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
    
    // --- 3. Более агрессивный порог для тонких линий ---
    float edgeThreshold = 0.08;
    float lineStrength = smoothstep(edgeThreshold, edgeThreshold + 0.05, edge);
    
    // --- 4. Анимированный цвет линий (неон/tech) ---
    float pulse = 0.7 + sin(time * 2.0) * 0.3;
    float colorShift = time * 0.5;
    
    // Создаём неоновые цвета на основе позиции и времени
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
    
    // Смешиваем цвета на основе позиции
    float colorMix = sin(uv.x * 3.14159 + uv.y * 2.0 + time) * 0.5 + 0.5;
    float3 lineColor = mix(neonColor1, neonColor2, colorMix) * pulse;
    
    // --- 5. Сканирующая линия (sci-fi эффект) ---
    float scanLine = sin(uv.y * texSize.y * 0.5 + time * 3.0) * 0.5 + 0.5;
    scanLine = pow(scanLine, 8.0) * 0.15;
    
    // --- 6. Горизонтальная "волна" сканирования ---
    float scanWave = fmod(time * 0.3, 1.0);
    float scanDist = abs(uv.y - scanWave);
    float scanHighlight = smoothstep(0.05, 0.0, scanDist) * 0.4;
    
    // --- 7. Глубина на основе яркости (более яркие области = ближе) ---
    float depth = luma * 0.3;
    
    // --- 8. Комбинируем: чёрный фон + цветные линии + эффекты ---
    float3 finalColor = float3(0.02, 0.02, 0.05); // почти чёрный фон с синим оттенком
    finalColor += lineColor * lineStrength;
    finalColor += float3(0.0, scanLine * 0.5, scanLine); // cyan scan lines
    finalColor += float3(scanHighlight * 0.3, scanHighlight, scanHighlight * 0.8); // scan wave
    finalColor += float3(depth * 0.1, depth * 0.15, depth * 0.2); // subtle depth
    
    // --- 9. Apply intensity (mix с оригиналом) ---
    float3 result = mix(color.rgb, finalColor, uniforms.intensity);
    
    return float4(result, 1.0);
}

// ============================================================================
// MARK: - Passthrough (для отладки)
// ============================================================================
fragment float4 fragment_passthrough(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    return tex.sample(s, in.uv);
}

// ============================================================================
// MARK: - ACID TRIP SHADER (экстремально кислотный эффект)
// ============================================================================
fragment float4 fragment_acidtrip(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float time = uniforms.time;
    float2 uv = in.uv;
    
    // --- 1. Волновые искажения UV (без вращения от центра) ---
    float2 warpedUV = uv;
    
    // Горизонтальные и вертикальные волны
    warpedUV.x += sin(uv.y * 15.0 + time * 4.0) * 0.02;
    warpedUV.y += cos(uv.x * 15.0 + time * 3.5) * 0.02;
    
    // Дополнительные мелкие волны
    warpedUV.x += sin(uv.y * 30.0 - time * 6.0) * 0.01;
    warpedUV.y += cos(uv.x * 25.0 + time * 5.0) * 0.01;
    
    // --- 2. Chromatic Aberration (RGB split) ---
    float aberrationAmount = 0.012 + sin(time * 3.0) * 0.008;
    float2 aberrationDir = float2(sin(time * 2.0), cos(time * 2.5));
    
    float4 colorR = tex.sample(s, warpedUV + aberrationDir * aberrationAmount);
    float4 colorG = tex.sample(s, warpedUV);
    float4 colorB = tex.sample(s, warpedUV - aberrationDir * aberrationAmount);
    
    float3 color = float3(colorR.r, colorG.g, colorB.b);
    
    // --- 3. Быстрый цветовой сдвиг (hue rotation) ---
    float hueRotation = time * 1.5 + uv.x * 2.0 + uv.y * 2.0;
    
    float cosH = cos(hueRotation);
    float sinH = sin(hueRotation);
    
    float3x3 hueMatrix = float3x3(
        float3(0.299 + 0.701*cosH + 0.168*sinH, 0.587 - 0.587*cosH + 0.330*sinH, 0.114 - 0.114*cosH - 0.497*sinH),
        float3(0.299 - 0.299*cosH - 0.328*sinH, 0.587 + 0.413*cosH + 0.035*sinH, 0.114 - 0.114*cosH + 0.292*sinH),
        float3(0.299 - 0.300*cosH + 1.250*sinH, 0.587 - 0.588*cosH - 1.050*sinH, 0.114 + 0.886*cosH - 0.203*sinH)
    );
    
    color = hueMatrix * color;
    
    // --- 4. Перенасыщение ---
    float luma = dot(color, float3(0.299, 0.587, 0.114));
    float saturation = 2.2 + sin(time * 1.5) * 0.6;
    color = mix(float3(luma), color, saturation);
    
    // --- 5. Плывущие полосы ---
    float stripes1 = sin(uv.x * 40.0 + uv.y * 20.0 + time * 8.0) * 0.5 + 0.5;
    float stripes2 = sin(uv.x * 25.0 - uv.y * 40.0 - time * 6.0) * 0.5 + 0.5;
    float stripes3 = sin((uv.x + uv.y) * 35.0 + time * 10.0) * 0.5 + 0.5;
    
    float3 rainbow = float3(stripes1, stripes2, stripes3);
    
    float patternIntensity = 0.12 + sin(time * 2.0) * 0.08;
    color = mix(color, color * (1.0 + rainbow * 0.4), patternIntensity);
    
    // --- 6. Горизонтальные пульсирующие волны ---
    float waves = sin(uv.y * 25.0 - time * 6.0) * 0.5 + 0.5;
    waves = pow(waves, 4.0) * 0.2;
    color += float3(waves * sin(time), waves * sin(time + 2.0), waves * sin(time + 4.0));
    
    // --- 7. Мерцание ---
    float strobe = 0.9 + sin(time * 12.0) * 0.1;
    color *= strobe;
    
    // --- 8. Контраст ---
    color = (color - 0.5) * 1.25 + 0.5;
    
    color = clamp(color, 0.0, 1.0);
    
    // Шум
    float noise = fract(sin(dot(uv + time, float2(12.9898, 78.233))) * 43758.5453);
    color += (noise - 0.5) * 0.04;
    
    // --- 9. Apply intensity (mix с оригиналом) ---
    float4 originalColor = tex.sample(s, uv);
    float3 result = mix(originalColor.rgb, color, uniforms.intensity);
    
    return float4(result, 1.0);
}

// ============================================================================
// MARK: - NEURAL PAINTER SHADER (эффект дорисовки/достраивания объектов)
// ============================================================================

// Noise functions for procedural generation
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
    
    // --- 1. Получаем оригинальный цвет и информацию о сцене ---
    float4 originalColor = tex.sample(s, uv);
    float luma = dot(originalColor.rgb, float3(0.299, 0.587, 0.114));
    
    // --- 2. Edge detection для определения границ объектов ---
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
    
    // --- 3. Генерация "мазков кисти" на основе шума ---
    float brushScale = 40.0 + sin(time * 0.3) * 8.0;
    float2 brushUV = uv * brushScale;
    
    // Анимированный шум для движения мазков
    float brushNoise = fbm(brushUV + float2(time * 0.2, time * 0.15), time);
    float brushNoise2 = fbm(brushUV * 1.3 - float2(time * 0.15, time * 0.25), time * 0.8);
    
    // Направление мазков следует за градиентом изображения
    float2 brushDir = float2(cos(edgeAngle + brushNoise * 2.0), sin(edgeAngle + brushNoise * 2.0));
    
    // --- 4. Смещение UV для эффекта "растекания краски" ---
    float flowAmount = 0.006 + edge * 0.012;
    float2 flowOffset = brushDir * flowAmount * sin(time * 1.5 + brushNoise * 4.0);
    float2 flowedUV = uv + flowOffset;
    
    // Сэмплируем с "растёкшимися" координатами
    float4 flowedColor = tex.sample(s, flowedUV);
    
    // --- 5. Создание "достроенных" элементов на краях ---
    float generativePattern = 0.0;
    
    // Волнистые линии следующие за формой объектов
    float waveFreq = 25.0;
    float wave1 = sin(uv.x * waveFreq + uv.y * waveFreq * 0.5 + time * 2.0 + brushNoise * 8.0);
    float wave2 = sin(uv.y * waveFreq * 0.7 - uv.x * waveFreq * 0.3 + time * 1.8 + brushNoise2 * 6.0);
    generativePattern = (wave1 * wave2) * 0.5 + 0.5;
    
    // Усиливаем паттерн на краях объектов
    generativePattern *= smoothstep(0.1, 0.4, edge);
    
    // --- 6. Свечение на краях объектов ---
    float edgeGlow = edge * (0.6 + 0.4 * sin(time * 2.0 + uv.y * 10.0));
    
    // --- 7. Блики на ярких участках ---
    float glow = pow(luma, 2.5) * (0.4 + 0.3 * sin(time * 1.5));
    
    // --- 8. Комбинируем всё вместе ---
    float3 finalColor = flowedColor.rgb;
    
    // Добавляем "нарисованный" слой
    finalColor = mix(finalColor, originalColor.rgb, 0.2);
    
    // Добавляем генеративные паттерны с цветовым сдвигом
    float3 patternColor = float3(
        sin(time * 0.8 + generativePattern * 3.0) * 0.5 + 0.5,
        sin(time * 1.1 + generativePattern * 4.0 + 2.0) * 0.5 + 0.5,
        sin(time * 0.6 + generativePattern * 5.0 + 4.0) * 0.5 + 0.5
    );
    finalColor = mix(finalColor, patternColor, generativePattern * 0.35);
    
    // Добавляем свечение на краях
    float3 edgeColor = float3(0.4, 0.7, 1.0) * edgeGlow;
    finalColor += edgeColor * 0.25;
    
    // Добавляем блики
    float3 glowColor = float3(1.0, 0.95, 0.85) * glow * 0.25;
    finalColor += glowColor;
    
    // --- 9. Финальная обработка ---
    // Лёгкий контраст
    finalColor = (finalColor - 0.5) * 1.1 + 0.5;
    
    // Насыщенность
    float finalLuma = dot(finalColor, float3(0.299, 0.587, 0.114));
    finalColor = mix(float3(finalLuma), finalColor, 1.25);
    
    // --- 10. Apply intensity (mix с оригиналом) ---
    float3 result = mix(originalColor.rgb, clamp(finalColor, 0.0, 1.0), uniforms.intensity);
    
    return float4(result, 1.0);
}

// ============================================================================
// MARK: - DEPTH FOG SHADER (использует LiDAR depth)
// ============================================================================
fragment float4 fragment_depthfog(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float2 uv = in.uv;
    float time = uniforms.time;
    
    // --- Depth UV с коррекцией ориентации ---
    float2 depthUV = uv;
    if (uniforms.depthFlipX > 0.5) {
        depthUV.x = 1.0 - depthUV.x;
    }
    if (uniforms.depthFlipY > 0.5) {
        depthUV.y = 1.0 - depthUV.y;
    }
    
    // --- 1. Получаем цвет камеры ---
    float4 color = tex.sample(s, uv);
    
    // --- 2. Если нет depth данных — показываем оригинал с индикатором ---
    if (uniforms.hasDepth < 0.5) {
        // Добавляем красную рамку как индикатор отсутствия depth
        float border = 0.02;
        if (uv.x < border || uv.x > 1.0 - border || uv.y < border || uv.y > 1.0 - border) {
            return float4(1.0, 0.2, 0.2, 1.0); // красная рамка
        }
        return color;
    }
    
    // --- 3. Получаем depth значение (используем скорректированные UV) ---
    float depth = depthTex.sample(s, depthUV).r;
    
    // Нормализуем depth (обычно в метрах, ограничиваем 0-5м)
    float normalizedDepth = clamp(depth / 5.0, 0.0, 1.0);
    
    // --- 4. Создаём туман на основе глубины ---
    // Ближе = меньше тумана, дальше = больше тумана
    float fogAmount = smoothstep(0.1, 0.8, normalizedDepth);
    
    // Анимированный цвет тумана
    float3 fogColor = float3(
        0.5 + 0.2 * sin(time * 0.3),
        0.6 + 0.2 * sin(time * 0.4 + 1.0),
        0.8 + 0.2 * sin(time * 0.5 + 2.0)
    );
    
    // --- 5. Смешиваем камеру с туманом ---
    float3 finalColor = mix(color.rgb, fogColor, fogAmount * 0.7);
    
    // --- 6. Добавляем depth-based контур (края объектов) ---
    float2 texSize = float2(depthTex.get_width(), depthTex.get_height());
    float2 pixelSize = 1.0 / texSize;
    
    // Используем depthUV для edge detection тоже
    float depthL = depthTex.sample(s, depthUV + float2(-pixelSize.x, 0)).r;
    float depthR = depthTex.sample(s, depthUV + float2(pixelSize.x, 0)).r;
    float depthU = depthTex.sample(s, depthUV + float2(0, -pixelSize.y)).r;
    float depthD = depthTex.sample(s, depthUV + float2(0, pixelSize.y)).r;
    
    float depthEdge = abs(depthL - depthR) + abs(depthU - depthD);
    float edgeStrength = smoothstep(0.05, 0.2, depthEdge);
    
    // Неоновый контур на границах глубины
    float3 edgeColor = float3(0.0, 1.0, 0.8) * edgeStrength;
    finalColor += edgeColor * 0.5;
    
    // --- 7. Показываем индикатор глубины в углу (debug) ---
    if (uv.x < 0.15 && uv.y > 0.85) {
        // Маленький квадрат показывает depth
        float depthVis = normalizedDepth;
        return float4(depthVis, depthVis * 0.5, 1.0 - depthVis, 1.0);
    }
    
    // --- 8. Apply intensity (mix с оригиналом) ---
    float3 result = mix(color.rgb, finalColor, uniforms.intensity);
    
    return float4(result, 1.0);
}

// ============================================================================
// MARK: - DEPTH OUTLINE SHADER (контуры по глубине)
// ============================================================================
fragment float4 fragment_depthoutline(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> depthTex [[texture(1)]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float2 uv = in.uv;
    float time = uniforms.time;
    
    // --- Depth UV с коррекцией ориентации ---
    float2 depthUV = uv;
    if (uniforms.depthFlipX > 0.5) {
        depthUV.x = 1.0 - depthUV.x;
    }
    if (uniforms.depthFlipY > 0.5) {
        depthUV.y = 1.0 - depthUV.y;
    }
    
    float4 color = tex.sample(s, uv);
    
    // Без depth — просто показываем камеру
    if (uniforms.hasDepth < 0.5) {
        return color;
    }
    
    // Получаем depth (используем скорректированные UV)
    float depth = depthTex.sample(s, depthUV).r;
    float normalizedDepth = clamp(depth / 5.0, 0.0, 1.0);
    
    // Sobel по depth для контуров
    float2 texSize = float2(depthTex.get_width(), depthTex.get_height());
    float2 ps = 1.0 / texSize;
    
    // Используем depthUV для edge detection
    float tl = depthTex.sample(s, depthUV + float2(-ps.x, -ps.y)).r;
    float t  = depthTex.sample(s, depthUV + float2(0, -ps.y)).r;
    float tr = depthTex.sample(s, depthUV + float2(ps.x, -ps.y)).r;
    float l  = depthTex.sample(s, depthUV + float2(-ps.x, 0)).r;
    float r  = depthTex.sample(s, depthUV + float2(ps.x, 0)).r;
    float bl = depthTex.sample(s, depthUV + float2(-ps.x, ps.y)).r;
    float b  = depthTex.sample(s, depthUV + float2(0, ps.y)).r;
    float br = depthTex.sample(s, depthUV + float2(ps.x, ps.y)).r;
    
    float sobelX = -tl - 2.0*l - bl + tr + 2.0*r + br;
    float sobelY = -tl - 2.0*t - tr + bl + 2.0*b + br;
    float edge = sqrt(sobelX * sobelX + sobelY * sobelY);
    
    // Сильный контур
    float edgeStrength = smoothstep(0.03, 0.15, edge);
    
    // Цвет линий меняется от глубины
    float3 lineColor = float3(
        1.0 - normalizedDepth,
        0.5 + 0.5 * sin(time + normalizedDepth * 3.0),
        normalizedDepth
    );
    
    // Чёрный фон + цветные контуры
    float3 finalColor = mix(float3(0.02), lineColor, edgeStrength);
    
    // Добавляем немного оригинального цвета в близких объектах
    finalColor = mix(finalColor, color.rgb * 0.3, (1.0 - normalizedDepth) * 0.4);
    
    // --- Apply intensity (mix с оригиналом) ---
    float3 result = mix(color.rgb, finalColor, uniforms.intensity);
    
    return float4(result, 1.0);
}

