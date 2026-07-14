// ============================================================
// 环境贴图 (Environment Mapping) — 反射 / 折射 / 菲涅尔混合
// ============================================================

// ---------- 1. 立方体贴图反射 (Cubemap Reflection) ----------

// 输入: viewDir (视线方向), normal (法线), envMap (立方体贴图)
vec3 cubemapReflection(vec3 viewDir, vec3 normal, samplerCube envMap) {
    vec3 reflectDir = reflect(-viewDir, normal);
    return texture(envMap, reflectDir).rgb;
}

// ---------- 2. 立方体贴图折射 (Cubemap Refraction) ----------

// 输入: viewDir, normal, eta (折射率比 n1/n2), envMap
vec3 cubemapRefraction(vec3 viewDir, vec3 normal, float eta, samplerCube envMap) {
    vec3 refractDir = refract(-viewDir, normal, eta);
    return texture(envMap, refractDir).rgb;
}

// ---------- 3. 菲涅尔混合反射/折射 ----------

// 用 Schlick 近似在反射和折射之间混合
vec3 fresnelEnvMap(vec3 viewDir, vec3 normal, float F0,
                   samplerCube envMap, float eta) {
    float cosTheta = max(dot(viewDir, normal), 0.0);
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);

    vec3 reflection = cubemapReflection(viewDir, normal, envMap);
    vec3 refraction = cubemapRefraction(viewDir, normal, eta, envMap);

    return mix(refraction, reflection, fresnel);
}

// ---------- 4. 等距矩形投影 (Equirectangular / LatLong) 环境贴图 ----------

// 从方向向量采样 equirectangular 贴图
vec2 directionToEquirectUV(vec3 dir) {
    float phi = atan(dir.z, dir.x);   // [-π, π]
    float theta = acos(dir.y);        // [0, π]
    return vec2(
        0.5 + phi / (2.0 * 3.14159265),
        theta / 3.14159265
    );
}

vec3 equirectEnvMap(vec3 reflectDir, sampler2D envMap) {
    vec2 uv = directionToEquirectUV(reflectDir);
    return texture(envMap, uv).rgb;
}

// ---------- 5. 球谐光照 (Spherical Harmonics) 快速环境光 ----------

// 用 9 个 SH 系数近似漫反射环境光（常用于实时渲染）
// 输入: normal, sh[9] (9个 vec3 系数)
vec3 shIrradiance(vec3 normal, vec3 sh[9]) {
    // SH 基函数（二阶，9 个系数）
    float c0 = 0.282095;  // 1 / (2√π)
    float c1 = 0.488603;  // √(3/π) / 2
    float c2 = 1.092548;  // √(15/π) / 2
    float c3 = 0.315392;  // √(5/π) / 4
    float c4 = 0.546274;  // √(15/π) / 4

    float x = normal.x, y = normal.y, z = normal.z;

    vec3 result = c0 * sh[0]
                + c1 * sh[1] * y
                + c1 * sh[2] * z
                + c1 * sh[3] * x
                + c2 * sh[4] * (x * y)
                + c2 * sh[5] * (y * z)
                + c3 * sh[6] * (3.0 * z * z - 1.0)
                + c2 * sh[7] * (z * x)
                + c4 * sh[8] * (x * x - y * y);

    return max(result, 0.0);
}

// ---------- 6. 视差校正 (Parallax-Corrected) 立方体贴图 ----------

// 将无限远的环境贴图校正到有限包围盒，使反射位置正确
vec3 parallaxCorrectedReflection(vec3 worldPos, vec3 reflectDir,
                                  vec3 boxMin, vec3 boxMax,
                                  samplerCube envMap) {
    // 计算射线与 AABB 的交点
    vec3 invDir = 1.0 / (reflectDir + 0.0001);
    vec3 tMin = (boxMin - worldPos) * invDir;
    vec3 tMax = (boxMax - worldPos) * invDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);

    // 交点位置
    vec3 hitPos = worldPos + reflectDir * tNear;

    // 用交点位置采样（需要将 envMap 的采样方向从交点指向 cubemap 原点）
    vec3 correctedDir = hitPos - vec3(0.0); // cubemap 原点
    return texture(envMap, correctedDir).rgb;
}
