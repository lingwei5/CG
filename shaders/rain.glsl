// ============================================================
// 雨效果 (Rain) — 雨滴 + 涟漪 + 湿润表面
// ============================================================

// ---------- 雨滴粒子 ----------

float rainDrop(vec2 uv, float time, float speed, vec2 dropSize, float density) {
    float rain = 0.0;

    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        vec2 grid = floor(uv / dropSize);
        float r = hash21(grid + fi * 73.17);

        // 跳过部分格子来控制密度
        if (r > density) continue;

        // 雨滴下落（垂直方向）
        float y = fract(uv.y / dropSize.y + time * speed * (0.5 + r));
        float x = fract(uv.x / dropSize.x + r * 1.7);

        // 雨滴形状：细长的椭圆
        vec2 dropUV = (vec2(x, y) - 0.5) * 2.0;
        float drop = 1.0 - smoothstep(0.8, 1.0, abs(dropUV.x) * 8.0)
                         - smoothstep(0.9, 1.0, abs(dropUV.y) * 1.5);
        drop = max(drop, 0.0);

        // 运动模糊：在雨滴上方加拖尾
        float trail = 1.0 - smoothstep(0.0, 0.3, abs(dropUV.x) * 6.0)
                          - smoothstep(0.0, 1.5, dropUV.y + 1.0);
        trail = max(trail, 0.0) * 0.3;

        rain += (drop + trail) * r;
    }

    return clamp(rain, 0.0, 1.0);
}

// ---------- 涟漪效果 (用于水面/地面) ----------

float ripple(vec2 uv, float time, float frequency) {
    // 多个同心涟漪
    float ripple = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 center = vec2(
            hash21(vec2(fi, 0.0)),
            hash21(vec2(fi, 1.0))
        );
        float startTime = fi * 1.7;
        float age = fract((time - startTime) * frequency);
        float radius = age * 0.5;
        float dist = length(uv - center);

        float ring = abs(dist - radius);
        float intensity = (1.0 - age) * exp(-ring * 20.0);
        ripple += intensity * 0.3;
    }
    return ripple;
}

// ---------- 湿润表面 ----------

// 湿润表面：降低粗糙度，略微变暗
vec3 wetSurface(vec3 baseColor, float roughness, float wetness) {
    // 湿润后颜色变暗（水膜吸收部分光）
    vec3 wetColor = baseColor * 0.7;
    // 湿润后粗糙度降低（水面更光滑）
    // 在调用处: roughness = mix(roughness, 0.1, wetness);
    return mix(baseColor, wetColor, wetness);
}

// ---------- 完整雨景着色器示例 ----------

// uniform float iTime;
// uniform vec3 iResolution;
// uniform float rainIntensity; // 0~1
// uniform float wetness;       // 0~1 表面湿润度

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // 1. 雨滴
    float rain = rainDrop(uv, iTime, 3.0, vec2(0.03, 0.15), rainIntensity);

    // 2. 涟漪
    float rippleEffect = ripple(uv, iTime, 0.5) * rainIntensity;

    // 3. 雨滴颜色（略带蓝灰）
    vec3 rainColor = vec3(0.7, 0.75, 0.85);

    // 4. 合成
    vec3 color = mix(vec3(0.3), rainColor, rain * 0.6 + rippleEffect * 0.3);

    fragColor = vec4(color, 1.0);
}
