// ============================================================
// 屏幕空间环境光遮蔽 (SSAO)
// 基于深度缓冲在屏幕空间近似全局光照中的环境遮蔽
// ============================================================

// ---------- 1. 重建视角空间坐标 ----------

vec3 reconstructViewPos(vec2 uv, float depth, mat4 invProj) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = invProj * clipPos;
    return viewPos.xyz / viewPos.w;
}

// ---------- 2. 采样核心 (Kernel) ----------

// 生成半球采样方向（需要预计算的采样核心）
// 实际中通常在 CPU 预生成并传入 uniform 数组
vec3 sampleKernel[16]; // 预计算的半球采样点

void initKernel() {
    // 初始化 16 个半球采样点（实际中从 CPU 传入）
    sampleKernel[0]  = vec3(0.1, 0.0, 0.0);
    sampleKernel[1]  = vec3(-0.1, 0.1, 0.1);
    // ... (实际使用时填充完整)
}

// ---------- 3. SSAO 核心算法 ----------

// 输入: uv, depthTex, normalTex, invProjMat, projMat,
//       kernelSize (采样数), radius (采样半径), bias
// 输出: 遮蔽因子 (0=完全遮蔽, 1=无遮蔽)
float computeSSAO(vec2 uv, sampler2D depthTex, sampler2D normalTex,
                   mat4 invProjMat, mat4 projMat, vec2 texelSize,
                   int kernelSize, float radius, float bias) {
    // 当前像素的深度和法线
    float depth = texture(depthTex, uv).r;
    vec3 normal = texture(normalTex, uv).rgb * 2.0 - 1.0;
    vec3 fragPos = reconstructViewPos(uv, depth, invProjMat);

    // 构建 TBN 矩阵（使采样在法线方向的半球内）
    vec3 randomVec = vec3(
        fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453),
        fract(sin(dot(uv, vec2(39.346, 11.135))) * 43758.5453),
        0.0
    );
    vec3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bitangent, normal);

    // 遮蔽累积
    float occlusion = 0.0;

    for (int i = 0; i < 64; i++) {
        if (i >= kernelSize) break;

        // 采样点（从切线空间转换到视角空间）
        vec3 samplePos = TBN * sampleKernel[i];
        samplePos = fragPos + samplePos * radius;

        // 投影到屏幕空间
        vec4 offset = projMat * vec4(samplePos, 1.0);
        offset.xyz /= offset.w;
        vec2 sampleUV = offset.xy * 0.5 + 0.5;

        // 采样深度
        float sampleDepth = texture(depthTex, sampleUV).r;
        vec3 sampleViewPos = reconstructViewPos(sampleUV, sampleDepth, invProjMat);

        // 遮蔽检测：采样点的深度 < 实际深度 → 被遮蔽
        float zDiff = fragPos.z - sampleViewPos.z;
        if (zDiff > bias) {
            // 平滑过渡（避免硬边）
            float rangeCheck = smoothstep(0.0, 1.0, radius / abs(zDiff));
            occlusion += rangeCheck;
        }
    }

    occlusion = 1.0 - occlusion / float(kernelSize);
    return occlusion;
}

// ---------- 4. SSAO 模糊 (降噪) ----------

// 双边模糊：在模糊的同时保留边缘（用深度和法线作为权重）
vec3 bilateralBlur(sampler2D ssaoTex, vec2 uv, vec2 texelSize,
                   sampler2D depthTex, sampler2D normalTex) {
    vec3 result = vec3(0.0);
    float totalWeight = 0.0;

    float centerDepth = texture(depthTex, uv).r;
    vec3 centerNormal = texture(normalTex, uv).rgb;

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(x, y) * texelSize;
            vec2 sampleUV = uv + offset;

            float sampleDepth = texture(depthTex, sampleUV).r;
            vec3 sampleNormal = texture(normalTex, sampleUV).rgb;

            // 深度权重（深度差异大 → 权重低）
            float depthWeight = exp(-abs(centerDepth - sampleDepth) * 100.0);
            // 法线权重（法线差异大 → 权重低）
            float normalWeight = pow(max(dot(centerNormal, sampleNormal), 0.0), 8.0);

            float weight = depthWeight * normalWeight;
            result += texture(ssaoTex, sampleUV).rgb * weight;
            totalWeight += weight;
        }
    }

    return result / max(totalWeight, 0.0001);
}

// ---------- 5. 应用 SSAO ----------

vec3 applySSAO(vec3 sceneColor, float occlusion) {
    return sceneColor * occlusion;
}

// ---------- 6. 完整 SSAO 流程 ----------

// Pass 1: 计算 SSAO → ssaoTex (R 通道存储遮蔽因子)
// Pass 2: 双边模糊 → ssaoBlurredTex
// Pass 3: 合成 → sceneColor * occlusion

// uniform sampler2D depthTex;
// uniform sampler2D normalTex;
// uniform mat4 invProjMat;
// uniform mat4 projMat;
// uniform vec2 texelSize;
// uniform float ssaoRadius;
// uniform float ssaoBias;
// uniform int kernelSize;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    float occlusion = computeSSAO(uv, depthTex, normalTex,
                                    invProjMat, projMat, texelSize,
                                    kernelSize, ssaoRadius, ssaoBias);

    fragColor = vec4(vec3(occlusion), 1.0);
}
