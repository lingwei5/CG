// ============================================================
// 数字故障 (Digital Glitch) — 信号损坏风格的画面错误
// 包含：RGB错位 / 块位移 / 扫描线撕裂 / 波形扭曲 /
//       信号丢失 / 综合故障
// ============================================================
// 设计要点：
//   故障效果的核心是"随机触发"——正常画面偶尔爆发电磁干扰。
//   用 time 的哈希决定"当前帧是否故障"以及"哪些行受影响"，
//   让故障呈阵发性而非持续存在，才有数字损坏的质感。
// ============================================================

// ---------- 0. 依赖：哈希 ----------
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// ---------- 1. RGB 错位 (RGB Shift) ----------
// RGB 通道水平错开。可加块状掩码：只在部分行错位。
vec3 glitchRGBShift(sampler2D tex, vec2 uv, float time,
                    float maxShift, float probability) {
    // 按行决定错位量（行 = uv.y 量化），每帧重新随机
    float row = floor(uv.y * 32.0);
    float trigger = step(1.0 - probability, hash12(vec2(row, floor(time * 15.0))));
    float shift = (hash12(vec2(row, floor(time * 15.0) + 7.0)) - 0.5)
                * 2.0 * maxShift * trigger;

    vec3 color;
    color.r = texture(tex, uv + vec2(shift, 0.0)).r;
    color.g = texture(tex, uv).g;
    color.b = texture(tex, uv - vec2(shift, 0.0)).b;
    return color;
}

// ---------- 2. 块位移 (Block Displacement) ----------
// 画面被切成横向条带，每条带随机水平位移——最典型的"信号损坏"。
vec3 glitchBlockDisplacement(sampler2D tex, vec2 uv, float time,
                             float maxOffset, float probability) {
    float band = floor(uv.y * 24.0);                  // 24 个条带
    // 每帧+每条带独立随机；低概率触发大幅位移
    float h = hash12(vec2(band, floor(time * 12.0)));
    float displaced = step(1.0 - probability, h);

    // 位移量：触发的条带内再随机大小与方向
    float offset = (hash12(vec2(band + 31.0, floor(time * 12.0))) - 0.5)
                 * 2.0 * maxOffset * displaced;

    return texture(tex, uv + vec2(offset, 0.0)).rgb;
}

// ---------- 3. 扫描线撕裂 (Scanline Tear) ----------
// 一条水平亮线附近画面撕裂：线上/下采样坐标跳变。
vec3 glitchScanlineTear(sampler2D tex, vec2 uv, float time,
                        float tearHeight, float maxJump) {
    // 撕裂线的位置每帧随机
    float tearY = hash11(floor(time * 9.0) + 3.0);
    float inTear = step(tearY, uv.y) * step(uv.y, tearY + tearHeight);

    // 撕裂区内垂直坐标跳变（上下画面内容互换的错觉）
    float jump = (hash11(floor(time * 9.0) + 11.0) - 0.5)
               * 2.0 * maxJump * inTear;
    return texture(tex, uv + vec2(0.0, jump)).rgb;
}

// ---------- 4. 波形扭曲 (Signal Wave) ----------
// 模拟电磁干扰对扫描信号的干扰：行相位正弦偏移。
vec3 glitchSignalWave(sampler2D tex, vec2 uv, float time,
                      float amplitude, float frequency) {
    // 只扰动 x；频率高时像射频干扰
    float wave = sin(uv.y * frequency + time * 40.0)
               * amplitude;
    // 波形强度也随时间随机波动（时有时无）
    wave *= step(0.3, hash11(floor(time * 8.0)));
    return texture(tex, uv + vec2(wave, 0.0)).rgb;
}

// ---------- 5. 信号丢失 (Signal Loss / Datamosh) ----------
// 部分区域变成马赛克色块或纯噪声。
vec3 glitchSignalLoss(vec3 color, vec2 uv, float time,
                      float probability) {
    // 大格子触发的"色块损坏"
    vec2 block = floor(uv * vec2(16.0, 9.0));
    float h = hash12(vec2(block, floor(time * 6.0)));

    if (h > 1.0 - probability) {
        // 坏块：显示随机色或噪声
        float mode = hash12(vec2(block + 5.0, floor(time * 6.0)));
        if (mode < 0.5) {
            // 纯色块（品红/青/黄——损坏的 YUV 感）
            vec3 corrupt = vec3(step(0.5, hash12(block + 1.0)),
                                step(0.5, hash12(block + 2.0)),
                                step(0.5, hash12(block + 3.0)));
            color = mix(corrupt, vec3(0.5), 0.3);
        } else {
            // 白噪声块
            color = vec3(hash12(uv * 500.0 + time * 100.0));
        }
    }
    return color;
}

// ---------- 6. 闪屏抖动 (Frame Jitter) ----------
// 整帧偶尔跳变——模拟接触不良。返回 UV 偏移。
vec2 glitchFrameJitter(vec2 uv, float time, float probability,
                       float maxJitter) {
    // 每帧一次哈希决定是否跳变（帧号 = floor(time*fps)）
    float frame = floor(time * 24.0);
    if (hash11(frame) < probability) {
        return uv + vec2(hash11(frame + 7.0) - 0.5,
                         hash11(frame + 13.0) - 0.5) * 2.0 * maxJitter;
    }
    return uv;
}

// ---------- 7. 综合故障示例 ----------
// 各子效果按不同概率叠加，爆发时有整体噪声增强
vec3 fullGlitch(sampler2D tex, vec2 uv, float time, float intensity) {
    // 主触发：时间分段随机，intensity 控制故障频率
    float burstSeed = floor(time * 2.0);
    float burst = step(1.0 - 0.3 * intensity, hash11(burstSeed));

    // 帧抖动（UV 级，最先应用）
    vec2 jitterUV = glitchFrameJitter(uv, time, 0.4 * intensity * burst, 0.02);

    // 信号波形
    vec3 color = glitchSignalWave(tex, jitterUV, time,
                                  0.01 * intensity * burst, 90.0);
    // 块位移
    color = glitchBlockDisplacement(tex, jitterUV, time,
                                    0.15 * intensity, 0.15 * intensity * burst)
            * 0.5 + color * 0.5;   // 与波形混合避免完全覆盖
    // 撕裂
    color = glitchScanlineTear(tex, jitterUV, time,
                               0.03, 0.1 * intensity * burst) * 0.5 + color * 0.5;
    // RGB 错位
    color = glitchRGBShift(tex, jitterUV, time,
                           0.01 * intensity, 0.2 * intensity * burst) * 0.5 + color * 0.5;
    // 信号丢失色块
    color = glitchSignalLoss(color, uv, time, 0.05 * intensity * burst);

    // 爆发时叠加整体噪声
    float staticNoise = hash12(uv * 300.0 + time * 200.0);
    color += (staticNoise - 0.5) * 0.15 * intensity * burst;

    return color;
}
