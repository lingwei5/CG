// ============================================================
// 色调映射 (Tone Mapping) — HDR → LDR
// 将线性 HDR 颜色映射到显示器可显示的 LDR 范围
// ============================================================

// ---------- 1. Reinhard 色调映射 ----------

// 最简单的色调映射，但高光区域可能偏灰
vec3 reinhard(vec3 hdr) {
    return hdr / (hdr + 1.0);
}

// 扩展版：带白场
vec3 reinhardExtended(vec3 hdr, float white) {
    return (hdr * (1.0 + hdr / (white * white))) / (1.0 + hdr);
}

// ---------- 2. ACES Filmic (最常用 ⭐) ----------

// 业界标准，由 ACES (American Cinema Editors) 提出
// 对比度好，色彩饱和度保持好
vec3 ACESFilmic(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// ACES 的近似快速版
vec3 ACESApprox(vec3 x) {
    x = x * 0.6 + 0.1; // pre-exposure
    return clamp(x * (x * 2.51 + 0.03) / (x * (x * 2.43 + 0.59) + 0.14), 0.0, 1.0);
}

// ---------- 3. Uncharted 2 (Hable) ----------

vec3 uncharted2Partial(vec3 x) {
    float A = 0.15;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20;
    float E = 0.02;
    float F = 0.30;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 uncharted2(vec3 hdr, float exposure) {
    vec3 curr = uncharted2Partial(hdr * exposure);
    vec3 whiteScale = 1.0 / uncharted2Partial(vec3(11.2));
    return curr * whiteScale;
}

// ---------- 4. 指数映射 ----------

vec3 exponentialToneMap(vec3 hdr, float exposure) {
    return vec3(1.0) - exp(-hdr * exposure);
}

// ---------- 5. 对数映射 ----------

vec3 logarithmicToneMap(vec3 hdr, float logMin, float logMax) {
    return (log2(hdr + 1.0) - logMin) / (logMax - logMin);
}

// ---------- 6. 伽马校正 ----------

// sRGB 逆校正（色调映射后通常需要）
vec3 linearToSRGB(vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

vec3 sRGBToLinear(vec3 color) {
    return pow(color, vec3(2.2));
}

// 精确 sRGB 转换
vec3 linearToSRGBPrecise(vec3 color) {
    vec3 lo = color * 12.92;
    vec3 hi = pow(color, vec3(1.0 / 2.4)) * 1.055 - 0.055;
    return mix(lo, hi, step(0.0031308, color));
}

// ---------- 7. 曝光控制 ----------

vec3 applyExposure(vec3 color, float exposure) {
    return color * exp2(exposure); // exp2 更高效
}

// 自动曝光（基于平均亮度）
vec3 autoExposure(vec3 color, float avgLuminance, float key, float white) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float scaledLum = (key / avgLuminance) * luminance;
    float compressedLum = scaledLum * (1.0 + scaledLum / (white * white))
                         / (1.0 + scaledLum);
    return color * (compressedLum / max(luminance, 0.0001));
}

// ---------- 8. 颜色分级 (LUT) ----------

// 用 3D LUT 进行颜色分级
vec3 applyLUT(sampler3D lutTex, vec3 color, float intensity) {
    vec3 lutSize = vec3(textureSize(lutTex, 0));
    vec3 lutCoord = color * ((lutSize - 1.0) / lutSize) + 0.5 / lutSize;
    vec3 graded = texture(lutTex, lutCoord).rgb;
    return mix(color, graded, intensity);
}

// ---------- 9. 完整色调映射流程 ----------

// 流程: HDR 颜色 → 曝光 → 色调映射 → 颜色分级 → sRGB → 输出

// uniform sampler2D hdrTex;
// uniform float exposure;
// uniform sampler3D lutTex;
// uniform float lutIntensity;

vec3 toneMappingPass(vec2 uv) {
    // 1. 采样 HDR 颜色
    vec3 hdr = texture(hdrTex, uv).rgb;

    // 2. 曝光
    hdr = applyExposure(hdr, exposure);

    // 3. ACES 色调映射
    vec3 ldr = ACESFilmic(hdr);

    // 4. 颜色分级 (可选)
    // ldr = applyLUT(lutTex, ldr, lutIntensity);

    // 5. 线性 → sRGB
    ldr = linearToSRGB(ldr);

    return ldr;
}

// ---------- 10. 色调映射对比速查 ----------

// | 方法         | 特点                         | 适用场景       |
// |-------------|------------------------------|---------------|
// | Reinhard    | 简单，高光偏灰                 | 快速原型       |
// | ACES Filmic | 对比度好，业界标准 ⭐          | 电影级渲染     |
// | Uncharted2  | 类似 ACES，参数可调            | 游戏渲染       |
// | 指数映射     | 高光抑制强                     | 亮度范围大     |
// | 对数映射     | 压缩范围大                     | 超大动态范围   |
