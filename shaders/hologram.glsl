// ============================================================
// 全息效果 (Hologram) — 扫描线 + 故障 + 发光
// ============================================================

// ---------- 1. 扫描线 ----------

float scanlines(vec2 uv, float frequency, float intensity) {
    float lines = sin(uv.y * frequency * 3.14159 * 2.0) * 0.5 + 0.5;
    return mix(1.0, lines, intensity);
}

// ---------- 2. 水平故障 (Glitch) ----------

float random(float n) {
    return fract(sin(n) * 43758.5453);
}

vec2 glitchOffset(vec2 uv, float time, float intensity) {
    // 随机时间触发故障
    float glitchTime = floor(time * 5.0);
    float glitchTrigger = step(0.8, random(glitchTime));

    // 分条偏移
    float band = floor(uv.y * 20.0);
    float offset = (random(band + glitchTime) - 0.5) * 0.1 * intensity * glitchTrigger;

    return vec2(offset, 0.0);
}

// ---------- 3. 菲涅尔边缘发光 ----------

float hologramFresnel(vec3 viewDir, vec3 normal, float power) {
    float NdotV = abs(dot(normal, viewDir));
    return pow(1.0 - NdotV, power);
}

// ---------- 4. 闪烁 (Flicker) ----------

float flicker(float time, float base, float amplitude) {
    return base + sin(time * 30.0) * amplitude * 0.5 + amplitude * 0.5
         + sin(time * 137.0) * amplitude * 0.3;
}

// ---------- 5. RGB 色差 ----------

vec3 chromaticAberration(sampler2D tex, vec2 uv, float amount) {
    vec2 dir = uv - 0.5;
    float r = texture(tex, uv - dir * amount).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv + dir * amount).b;
    return vec3(r, g, b);
}

// ---------- 6. 数据网格 ----------

float dataGrid(vec2 uv, float time) {
    // 水平网格线
    float hLine = smoothstep(0.98, 1.0, abs(fract(uv.y * 20.0) - 0.5) * 2.0);
    // 垂直网格线
    float vLine = smoothstep(0.98, 1.0, abs(fract(uv.x * 20.0) - 0.5) * 2.0);
    return max(hLine, vLine) * 0.1;
}

// ---------- 7. 完整全息着色器 ----------

// uniform float iTime;
// uniform vec3 hologramColor;     // 全息主色 (通常为青色或蓝色)
// uniform sampler2D sceneTex;     // 场景/物体纹理

vec3 renderHologram(vec2 uv, vec3 viewDir, vec3 normal, float time) {
    vec3 holoColor = vec3(0.0, 0.8, 1.0); // 青色

    // 1. 故障偏移
    vec2 glitchedUV = uv + glitchOffset(uv, time, 0.5);

    // 2. 基础纹理
    vec3 base = texture(sceneTex, glitchedUV).rgb;

    // 3. 扫描线
    float scan = scanlines(uv, 500.0, 0.3);

    // 4. 菲涅尔边缘
    float fresnel = hologramFresnel(viewDir, normal, 3.0);

    // 5. 闪烁
    float flick = flicker(time, 0.8, 0.2);

    // 6. 数据网格
    float grid = dataGrid(uv, time);

    // 7. 合成
    vec3 color = base * holoColor * scan * flick;
    color += holoColor * fresnel * 2.0;   // 边缘发光
    color += holoColor * grid;            // 网格

    // 半透明
    float alpha = (length(base) + fresnel) * scan * flick;

    return color;
}
