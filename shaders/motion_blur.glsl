// ============================================================
// 运动模糊 (Motion Blur) — 基于速度缓冲 / 基于快门
// ============================================================

// ---------- 1. 速度缓冲法 (Velocity Buffer) ----------

// 需要上一帧的 MVP 矩阵来计算每个像素的运动速度
vec2 computeVelocity(vec4 clipPosCurrent, mat4 prevViewProj) {
    // 当前帧 NDC
    vec2 ndcCurrent = clipPosCurrent.xy / clipPosCurrent.w;

    // 上一帧投影
    vec4 clipPosPrev = prevViewProj * vec4(clipPosCurrent.xyz, 1.0);
    vec2 ndcPrev = clipPosPrev.xy / clipPosPrev.w;

    // 速度 = 当前 - 上一帧 (NDC 空间)
    return (ndcCurrent - ndcPrev) * 0.5;
}

// ---------- 2. 基于速度的运动模糊 ----------

vec3 velocityMotionBlur(sampler2D sceneTex, sampler2D velocityTex,
                         vec2 uv, vec2 texelSize, int maxSamples,
                         float maxBlurRadius) {
    vec2 velocity = texture(velocityTex, uv).rg;
    float velocityLength = length(velocity);

    if (velocityLength < 0.001) {
        return texture(sceneTex, uv).rgb;
    }

    // 限制最大模糊半径
    velocity = normalize(velocity) * min(velocityLength, maxBlurRadius);

    vec3 color = vec3(0.0);
    float totalWeight = 0.0;

    int samples = min(maxSamples, int(velocityLength * 100.0) + 1);

    for (int i = 0; i < 64; i++) {
        if (i >= samples) break;
        float t = float(i) / float(samples - 1) - 0.5; // -0.5 ~ 0.5
        vec2 offset = velocity * t;
        vec3 sampleColor = texture(sceneTex, uv + offset).rgb;
        color += sampleColor;
        totalWeight += 1.0;
    }

    return color / max(totalWeight, 1.0);
}

// ---------- 3. 相机运动模糊 (基于深度) ----------

// 不需要速度缓冲，用深度 + 相机运动推算
vec3 cameraMotionBlur(sampler2D sceneTex, sampler2D depthTex,
                       vec2 uv, vec2 texelSize, mat4 invViewProj,
                       mat4 prevViewProj, mat4 currentViewProj,
                       int samples, float blurScale) {
    float depth = texture(depthTex, uv).r;

    // 重建世界坐标
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 worldPos = invViewProj * clipPos;
    worldPos /= worldPos.w;

    // 当前帧和上一帧的投影差异 = 运动向量
    vec4 currentClip = currentViewProj * worldPos;
    vec4 prevClip = prevViewProj * worldPos;
    vec2 currentNDC = currentClip.xy / currentClip.w;
    vec2 prevNDC = prevClip.xy / prevClip.w;

    vec2 velocity = (currentNDC - prevNDC) * 0.5 * blurScale;

    if (length(velocity) < 0.001) {
        return texture(sceneTex, uv).rgb;
    }

    // 沿速度方向采样
    vec3 color = vec3(0.0);
    for (int i = 0; i < 32; i++) {
        if (i >= samples) break;
        float t = float(i) / float(samples - 1) - 0.5;
        vec2 sampleUV = uv + velocity * t;
        color += texture(sceneTex, sampleUV).rgb;
    }

    return color / float(samples);
}

// ---------- 4. 径向运动模糊 (从中心向外) ----------

// 常用于快速移动 / 超速效果
vec3 radialMotionBlur(sampler2D sceneTex, vec2 uv, vec2 center,
                       int samples, float strength) {
    vec2 dir = uv - center;
    float dist = length(dir);

    if (dist < 0.001) {
        return texture(sceneTex, uv).rgb;
    }

    vec3 color = vec3(0.0);
    for (int i = 0; i < 32; i++) {
        if (i >= samples) break;
        float t = float(i) / float(samples - 1) - 0.5;
        vec2 offset = dir * t * strength;
        color += texture(sceneTex, uv + offset).rgb;
    }

    return color / float(samples);
}

// ---------- 5. 完整运动模糊着色器 ----------

// uniform sampler2D sceneTex;
// uniform sampler2D velocityTex;
// uniform vec2 texelSize;
// uniform float maxBlurRadius;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 color = velocityMotionBlur(sceneTex, velocityTex, uv,
                                     texelSize, 32, maxBlurRadius);

    fragColor = vec4(color, 1.0);
}
