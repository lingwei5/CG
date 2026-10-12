// ============================================================
// 视差贴图 (Parallax Mapping) — 高度图的伪 3D 表面细节
// 包含：基础偏移视差 / 陡峭视差 (Steep Parallax) /
//       视差遮蔽映射 (POM) / POM 自阴影
// ============================================================
// 原理：
//   法线贴图只欺骗"光照方向"，视差贴图欺骗"视线几何"——
//   根据视线方向在切线空间中对高度图做采样偏移，
//   让凹凸表面在不同视角下产生真实的相对位移（视差）。
//   全部计算在切线空间（TBN）进行。
//
// 依赖：物体表面的切线空间基 (T, B, N) 与高度图 (heightTex)
// ============================================================

// ---------- 0. TBN 构建 ----------
// 从顶点数据构建（正交完整个版本）
mat3 buildTBN(vec3 T, vec3 B, vec3 N) {
    // 施密特正交化：保证 T、B 与 N 垂直（插值后可能不正交）
    T = normalize(T - N * dot(N, T));
    B = cross(N, T);                     // 重建正交的 B
    return mat3(T, B, N);
}

// 从 dFdx/dFdy 现场构建（无需顶点切线属性）
mat3 buildTBNCotangent(vec3 N, vec3 p, vec2 uv) {
    vec3 dp1 = dFdx(p), dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv), duv2 = dFdy(uv);
    // 解 2x2 线性方程得切线方向（"cotangent frame" 技巧）
    vec3 dp2perp = cross(dp2, N);
    vec3 dp1perp = cross(N, dp1);
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;
    float invMax = max(1.0 / max(length(T), 1e-8),
                       1.0 / max(length(B), 1e-8));
    return mat3(T * invMax, B * invMax, N);
}

// ---------- 1. 基础偏移视差 (Offset Parallax) ----------
// 最简单的版本：视线方向 × 高度直接偏移 UV。
// 问题：视角越平偏移越大但方向不反演 → 边缘 artifacts。
vec2 parallaxSimple(vec2 uv, vec3 viewDirTS /*切线空间,指向表面*/,
                    sampler2D heightMap, float scale) {
    float h = texture(heightMap, uv).r;       // 0..1
    // viewDirTS.z 分量归一化视线（接近水平时分母小→偏移大）
    return uv - (viewDirTS.xy / viewDirTS.z) * (h * scale);
}

// 带符号的高度版（0.5 为基准面）：凹凸对称
vec2 parallaxSimpleSymmetric(vec2 uv, vec3 viewDirTS,
                             sampler2D heightMap, float scale) {
    float h = texture(heightMap, uv).r - 0.5;
    return uv - (viewDirTS.xy / viewDirTS.z) * (h * scale);
}

// ---------- 2. 陡峭视差 (Steep Parallax Mapping) ----------
// 沿视线做固定步数的 raymarch，找到第一个进入高度场下方的层。
// 比基础版准确得多（自遮挡正确），但有"台阶"分层伪影。
// 输入: layers 步进层数（视角越平需要越多，动态可调）
vec2 parallaxSteep(vec2 uv, vec3 viewDirTS, sampler2D heightMap,
                   float scale, int layers) {
    // 视线越水平（z 越小），需要的层数越多
    float numLayers = mix(float(layers) * 2.0, float(layers),
                          abs(viewDirTS.z));

    float layerHeight = 1.0 / numLayers;          // 每层高度差
    vec2 texelStep = (viewDirTS.xy / viewDirTS.z) * scale / numLayers;

    float currentLayer = 1.0;                      // 从最高处开始走
    vec2 currentUV = uv;
    float currentHeight = texture(heightMap, currentUV).r;

    // 步进直到穿入高度场内部
    for (int i = 0; i < 64; i++) {
        if (float(i) >= numLayers) break;
        currentUV -= texelStep;
        currentHeight = texture(heightMap, currentUV).r;
        currentLayer -= layerHeight;
        if (currentHeight > currentLayer) break;   // 射线进入表面下方
    }
    return currentUV;
}

// ---------- 3. 视差遮蔽映射 (POM, Parallax Occlusion Mapping) ----------
// 陡峭视差的插值精修：在最后两步之间线性插值交点。
// 当前主流方案，质量接近置换但只改 UV。
vec2 parallaxOcclusionMapping(vec2 uv, vec3 viewDirTS,
                              sampler2D heightMap, float scale,
                              int layers) {
    float numLayers = mix(float(layers) * 2.0, float(layers),
                          abs(viewDirTS.z));

    float layerHeight = 1.0 / numLayers;
    vec2 texelStep = (viewDirTS.xy / viewDirTS.z) * scale / numLayers;

    float currentLayer = 1.0;
    vec2 currentUV = uv;
    float currentHeight = texture(heightMap, currentUV).r;

    vec2 prevUV = currentUV;                       // 记住上一层的 UV
    float prevHeightDiff = 0.0;

    for (int i = 0; i < 64; i++) {
        if (float(i) >= numLayers) break;
        prevUV = currentUV;
        currentUV -= texelStep;
        currentHeight = texture(heightMap, currentUV).r;
        float prevLayer = currentLayer;
        currentLayer -= layerHeight;

        if (currentHeight > currentLayer) {
            // 穿透了。在 [prev, current] 之间插值精确交点：
            // 两段的"高度差/层高差"比值 = 线性插值系数
            float after = currentHeight - currentLayer;          // 穿透深度
            float before = texture(heightMap, prevUV).r - prevLayer;
            float weight = after / (after - before);             // 0..1
            return mix(currentUV, prevUV, weight);               // 交点 UV
        }
    }
    return currentUV;
}

// ---------- 4. POM 自阴影 (Soft Shadow) ----------
// 从交点向光源方向再 raymarch 一遍：被更高处挡住则在阴影中。
// 同样的步进逻辑，方向换成光的方向。
float pomSelfShadow(vec2 uv, vec3 lightDirTS, sampler2D heightMap,
                    float scale, int layers, float softness) {
    if (lightDirTS.z <= 0.0) return 0.0;           // 背光面

    float numLayers = mix(float(layers) * 2.0, float(layers),
                          abs(lightDirTS.z));
    float layerHeight = 1.0 / numLayers;
    vec2 texelStep = (lightDirTS.xy / lightDirTS.z) * scale / numLayers;

    float shadow = 0.0;
    float currentLayer = texture(heightMap, uv).r; // 起点：当前表面高度
    vec2 currentUV = uv;

    for (int i = 0; i < 32; i++) {
        if (float(i) >= numLayers) break;
        currentUV += texelStep;
        currentLayer += layerHeight;               // 沿光线"爬升"
        float sampled = texture(heightMap, currentUV).r;
        if (sampled < currentLayer) {
            // 光线上方没有遮挡物——累积"可通行程度"（软阴影）
            shadow = max(shadow, (currentLayer - sampled) / softness);
        }
    }
    return clamp(1.0 - shadow, 0.0, 1.0);          // 1=无遮挡
}

// ---------- 5. 完整应用示例 ----------
// 片元着色器中把 POM 应用到法线贴图采样
vec3 applyPORMaterial(sampler2D albedoMap, sampler2D normalMap,
                      sampler2D heightMap, vec2 uv, vec3 viewDirTS,
                      vec3 lightDirTS, float heightScale) {
    // 1) POM 得到偏移后的 UV
    vec2 pomUV = parallaxOcclusionMapping(uv, viewDirTS, heightMap,
                                          heightScale, 32);
    // 出界即丢弃（边缘拉伸防止）
    if (pomUV.x < 0.0 || pomUV.x > 1.0 ||
        pomUV.y < 0.0 || pomUV.y > 1.0) discard;

    // 2) 用偏移后 UV 采样反照率与法线
    vec3 albedo = texture(albedoMap, pomUV).rgb;
    vec3 normalTS = texture(normalMap, pomUV).rgb * 2.0 - 1.0;

    // 3) 自阴影调制光照
    float shadow = pomSelfShadow(pomUV, lightDirTS, heightMap,
                                 heightScale, 16, 0.15);
    float ndl = max(dot(normalTS, lightDirTS), 0.0);
    return albedo * ndl * shadow;
}

// ---------- 6. 性能与质量调优 ----------
// 层数策略：
//   移动端: 8~16 层 + 基础 POM（质量优先用插值精修）
//   主机/PC: 32~64 层
//   极端质量: 用预烘焙的预过滤高度图（POM 的预计算变体）
// 视角自适应已内置（mix by viewDirTS.z）；
// 高度图建议平滑（导数连续），否则步进出现锯齿跳变。
