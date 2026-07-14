// ============================================================
// 云效果 (Clouds) — 基于分形噪声 (Fractal Noise / fBm)
// 适用于天空球/天空盒的全屏后处理或天空着色器
// ============================================================

// ---------- 噪声基础 ----------

// 2D 随机哈希
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D 值噪声 (Value Noise)
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ---------- fBm (Fractal Brownian Motion) ----------

float fbm(vec2 p, int octaves, float lacunarity, float gain) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        value += amplitude * valueNoise(p * frequency);
        maxValue += amplitude;
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return value / maxValue;
}

// ---------- 云密度函数 ----------

float cloudDensity(vec2 uv, float time, float coverage) {
    // 多层噪声叠加模拟云的形态
    float n1 = fbm(uv * 3.0 + time * 0.02, 5, 2.0, 0.5);
    float n2 = fbm(uv * 5.0 - time * 0.015 + 1.0, 4, 2.0, 0.5);
    float n3 = fbm(uv * 8.0 + time * 0.01 + 2.0, 3, 2.0, 0.5);

    // 混合不同频率的噪声
    float density = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;

    // 用 coverage 控制云量（阈值映射）
    density = smoothstep(1.0 - coverage, 1.0, density);

    return density;
}

// ---------- 主函数 ----------

// 输入: uv (0~1), time (秒), coverage (0~1 云量), sunDir (太阳方向)
// 输出: 云的颜色 (RGB)
vec3 renderClouds(vec2 uv, float time, float coverage, vec3 sunDir) {
    float density = cloudDensity(uv, time, coverage);

    // 云的颜色：亮部（白色）和暗部（灰色）
    vec3 cloudColor = mix(vec3(0.5, 0.55, 0.6), vec3(1.0), density);

    // 简单的光照：用噪声梯度近似法线
    float eps = 0.001;
    float dx = cloudDensity(uv + vec2(eps, 0.0), time, coverage)
             - cloudDensity(uv - vec2(eps, 0.0), time, coverage);
    float dy = cloudDensity(uv + vec2(0.0, eps), time, coverage)
             - cloudDensity(uv - vec2(0.0, eps), time, coverage);
    vec3 normal = normalize(vec3(-dx, -dy, 0.1));

    float NdotL = max(dot(normal, normalize(sunDir)), 0.0);
    float lighting = mix(0.3, 1.0, NdotL);

    return cloudColor * lighting * density;
}
