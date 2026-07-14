// ============================================================
// 景深 (Depth of Field) — 模拟相机镜头的焦外模糊
// 包含：高斯景深 / 圆盘景深 / 散景景深
// ============================================================

// ---------- 1. 焦距计算 (CoC - Circle of Confusion) ----------

// 根据深度计算弥散圆大小
// 输入: depth, focalDistance (焦距), focalRange (焦距范围)
// 输出: CoC (0=清晰, 1=完全模糊)
float computeCoC(float depth, float focalDistance, float focalRange) {
    return clamp(abs(depth - focalDistance) / focalRange, 0.0, 1.0);
}

// 物理相机 CoC 计算
float physicalCoC(float depth, float focalLength, float focusDistance,
                   float aperture, float sensorSize) {
    float magnification = focalLength / (focusDistance - focalLength);
    float coc = abs(depth - focusDistance) * aperture * focalLength
              / (depth * (focusDistance - focalLength));
    return clamp(coc / sensorSize, 0.0, 1.0);
}

// ---------- 2. 高斯景深 (简单版) ----------

vec3 gaussianDoF(sampler2D sceneTex, vec2 uv, vec2 texelSize,
                  float coc, int samples) {
    if (coc < 0.01) {
        return texture(sceneTex, uv).rgb;
    }

    vec3 color = vec3(0.0);
    float total = 0.0;
    float radius = coc * 5.0;

    for (int x = -4; x <= 4; x++) {
        for (int y = -4; y <= 4; y++) {
            vec2 offset = vec2(x, y) * texelSize * radius;
            float weight = exp(-length(vec2(x, y)) / 3.0);
            color += texture(sceneTex, uv + offset).rgb * weight;
            total += weight;
        }
    }

    return color / total;
}

// ---------- 3. 圆盘景深 (Disk DoF) ----------

// 采样点分布在圆盘上，更接近真实的镜头模糊
vec3 diskDoF(sampler2D sceneTex, vec2 uv, vec2 texelSize, float coc) {
    if (coc < 0.01) {
        return texture(sceneTex, uv).rgb;
    }

    // 黄金角螺旋采样
    vec3 color = vec3(0.0);
    float total = 0.0;
    int samples = 16;
    float radius = coc * 5.0;

    for (int i = 0; i < 32; i++) {
        if (i >= samples) break;
        float angle = float(i) * 2.39996; // 黄金角
        float r = sqrt(float(i) / float(samples)) * radius;
        vec2 offset = vec2(cos(angle), sin(angle)) * r * texelSize;
        color += texture(sceneTex, uv + offset).rgb;
        total += 1.0;
    }

    return color / total;
}

// ---------- 4. 散景景深 (Bokeh DoF) ----------

// 散景权重：亮像素权重更高，产生漂亮的散景圆
vec3 bokehDoF(sampler2D sceneTex, vec2 uv, vec2 texelSize,
               float coc, float bokehStrength) {
    if (coc < 0.01) {
        return texture(sceneTex, uv).rgb;
    }

    vec3 centerColor = texture(sceneTex, uv).rgb;
    vec3 color = vec3(0.0);
    float totalWeight = 0.0;
    float radius = coc * 5.0;
    int samples = 24;

    for (int i = 0; i < 32; i++) {
        if (i >= samples) break;
        float angle = float(i) * 2.39996;
        float r = sqrt(float(i) / float(samples)) * radius;
        vec2 offset = vec2(cos(angle), sin(angle)) * r * texelSize;

        vec3 sampleColor = texture(sceneTex, uv + offset).rgb;
        float sampleLuma = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));

        // 散景权重：亮度越高权重越大
        float weight = pow(sampleLuma, bokehStrength) + 0.1;
        color += sampleColor * weight;
        totalWeight += weight;
    }

    return color / max(totalWeight, 0.0001);
}

// ---------- 5. 前后景分离混合 ----------

// 前景模糊会遮挡背景，需要分别处理
vec3 depthAwareDoF(sampler2D sceneTex, sampler2D depthTex,
                    vec2 uv, vec2 texelSize,
                    float focalDistance, float focalRange) {
    float depth = texture(depthTex, uv).r;
    float coc = computeCoC(depth, focalDistance, focalRange);

    // 散景景深
    vec3 dofColor = bokehDoF(sceneTex, uv, texelSize, coc, 2.0);
    vec3 focusedColor = texture(sceneTex, uv).rgb;

    // 平滑混合
    return mix(focusedColor, dofColor, smoothstep(0.0, 0.3, coc));
}

// ---------- 6. 完整景深着色器 ----------

// uniform sampler2D sceneTex;
// uniform sampler2D depthTex;
// uniform float focalDistance;
// uniform float focalRange;
// uniform float bokehStrength;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 color = depthAwareDoF(sceneTex, depthTex, uv, texelSize,
                                focalDistance, focalRange);

    fragColor = vec4(color, 1.0);
}
