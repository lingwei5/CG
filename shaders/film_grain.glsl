// ============================================================
// 胶片颗粒与暗角 (Film Grain & Vignette) — 胶片质感后处理
// 包含：胶片颗粒（亮度相关/彩噪/时序）/ 多种暗角 /
//       老电影综合效果（划痕/尘埃/闪烁/褪色）
// ============================================================
// 物理背景：
//   胶片颗粒——卤化银晶体显影的随机分布。真实特性：
//     1. 暗部颗粒更明显（信噪比低）
//     2. 颗粒是彩色的（三层乳剂独立）
//     3. 每帧独立变化（时序噪声）
//     4. 与图像内容有轻微运动相关性（近似难做，一般忽略）
//   暗角——镜头边缘入射光衰减（cos⁴ 定律）+ 镜筒遮挡。
// ============================================================

// ---------- 1. 基础胶片颗粒 ----------
// 均匀白噪声颗粒（最简单，数字感强）
vec3 filmGrainUniform(vec3 color, vec2 uv, float time, float amount) {
    float grain = hash12(uv * 1000.0 + time * 60.0);   // 每帧变化
    grain = (grain - 0.5) * 2.0;                        // [-1, 1]
    return color + grain * amount;
}

// ---------- 2. 亮度相关颗粒（推荐） ----------
// 真实胶片：中间调颗粒最明显，暗部次之，亮部几乎无颗粒。
// 用钟形曲线对亮度加权。
vec3 filmGrainLuminance(vec3 color, vec2 uv, float time, float amount) {
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // 颗粒强度曲线：在 0.25 亮度处峰值，向两端衰减
    // （暗部纯黑无信息，亮部曝光饱和，都是低颗粒区）
    float grainScale = exp(-pow((lum - 0.25) * 3.0, 2.0));

    float grain = hash12(uv * 800.0 + fract(time) * 100.0) - 0.5;
    return color + grain * grainScale * amount;
}

// ---------- 3. 彩色颗粒 ----------
// 三层乳剂独立的 RGB 噪声（更接近真实彩色胶片）
vec3 filmGrainColor(vec3 color, vec2 uv, float time, float amount) {
    vec2 seed = uv * 800.0 + fract(time) * 100.0;
    vec3 grain = vec3(hash12(seed),
                      hash12(seed + 17.17),
                      hash12(seed + 43.37)) - 0.5;
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float grainScale = exp(-pow((lum - 0.25) * 3.0, 2.0));
    return color + grain * grainScale * amount;
}

// ---------- 4. 哈希依赖（颗粒用） ----------
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// ---------- 5. 暗角 (Vignette) ----------

// 5.1 经典暗角：cos⁴ 近似，圆形径向衰减
vec3 vignetteSimple(vec3 color, vec2 uv, float strength) {
    vec2 d = uv - 0.5;
    float r = length(d) * 1.414;               // 归一化到 [0,1]
    float v = 1.0 - r * r * strength;
    return color * clamp(v, 0.0, 1.0);
}

// 5.2 圆角矩形暗角：匹配 16:9 画面（圆形暗角在宽屏上四角过暗）
vec3 vignetteRoundedRect(vec3 color, vec2 uv, float aspect,
                         float roundness, float strength) {
    vec2 d = (uv - 0.5) * vec2(aspect, 1.0);   // 修正宽高比
    // 超椭圆：指数控制圆角程度（1=菱形, 2=椭圆, ∞=矩形）
    float r = pow(pow(abs(d.x), roundness) + pow(abs(d.y), roundness),
                  1.0 / roundness);
    float v = 1.0 - smoothstep(0.4, 1.2, r) * strength;
    return color * v;
}

// 5.3 自然暗角 + 色偏暗角：边缘不仅变暗且轻微偏色
// （真实镜头边缘光通量下降导致白平衡偏移）
vec3 vignetteChromatic(vec3 color, vec2 uv, float strength) {
    vec2 d = uv - 0.5;
    float r = length(d) * 1.414;
    float v = 1.0 - r * r * strength;
    // 边缘偏暖（蓝光衰减更快）
    vec3 tint = mix(vec3(1.0), vec3(1.04, 1.0, 0.94), r * r);
    return color * clamp(v, 0.0, 1.0) * tint;
}

// ---------- 6. 老电影综合效果 ----------
// 颗粒 + 划痕 + 尘埃 + 抖动 + 闪烁 + 褪色
vec3 oldFilm(vec3 color, vec2 uv, float time, float intensity) {
    // 1) 棕褐色调（褪色）
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec3 sepia = vec3(lum) * vec3(1.2, 1.0, 0.7);
    color = mix(color, sepia, 0.7 * intensity);

    // 2) 胶片颗粒
    color = filmGrainLuminance(color, uv, time, 0.08 * intensity);

    // 3) 划痕：随机出现的竖线（低概率，每条持续几帧）
    float scratchCol = floor(uv.x * 300.0);
    float hasScratch = step(0.998, hash12(vec2(scratchCol, floor(time * 8.0))));
    float scratchY = hash12(vec2(scratchCol, 5.0));
    float scratch = hasScratch *
        smoothstep(0.02, 0.0, abs(uv.y - scratchY) - 0.3);  // 长划痕
    color += scratch * 0.3 * intensity;

    // 4) 尘埃斑点：稀疏的暗点
    vec2 dustCell = uv * 200.0;
    vec2 dustId = floor(dustCell);
    float dust = step(0.995, hash12(dustId + floor(time * 12.0)));
    vec2 dustPos = vec2(hash12(dustId + 1.0), hash12(dustId + 2.0));
    float dustDot = dust * smoothstep(0.1, 0.0, length(fract(dustCell) - dustPos));
    color -= dustDot * 0.2 * intensity;

    // 5) 投影闪烁：亮度低频抖动
    float flicker = 1.0 + (valueNoise1D(time * 24.0) - 0.5) * 0.1 * intensity;
    color *= flicker;

    // 6) 暗角
    color = vignetteSimple(color, uv, 0.6 * intensity);

    return color;
}

// 依赖的 1D 值噪声（闪烁用，平滑随机）
float valueNoise1D(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash11(i), hash11(i + 1.0), u);
}
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}
