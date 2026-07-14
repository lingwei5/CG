// ============================================================
// 雪效果 (Snow) — 飘落粒子 + 地面/物体积雪
// ============================================================

// ---------- 飘落雪花 (全屏粒子效果) ----------

// 输入: fragCoord (屏幕坐标), iResolution (分辨率), iTime (时间)
// 输出: 雪花颜色 (RGB, alpha)

float snowParticle(vec2 uv, float time, float speed, float size, float wind) {
    // 多层雪花，每层不同速度和偏移
    float snow = 0.0;

    for (int layer = 0; layer < 3; layer++) {
        float layerSpeed = speed * (1.0 + float(layer) * 0.5);
        float layerSize = size * (1.0 + float(layer) * 0.3);

        // 用 hash 生成伪随机雪花位置
        vec2 grid = floor(uv / layerSize);
        float r = hash21(grid + float(layer) * 127.1);

        // 雪花在格子内的位置随时间变化
        vec2 offset = vec2(
            sin(time * layerSpeed * 1.3 + r * 6.28) * 0.4 + wind * time * 0.1,
            fract(time * layerSpeed * 0.7 + r * 6.28)
        );

        vec2 snowPos = (grid + offset) * layerSize;
        float dist = length(uv - snowPos) / layerSize;

        // 圆形雪花，边缘柔和
        snow += smoothstep(0.5, 0.0, dist) * (0.3 + r * 0.7);
    }

    return clamp(snow, 0.0, 1.0);
}

// ---------- 物体表面积雪 (基于法线) ----------

// 输入: worldNormal (世界空间法线), snowDir (雪落方向，通常为 up)
// 输出: 积雪量 (0~1)
float surfaceSnowAmount(vec3 worldNormal, vec3 snowDir, float threshold) {
    float NdotS = dot(normalize(worldNormal), normalize(snowDir));
    return smoothstep(threshold - 0.1, threshold + 0.1, NdotS);
}

// ---------- 积雪颜色混合 ----------

// 输入: baseColor (原始颜色), snowAmount (积雪量), snowColor (雪的颜色)
// 输出: 混合后的颜色
vec3 applySurfaceSnow(vec3 baseColor, float snowAmount, vec3 snowColor) {
    return mix(baseColor, snowColor, snowAmount);
}

// ---------- 完整雪景着色器示例 (fragment shader) ----------

// uniform float iTime;
// uniform vec3 iResolution;
// uniform vec3 snowDir;       // 雪落方向，通常 (0, 1, 0)
// uniform float snowIntensity; // 降雪强度 0~1
// uniform vec3 baseColor;      // 场景基础色
// uniform vec3 worldNormal;    // 世界空间法线

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // 1. 飘落雪花
    float particleSnow = snowParticle(uv, iTime, 1.0, 0.02, 0.5);

    // 2. 表面积雪
    float surfaceSnow = surfaceSnowAmount(worldNormal, snowDir, 0.6);

    // 3. 混合
    vec3 snowColor = vec3(0.95, 0.96, 0.98);
    vec3 color = applySurfaceSnow(baseColor, surfaceSnow * snowIntensity, snowColor);

    // 4. 叠加飘落雪花
    color = mix(color, snowColor, particleSnow * snowIntensity * 0.8);

    fragColor = vec4(color, 1.0);
}
