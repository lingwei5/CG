// ============================================================
// 溶解效果 (Dissolve) — 噪声阈值 + 边缘发光
// 常用于：角色传送、物体出现/消失、烧毁
// ============================================================

// ---------- 1. 噪声 ----------

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * valueNoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// ---------- 2. 溶解核心 ----------

// 输入: uv, progress (0=完全显示, 1=完全溶解)
// 输出: visible (是否可见 0/1), edge (边缘发光强度 0~1)
struct DissolveResult {
    float visible;
    float edge;
};

DissolveResult dissolve(vec2 uv, float progress, float edgeWidth) {
    // 采样噪声
    float noise = fbm(uv * 5.0);

    // 溶解阈值：progress 从 0→1，阈值从 0→1
    float threshold = progress;

    // 可见性：噪声 > 阈值 时可见
    float visible = step(threshold, noise);

    // 边缘：在阈值附近的一定范围内
    float edge = 1.0 - smoothstep(threshold, threshold + edgeWidth, noise);
    edge = clamp(edge - visible, 0.0, 1.0); // 只保留正在溶解的边缘

    DissolveResult result;
    result.visible = visible;
    result.edge = edge;
    return result;
}

// ---------- 3. 边缘发光颜色 ----------

vec3 dissolveEdgeColor(float edge, vec3 innerColor, vec3 outerColor) {
    // 边缘内侧（还可见的部分）用 innerColor（如黄）
    // 边缘外侧（正在消失的部分）用 outerColor（如红/橙）
    return mix(innerColor, outerColor, edge);
}

// ---------- 4. 带方向性的溶解 ----------

// 从下到上逐渐溶解
DissolveResult directionalDissolve(vec2 uv, float progress, float edgeWidth,
                                    vec2 direction) {
    // 方向性偏移：将 progress 沿 direction 方向变化
    float dirFactor = dot(uv - 0.5, normalize(direction)) + 0.5;
    float adjustedProgress = progress * 2.0 - dirFactor;

    float noise = fbm(uv * 5.0);
    float threshold = adjustedProgress;

    float visible = step(threshold, noise);
    float edge = 1.0 - smoothstep(threshold, threshold + edgeWidth, noise);
    edge = clamp(edge - visible, 0.0, 1.0);

    DissolveResult result;
    result.visible = visible;
    result.edge = edge;
    return result;
}

// ---------- 5. 完整溶解着色器 ----------

// uniform float dissolveProgress; // 0=显示, 1=完全溶解
// uniform vec3 edgeInnerColor;    // 边缘内色（黄）
// uniform vec3 edgeOuterColor;    // 边缘外色（红橙）
// uniform float edgeWidth;        // 边缘宽度
// uniform sampler2D mainTex;      // 物体纹理

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // 1. 溶解计算
    DissolveResult d = dissolve(uv, dissolveProgress, edgeWidth);

    // 2. 基础颜色
    vec3 baseColor = texture(mainTex, uv).rgb;

    // 3. 边缘发光
    vec3 edgeGlow = dissolveEdgeColor(d.edge, edgeInnerColor, edgeOuterColor);
    edgeGlow *= d.edge * 3.0; // 增强亮度用于 bloom

    // 4. 合成
    vec3 color = baseColor * d.visible + edgeGlow;
    float alpha = d.visible + d.edge * 0.5;

    fragColor = vec4(color, alpha);
}
