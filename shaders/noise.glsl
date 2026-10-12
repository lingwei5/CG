// ============================================================
// 噪声库 (Noise Library) — 程序化噪声全家桶
// 包含：白噪声 / 值噪声 / Perlin梯度噪声 / Simplex噪声 /
//       Worley细胞噪声 / Voronoi边界 / fBm分形 / 域扭曲 /
//       可平铺噪声 / 旋度噪声 / 交错梯度噪声
// ============================================================
// 噪声选型指南：
//   白噪声   → 颗粒、抖动、随机触发
//   值噪声   → 最廉价的光滑噪声，硬件友好
//   Perlin   → 经典梯度噪声，方向性强，适合地形/云
//   Simplex  → Perlin 的改良，无轴向伪影、更快（高维），适合 3D
//   Worley   → 细胞/石纹/海绵，F2-F1 用于边界
//   fBm      → 任何基础噪声的多倍频叠加，自然的分形细节
//   域扭曲   → fBm 的非线性变换，烟雾/大理石/流体感
// ============================================================

// ---------- 1. 哈希函数 (Hash) — 一切噪声的地基 ----------
// 输入坐标 → [0,1) 伪随机数。要求：快、统计均匀、相邻输入不相关

// 1D 哈希：用于时间随机触发
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// 2D → 1D：最常用
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 2D → 2D：生成梯度向量/细胞偏移
vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// 3D → 1D
float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// 白噪声：逐像素独立随机（就是直接用哈希）
float whiteNoise(vec2 p) {
    return hash12(p);
}

// ---------- 2. 值噪声 (Value Noise) ----------
// 格点存随机值，格间双线性插值。最便宜的光滑噪声。

// 1D 值噪声：用于动画（比逐帧白噪声平滑）
float valueNoise1D(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);           // smoothstep 插值
    return mix(hash11(i), hash11(i + 1.0), u);
}

// 2D 值噪声
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);            // fade 曲线，C1 连续
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);   // 双线性
}

// 3D 值噪声（体积雾/云内部密度常用）
float valueNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    // 8 个角点的三线性插值
    return mix(
        mix(mix(hash13(i + vec3(0,0,0)), hash13(i + vec3(1,0,0)), u.x),
            mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), u.x), u.y),
        mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), u.x),
            mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), u.x), u.y),
        u.z);
}

// ---------- 3. Perlin 梯度噪声 (Gradient Noise) ----------
// 格点存随机"梯度向量"，输入与梯度点积后插值。
// 值噪声有"块状"感，Perlin 过零点更自然，方向纹理更少。

float perlinNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);  // quintic fade，C2 连续
    // 4 个角点：梯度 · (p - 角点)
    float a = dot(hash22(i),               f - vec2(0.0, 0.0));
    float b = dot(hash22(i + vec2(1, 0)),  f - vec2(1.0, 0.0));
    float c = dot(hash22(i + vec2(0, 1)),  f - vec2(0.0, 1.0));
    float d = dot(hash22(i + vec2(1, 1)),  f - vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);      // 输出约 [-0.7, 0.7]
}

// Perlin 的 fade 曲线对比：
//   smoothstep: 3t²-2t³      C1 连续，一阶导在格点连续
//   quintic:    6t⁵-15t⁴+10t³ C2 连续，二阶导也连续 → 更平滑的视觉效果

// ---------- 4. Simplex 噪声 ----------
// Perlin 的几何改良：n 维单纯形（2D 是三角形）代替方格。
// 优点：无轴向伪影、倍频更均匀、3D 时计算量更低（3³=27 → 4 个顶点）。
// 以下为 Ashima Arts / Stefan Gustavson 的经典 WebGL 实现（公有领域）。

vec3 permute3(vec3 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }

float simplexNoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187,  // (3-sqrt(3))/6  F1 偏移
                        0.366025403784439,  // (sqrt(3)-1)/2  单纯形斜切系数
                       -0.577350269189626,  // -1/sqrt(3)     原点移动
                        0.024390243902439); // 1/41           置换常数
    // 斜切空间格点 + 未剪切空间局部坐标
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    // 判断在哪个三角形（中边拆分）
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    // 三个角点相对坐标
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    // 置换生成梯度索引
    i = mod(i, 289.0);
    vec3 p = permute3(permute3(i.y + vec3(0.0, i1.y, 1.0))
                        + i.x + vec3(0.0, i1.x, 1.0));
    // 径向衰减核 0.5-|x|²
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
                            dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    // 梯度：把哈希值映到 [-1,1] 的近似均匀方向
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);  // 归一化
    // 梯度·距离
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);      // 输出约 [-1, 1]
}

// ---------- 5. Worley / 细胞噪声 (Cellular Noise) ----------
// 每个格点放一个随机"特征点"，输出到最近特征点的距离。
// F1 = 最近距离，F2 = 次近距离。F2-F1 → 细胞边界。

// 返回 vec2(F1, F2)
vec2 worleyNoise(vec2 p, float time) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float f1 = 8.0, f2 = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 o = hash22(i + g);
            // 特征点在格内随机漂移（time 驱动动画，不需要时传 0）
            o = 0.5 + 0.5 * sin(time + 6.2831 * o);
            float d = length(g + o - f);
            if (d < f1) { f2 = f1; f1 = d; }
            else if (d < f2) { f2 = d; }
        }
    }
    return vec2(f1, f2);
}

// 经典细胞纹理
float worleyF1(vec2 p, float time) { return worleyNoise(p, time).x; }

// F2-F1：接近 0 处即细胞边界，锐利的石纹/海绵
float worleyEdge(vec2 p, float time) {
    vec2 f = worleyNoise(p, time);
    return f.y - f.x;
}

// ---------- 6. Voronoi 精确边界距离 ----------
// Worley 只给 F1/F2，iq 的这个版本输出到"细胞边界的精确距离"，
// 可直接用 smoothstep 画任意宽度的边界线（见 iq 的 voronoi 文章）。

float voronoiEdgeDistance(vec2 x, float time) {
    // 第一遍：找最近特征点的相对向量 mr
    vec2 n = floor(x);
    vec2 f = fract(x);
    float md = 8.0;
    vec2 mr = vec2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            o = 0.5 + 0.5 * sin(time + 6.2831 * o);
            vec2 r = g + o - f;
            float d = dot(r, r);
            if (d < md) { md = d; mr = r; }
        }
    }
    // 第二遍：mr 与 5x5 邻域内特征点连线的中垂线距离取最小
    md = 8.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g = mr + vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            o = 0.5 + 0.5 * sin(time + 6.2831 * o);
            vec2 r = g + o - f;
            if (dot(mr - r, mr - r) > 0.00001)   // 排除自身
                md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
        }
    }
    return md;    // 可直接当作 SDF 用
}

// ---------- 7. fBm 分形布朗运动 (Fractal Brownian Motion) ----------
// 倍频叠加：频率 ×2、振幅 ×0.5（lacunarity=2, gain=0.5）。
// 自然界的云/地形/纹理都具有近似的自相似分形结构。

// 基于值噪声的 fBm（最廉价）
float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    // 每倍频旋转坐标，消除轴向对齐伪影
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < octaves; i++) {
        value += amp * valueNoise(p);
        p = rot * p * 2.0;
        amp *= 0.5;
    }
    return value;   // 约 [0, 1)
}

// 基于 Perlin 的 fBm（质量更好，输出约 [-1,1]）
float fbmPerlin(vec2 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < octaves; i++) {
        value += amp * perlinNoise(p);
        p = rot * p * 2.0;
        amp *= 0.5;
    }
    return value;
}

// 脊状分形 (Ridged Multifractal)：1-|noise| 再平方 → 山脊/峡谷
float ridgedFbm(vec2 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < octaves; i++) {
        float n = 1.0 - abs(perlinNoise(p));   // 反转：谷变脊
        n *= n;                                  // 锐化脊线
        value += amp * n;
        p = rot * p * 2.0;
        amp *= 0.5;
    }
    return value;
}

// 湍流 (Turbulence)：|noise| 累加 → 火焰/大理石
float turbulence(vec2 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    for (int i = 0; i < octaves; i++) {
        value += amp * abs(perlinNoise(p));
        p *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// ---------- 8. 域扭曲 (Domain Warping) ----------
// 用 fBm 的输出当作坐标偏移再采 fBm——"用噪声扭曲噪声"。
// iq 的经典两层扭曲，产生流动的烟雾/大理石纹理。

float domainWarp(vec2 p, float time) {
    // 第一层：q 是低频扭曲量
    vec2 q = vec2(fbm(p + vec2(0.0, 0.0) + 0.15 * time, 4),
                  fbm(p + vec2(5.2, 1.3) + 0.12 * time, 4));
    // 第二层：q 再放大扭曲出 r
    vec2 r = vec2(fbm(p + 4.0 * q + vec2(1.7, 9.2) + 0.10 * time, 4),
                  fbm(p + 4.0 * q + vec2(8.3, 2.8) + 0.13 * time, 4));
    // 最终在 r 扭曲后的域里采样
    return fbm(p + 4.0 * r, 5);
}

// ---------- 9. 可平铺噪声 (Tileable / Periodic Noise) ----------
// 纹理需要无缝平铺时使用：哈希时把格点坐标按周期取模。
float tileableValueNoise(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    // 关键：mod 包裹格点坐标，左右/上下边界自然衔接
    vec2 i0 = mod(i, period);
    vec2 i1 = mod(i + vec2(1.0, 0.0), period);
    vec2 i2 = mod(i + vec2(0.0, 1.0), period);
    vec2 i3 = mod(i + vec2(1.0, 1.0), period);
    float a = hash12(i0);
    float b = hash12(i1);
    float c = hash12(i2);
    float d = hash12(i3);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 可平铺 fBm：每个倍频的周期也要 ×2
float tileableFbm(vec2 p, float period, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    for (int i = 0; i < octaves; i++) {
        value += amp * tileableValueNoise(p, period);
        p *= 2.0;
        period *= 2.0;      // 频率翻倍时周期同步翻倍才能保持平铺
        amp *= 0.5;
    }
    return value;
}

// ---------- 10. 旋度噪声 (Curl Noise) ----------
// 对标量噪声取二维旋度 → 无散度向量场，粒子沿它运动
// 不会聚集成堆（流体感的关键）。适合 GPU 粒子、烟雾平流。

vec2 curlNoise(vec2 p, float time) {
    const float e = 0.1;
    // 中心差分求偏导
    float n1 = fbm(p + vec2(0.0, e) + time * 0.1, 4);
    float n2 = fbm(p - vec2(0.0, e) + time * 0.1, 4);
    float n3 = fbm(p + vec2(e, 0.0) + time * 0.1, 4);
    float n4 = fbm(p - vec2(e, 0.0) + time * 0.1, 4);
    // curl = (∂n/∂y, -∂n/∂x)，自动无散度
    return vec2(n1 - n2, n4 - n3) / (2.0 * e);
}

// ---------- 11. 交错梯度噪声 (Interleaved Gradient Noise) ----------
// Jimenez 2014 (SIGGRAPH Advances)：空间相关而非独立的噪声，
// 配合 TAA 时序累积，比白噪声/蓝噪声纹理更省内存且收敛快。
// 输入是整数像素坐标（gl_FragCoord.xy）。

float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(0.06711056 * pixel.x
                                  + 0.00583715 * pixel.y));
}

// 时序版本：每帧偏移，TAA 累积多帧后等效超采样
float ignTemporal(vec2 pixel, float frameIndex) {
    return fract(52.9829189 * fract(0.06711056 * pixel.x
                                  + 0.00583715 * pixel.y
                                  + 0.0233      * frameIndex));
}

// ---------- 12. 应用示例 ----------

// 大理石纹理：turbulence 驱动正弦条纹
vec3 marbleColor(vec2 uv) {
    float t = turbulence(uv * 4.0, 5);
    float veins = sin((uv.x + t * 1.5) * 12.0) * 0.5 + 0.5;
    return mix(vec3(0.92, 0.90, 0.87), vec3(0.15, 0.14, 0.16), veins);
}

// 石头纹理：Voronoi 边界 + fBm 扰动
vec3 rockColor(vec2 uv, float time) {
    float border = voronoiEdgeDistance(uv * 6.0 + fbm(uv * 3.0, 4), 0.0);
    float crack = 1.0 - smoothstep(0.0, 0.08, border);   // 边界线
    float shade = 0.5 + 0.5 * fbm(uv * 8.0, 4);          // 表面明暗
    return mix(vec3(0.45, 0.42, 0.40) * shade, vec3(0.1), crack * 0.7);
}

// 程序化星空：稀疏白噪声做星星，fBm 做银河
vec3 starField(vec2 uv) {
    vec2 grid = uv * 60.0;
    vec2 cellId = floor(grid);
    float star = hash12(cellId);
    vec2 starPos = hash22(cellId);
    float d = length(fract(grid) - starPos);
    float brightness = (star > 0.97) ? smoothstep(0.12, 0.0, d) : 0.0;
    float milkyWay = fbm(uv * 3.0, 5) * smoothstep(0.9, 0.2, uv.y);
    return vec3(0.05, 0.06, 0.12) * milkyWay + vec3(brightness);
}
