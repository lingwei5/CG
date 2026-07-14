// ============================================================
// 物体交界处高亮 (Intersection Highlight)
// 两个物体相交/接触的区域产生高亮效果
// 常用于：水面与岸边、物体与地面、选中物体与场景
// ============================================================

// ---------- 1. 基于深度的交界检测 (后处理) ----------

// 比较当前像素深度与场景深度，接近时高亮
// 适用于：选中物体与场景其他物体的交界

float depthIntersection(float currentDepth, float sceneDepth,
                        float threshold, float softness) {
    float diff = abs(currentDepth - sceneDepth);
    return 1.0 - smoothstep(threshold, threshold + softness, diff);
}

// ---------- 2. 基于深度差的方向性交界 ----------

// 不仅检测深度接近，还要求当前物体在前面（避免被遮挡时也高亮）
float directionalIntersection(float currentDepth, float sceneDepth,
                               float threshold, float softness) {
    float diff = currentDepth - sceneDepth; // 正=在前面, 负=在后面
    // 只在当前物体在前面且深度接近时高亮
    float near = 1.0 - smoothstep(0.0, softness, diff);
    float close = 1.0 - smoothstep(threshold, threshold + softness, abs(diff));
    return near * close;
}

// ---------- 3. 基于世界空间距离的交界检测 ----------

// 在物体着色器中，用世界坐标计算到另一个物体表面的距离
// 需要传入另一个物体的 SDF 或深度信息

// 简单平面交界（如物体与地面的接触面）
float planeIntersection(vec3 worldPos, vec4 plane, float threshold, float softness) {
    // plane: vec4(normal.xyz, distance)
    float dist = dot(worldPos, plane.xyz) - plane.w;
    return 1.0 - smoothstep(threshold, threshold + softness, abs(dist));
}

// ---------- 4. 球体交界 ----------

float sphereIntersection(vec3 worldPos, vec3 sphereCenter, float sphereRadius,
                          float threshold, float softness) {
    float dist = length(worldPos - sphereCenter) - sphereRadius;
    return 1.0 - smoothstep(threshold, threshold + softness, abs(dist));
}

// ---------- 5. 通用 SDF 交界 ----------

// 用有符号距离函数 (SDF) 检测两个物体的交界
float sdfIntersection(float sdfA, float sdfB, float threshold, float softness) {
    // 两个 SDF 都接近 0 → 在交界处
    float nearA = 1.0 - smoothstep(threshold, threshold + softness, abs(sdfA));
    float nearB = 1.0 - smoothstep(threshold, threshold + softness, abs(sdfB));
    return nearA * nearB;
}

// ---------- 6. 后处理：用两个深度缓冲的交界 ----------

// 分别渲染两个物体到不同的深度纹理，然后比较
float dualDepthIntersection(sampler2D depthTexA, sampler2D depthTexB,
                             vec2 uv, float threshold, float softness) {
    float depthA = texture(depthTexA, uv).r;
    float depthB = texture(depthTexB, uv).r;

    // 两个深度都有效（非背景）且接近
    float validA = step(0.0, depthA) * step(depthA, 0.999);
    float validB = step(0.0, depthB) * step(depthB, 0.999);

    float diff = abs(depthA - depthB);
    float close = 1.0 - smoothstep(threshold, threshold + softness, diff);

    return validA * validB * close;
}

// ---------- 7. 交界高亮着色 ----------

// 输入: baseColor (基础颜色), intersection (交界强度 0~1),
//       highlightColor (高亮颜色), glowIntensity (发光强度)
vec3 applyIntersectionHighlight(vec3 baseColor, float intersection,
                                 vec3 highlightColor, float glowIntensity) {
    // 加法混合：交界处叠加高亮
    vec3 glow = highlightColor * intersection * glowIntensity;
    return baseColor + glow;
}

// 替代方案：完全替换为高亮色
vec3 replaceIntersectionHighlight(vec3 baseColor, float intersection,
                                   vec3 highlightColor) {
    return mix(baseColor, highlightColor, intersection);
}

// ---------- 完整交界高亮示例 (fragment shader) ----------

// uniform sampler2D sceneDepthTex;  // 场景深度
// uniform float currentDepth;        // 当前物体的深度
// uniform float intersectionThreshold;
// uniform float intersectionSoftness;
// uniform vec3 highlightColor;
// uniform float glowIntensity;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 baseColor = texture(sceneTex, uv).rgb;
    float sceneDepth = texture(sceneDepthTex, uv).r;

    // 检测交界
    float intersection = depthIntersection(currentDepth, sceneDepth,
                                            intersectionThreshold,
                                            intersectionSoftness);

    // 应用高亮
    vec3 color = applyIntersectionHighlight(baseColor, intersection,
                                             highlightColor, glowIntensity);

    fragColor = vec4(color, 1.0);
}
