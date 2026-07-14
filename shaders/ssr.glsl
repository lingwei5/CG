// ============================================================
// 屏幕空间反射 (SSR - Screen Space Reflection)
// 基于深度缓冲的射线步进反射
// ============================================================

// ---------- 1. 重建世界/视角空间坐标 ----------

vec3 reconstructViewPos(vec2 uv, float depth, mat4 invProj) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = invProj * clipPos;
    return viewPos.xyz / viewPos.w;
}

// ---------- 2. 射线步进 (Ray Marching) ----------

// 输入: viewPos (视角空间坐标), viewDir (视角方向),
//       reflectDir (反射方向), depthTex, projMat
// 输出: hitUV (命中 UV), hit (是否命中)
struct SSRResult {
    vec2 hitUV;
    bool hit;
    float steps;
};

SSRResult screenSpaceRayMarch(vec3 viewPos, vec3 reflectDir,
                               sampler2D depthTex, mat4 projMat,
                               vec2 texelSize, int maxSteps,
                               float maxDistance, float thickness) {
    SSRResult result;
    result.hit = false;
    result.hitUV = vec2(0.0);
    result.steps = 0.0;

    vec3 rayPos = viewPos;
    vec3 rayDir = reflectDir;

    float stepSize = maxDistance / float(maxSteps);

    for (int i = 0; i < 256; i++) {
        if (i >= maxSteps) break;

        rayPos += rayDir * stepSize;
        result.steps = float(i);

        // 投影到屏幕空间
        vec4 clipPos = projMat * vec4(rayPos, 1.0);
        vec3 ndcPos = clipPos.xyz / clipPos.w;
        vec2 screenUV = ndcPos.xy * 0.5 + 0.5;

        // 超出屏幕
        if (screenUV.x < 0.0 || screenUV.x > 1.0 ||
            screenUV.y < 0.0 || screenUV.y > 1.0) {
            break;
        }

        // 采样深度
        float sampledDepth = texture(depthTex, screenUV).r;
        sampledDepth = sampledDepth * 2.0 - 1.0; // NDC

        float rayDepth = ndcPos.z;
        float depthDiff = rayDepth - sampledDepth;

        // 命中检测：射线深度 > 场景深度（在表面后面），且差距在厚度内
        if (depthDiff > 0.0 && depthDiff < thickness) {
            result.hit = true;
            result.hitUV = screenUV;
            break;
        }

        // 动态步长：越远步长越大
        stepSize *= 1.1;
    }

    return result;
}

// ---------- 3. 二分查找精确命中 ----------

vec2 binarySearchRefine(vec3 rayPos, vec3 rayDir, float stepSize,
                         sampler2D depthTex, mat4 projMat, int iterations) {
    for (int i = 0; i < 8; i++) {
        if (i >= iterations) break;

        vec4 clipPos = projMat * vec4(rayPos, 1.0);
        vec3 ndcPos = clipPos.xyz / clipPos.w;
        vec2 screenUV = ndcPos.xy * 0.5 + 0.5;

        float sampledDepth = texture(depthTex, screenUV).r * 2.0 - 1.0;
        float depthDiff = ndcPos.z - sampledDepth;

        stepSize *= 0.5;
        if (depthDiff > 0.0) {
            rayPos -= rayDir * stepSize;
        } else {
            rayPos += rayDir * stepSize;
        }
    }

    vec4 clipPos = projMat * vec4(rayPos, 1.0);
    return (clipPos.xy / clipPos.w) * 0.5 + 0.5;
}

// ---------- 4. 反射颜色采样 ----------

vec3 sampleReflectionColor(sampler2D sceneTex, vec2 uv, float roughness,
                            sampler2D normalTex, vec2 texelSize) {
    if (roughness > 0.8) {
        // 高粗糙度：多采样模糊
        vec3 color = vec3(0.0);
        float total = 0.0;
        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                vec2 offset = vec2(x, y) * texelSize * (1.0 + roughness * 3.0);
                float w = 1.0 / (1.0 + length(vec2(x, y)));
                color += texture(sceneTex, uv + offset).rgb * w;
                total += w;
            }
        }
        return color / total;
    } else {
        return texture(sceneTex, uv).rgb;
    }
}

// ---------- 5. 边缘衰减 ----------

float edgeFade(vec2 uv, float fadeStart) {
    vec2 d = abs(uv - 0.5) * 2.0;
    float fadeX = smoothstep(1.0, fadeStart, d.x);
    float fadeY = smoothstep(1.0, fadeStart, d.y);
    return fadeX * fadeY;
}

// ---------- 6. 完整 SSR 着色器 ----------

// uniform sampler2D sceneTex;     // 场景颜色
// uniform sampler2D depthTex;     // 深度缓冲
// uniform sampler2D normalTex;    // 法线缓冲
// uniform mat4 projMat;
// uniform mat4 invProjMat;
// uniform vec2 texelSize;
// uniform float maxDistance;
// uniform float thickness;
// uniform float roughness;
// uniform vec3 cameraPos;

vec3 renderSSR(vec2 uv, vec3 viewDir, vec3 normal, vec3 baseColor) {
    // 1. 重建视角空间位置
    float depth = texture(depthTex, uv).r;
    vec3 viewPos = reconstructViewPos(uv, depth, invProjMat);

    // 2. 反射方向
    vec3 reflectDir = reflect(-viewDir, normal);

    // 3. 射线步进
    SSRResult ssr = screenSpaceRayMarch(viewPos, reflectDir, depthTex,
                                         projMat, texelSize, 64,
                                         maxDistance, thickness);

    // 4. 采样反射颜色
    vec3 reflection = vec3(0.0);
    if (ssr.hit) {
        reflection = sampleReflectionColor(sceneTex, ssr.hitUV, roughness,
                                            normalTex, texelSize);
        // 边缘衰减
        reflection *= edgeFade(ssr.hitUV, 0.9);
    }

    // 5. 菲涅尔
    float F0 = 0.04;
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - max(dot(viewDir, normal), 0.0), 5.0);

    // 6. 粗糙度衰减（高粗糙度反射弱）
    float roughnessFactor = 1.0 - roughness;

    // 7. 合成
    vec3 color = mix(baseColor, reflection, fresnel * roughnessFactor * float(ssr.hit));

    return color;
}
