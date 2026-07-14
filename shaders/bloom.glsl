// ============================================================
// 泛光 (Bloom) — 提取亮部 + 高斯模糊 + 合成
// 后处理流程：亮度提取 → 降采样模糊 → 上采样合成
// ============================================================

// ---------- 1. 亮度提取 (Luminance Threshold) ----------

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 extractBright(vec3 color, float threshold, float softKnee) {
    float luma = luminance(color);
    float knee = threshold * softKnee + 1e-5;
    float soft = clamp(luma - threshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee + 1e-5);
    float contribution = max(soft, luma - threshold);
    contribution /= max(luma, 1e-5);
    return color * contribution;
}

// ---------- 2. 高斯模糊 (9-tap) ----------

// 单次 9 采样高斯模糊（利用双线性优化可降到 5 次）
vec3 gaussianBlur9(sampler2D tex, vec2 uv, vec2 texelSize, vec2 direction) {
    vec3 color = vec3(0.0);
    // 高斯权重 (sigma ≈ 2.0)
    float weights[5];
    weights[0] = 0.227027;
    weights[1] = 0.1945946;
    weights[2] = 0.1216216;
    weights[3] = 0.054054;
    weights[4] = 0.016216;

    color += texture(tex, uv).rgb * weights[0];
    for (int i = 1; i < 5; i++) {
        vec2 offset = direction * texelSize * float(i);
        color += texture(tex, uv + offset).rgb * weights[i];
        color += texture(tex, uv - offset).rgb * weights[i];
    }
    return color;
}

// ---------- 3. 双向高斯模糊 (分离式) ----------

// 水平 + 垂直两次模糊
vec3 separableGaussian(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec3 horizontal = gaussianBlur9(tex, uv, texelSize, vec2(1.0, 0.0));
    vec3 vertical = gaussianBlur9(tex, uv, texelSize, vec2(0.0, 1.0));
    return (horizontal + vertical) * 0.5;
}

// ---------- 4. 多级降采样 (Mip Chain) ----------

// 逐级降采样：每级取 4 个采样并平均
vec3 downsample(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec2 offset1 = vec2(1.0, 1.0) * texelSize;
    vec2 offset2 = vec2(-1.0, 1.0) * texelSize;
    vec2 offset3 = vec2(1.0, -1.0) * texelSize;
    vec2 offset4 = vec2(-1.0, -1.0) * texelSize;

    vec3 c1 = texture(tex, uv + offset1 * 0.5).rgb;
    vec3 c2 = texture(tex, uv + offset2 * 0.5).rgb;
    vec3 c3 = texture(tex, uv + offset3 * 0.5).rgb;
    vec3 c4 = texture(tex, uv + offset4 * 0.5).rgb;

    return (c1 + c2 + c3 + c4) * 0.25;
}

// ---------- 5. 上采样 (Upsample + 合成) ----------

// 9-tap 上采样：取上级 mip 的 9 个采样并加权合成
vec3 upsample(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec3 color = vec3(0.0);
    float weights[5];
    weights[0] = 0.227027;
    weights[1] = 0.1945946;
    weights[2] = 0.1216216;
    weights[3] = 0.054054;
    weights[4] = 0.016216;

    color += texture(tex, uv).rgb * weights[0];
    color += texture(tex, uv + vec2(1.0, 0.0) * texelSize).rgb * weights[1];
    color += texture(tex, uv - vec2(1.0, 0.0) * texelSize).rgb * weights[1];
    color += texture(tex, uv + vec2(0.0, 1.0) * texelSize).rgb * weights[2];
    color += texture(tex, uv - vec2(0.0, 1.0) * texelSize).rgb * weights[2];
    color += texture(tex, uv + vec2(1.0, 1.0) * texelSize).rgb * weights[3];
    color += texture(tex, uv - vec2(1.0, 1.0) * texelSize).rgb * weights[3];
    color += texture(tex, uv + vec2(1.0, -1.0) * texelSize).rgb * weights[4];
    color += texture(tex, uv - vec2(1.0, -1.0) * texelSize).rgb * weights[4];

    return color;
}

// ---------- 6. 合成 ----------

vec3 applyBloom(vec3 sceneColor, vec3 bloomColor, float intensity) {
    // 加法混合（HDR）
    return sceneColor + bloomColor * intensity;
}

// 软混合（适合 LDR）
vec3 applyBloomSoft(vec3 sceneColor, vec3 bloomColor, float intensity) {
    return sceneColor + bloomColor * intensity * (1.0 - sceneColor);
}

// ---------- 7. 完整 Bloom 流程 ----------

// 流程说明:
// Pass 1: 亮度提取 → brightTex
// Pass 2~5: 逐级降采样 → brightTex_mip1, mip2, mip3, mip4
// Pass 6~9: 逐级上采样合成 → 合并所有 mip
// Pass 10: 最终合成 = sceneColor + bloom

// uniform sampler2D sceneTex;
// uniform sampler2D brightTex;     // 亮度提取后的纹理
// uniform sampler2D bloomMip0;     // 降采样 mip 链
// uniform sampler2D bloomMip1;
// uniform sampler2D bloomMip2;
// uniform sampler2D bloomMip3;
// uniform vec2 texelSize;
// uniform float bloomIntensity;
// uniform float threshold;
// uniform float softKnee;

// --- Pass 1: 亮度提取 ---
vec3 passBrightExtract(vec2 uv) {
    vec3 color = texture(sceneTex, uv).rgb;
    return extractBright(color, threshold, softKnee);
}

// --- Pass 2~5: 降采样 ---
vec3 passDownsample(vec2 uv, sampler2D srcTex, vec2 srcTexelSize) {
    return downsample(srcTex, uv, srcTexelSize);
}

// --- Pass 6~9: 上采样合成 ---
vec3 passUpsample(vec2 uv, sampler2D highMip, sampler2D lowMip,
                  vec2 highTexelSize, float blendFactor) {
    vec3 high = upsample(lowMip, uv, highTexelSize * 2.0);
    vec3 low = texture(highMip, uv).rgb;
    return mix(low, high, blendFactor);
}

// --- Pass 10: 最终合成 ---
vec3 passComposite(vec2 uv) {
    vec3 sceneColor = texture(sceneTex, uv).rgb;
    vec3 bloom = texture(bloomMip0, uv).rgb;
    return applyBloom(sceneColor, bloom, bloomIntensity);
}
