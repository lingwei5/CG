// ============================================================
// 镜头光晕 (Lens Flare) — 镜片组内反射产生的光斑系统
// 包含：鬼影 (Ghost) / 光环 (Halo) / 星芒 (Starburst) /
//       变形宽银幕光斑 (Anamorphic Streak) / 镜头污渍 (Dirt)
// ============================================================
// 物理背景：
//   强光源的光在多片镜片之间来回反射，形成一串沿
//   "光源-画面中心"连线上分布的光斑（鬼影），以及围绕
//   光源的光环、衍射星芒。电影中常见的 anamorphic 横向蓝
//   条纹来自变形宽银幕镜头的柱面镜结构。
//   关键：光斑强度受光源可见性（遮挡）调制——光源被场景
//   遮挡时 flare 应淡出（需对光源位置采样遮挡缓冲）。
// ============================================================

// ---------- 0. 依赖：简单哈希（随机化鬼影参数） ----------
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// ---------- 1. 鬼影 (Ghosts) ----------
// 沿光源到画面中心(2*center-light)的连线分布一系列圆斑。
// 输入: lightPos 光源屏幕UV, uv 当前坐标, count 鬼影数量
vec3 lensGhosts(vec2 uv, vec2 lightPos, int count, float intensity) {
    vec3 color = vec3(0.0);
    vec2 center = vec2(0.5);

    for (int i = 0; i < count; i++) {
        float t = float(i) / float(count - 1);          // 0..1 沿连线
        // 鬼影位置：光源 → 中心对称点 插值（真实镜头的反射序号）
        vec2 ghostPos = mix(lightPos, 2.0 * center - lightPos,
                            0.15 + 0.75 * t);

        // 每个鬼影独立的大小/亮度/色相（哈希驱动，避免均匀呆板）
        float h = hash12(vec2(float(i), 7.31));
        float size   = mix(0.02, 0.10, h);
        float bright = mix(0.3, 1.0, hash12(vec2(float(i), 3.7)))
                     * intensity * (1.0 - 0.6 * t);     // 越远越暗

        // 鬼影颜色：镜头镀膜干涉色（青/品红/黄绿循环）
        vec3 tint = 0.5 + 0.5 * cos(6.2831 * (t + vec3(0.0, 0.33, 0.67)));

        float d = length(uv - ghostPos);
        // 软边圆斑 + 边缘微亮环（薄膜干涉感）
        float disc  = smoothstep(size, size * 0.6, d);
        float ring  = smoothstep(size * 1.15, size, d)
                    * smoothstep(size * 0.85, size, d) * 0.5;

        color += tint * bright * (disc + ring);
    }
    return color;
}

// ---------- 2. 光环 (Halo) ----------
// 围绕光源的环形光晕（镜片间全反射）
vec3 lensHalo(vec2 uv, vec2 lightPos, float radius, float intensity) {
    float d = length(uv - lightPos);
    // 主环：以 radius 为中心的窄环
    float ring = smoothstep(0.02, 0.0, abs(d - radius));
    // 内侧柔光：向光源衰减
    float glow = exp(-d * 6.0) * 0.4;
    return vec3(1.0, 0.95, 0.85) * (ring * 0.6 + glow) * intensity;
}

// ---------- 3. 星芒 (Starburst / Diffraction Spikes) ----------
// 光圈叶片的衍射星芒：十字（偶数光圈）或六芒（六叶片）。
// 各向异性衰减：沿星臂方向延伸。
vec3 starburst(vec2 uv, vec2 lightPos, float intensity) {
    vec2 d = uv - lightPos;
    float r = length(d);
    if (r < 1e-4) return vec3(intensity);

    vec2 n = d / r;                       // 径向单位向量
    float a = atan(n.y, n.x);

    // 4 条星臂（每 90°一条，arms=4）；6芒星改为 6.2831/6
    float arms = pow(abs(cos(a * 2.0)), 8.0);        // 十字
    // 星臂亮度随半径衰减，中央是亮核
    float falloff = exp(-r * 4.0);
    float core = exp(-r * 30.0) * 2.0;

    return vec3(1.0) * (arms * falloff + core) * intensity;
}

// ---------- 4. 变形宽银幕光斑 (Anamorphic Streak) ----------
// 柱面镜把光源横向拉成蓝色长条（JJ Abrams 式蓝光晕）。
// 核心：x/y 用不同衰减率。
vec3 anamorphicStreak(vec2 uv, vec2 lightPos, vec3 color,
                      float intensity) {
    vec2 d = uv - lightPos;
    // x 方向极慢衰减（长条），y 方向快速衰减（细线）
    float falloff = exp(-abs(d.x) * 6.0) * exp(-abs(d.y) * 60.0);
    // 中心亮核
    float core = exp(-length(d) * 20.0) * 2.0;
    return color * (falloff + core) * intensity;
}

// ---------- 5. 镜头污渍 (Lens Dirt) ----------
// 需要一张污渍遮罩纹理；仅在被 flare 照亮时可见
// （正常曝光下看不见灰尘，逆光时灰尘散射发光）。
// dirtTex: RGB=污渍颜色, A=强度
vec3 lensDirt(sampler2D dirtTex, vec2 uv, vec2 lightPos,
              float flareBrightness) {
    vec4 dirt = texture(dirtTex, uv);
    // 光源强度调制污渍可见度
    float lightEnergy = exp(-length(uv - lightPos) * 2.0);
    return dirt.rgb * dirt.a * lightEnergy * flareBrightness;
}

// ---------- 6. 光源遮挡淡出 ----------
// flare 不应穿透遮挡物：对光源位置的深度/遮挡图采样。
// occlusionTex: 1=有遮挡, 0=可见; 用多次采样处理半遮挡边缘
float flareVisibility(sampler2D occlusionTex, vec2 lightPos,
                      int samples, float spiralScale) {
    // 螺旋采样多个点，光源被部分遮挡时平滑淡出
    float vis = 0.0;
    for (int i = 0; i < samples; i++) {
        float a = float(i) * 2.39996;                    // 黄金角
        float r = sqrt(float(i) / float(samples)) * spiralScale;
        vec2 offset = vec2(cos(a), sin(a)) * r;
        // 采样遮挡图并按距离加权（中心权重大）
        vis += texture(occlusionTex, lightPos + offset).r
             * (1.0 - r);
    }
    return vis / float(samples);
}

// ---------- 7. 综合示例 ----------
vec3 fullLensFlare(vec2 uv, vec2 lightPos, sampler2D occlusionTex,
                   sampler2D dirtTex, float intensity) {
    // 1) 光源可见性（被挡则整体淡出）
    float vis = flareVisibility(occlusionTex, lightPos, 8, 0.03);
    if (vis < 0.01) return vec3(0.0);

    vec3 flare = vec3(0.0);
    // 2) 鬼影 + 光环 + 星芒 + 变形条纹
    flare += lensGhosts(uv, lightPos, 6, 0.5);
    flare += lensHalo(uv, lightPos, 0.25, 0.4);
    flare += starburst(uv, lightPos, 0.8);
    flare += anamorphicStreak(uv, lightPos,
                              vec3(0.4, 0.6, 1.0), 0.6);   // 经典蓝条
    // 3) 污渍
    flare += lensDirt(dirtTex, uv, lightPos, 1.5);

    return flare * intensity * vis;
}
