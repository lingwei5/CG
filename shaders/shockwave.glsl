// ============================================================
// 冲击波与 UV 变形 (Shockwave & UV Distortion)
// 包含：冲击波 / 水面涟漪 / 旋涡扭曲 / 球面膨胀收缩 /
//       多冲击波管理
// ============================================================
// 共同原理：全部是"修改采样 UV"的后处理——
//   不改颜色本身，而是计算每个像素应该去场景纹理的"哪里"采样。
//   shockwave(p) = offset，最终 texture(scene, uv + offset)。
//   湍流/热浪/传送波纹都属于这一类（fire.glsl 的 heatDistortion 同源）。
// ============================================================

// ---------- 1. 冲击波 (Shockwave) ----------
// 从中心向外扩张的环：环内外的折射偏移方向相反（凸透镜边缘感）。
// 输入: center 爆炸中心UV, radius 当前波前半径, width 波环宽度
vec2 shockwaveOffset(vec2 uv, vec2 center, float radius, float width,
                     float strength) {
    float dist = length(uv - center);
    // 波环：[radius-width, radius] 内有效
    float inWave = smoothstep(radius, radius - width * 0.5, dist)
                 * smoothstep(radius - width, radius - width * 0.5, dist);
    if (inWave <= 0.0) return vec2(0.0);

    // 波形剖面：环中心偏移最大，两侧衰减到 0（一阶导连续）
    float t = (dist - (radius - width)) / width;        // 0..1 within ring
    float profile = sin(t * 3.14159);                    // 钟形

    // 偏移方向：沿径向。向外折射（把周围像素"推开"）
    vec2 dir = (uv - center) / max(dist, 1e-5);
    return dir * profile * strength;
}

// 完整的年龄驱动版本：radius 随 age 增长、强度随 age 衰减
// age: 0(爆炸瞬间) → 1(消散)；lifespan 控制传播速度
vec2 shockwave(vec2 uv, vec2 center, float age /*0..1*/,
               float maxRadius, float lifespan) {
    float radius = age * maxRadius;
    float width = 0.08 + age * 0.15;                    // 波环越来越宽
    float strength = 0.03 * (1.0 - age);                // 越传越弱
    // 宽高比修正：屏幕 UV 不是等距的
    return shockwaveOffset(uv, center, radius, width, strength) / lifespan;
}

// ---------- 2. 水面涟漪 (Ripple) ----------
// 同心衰减正弦环：雨滴、水波纹。
// 与冲击波的区别：多个持续振荡的环而非单个脉冲。
vec2 rippleOffset(vec2 uv, vec2 center, float time,
                  float frequency, float amplitude, float decay) {
    float dist = length(uv - center);
    // 振幅随距离指数衰减
    float atten = exp(-dist * decay);
    // 向外传播的衰减正弦：波数 = dist*freq - time*speed
    float wave = sin(dist * frequency - time * 8.0) * atten;
    vec2 dir = (uv - center) / max(dist, 1e-5);
    return dir * wave * amplitude;
}

// 多滴雨落水面：随机中心的涟漪叠加
vec2 multiRipple(vec2 uv, float time) {
    vec2 total = vec2(0.0);
    // 3 个固定相位差的雨滴
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        // 每滴有自己的触发周期与位置
        float period = 2.0 + fi * 0.7;
        float phase = mod(time, period) / period;       // 0..1 重复
        vec2 dropCenter = vec2(0.3 + 0.3 * fract(sin(fi * 78.233) * 43758.5453),
                               0.3 + 0.4 * fract(sin(fi * 12.9898) * 43758.5453));
        total += rippleOffset(uv, dropCenter, phase * 6.0,
                              60.0, 0.006, 12.0) * (1.0 - phase);
    }
    return total;
}

// ---------- 3. 旋涡扭曲 (Twirl / Vortex) ----------
// 角度随半径旋转：传送门、魔法旋涡、黑洞。
// angle: 最大扭转角（弧度），radius: 作用半径
vec2 twirlOffset(vec2 uv, vec2 center, float radius, float angle) {
    vec2 d = uv - center;
    float dist = length(d);
    if (dist > radius || dist < 1e-5) return vec2(0.0);

    // 中心扭转最大、边缘为 0 的角度场
    float t = 1.0 - dist / radius;
    float a = angle * t * t;
    // 旋转 d 向量
    float s = sin(a), c = cos(a);
    vec2 rotated = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
    return rotated - d;      // offset = 旋转后位置 - 原位置
}

// 动画版本：扭转角随时间脉动（呼吸感的漩涡）
vec2 twirlAnimated(vec2 uv, vec2 center, float time,
                   float maxAngle, float radius) {
    float angle = maxAngle * (0.7 + 0.3 * sin(time * 2.0));
    return twirlOffset(uv, center, radius, angle);
}

// ---------- 4. 球面变形 (Bulge / Pinch) ----------
// 放大镜（bulge）/ 收缩（pinch）：径向距离的非线性重映射。
// factor > 1: bulge（中心放大），0 < factor < 1: pinch（中心缩小）
vec2 bulgeOffset(vec2 uv, vec2 center, float radius, float factor) {
    vec2 d = uv - center;
    float dist = length(d);
    if (dist > radius || dist < 1e-5) return vec2(0.0);

    float t = dist / radius;
    // 平滑过渡：中心完全 factor，边缘 1.0
    float blend = 1.0 - smoothstep(0.0, 1.0, t);
    float newDist = dist * mix(1.0, 1.0 / factor, blend);
    vec2 dir = d / dist;
    return dir * newDist - d;
}

// ---------- 5. 组合示例：爆炸后处理 ----------
// 需要外部管理 age（0..1），爆炸发生时置 0，每帧 += dt/lifespan
vec3 explosionEffect(sampler2D sceneTex, vec2 uv,
                     vec2 explosionCenter, float age) {
    if (age >= 1.0) return texture(sceneTex, uv).rgb;

    // 1) 主冲击波
    vec2 offset = shockwave(uv, explosionCenter, age, 0.6, 1.0);
    // 2) 叠加轻微涟漪（爆炸余波）
    offset += rippleOffset(uv, explosionCenter, age * 10.0, 40.0,
                           0.002 * (1.0 - age), 15.0);

    vec3 color = texture(sceneTex, uv + offset).rgb;

    // 3) 波前边缘发光（可选：叠一圈暖色壳）
    float dist = length(uv - explosionCenter);
    float waveFront = age * 0.6;
    float edgeGlow = smoothstep(0.03, 0.0, abs(dist - waveFront))
                   * (1.0 - age) * 0.5;
    color += vec3(1.0, 0.6, 0.2) * edgeGlow;

    return color;
}
