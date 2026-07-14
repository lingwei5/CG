// ============================================================
// 火焰效果 (Fire) — 程序化噪声火焰
// ============================================================

// ---------- 1. 火焰噪声 ----------

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

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        value += amplitude * valueNoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

// ---------- 2. 火焰形状 ----------

// 输入: uv (0~1, y 向上), time
// 输出: 火焰强度 (0~1)
float fireShape(vec2 uv, float time) {
    // 纵向坐标映射：底部 = 0, 顶部 = 1
    float y = uv.y;

    // 噪声采样（随时间向上滚动模拟火焰上升）
    vec2 noiseUV = uv * vec2(3.0, 1.0);
    noiseUV.y -= time * 0.8; // 向上滚动

    float n = fbm(noiseUV * 2.0, 5);

    // 火焰形状：底部宽、顶部窄，用 y 控制横向收缩
    float mask = (1.0 - y);
    float shape = n * mask * 2.0;

    // 边缘软化
    shape = smoothstep(0.0, 0.5, shape);

    // 顶部渐隐
    shape *= smoothstep(1.0, 0.3, y);

    return shape;
}

// ---------- 3. 火焰颜色映射 ----------

vec3 fireColor(float intensity) {
    // 黑→红→橙→黄→白的温度梯度
    vec3 c1 = vec3(0.0, 0.0, 0.0);        // 黑
    vec3 c2 = vec3(0.5, 0.0, 0.0);        // 暗红
    vec3 c3 = vec3(1.0, 0.3, 0.0);        // 橙红
    vec3 c4 = vec3(1.0, 0.8, 0.2);        // 黄
    vec3 c5 = vec3(1.0, 1.0, 0.9);        // 白

    vec3 color = mix(c1, c2, smoothstep(0.0, 0.25, intensity));
    color = mix(color, c3, smoothstep(0.25, 0.5, intensity));
    color = mix(color, c4, smoothstep(0.5, 0.75, intensity));
    color = mix(color, c5, smoothstep(0.75, 1.0, intensity));

    return color;
}

// ---------- 4. 火焰扭曲 (模拟热气上升) ----------

vec2 heatDistortion(vec2 uv, float time, float strength) {
    float distortion = sin(uv.y * 10.0 + time * 3.0) * 0.02 * strength;
    distortion *= (1.0 - uv.y); // 底部扭曲更强
    return vec2(distortion, 0.0);
}

// ---------- 5. 完整火焰着色器 ----------

// uniform float iTime;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // 热气扭曲
    uv += heatDistortion(uv, iTime, 1.0);

    // 火焰形状
    float fire = fireShape(uv, iTime);

    // 颜色
    vec3 color = fireColor(fire);

    // 发光（HDR，用于后续 bloom）
    color *= 2.0;

    // alpha
    float alpha = fire;

    fragColor = vec4(color, alpha);
}
