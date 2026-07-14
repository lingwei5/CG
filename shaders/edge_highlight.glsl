// ============================================================
// 边界高亮 (Edge Highlight / Outline / Silhouette)
// 多种实现方式：深度边缘 / 法线边缘 / 后处理 Sobel / 几何外扩
// ============================================================

// ---------- 1. 基于深度和法线的边缘检测 (后处理) ----------

// 用 Sobel 算子检测深度和法线的不连续性
// 输入: depthTex (深度纹理), normalTex (法线纹理), uv, texelSize

float sobelDepth(sampler2D depthTex, vec2 uv, vec2 texelSize) {
    // Sobel 3x3 核
    float tl = texture(depthTex, uv + vec2(-1, 1) * texelSize).r;
    float t  = texture(depthTex, uv + vec2( 0, 1) * texelSize).r;
    float tr = texture(depthTex, uv + vec2( 1, 1) * texelSize).r;
    float l  = texture(depthTex, uv + vec2(-1, 0) * texelSize).r;
    float r  = texture(depthTex, uv + vec2( 1, 0) * texelSize).r;
    float bl = texture(depthTex, uv + vec2(-1,-1) * texelSize).r;
    float b  = texture(depthTex, uv + vec2( 0,-1) * texelSize).r;
    float br = texture(depthTex, uv + vec2( 1,-1) * texelSize).r;

    float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
    float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;

    return sqrt(gx * gx + gy * gy);
}

float sobelNormal(sampler2D normalTex, vec2 uv, vec2 texelSize) {
    vec3 tl = texture(normalTex, uv + vec2(-1, 1) * texelSize).rgb;
    vec3 t  = texture(normalTex, uv + vec2( 0, 1) * texelSize).rgb;
    vec3 tr = texture(normalTex, uv + vec2( 1, 1) * texelSize).rgb;
    vec3 l  = texture(normalTex, uv + vec2(-1, 0) * texelSize).rgb;
    vec3 r  = texture(normalTex, uv + vec2( 1, 0) * texelSize).rgb;
    vec3 bl = texture(normalTex, uv + vec2(-1,-1) * texelSize).rgb;
    vec3 b  = texture(normalTex, uv + vec2( 0,-1) * texelSize).rgb;
    vec3 br = texture(normalTex, uv + vec2( 1,-1) * texelSize).rgb;

    vec3 gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
    vec3 gy = -tl - 2.0*t - tr + bl + 2.0*b + br;

    return length(gx) + length(gy);
}

// 综合深度和法线边缘
float detectEdge(sampler2D depthTex, sampler2D normalTex,
                 vec2 uv, vec2 texelSize,
                 float depthThreshold, float normalThreshold) {
    float depthEdge = sobelDepth(depthTex, uv, texelSize);
    float normalEdge = sobelNormal(normalTex, uv, texelSize);

    float edge = 0.0;
    if (depthEdge > depthThreshold) edge = 1.0;
    if (normalEdge > normalThreshold) edge = 1.0;

    return edge;
}

// ---------- 2. 基于视角的轮廓线 (Fresnel Edge) ----------

// 在物体着色器中直接计算：视角与法线夹角大 → 边缘
float fresnelEdge(vec3 viewDir, vec3 normal, float edgeWidth, float edgeSoftness) {
    float NdotV = abs(dot(normalize(normal), normalize(viewDir)));
    return 1.0 - smoothstep(edgeWidth, edgeWidth + edgeSoftness, NdotV);
}

// ---------- 3. 几何外扩轮廓 (Inverted Hull / Shell Method) ----------

// 在 vertex shader 中沿法线外扩顶点（需要第二个 pass）
// vertex shader:
vec4 shellVertex(vec4 vertex, vec3 normal, float outlineWidth) {
    return vertex + vec4(normal * outlineWidth, 0.0);
}

// fragment shader: 纯色输出
// gl_FragColor = outlineColor;

// ---------- 4. 后处理边缘高亮 ----------

// 输入: sceneColor (场景颜色), edge (边缘强度 0~1), edgeColor (边缘颜色)
vec3 applyEdgeHighlight(vec3 sceneColor, float edge, vec3 edgeColor) {
    return mix(sceneColor, edgeColor, edge);
}

// ---------- 完整后处理边缘检测示例 ----------

// uniform sampler2D sceneTex;
// uniform sampler2D depthTex;
// uniform sampler2D normalTex;
// uniform vec2 texelSize;
// uniform float depthThreshold;
// uniform float normalThreshold;
// uniform vec3 edgeColor;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 sceneColor = texture(sceneTex, uv).rgb;
    float edge = detectEdge(depthTex, normalTex, uv, texelSize,
                            depthThreshold, normalThreshold);

    vec3 color = applyEdgeHighlight(sceneColor, edge, edgeColor);
    fragColor = vec4(color, 1.0);
}
