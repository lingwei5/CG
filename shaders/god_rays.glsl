// ============================================================
// 体积光 / 上帝之光 (Volumetric Light / God Rays)
// 屏幕空间径向模糊方式 + 光线步进方式
// ============================================================

// ---------- 1. 屏幕空间径向模糊 (后处理方式) ----------

// 从光源位置向外径向采样，模拟光线散射
// 输入: sceneTex (场景纹理), lightScreenPos (光源屏幕坐标),
//       uv, samples (采样数), decay (衰减), exposure (曝光)
vec3 godRaysRadial(sampler2D sceneTex, vec2 lightScreenPos,
                   vec2 uv, int samples, float decay, float exposure,
                   vec2 texelSize) {
    vec2 deltaUV = (uv - lightScreenPos);
    deltaUV *= 1.0 / float(samples) * exposure;

    vec3 color = texture(sceneTex, uv).rgb;
    float illumination = 1.0;

    for (int i = 0; i < 128; i++) {
        if (i >= samples) break;
        uv -= deltaUV;
        vec3 sampleColor = texture(sceneTex, uv).rgb;
        sampleColor *= illumination * decay;
        color += sampleColor;
        illumination *= decay;
    }

    return color;
}

// ---------- 2. 光线步进体积光 (Ray Marching) ----------

// 沿视线方向步进，计算光在均匀介质中的散射
// 输入: worldPos (世界坐标), cameraPos, lightPos,
//       shadowMap (阴影贴图用于遮挡), time
vec3 godRaysRayMarch(vec3 worldPos, vec3 cameraPos, vec3 lightPos,
                     sampler2DShadow shadowMap, int steps) {
    vec3 viewDir = worldPos - cameraPos;
    float distance = length(viewDir);
    viewDir = viewDir / distance;

    vec3 lightDir = normalize(lightPos - cameraPos);
    float stepSize = distance / float(steps);

    vec3 scatteredLight = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < 64; i++) {
        if (i >= steps) break;
        float t = stepSize * float(i);
        vec3 samplePos = cameraPos + viewDir * t;

        // 阴影测试
        vec4 lightClipPos = lightViewProj * vec4(samplePos, 1.0);
        float shadow = textureProj(shadowMap, lightClipPos);

        // 相位函数（前向散射）
        float cosTheta = dot(viewDir, lightDir);
        float phase = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5);
        // g: 相位参数，-1~1，正值前向散射

        // Beer-Lambert 衰减
        float density = 0.01; // 介质密度
        float extinction = exp(-density * stepSize);

        scatteredLight += lightColor * shadow * phase * transmittance * stepSize;
        transmittance *= extinction;
    }

    return scatteredLight;
}

// ---------- 3. 简化的体积雾散射 ----------

// 仅考虑均匀雾介质中的散射，不需要阴影贴图
vec3 simpleVolumetricScatter(vec3 cameraPos, vec3 worldPos,
                              vec3 lightPos, vec3 lightColor,
                              float density, int steps) {
    vec3 viewDir = worldPos - cameraPos;
    float distance = length(viewDir);
    viewDir /= distance;

    vec3 lightDir = normalize(lightPos - cameraPos);
    float stepSize = distance / float(steps);

    vec3 result = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < 32; i++) {
        if (i >= steps) break;
        float t = stepSize * (float(i) + 0.5);
        vec3 samplePos = cameraPos + viewDir * t;

        // 距离光源越近，散射越强
        float distToLight = length(lightPos - samplePos);
        float lightFalloff = 1.0 / (distToLight * distToLight + 1.0);

        // 前向散射相位
        float cosTheta = dot(viewDir, lightDir);
        float phase = 0.5 + 0.5 * cosTheta; // 简化的瑞利相位

        result += lightColor * lightFalloff * phase * transmittance * stepSize * density;
        transmittance *= exp(-density * stepSize);
    }

    return result;
}

// ---------- 4. 完整体积光后处理 ----------

// uniform sampler2D sceneTex;
// uniform vec2 lightScreenPos; // 光源在屏幕空间的位置
// uniform float decay;
// uniform float exposure;
// uniform vec2 texelSize;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 sceneColor = texture(sceneTex, uv).rgb;

    // 径向模糊体积光
    vec3 godRays = godRaysRadial(sceneTex, lightScreenPos, uv,
                                  64, 0.95, 1.0, texelSize);

    // 提取亮度（只保留亮的部分）
    godRays = max(godRays - sceneColor, 0.0);

    // 合成
    vec3 color = sceneColor + godRays * 0.5;

    fragColor = vec4(color, 1.0);
}
