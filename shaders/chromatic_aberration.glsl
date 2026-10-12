// ============================================================
// 色差与镜头畸变 (Chromatic Aberration & Lens Distortion)
// 包含：径向色差 / 横向色差 / 变形色差 /
//       桶形畸变 / 枕形畸变 / 鱼眼畸变 / 综合老镜头效果
// ============================================================
// 物理背景：
//   色差——玻璃对不同波长折射率不同（色散），RGB 无法汇聚到同一焦点。
//   径向色差：越靠画面边缘越明显（焦距随波长变化）。
//   横向色差：RGB 放大率不同，边缘产生彩色"镶边"。
//   畸变——透镜放大率随离轴距离变化：
//     桶形 (barrel): 放大率随半径递减，直线向外弯（广角常见）
//     枕形 (pincushion): 放大率随半径递增，直线向内弯（长焦常见）
// ============================================================

// ---------- 1. 径向色差 (Radial Chromatic Aberration) ----------
// 从画面中心向外，RGB 通道沿径向偏移量不同。
// 强度随半径增大（中心清晰、边缘色散）。
// 输入: sceneTex 场景纹理, uv 当前坐标, amount 色散强度(0.001~0.01)
vec3 radialChromaticAberration(sampler2D sceneTex, vec2 uv,
                               vec2 center, float amount) {
    vec2 dir = uv - center;              // 径向方向
    float dist = length(dir);
    // 边缘偏移大、中心为 0；平方加速边缘效果
    vec2 offset = normalize(dir + 1e-6) * dist * dist * amount;

    vec3 color;
    color.r = texture(sceneTex, uv + offset).r;        // 红向外
    color.g = texture(sceneTex, uv).g;                  // 绿不动
    color.b = texture(sceneTex, uv - offset).b;         // 蓝向内
    return color;
}

// 可调三通道独立强度的版本
vec3 radialCAChannels(sampler2D sceneTex, vec2 uv, vec2 center,
                      vec3 amountRGB) {
    vec2 dir = uv - center;
    float dist = length(dir);
    vec2 n = normalize(dir + 1e-6) * dist * dist;
    return vec3(
        texture(sceneTex, uv + n * amountRGB.r).r,
        texture(sceneTex, uv + n * amountRGB.g).g,
        texture(sceneTex, uv - n * amountRGB.b).b);
}

// ---------- 2. 横向色差 (Lateral CA) ----------
// RGB 各通道放大率不同（不是偏移），仅影响边缘放大。
// 用不同半径分别采样，等效于每通道独立的畸变系数。
vec3 lateralChromaticAberration(sampler2D sceneTex, vec2 uv,
                                vec2 center, float scaleR, float scaleB) {
    vec2 d = uv - center;
    return vec3(
        texture(sceneTex, center + d * scaleR).r,   // 红通道放大
        texture(sceneTex, uv).g,
        texture(sceneTex, center + d * scaleB).b);  // 蓝通道缩小
}

// ---------- 3. 变形色差 (Distorted CA) ----------
// 色差采样发生在"畸变后的坐标"上——更接近真实镜头的耦合行为。
// 三个通道用略不同的畸变系数 → 自然的色散耦合。
vec3 distortedChromaticAberration(sampler2D sceneTex, vec2 uv,
                                  vec2 center, float k1, float k2,
                                  float caAmount) {
    float r2 = dot(uv - center, uv - center);
    float fBase = 1.0 + k1 * r2 + k2 * r2 * r2;
    vec3 factors = fBase + vec3(caAmount, 0.0, -caAmount) * r2;

    vec2 d = uv - center;
    return vec3(
        texture(sceneTex, center + d * factors.r).r,
        texture(sceneTex, center + d * factors.g).g,
        texture(sceneTex, center + d * factors.b).b);
}

// ---------- 4. 桶形/枕形畸变 (Barrel / Pincushion) ----------
// Brown-Conrady 模型（OpenCV 同款）:
//   x_d = x(1 + k1 r² + k2 r⁴)
// k1<0 → 桶形, k1>0 → 枕形
// 采样时直接用畸变坐标查原图即可（屏幕像素查畸变映射位置）。

vec2 barrelDistortUV(vec2 uv, vec2 center, float k1, float k2) {
    vec2 d = uv - center;
    float r2 = dot(d, d);                 // r²
    float factor = 1.0 + k1 * r2 + k2 * r2 * r2;
    return center + d * factor;
}

vec3 barrelDistortion(sampler2D sceneTex, vec2 uv, vec2 center,
                      float k1, float k2) {
    vec2 distorted = barrelDistortUV(uv, center, k1, k2);
    // 畸变可能出界，clamp 避免采到环绕内容
    return texture(sceneTex, clamp(distorted, 0.001, 0.999)).rgb;
}

// 逆畸变（校正真实镜头畸变时用）：
// 正向畸变无解析逆，需牛顿迭代 2~3 次近似
vec2 undistortUV(vec2 uv, vec2 center, float k1, float k2) {
    vec2 d = uv - center;
    vec2 approx = d;
    for (int i = 0; i < 3; i++) {
        float r2 = dot(approx, approx);
        float f = 1.0 + k1 * r2 + k2 * r2 * r2;
        approx = d / f;                   // 逐步逼近
    }
    return center + approx;
}

// ---------- 5. 广角"鱼眼"极端畸变 ----------
// 等距投影模型：r_src = tan(r_dst * fov) / tan(fov)
// 用于强烈的鱼眼镜头/监视器风格
vec3 fisheyeDistortion(sampler2D sceneTex, vec2 uv, vec2 center,
                       float fov /*弧度, 建议 <1.5*/) {
    vec2 d = uv - center;
    float r = length(d);
    if (r < 1e-5) return texture(sceneTex, uv).rgb;

    float rSrc = tan(r * fov) / tan(fov);
    rSrc = clamp(rSrc, 0.0, 1.0);
    vec2 srcUV = center + normalize(d) * rSrc;
    // 超出球面范围的部分填黑
    if (any(lessThan(srcUV, vec2(0.0))) || any(greaterThan(srcUV, vec2(1.0))))
        return vec3(0.0);
    return texture(sceneTex, srcUV).rgb;
}

// ---------- 6. 综合示例：老式广角镜头 ----------
// 桶形畸变 + 径向色差 + 边缘暗角一次到位
vec3 vintageWideAngleLens(sampler2D sceneTex, vec2 uv, vec2 resolution) {
    vec2 center = vec2(0.5);
    float aspect = resolution.x / resolution.y;

    // 1) 桶形畸变
    vec2 d = (uv - center) * vec2(aspect, 1.0);
    float r2 = dot(d, d);
    float k1 = -0.15;
    float factor = 1.0 + k1 * r2;
    vec2 distorted = center + (uv - center) * factor;

    // 2) 径向色差（在畸变坐标上）
    vec3 color = radialChromaticAberration(sceneTex, distorted, center, 0.008);

    // 3) 边缘暗角（自然衰减，与畸变半径一致）
    float vignette = 1.0 - 0.4 * r2;
    color *= clamp(vignette, 0.0, 1.0);

    return color;
}
