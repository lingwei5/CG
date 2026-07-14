# Shader 效果总结

本目录收录了 20 个常见游戏/渲染效果的 GLSL 代码，按类别整理如下。

---

## 一、自然环境效果

### 1. clouds.glsl — 云

| 项 | 说明 |
|---|---|
| 核心算法 | 分形布朗运动 (fBm) 多层值噪声叠加 |
| 关键函数 | `fbm()` 多层噪声、`cloudDensity()` 云密度函数 |
| 可调参数 | coverage（云量）、time（流动）、sunDir（光照方向） |
| 光照 | 用噪声梯度近似法线，计算 NdotL |
| 适用场景 | 天空盒/天空球着色 |

### 2. snow.glsl — 雪

| 项 | 说明 |
|---|---|
| 核心算法 | 多层伪随机雪花粒子 + 基于法线的积雪 |
| 关键函数 | `snowParticle()` 飘落粒子、`surfaceSnowAmount()` 表面积雪 |
| 可调参数 | snowIntensity（降雪强度）、snowDir（雪落方向）、speed、size、wind |
| 技术要点 | 3 层不同速度/大小的粒子模拟景深；法线点积判断积雪面 |
| 适用场景 | 雪景全屏特效 + 物体积雪 |

### 3. rain.glsl — 雨

| 项 | 说明 |
|---|---|
| 核心算法 | 细长椭圆雨滴粒子 + 同心圆涟漪 + 湿润表面 |
| 关键函数 | `rainDrop()` 雨滴（含拖尾）、`ripple()` 涟漪、`wetSurface()` 湿润 |
| 可调参数 | rainIntensity（强度）、speed、dropSize、density |
| 技术要点 | 拖尾用运动模糊模拟；涟漪用年龄衰减的环形函数 |
| 适用场景 | 雨天全屏特效 + 地面涟漪 |

### 4. fog.glsl — 雾

| 项 | 说明 |
|---|---|
| 核心算法 | 5 种雾模型：线性、指数、指数平方、高度、体积 |
| 关键函数 | `linearFog()`、`expFog()`、`heightFog()`、`volumetricFog()` |
| 可调参数 | near/far（距离雾范围）、fogHeight、density |
| 技术要点 | 体积雾用 3D 噪声模拟不均匀雾团；高度雾按 y 坐标衰减 |
| 适用场景 | 户外场景大气效果 |

### 5. fire.glsl — 火焰

| 项 | 说明 |
|---|---|
| 核心算法 | fBm 噪声 + 向上滚动 + 形状掩码 |
| 关键函数 | `fireShape()` 火焰形状、`fireColor()` 温度色映射、`heatDistortion()` 热气扭曲 |
| 颜色映射 | 黑→暗红→橙红→黄→白 五段温度梯度 |
| 技术要点 | 噪声随时间向上滚动模拟火焰上升；底部宽顶部窄 |
| 适用场景 | 篝火、火球、爆炸初期 |

### 6. water.glsl — 水面

| 项 | 说明 |
|---|---|
| 核心算法 | Gerstner 波 + 菲涅尔反射/折射 + 焦散 |
| 关键函数 | `gerstnerNormal()` 波法线、`multiWaveNormal()` 多波叠加、`caustics()` 焦散 |
| 可调参数 | F0（水的菲涅尔）、shallowColor/deepColor、波参数 |
| 技术要点 | 3 层 Gerstner 波叠加；焦散用两层正弦波叉乘产生光斑纹理 |
| 适用场景 | 湖面、海面、水池 |

---

## 二、材质效果

### 7. glass.glsl — 玻璃

| 项 | 说明 |
|---|---|
| 核心算法 | 菲涅尔反射/折射 + RGB 色散 + Beer-Lambert 吸收 |
| 关键函数 | `dispersionGlass()` 色散折射、`frostedGlass()` 磨砂玻璃、`beerLambertAbsorption()` 吸收 |
| 可调参数 | ior（折射率）、roughness、tint（颜色）、dispersion（色散强度） |
| 技术要点 | RGB 三通道用不同折射率模拟色散；磨砂玻璃用噪声扰动法线 |
| 适用场景 | 窗户、玻璃瓶、宝石 |

### 8. toon.glsl — 卡通渲染

| 项 | 说明 |
|---|---|
| 核心算法 | 阶梯式离散光照 (Cel Shading) + 半兰伯特 + 硬边高光 |
| 关键函数 | `celShading()` 阶梯化、`halfLambert()` 半兰伯特、`toonOutline()` 描边 |
| 可调参数 | shadeSteps（色阶数）、specThreshold、specShininess |
| 技术要点 | 半兰伯特避免暗部全黑；描边用菲涅尔或几何外扩 |
| 适用场景 | 动漫风格游戏 |

### 9. hologram.glsl — 全息

| 项 | 说明 |
|---|---|
| 核心算法 | 扫描线 + 故障偏移 + 菲涅尔边缘 + 闪烁 + RGB 色差 |
| 关键函数 | `scanlines()`、`glitchOffset()`、`hologramFresnel()`、`flicker()`、`chromaticAberration()` |
| 可调参数 | holoColor（主色）、frequency（扫描线密度）、intensity |
| 技术要点 | 故障用随机时间触发；数据网格叠加增强科技感 |
| 适用场景 | 科幻全息投影、UI 投影 |

### 10. dissolve.glsl — 溶解

| 项 | 说明 |
|---|---|
| 核心算法 | fBm 噪声阈值 + 边缘发光 |
| 关键函数 | `dissolve()` 溶解核心、`dissolveEdgeColor()` 边缘色、`directionalDissolve()` 方向性溶解 |
| 可调参数 | progress（0→1 溶解进度）、edgeWidth、edgeInnerColor/edgeOuterColor |
| 技术要点 | `step(threshold, noise)` 控制可见性；边缘用 `smoothstep` 提取过渡带 |
| 适用场景 | 角色传送、物体出现/消失、烧毁 |

---

## 三、屏幕空间后处理

### 11. bloom.glsl — 泛光

| 项 | 说明 |
|---|---|
| 核心算法 | 亮度提取 → 降采样 Mip 链 → 上采样合成 |
| 关键函数 | `extractBright()` 软阈值提取、`downsample()`/`upsample()` Mip 链、`gaussianBlur9()` 高斯模糊 |
| 可调参数 | threshold（亮度阈值）、softKnee（软拐点）、bloomIntensity |
| 技术要点 | 多级降采样实现大范围模糊；上采样时混合各级 Mip |
| 适用场景 | HDR 渲染管线必备后处理 |

### 12. ssr.glsl — 屏幕空间反射

| 项 | 说明 |
|---|---|
| 核心算法 | 屏幕空间射线步进 + 二分查找精确命中 |
| 关键函数 | `screenSpaceRayMarch()` 射线步进、`binarySearchRefine()` 二分查找、`sampleReflectionColor()` 反射采样 |
| 可调参数 | maxDistance、thickness（厚度）、roughness |
| 技术要点 | 动态步长（越远步长越大）；高粗糙度时多采样模糊；边缘衰减 |
| 局限性 | 只能反射屏幕内可见物体 |
| 适用场景 | 光滑地板反射、湿润表面 |

### 13. ssao.glsl — 屏幕空间环境光遮蔽

| 项 | 说明 |
|---|---|
| 核心算法 | 半球采样核心 + TBN 矩阵 + 深度对比 |
| 关键函数 | `computeSSAO()` 核心算法、`bilateralBlur()` 双边模糊降噪 |
| 可调参数 | radius（采样半径）、bias、kernelSize（采样数） |
| 技术要点 | 用随机向量构建 TBN 矩阵；rangeCheck 避免远处误遮蔽；双边模糊保留边缘 |
| 适用场景 | 室内角落、缝隙遮蔽增强 |

### 14. dof.glsl — 景深

| 项 | 说明 |
|---|---|
| 核心算法 | 弥散圆 (CoC) 计算 + 3 种模糊方式 |
| 关键函数 | `computeCoC()` 弥散圆、`gaussianDoF()` 高斯、`diskDoF()` 圆盘、`bokehDoF()` 散景 |
| 可调参数 | focalDistance（焦距）、focalRange（焦距范围）、bokehStrength |
| 技术要点 | 散景景深用亮度加权，亮像素贡献更大，产生漂亮光斑 |
| 适用场景 | 电影级镜头效果、聚焦强调 |

### 15. motion_blur.glsl — 运动模糊

| 项 | 说明 |
|---|---|
| 核心算法 | 速度缓冲法 + 相机运动推算法 + 径向模糊 |
| 关键函数 | `computeVelocity()` 速度计算、`velocityMotionBlur()` 基于速度、`cameraMotionBlur()` 基于相机、`radialMotionBlur()` 径向 |
| 可调参数 | maxBlurRadius、blurScale、samples |
| 技术要点 | 速度缓冲用当前帧-上一帧 NDC 差；径向模糊用于超速特效 |
| 适用场景 | 快速移动、相机转动、速度感 |

### 16. tonemapping.glsl — 色调映射

| 项 | 说明 |
|---|---|
| 核心算法 | HDR → LDR 的多种映射函数 |
| 关键函数 | `reinhard()`、`ACESFilmic()`（推荐⭐）、`uncharted2()`、`exponentialToneMap()` |
| 其他功能 | 曝光控制 `applyExposure()`、自动曝光 `autoExposure()`、sRGB 转换、LUT 颜色分级 |
| 技术要点 | ACES 对比度好、色彩保持好，是业界标准 |
| 适用场景 | HDR 渲染管线最后一步 |

---

## 四、光照与高亮

### 17. envmap.glsl — 环境贴图

| 项 | 说明 |
|---|---|
| 核心算法 | Cubemap 反射/折射 + 菲涅尔混合 + 球谐光照 |
| 关键函数 | `cubemapReflection()`、`cubemapRefraction()`、`fresnelEnvMap()`、`equirectEnvMap()`、`shIrradiance()`、`parallaxCorrectedReflection()` |
| 技术要点 | Equirectangular 用球面坐标转 UV；球谐用 9 个系数近似漫反射环境光；视差校正使反射位置正确 |
| 适用场景 | 金属反射、玻璃、天空光照 |

### 18. edge_highlight.glsl — 边界高亮

| 项 | 说明 |
|---|---|
| 核心算法 | Sobel 边缘检测 + Fresnel 轮廓 + 几何外扩 |
| 关键函数 | `sobelDepth()`/`sobelNormal()` Sobel 算子、`fresnelEdge()` 菲涅尔边缘、`shellVertex()` 几何外扩 |
| 可调参数 | depthThreshold、normalThreshold、edgeWidth、edgeSoftness |
| 技术要点 | 深度+法线双重检测更鲁棒；几何外扩法描边最稳定 |
| 适用场景 | 物体选中高亮、描边风格 |

### 19. intersection_highlight.glsl — 交界处高亮

| 项 | 说明 |
|---|---|
| 核心算法 | 深度差检测 + SDF 交界检测 + 双深度缓冲对比 |
| 关键函数 | `depthIntersection()` 深度差、`directionalIntersection()` 方向性、`planeIntersection()`/`sphereIntersection()`/`sdfIntersection()` 几何体交界、`dualDepthIntersection()` 双缓冲 |
| 可调参数 | threshold、softness、highlightColor、glowIntensity |
| 技术要点 | 方向性检测避免被遮挡时误高亮；SDF 方式最精确 |
| 适用场景 | 水面与岸边、选中物体与场景、物体接触面 |

### 20. god_rays.glsl — 体积光

| 项 | 说明 |
|---|---|
| 核心算法 | 屏幕空间径向模糊 + 光线步进散射 |
| 关键函数 | `godRaysRadial()` 径向模糊、`godRaysRayMarch()` 光线步进（含阴影）、`simpleVolumetricScatter()` 简化散射 |
| 可调参数 | decay（衰减）、exposure（曝光）、density、steps |
| 技术要点 | 径向模糊从光源位置向外采样；光线步进用相位函数计算前向散射；Beer-Lambert 衰减 |
| 适用场景 | 阳光穿过树叶/云层、聚光灯体积光 |

---

## 快速索引

| 效果 | 文件 | 核心技术 |
|---|---|---|
| 云 | clouds.glsl | fBm 噪声 |
| 雪 | snow.glsl | 粒子 + 法线积雪 |
| 雨 | rain.glsl | 粒子 + 涟漪 |
| 雾 | fog.glsl | 距离/高度/体积 |
| 火 | fire.glsl | 噪声 + 温度色 |
| 水 | water.glsl | Gerstner 波 + 焦散 |
| 玻璃 | glass.glsl | 折射 + 色散 |
| 卡通 | toon.glsl | 阶梯光照 |
| 全息 | hologram.glsl | 扫描线 + 故障 |
| 溶解 | dissolve.glsl | 噪声阈值 |
| 泛光 | bloom.glsl | Mip 链模糊 |
| SSR | ssr.glsl | 射线步进 |
| SSAO | ssao.glsl | 半球采样 |
| 景深 | dof.glsl | CoC + 散景 |
| 运动模糊 | motion_blur.glsl | 速度缓冲 |
| 色调映射 | tonemapping.glsl | ACES |
| 环境贴图 | envmap.glsl | Cubemap + SH |
| 边缘高亮 | edge_highlight.glsl | Sobel + Fresnel |
| 交界高亮 | intersection_highlight.glsl | 深度差 + SDF |
| 体积光 | god_rays.glsl | 径向模糊 + 相位函数 |
