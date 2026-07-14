// ============================================================
// 卡通渲染 (Toon / Cel Shading) — 离散光照 + 描边
// ============================================================

// ---------- 1. 阶梯式光照 (Cel Shading) ----------

// 将连续的 NdotL 离散化为几个阶梯
float celShading(float NdotL, float steps) {
    return floor(NdotL * steps) / steps;
}

// 带平滑过渡的阶梯光照
float celShadingSmooth(float NdotL, float steps, float smoothWidth) {
    float stepped = floor(NdotL * steps) / steps;
    float smoothTransition = smoothstep(0.0, smoothWidth, fract(NdotL * steps));
    return stepped + smoothTransition / steps;
}

// ---------- 2. 高光阶梯 ----------

float celSpecular(float spec, float threshold) {
    return step(threshold, spec);
}

// ---------- 3. 半兰伯特 (Half-Lambert) ----------

// 让暗部也有渐变，避免完全黑
float halfLambert(vec3 normal, vec3 lightDir) {
    return dot(normal, lightDir) * 0.5 + 0.5;
}

// ---------- 4. 卡通色调映射 ----------

vec3 toonShading(vec3 baseColor, vec3 normal, vec3 lightDir,
                 vec3 ambientColor, int shadeSteps) {
    // 半兰伯特
    float NdotL = halfLambert(normal, lightDir);

    // 阶梯化
    float shade = celShading(NdotL, float(shadeSteps));

    // 明暗色调
    vec3 darkColor = baseColor * 0.5;
    vec3 brightColor = baseColor;

    vec3 color = mix(darkColor, brightColor, shade);

    // 环境光
    color += ambientColor * baseColor * 0.3;

    return color;
}

// ---------- 5. 卡通高光 ----------

vec3 toonSpecular(vec3 normal, vec3 viewDir, vec3 lightDir,
                  vec3 specColor, float threshold, float shininess) {
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfDir), 0.0);
    float spec = pow(NdotH, shininess);

    // 阶梯化高光
    spec = celSpecular(spec, threshold);

    return specColor * spec;
}

// ---------- 6. 描边 (法线外扩法) ----------

// vertex shader 中:
// vec4 outlineVertex(vec4 vertex, vec3 normal, float outlineWidth) {
//     return vertex + vec4(normal * outlineWidth, 0.0);
// }
// fragment shader 中输出纯黑色

// ---------- 7. 基于视角的边缘描边 (后处理描边) ----------

float toonOutline(vec3 normal, vec3 viewDir, float threshold, float softness) {
    float NdotV = abs(dot(normal, viewDir));
    return 1.0 - smoothstep(threshold, threshold + softness, NdotV);
}

// ---------- 8. 完整卡通着色器 ----------

// uniform vec3 lightDir;
// uniform vec3 viewDir;
// uniform vec3 baseColor;
// uniform vec3 ambientColor;
// uniform vec3 specColor;
// uniform int shadeSteps;     // 色阶数，通常 3~5
// uniform float specThreshold; // 高光阈值
// uniform float specShininess;

vec3 renderToon(vec3 normal, vec3 viewDir, vec3 lightDir, vec3 baseColor) {
    // 1. 漫反射（阶梯式）
    vec3 diffuse = toonShading(baseColor, normal, lightDir,
                                vec3(0.3), 4);

    // 2. 高光（硬边）
    vec3 specular = toonSpecular(normal, viewDir, lightDir,
                                  vec3(1.0), 0.5, 64.0);

    // 3. 边缘描边
    float outline = toonOutline(normal, viewDir, 0.2, 0.1);
    vec3 color = mix(diffuse + specular, vec3(0.0), outline);

    return color;
}

// ---------- 9. 渐变贴图 (Ramp Texture) 方式 ----------

// 用一张 1D 渐变贴图替代离散阶梯，效果更柔和
vec3 rampShading(vec3 baseColor, vec3 normal, vec3 lightDir,
                 sampler2D rampTex) {
    float NdotL = dot(normal, lightDir) * 0.5 + 0.5;
    vec3 ramp = texture(rampTex, vec2(NdotL, 0.5)).rgb;
    return baseColor * ramp;
}
