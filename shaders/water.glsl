// ============================================================
// 水面效果 (Water) — 波动 + 反射 + 折射 + 焦散 + 菲涅尔
// ============================================================

// ---------- 1. 水面法线 (Gerstner 波) ----------

// Gerstner 波：模拟真实水面波形
// 输入: position (世界坐标), time, waveParams (方向, 频率, 振幅, 速度)
vec3 gerstnerNormal(vec2 position, float time, vec4 waveParams) {
    vec2 direction = normalize(waveParams.xy);
    float frequency = waveParams.z;
    float speed = waveParams.w;

    float phase = dot(direction, position) * frequency + time * speed;
    float amplitude = 1.0 / frequency * 0.5;

    // 法线近似
    vec3 normal = vec3(
        -direction.x * amplitude * cos(phase),
        -direction.y * amplitude * cos(phase),
        1.0
    );
    return normalize(normal);
}

// 多层 Gerstner 波叠加
vec3 multiWaveNormal(vec2 position, float time) {
    vec3 normal = vec3(0.0);
    normal += gerstnerNormal(position, time, vec4(1.0, 0.6, 0.8, 0.5)) * 0.5;
    normal += gerstnerNormal(position, time, vec4(-0.7, 1.0, 1.2, 0.3)) * 0.3;
    normal += gerstnerNormal(position, time, vec4(0.3, -0.8, 2.0, 0.7)) * 0.2;
    return normalize(normal);
}

// ---------- 2. 水面焦散 (Caustics) ----------

// 水底焦散光斑
float caustics(vec2 uv, float time) {
    vec2 p = uv * 8.0;
    float c = 0.0;

    // 两层噪声的差值产生焦散纹理
    float n1 = sin(p.x * 0.5 + time) * cos(p.y * 0.5 + time * 0.7);
    float n2 = sin(p.x * 0.3 - time * 0.5) * cos(p.y * 0.4 + time * 0.3);

    c = pow(abs(n1 * n2), 3.0) * 3.0;
    return clamp(c, 0.0, 1.0);
}

// ---------- 3. 水面颜色深度 ----------

// 根据水深调整颜色（深水偏蓝，浅水偏浅蓝绿）
vec3 waterColorByDepth(float depth, vec3 shallowColor, vec3 deepColor) {
    return mix(shallowColor, deepColor, smoothstep(0.0, 5.0, depth));
}

// ---------- 4. 完整水面着色器 (fragment shader) ----------

// uniform float iTime;
// uniform vec3 cameraPos;
// uniform sampler2D reflectionMap;  // 反射纹理
// uniform sampler2D refractionMap;  // 折射纹理
// uniform sampler2D depthMap;       // 水深纹理
// uniform vec2 texelSize;

vec3 renderWater(vec3 worldPos, vec3 viewDir, vec3 lightDir, float time) {
    // 1. 水面法线（多层波叠加）
    vec3 normal = multiWaveNormal(worldPos.xz, time);

    // 2. 菲涅尔
    float F0 = 0.02; // 水的 F0
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - max(dot(viewDir, normal), 0.0), 5.0);

    // 3. 反射方向
    vec3 reflectDir = reflect(-viewDir, normal);

    // 4. 折射方向
    vec3 refractDir = refract(-viewDir, normal, 1.0 / 1.33);

    // 5. 高光（Blinn-Phong）
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfDir), 0.0), 256.0);

    // 6. 水面颜色
    vec3 shallowColor = vec3(0.3, 0.7, 0.5);
    vec3 deepColor = vec3(0.02, 0.1, 0.3);
    vec3 waterColor = mix(shallowColor, deepColor, 0.6);

    // 7. 合成：菲涅尔混合反射和折射
    vec3 reflection = texture(reflectionMap, reflectDir.xy * 0.5 + 0.5).rgb;
    vec3 refraction = texture(refractionMap, refractDir.xy * 0.5 + 0.5).rgb;
    refraction *= waterColor; // 折射光被水吸收着色

    vec3 color = mix(refraction, reflection, fresnel);

    // 8. 高光
    color += vec3(1.0) * spec * 0.5;

    return color;
}
