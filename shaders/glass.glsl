// ============================================================
// 玻璃效果 (Glass) — 透明 + 折射 + 反射 + 色散
// ============================================================

// ---------- 1. 玻璃基础反射+折射 ----------

vec3 glassBase(vec3 viewDir, vec3 normal, float eta,
               samplerCube envMap, float F0) {
    float cosTheta = max(dot(viewDir, normal), 0.0);
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);

    vec3 reflectDir = reflect(-viewDir, normal);
    vec3 refractDir = refract(-viewDir, normal, eta);

    vec3 reflection = texture(envMap, reflectDir).rgb;
    vec3 refraction = texture(envMap, refractDir).rgb;

    return mix(refraction, reflection, fresnel);
}

// ---------- 2. 折射色散 (Chromatic Dispersion) ----------

// 不同波长的光折射率不同，产生 RGB 分离
vec3 dispersionGlass(vec3 viewDir, vec3 normal, float eta,
                     samplerCube envMap, float dispersion) {
    // 红光折射率最小，蓝光最大
    float etaR = eta;
    float etaG = eta * (1.0 + dispersion * 0.5);
    float etaB = eta * (1.0 + dispersion * 1.0);

    vec3 refractR = refract(-viewDir, normal, etaR);
    vec3 refractG = refract(-viewDir, normal, etaG);
    vec3 refractB = refract(-viewDir, normal, etaB);

    float r = texture(envMap, refractR).r;
    float g = texture(envMap, refractG).g;
    float b = texture(envMap, refractB).b;

    return vec3(r, g, b);
}

// ---------- 3. 屏幕空间折射 (Screen Space Refraction) ----------

// 用场景颜色纹理做折射（用于实时渲染）
vec3 screenSpaceRefraction(vec2 uv, vec3 normal, vec3 viewDir,
                           sampler2D sceneTex, vec2 texelSize,
                           float refractionStrength) {
    // 将法线的 xy 分量作为 UV 偏移
    vec2 offset = normal.xy * refractionStrength * texelSize * 100.0;
    return texture(sceneTex, uv + offset).rgb;
}

// ---------- 4. 玻璃粗糙度 (Frosted Glass) ----------

// 粗糙玻璃：用噪声扰动折射方向
vec3 frostedGlass(vec2 uv, vec3 viewDir, vec3 normal,
                  sampler2D sceneTex, sampler2D noiseTex,
                  vec2 texelSize, float roughness) {
    // 噪声扰动
    float n = texture(noiseTex, uv * 5.0).r;
    vec2 offset = (vec2(n) - 0.5) * roughness * 0.1;

    // 法线扰动
    vec3 perturbedNormal = normalize(normal + vec3(offset, 0.0));

    // 折射偏移
    vec2 refractOffset = perturbedNormal.xy * texelSize * 50.0 * roughness;

    return texture(sceneTex, uv + refractOffset).rgb;
}

// ---------- 5. 玻璃吸收 (Beer-Lambert) ----------

// 光在玻璃中传播距离越长，颜色变化越大（如有色玻璃）
vec3 beerLambertAbsorption(vec3 color, float distance, vec3 absorptionCoeff) {
    return color * exp(-absorptionCoeff * distance);
}

// ---------- 6. 雨滴在玻璃上的效果 ----------

// 水滴折射：离散的水滴区域改变折射方向
float waterDroplet(vec2 uv, float time) {
    vec2 grid = floor(uv * 20.0);
    float r = fract(sin(dot(grid, vec2(127.1, 311.7))) * 43758.5453);

    // 水滴下落
    float y = fract(uv.y * 20.0 + time * (0.5 + r) + r);
    float x = fract(uv.x * 20.0 + r);

    vec2 drop = vec2(x, y) - 0.5;
    float dist = length(drop);

    return smoothstep(0.4, 0.2, dist) * step(0.3, r);
}

// ---------- 7. 完整玻璃着色器 ----------

// uniform vec3 cameraPos;
// uniform vec3 worldPos;
// uniform vec3 normal;
// uniform samplerCube envMap;
// uniform sampler2D sceneTex;    // 场景颜色（用于屏幕空间折射）
// uniform sampler2D noiseTex;    // 噪声纹理（用于磨砂玻璃）
// uniform vec2 texelSize;
// uniform float roughness;
// uniform float ior;             // 折射率 (玻璃 ~1.5)
// uniform vec3 tint;             // 玻璃颜色
// uniform float dispersion;      // 色散强度

vec3 renderGlass(vec2 uv, vec3 normal, vec3 viewDir) {
    float eta = 1.0 / ior; // 从空气进入玻璃

    // 1. 菲涅尔
    float F0 = pow((1.0 - ior) / (1.0 + ior), 2.0);
    float cosTheta = max(dot(viewDir, normal), 0.0);
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);

    // 2. 折射（带色散）
    vec3 refraction = dispersionGlass(viewDir, normal, eta, envMap, dispersion);
    // 屏幕空间折射（如果需要看到背景）
    // vec3 refraction = screenSpaceRefraction(uv, normal, viewDir, sceneTex, texelSize, 0.1);

    // 3. 反射
    vec3 reflectDir = reflect(-viewDir, normal);
    vec3 reflection = texture(envMap, reflectDir).rgb;

    // 4. 粗糙度处理（磨砂玻璃）
    if (roughness > 0.01) {
        refraction = frostedGlass(uv, viewDir, normal, sceneTex, noiseTex,
                                   texelSize, roughness);
    }

    // 5. 玻璃着色（Beer-Lambert 吸收）
    refraction = beerLambertAbsorption(refraction, 0.5, tint * 0.5);

    // 6. 合成
    vec3 color = mix(refraction, reflection, fresnel);

    return color;
}
