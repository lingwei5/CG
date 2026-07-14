// ============================================================
// 雾效果 (Fog) — 距离雾 / 高度雾 / 体积雾
// ============================================================

// ---------- 1. 线性距离雾 (Linear Fog) ----------

// 输入: distance (到相机的距离), near (雾起始距离), far (雾结束距离)
// 输出: 雾因子 (0=无雾, 1=完全雾)
float linearFog(float distance, float near, float far) {
    return clamp((distance - near) / (far - near), 0.0, 1.0);
}

// ---------- 2. 指数距离雾 (Exponential Fog) ----------

float expFog(float distance, float density) {
    return 1.0 - exp(-distance * density);
}

// ---------- 3. 指数平方雾 (Exponential Squared Fog) ----------

float exp2Fog(float distance, float density) {
    return 1.0 - exp(-distance * distance * density * density);
}

// ---------- 4. 高度雾 (Height Fog) ----------

// 低处雾浓，高处雾淡
// 输入: worldPos (世界坐标), fogHeight (雾顶高度), fogDensity
float heightFog(vec3 worldPos, float fogHeight, float fogDensity) {
    float h = worldPos.y;
    float heightFactor = clamp((fogHeight - h) / fogHeight, 0.0, 1.0);
    return heightFactor * fogDensity;
}

// ---------- 5. 结合距离雾和高度雾 ----------

float combinedFog(float distance, vec3 worldPos, float near, float far,
                  float fogHeight, float heightDensity) {
    float distFog = linearFog(distance, near, far);
    float hFog = heightFog(worldPos, fogHeight, heightDensity);
    return max(distFog, hFog);
}

// ---------- 6. 体积雾 / 噪声雾 (Volumetric Fog) ----------

// 用 3D 噪声模拟不均匀的雾团
float volumetricFog(vec3 worldPos, float time, float density, float scale) {
    // 简化的 3D 噪声（用 2D hash 组合）
    float n1 = hash21(worldPos.xy * scale + time * 0.1);
    float n2 = hash21(worldPos.yz * scale - time * 0.07);
    float n3 = hash21(worldPos.xz * scale + time * 0.05);

    float noise = (n1 + n2 + n3) / 3.0;
    return noise * density;
}

// ---------- 7. 应用雾 ----------

// 输入: color (原始颜色), fogFactor (0~1), fogColor (雾的颜色)
vec3 applyFog(vec3 color, float fogFactor, vec3 fogColor) {
    return mix(color, fogColor, fogFactor);
}

// ---------- 完整雾着色器示例 (fragment shader) ----------

// uniform vec3 fogColor;       // 雾的颜色
// uniform float fogNear;       // 雾起始距离
// uniform float fogFar;        // 雾结束距离
// uniform float fogHeight;     // 高度雾顶
// uniform float heightDensity; // 高度雾密度
// uniform float volumetricDensity; // 体积雾密度
// uniform float iTime;

// 输入: 场景颜色 sceneColor, 世界坐标 worldPos, 到相机距离 dist
vec3 applyAllFog(vec3 sceneColor, vec3 worldPos, float dist) {
    // 距离雾
    float distFog = linearFog(dist, fogNear, fogFar);

    // 高度雾
    float hFog = heightFog(worldPos, fogHeight, heightDensity);

    // 体积雾
    float volFog = volumetricFog(worldPos, iTime, volumetricDensity, 0.5);

    // 合并
    float fogFactor = clamp(distFog + hFog + volFog * 0.3, 0.0, 1.0);

    return applyFog(sceneColor, fogFactor, fogColor);
}
