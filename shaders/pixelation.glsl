// ============================================================
// 像素化 / 抖动 / CRT 复古风 (Pixelation / Dithering / CRT)
// 包含：像素化 / 海报化 / 有序抖动(Bayer) / 误差扩散近似 /
//       CRT 扫描线 / 荫罩 / 屏幕弯曲 / 综合复古风
// ============================================================
// 应用场景：
//   像素画风格游戏、低色深仿古（PS1/GBC）、模拟老式 CRT 显示器。
//   抖动的核心价值：用可接受的图案噪声换取色阶数（8bit 色深
//   无法表达的渐变靠空间混色逼近），老游戏机都是真·硬件抖动。
// ============================================================

// ---------- 1. 像素化 (Pixelation) ----------
// UV 量化到网格中心。注意宽高比：像素块应为正方形。
// 输入: targetRes 目标"分辨率"（如 vec2(320, 180)）
vec3 pixelate(sampler2D tex, vec2 uv, vec2 resolution, vec2 targetRes) {
    // 修正宽高比后的块大小
    vec2 block = resolution / targetRes;
    vec2 grid = floor(uv * targetRes);         // 像素格子索引
    // +0.5 取格子中心，避免采样到格边产生缝隙
    vec2 quantizedUV = (grid + 0.5) / targetRes;
    return texture(tex, quantizedUV).rgb;
}

// 六边形像素化（更有机的风格）
vec3 pixelateHex(sampler2D tex, vec2 uv, float cellSize) {
    // 六边形网格：斜坐标系统
    vec2 s = vec2(1.0, 1.732);                  // √3
    vec2 h = uv / cellSize;
    // axial → cube 坐标
    vec2 a = mod(h, s);
    vec2 cell = floor(h);
    float test = s.x * 0.5 > a.x * s.y - a.y * (s.y - 1.0) ? 0.0 : 1.0;
    // 简化处理：直接用斜切的方块近似
    vec2 hexCell = cell + mix(vec2(0.0), vec2(0.5, 0.5),
                              step(a.x * s.y, a.y * (s.y - 1.0)));
    vec2 outUV = (hexCell + (a.x > 0.5 ? vec2(0.25) : vec2(0.0)))
               * cellSize;
    return texture(tex, clamp(outUV, 0.0, 1.0)).rgb;
}

// ---------- 2. 海报化 (Posterization) ----------
// 连续色阶 → 离散色阶。levels=4 即 GBC 风格
vec3 posterize(vec3 color, int levels) {
    return floor(color * float(levels)) / float(levels - 1);
}

// ---------- 3. 有序抖动 (Ordered Dithering - Bayer Matrix) ----------
// 用 Bayer 矩阵的阈值抖动后量化：色阶边界用棋盘图案过渡。
// 4x4 Bayer 矩阵（每项/16 归一化为阈值）
float bayer4x4(vec2 pixel) {
    // 展开的 Bayer 4x4：交叉相加的递归结构
    int x = int(mod(pixel.x, 4.0));
    int y = int(mod(pixel.y, 4.0));
    // 硬编码查找表（行列）
    int m[16] = int[16](
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5);
    return float(m[y * 4 + x]) / 16.0;
}

// 8x8 Bayer：递归构造 = 4x4*4 + 4x4（无需纹理，纯算术）
float bayer8x8(vec2 pixel) {
    vec2 p1 = mod(pixel, 2.0);
    vec2 p2 = mod(floor(pixel / 2.0), 2.0);
    vec2 p4 = mod(floor(pixel / 4.0), 2.0);
    // 每两级 bit 的贡献：bit0 权重 1/4, bit1 权重 1/4 ... 递归 Bayer 定义
    float b1 = (p1.x + p1.y * 2.0) * 0.25;           // 0,1,2,3 → /16
    float b2 = (p2.x * 2.0 + p2.y) * 0.25;           // 交叉
    float b3 = (p4.x + p4.y * 2.0) * 0.25;
    // 归一化：三个 2x2 层叠加，各层权重按 Bayer 递归
    return mod(p1.x + 2.0 * p1.y
             + 4.0 * mod(p2.x + 2.0 * p2.y + (p1.x + p1.y), 2.0), 8.0) / 8.0;
}

// 海报化 + Bayer 抖动（完整的复古色深模拟）
// levels=3 时视觉色阶远多于 3（图案混色）
vec3 posterizeDither(vec3 color, vec2 pixel, int levels) {
    float threshold = bayer4x4(pixel) - 0.5;
    // 阈值移入量化：抖动决定进位
    vec3 dithered = color + threshold / float(levels);
    return floor(dithered * float(levels)) / float(levels - 1);
}

// ---------- 4. 蓝噪声近似抖动 ----------
// 交错梯度噪声当阈值（比 Bayer 更适合配合 TAA）
float ign(vec2 pixel) {
    return fract(52.9829189 * fract(0.06711056 * pixel.x
                                  + 0.00583715 * pixel.y));
}
vec3 posterizeIGN(vec3 color, vec2 pixel, int levels) {
    float threshold = ign(pixel) - 0.5;
    vec3 dithered = color + threshold / float(levels);
    return floor(dithered * float(levels)) / float(levels - 1);
}

// ---------- 5. CRT 效果 ----------

// 5.1 扫描线：每隔一行压暗（隔行扫描的黑线）
vec3 crtScanlines(vec3 color, vec2 uv, float intensity, float count) {
    float scan = sin(uv.y * count * 3.14159) * 0.5 + 0.5;
    // scan 周期性明暗；强度钳制避免全黑
    return color * mix(1.0, scan, intensity);
}

// 5.2 荫罩 (Aperture Grille)：RGB 竖条子像素结构
// 三色荧光粉竖条：不同列采样不同通道的增强
vec3 crtApertureGrille(vec3 color, vec2 uv, float resolutionX,
                       float strength) {
    float stripe = floor(uv.x * resolutionX * 3.0);    // RGB 循环条纹
    float phase = mod(stripe, 3.0);
    // 当前列增强对应通道、衰减其他通道
    vec3 mask = vec3(phase == 0.0 ? 1.0 : 0.7,
                     phase == 1.0 ? 1.0 : 0.7,
                     phase == 2.0 ? 1.0 : 0.7);
    return mix(color, color * mask, strength);
}

// 5.3 CRT 屏幕弯曲：桶形畸变 + 边框
vec2 crtCurve(vec2 uv, float curvature) {
    uv = uv * 2.0 - 1.0;                               // [-1,1]
    vec2 offset = abs(uv.yx) / vec2(curvature, curvature);
    uv = uv + uv * offset * offset;
    return uv * 0.5 + 0.5;
}

// ---------- 6. 综合示例：完整 CRT 复古风 ----------
vec3 fullCRT(sampler2D tex, vec2 uv, vec2 resolution, float time) {
    // 1) 屏幕弯曲
    vec2 curved = crtCurve(uv, 5.0);
    // 弯曲出界 → 黑边框
    if (curved.x < 0.0 || curved.x > 1.0 ||
        curved.y < 0.0 || curved.y > 1.0) {
        return vec3(0.0);
    }

    // 2) 像素化（低分辨率内容）+ 抖动
    vec3 color = pixelate(tex, curved, resolution, vec2(320.0, 240.0));
    color = posterizeDither(color, curved * resolution, 16);

    // 3) 扫描线 + 荫罩
    color = crtScanlines(color, curved, 0.3, resolution.y);
    color = crtApertureGrille(color, curved, resolution.x, 0.3);

    // 4) 轻微色差（老 CRT 聚焦不实）
    vec2 d = curved - 0.5;
    float r2 = dot(d, d);
    vec3 ca;
    ca.r = texture(tex, curved + d * r2 * 0.02).r;
    ca.g = color.g;
    ca.b = texture(tex, curved - d * r2 * 0.02).b;
    color = mix(color, ca, 0.5);

    // 5) 暗角 + 微弱闪烁（CRT 高压波动）
    float v = 1.0 - r2 * 0.8;
    color *= clamp(v, 0.0, 1.0);
    color *= 1.0 + sin(time * 60.0) * 0.005;

    return color;
}
