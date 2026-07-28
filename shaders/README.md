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


# PBRT PBR 展示 Shader 分析

> 来源：ShaderToy 上的交互式 PBR 教学工具，使用 GLSL 实现完整的基于物理的渲染流程，并支持实时交互调节参数查看各项 BRDF 分量。

## 一、整体架构

采用 ShaderToy 经典的**双通道结构**：

| 通道 | 文件 | 职责 |
|------|------|------|
| **Buffer A** | [pbr_show_BufferA.glsl](./pbr_show_BufferA.glsl) | 控制通道：处理鼠标输入、维护 UI 状态（菜单/滑块/旋转），把状态写入纹理像素 |
| **Image** | [pbr_show_Image.glsl](./pbr_show_Image.glsl) | 渲染通道：读取状态、SDF 光线步进、PBR 光照、UI 绘制 |

两者通过 `iChannel0`（Buffer A 的输出纹理）传递状态，使用 `texelFetch(iChannel0, ivec2(x,y), 0)` 在固定像素位置读写状态。

## 二、状态管理（Buffer A）

[pbr_show_BufferA.glsl#L84-L140](./pbr_show_BufferA.glsl#L84-L140) 中的 `mainImage`：

- **仅在左上角 8×8 像素区域写入状态**（`fragCoord.x >= 8. || fragCoord.y >= 8.` 时 `discard`），把整张纹理的左上角当作"寄存器"使用。
- `AppState` 结构包含 7 个 float：menuId / metal / roughness / baseColor / focus / focusObjRot / objRot。
- 通过 `StoreValue(vec2(0,0), ...)` 和 `StoreValue(vec2(1,0), ...)` 把状态写到 (0,0) 和 (1,0) 两个像素中（每像素 vec4 = 4 个 float）。
- 鼠标交互判定：滑块、颜色选择、金属/非金属切换、物体拖拽旋转。
- `iFrame >= 1 ? ret : vec4(0.)` 保证第一帧初始化为默认状态。

## 三、场景建模（SDF）

[pbr_show_Image.glsl#L376-L419](./pbr_show_Image.glsl#L376-L419) 使用符号距离函数（SDF）建模一个抽象雕像：

```
Scene(p) = Union(ring, body)
  ring = Disc - Cylinder - Box(旋转45°切口) + Disc装饰
  body = Sphere - Sphere(前凹) - Sphere(后凹) - Box(横向切割) + Sphere(主体)
```

- 使用 CSG 运算：`Substract`（差集）、`Union`（并集）、`SubstractRound`（圆角差集）。
- `localToWorld` 矩阵由 `rotY * rotZ` 组成，支持物体随鼠标横向拖拽旋转 + 自动 Y 轴自转。
- `CastRay` 采用 50 步光线步进，`SceneNormal` 用中心差分估法线，`SceneAO` 用 6 段步进估环境光遮蔽。

## 四、PBR 核心实现

这是整个 shader 的精华，[pbr_show_Image.glsl#L626-L688](./pbr_show_Image.glsl#L626-L688) 实现了完整的 **Cook-Torrance BRDF**：

### 1. 参数准备

```glsl
vec3 baseColor    = pow(BASE_COLORS[...], vec3(2.2));   // sRGB → 线性
vec3 diffuseColor = s.metal==1. ? vec3(0.) : baseColor; // 金属无漫反射
vec3 specularColor= s.metal==1. ? baseColor : vec3(0.02); // 非金属 F0=0.02
float roughnessE  = s.roughness * s.roughness;          // Disney 映射
float roughnessL  = max(.01, roughnessE);               // 光照项使用
```

### 2. Cook-Torrance 三大项

[pbr_show_Image.glsl#L308-L331](./pbr_show_Image.glsl#L308-L331)：

| 项 | 函数 | 公式 |
|----|------|------|
| **D 法线分布 (GGX)** | `DistributionTerm` | `r² / [π·((N·H)²·(r²-1)+1)²]` |
| **G 几何遮蔽 (Smith GGX)** | `VisibilityTerm` | `0.5 / [N·L·√((N·V)²-(N·V)²r²+r²) + N·V·√((N·L)²-(N·L)²r²+r²)]` |
| **F 菲涅尔 (Schlick)** | `FresnelTerm` | `F0 + (1-F0)·(1-V·H)⁵` |

注意 `VisibilityTerm` 返回的是 **G/(4·N·V·N·L)** 形式（即 V = G/(4 NdotV NdotL)），所以最终镜面反射项为：

```glsl
specular += lightColor * F * (D * V * π * NdotL);
```

其中 `π` 用于平衡 D 项里的 `1/π`，最终符合能量守恒。

### 3. 环境光照（IBL）

[pbr_show_Image.glsl#L649-L655](./pbr_show_Image.glsl#L649-L655) 实现了**近似 IBL（Image-Based Lighting）**：

```glsl
vec3 env1 = EnvRemap(texture(iChannel2, refl).xyz);  // 高分辨率环境贴图（光滑）
vec3 env2 = EnvRemap(texture(iChannel1, refl).xyz);  // 低分辨率环境贴图（粗糙）
vec3 env3 = EnvRemap(SHIrradiance(refl));            // 球谐近似（超粗糙）
vec3 env  = mix(env1, env2, roughnessE*4.);          // 粗糙度混合
env       = mix(env, env3, (roughnessE-0.25)/0.75);  // 极粗糙切到 SH
```

- 用两张贴图 + 球谐三档混合近似 prefiltered environment map。
- `EnvBRDFApprox`（[pbr_show_Image.glsl#L602-L612](./pbr_show_Image.glsl#L602-L612)）采用 Unreal Engine 4 移动端方案近似 BRDF LUT，输出 `(scale, bias)` 给 `specularColor * AB.x + AB.y`。
- 球谐系数 `SH_STPETER`（[pbr_show_Image.glsl#L541-L553](./pbr_show_Image.glsl#L541-L553)）取自圣彼得大教堂的真实光照探测数据，参考 iq 的 [lt2GRD](https://www.shadertoy.com/view/lt2GRD)。

### 4. 最终合成

```glsl
diffuse  *= ao;
specular *= saturate(pow(ndotv+ao, roughnessE) - 1. + ao);  // AO 衰减 specular
color = diffuse + specular;
color = pow(color * .4, vec3(1./2.2));                       // 曝光 + 线性→sRGB
```

## 五、可视化模式（教学亮点）

[pbr_show_Image.glsl#L672-L686](./pbr_show_Image.glsl#L672-L686) 通过 `menuId` 切换显示不同分量，是核心教学功能：

| menuId | 显示内容 | 对应章节 |
|--------|---------|---------|
| `MENU_SURFACE` (0) | 完整 PBR 结果 | — |
| `MENU_DIFFUSE` (6) | 仅漫反射项 | 漫反射 |
| `MENU_SPECULAR` (7) | 仅镜面项 | 高光 |
| `MENU_DISTR` (8) | D 项（法线分布） | NDF |
| `MENU_FRESNEL` (9) | F 项（菲涅尔/envBRDF approx） | Fresnel |
| `MENU_GEOMETRY` (10) | G 项（乘以 4·NdotV·NdotL 还原原始 G） | Geometry |

这种"逐项可视化"是该 shader 最大的教学价值，可直接对应 PBRT 第 8 章 BRDF 模型。

## 六、UI 绘制

[pbr_show_Image.glsl#L115-L260](./pbr_show_Image.glsl#L115-L260) 在 shader 内手绘了完整 UI：

- **SDF 文字**：`TextSDF` 从 `iChannel3` 字体纹理采样，按字符索引切分（16×16 字符网格）。
- **2D 图示**：`Diagram` 用 `Arrow`/`Capsule`/`Rectangle` SDF 画出反射/折射/入射光示意。
- **位图文字编码**：[pbr_show_Image.glsl#L691-L764](./pbr_show_Image.glsl#L691-L764) 把每个英文单词编码成 `uint`（4 字符 = 1 个 uint），按小端字节序还原字符，用 `uint(v)` 解码——这是 ShaderToy 上常见的"无纹理文字"技巧。

## 七、技术亮点总结

1. **完整 Cook-Torrance BRDF**：D/G/F 三项均按 GGX + Schlick + Smith 实现，参数取值符合 Disney PBR 规范。
2. **近似 IBL**：双贴图 + 球谐三档混合代替 prefiltered map + BRDF LUT，移动端友好。
3. **SDF 建模 + 光线步进**：纯片元 shader 实现 3D 物体，无顶点数据。
4. **逐项可视化**：把 BRDF 各分量分离显示，是学习 PBR 公式最直观的方式。
5. **状态机 UI**：用 Buffer A 维护交互状态，纯 shader 实现可点击菜单/滑块/拖拽。
6. **数学一致性**：Disney roughness 映射（`r² = roughness²`）、能量守恒、Gamma 校正全部正确。

---

## 八、可继续深入的部分

下面列出本 shader 中涉及但未完全展开的若干技术点，可作为后续进一步学习的方向。每一项均给出关键问题、参考代码位置和延伸资料。

### 1. SDF 建模与 CSG 运算细节

- **关键问题**
  - `Substract`、`SubstractRound`、`UnionRound` 的数学推导与适用场景
  - 为什么 `length(max(d, 0.0))` 可以构造正确的 SDF Box
  - 平滑混合（smooth union / smin）的 `k` 参数对几何形状的影响
- **代码位置**：[pbr_show_Image.glsl#L284-L376](./pbr_show_Image.glsl#L284-L376)
- **延伸资料**：Inigo Quilez 的 [distance functions](https://iquilezles.org/articles/distfunctions/) 与 [smooth combinations](https://iquilezles.org/articles/smin/)。

### 2. Raymarching 步进与法线估计

- **关键问题**
  - 50 步迭代是否足够？如何根据场景自适应步长（sphere tracing 加速）
  - 中心差分法线估计的 epsilon 取值策略
  - `SceneAO` 中 `s *= 0.4` 的衰减系数依据
- **代码位置**：[pbr_show_Image.glsl#L421-L475](./pbr_show_Image.glsl#L421-L475)
- **延伸资料**：PBRT 第 3.7 节（Acceleration Structures）与 Hart 的 sphere tracing 原始论文。

### 3. GGX / Trowbridge-Reitz 分布推导

- **关键问题**
  - GGX 的长尾特性为什么比 Beckmann 更接近真实材质
  - D 项中 `(N·H)²·(r²-1)+1` 这一项的几何含义
  - Disney 的 `roughness²` 重映射为什么能更好控制视觉感受
- **代码位置**：`DistributionTerm` [pbr_show_Image.glsl#L317-L322](./pbr_show_Image.glsl#L317-L322)
- **延伸资料**：PBRT 第 8.4.3 节、Walter et al. 2007 *Microfacet Models for Refraction*、[Disney 2012 course notes](https://blog.selfshadow.com/publications/s2012-shading-course/)。

### 4. Smith 几何函数与高度相关遮蔽

- **关键问题**
  - `VisibilityTerm` 为何等价于 `G / (4·N·V·N·L)`
  - Smith Joint GGX 与分离 G1/G2 的差异
  - 高度相关（height-correlated）G2 的改进公式
- **代码位置**：`VisibilityTerm` [pbr_show_Image.glsl#L309-L315](./pbr_show_Image.glsl#L309-L315)
- **延伸资料**：Heitz 2014 *Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs*。

### 5. Schlick Fresnel 与导体/介质区别

- **关键问题**
  - 金属的 F0 与非金属 F0=0.04 (≈4%) 的物理来源
  - Schlick 近似在掠射角的误差
  - 色散菲涅尔（conductors 的复折射率）实现
- **代码位置**：`FresnelTerm` [pbr_show_Image.glsl#L324-L328](./pbr_show_Image.glsl#L324-L328)
- **延伸资料**：PBRT 第 8.2 节 Fresnel Equations。

### 6. IBL 近似与 prefiltered environment map

- **关键问题**
  - 用两张不同 mip 的环境贴图混合代替预过滤贴图的代价与限制
  - `EnvRemap` 中的 `pow(2*c, 2.2)` 是什么作用（HDR 与 gamma）
  - 粗糙度切到 SH 的过渡阈值 0.25 是如何决定的
- **代码位置**：[pbr_show_Image.glsl#L614-L655](./pbr_show_Image.glsl#L614-L655)
- **延伸资料**：Karis 2013 *Real Shading in Unreal Engine 4*（[SIGGRAPH course](https://blog.selfshadow.com/publications/s2013-shading-course/)）。

### 7. EnvBRDFApprox 的近似推导

- **关键问题**
  - UE4 的 BRDF LUT 2D 拟合多项式如何得到
  - `c0`、`c1` 这些 magic number 的来源
  - 不同 roughness / NdotV 下的拟合误差
- **代码位置**：`EnvBRDFApprox` [pbr_show_Image.glsl#L602-L612](./pbr_show_Image.glsl#L602-L612)
- **延伸资料**：[UE4 mobile PBR blog](https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile)、[LazyProgrammer 的拟合分析](https://blog.lazyrobot.me/post/ue4-ibl-approx)。

### 8. 球谐光照（Spherical Harmonics）

- **关键问题**
  - 9 个 SH 系数为什么对应 L0/L1/L2 三层
  - `SHIrradiance` 中 c1~c5 这些常数的推导
  - 旋转 SH 系数的高效方法（用于动态环境）
- **代码位置**：`SH_STPETER` 与 `SHIrradiance` [pbr_show_Image.glsl#L486-L537](./pbr_show_Image.glsl#L486-L537)
- **延伸资料**：Sloan 2008 *Stupid Spherical Harmonics (SH) Tricks*、Ramamoorthi 2001 *Precomputed Radiance Transfer*。

### 9. 状态机 UI 与纹理寄存器模式

- **关键问题**
  - 为什么用 8×8 像素的左上角做"寄存器"
  - `StoreValue` 的逐像素写入为何不会与其他像素冲突
  - 鼠标点击→拖拽状态切换的时序逻辑
- **代码位置**：[pbr_show_BufferA.glsl#L52-L82](./pbr_show_BufferA.glsl#L52-L82)、[pbr_show_BufferA.glsl#L84-L140](./pbr_show_BufferA.glsl#L84-L140)
- **延伸资料**：ShaderToy wiki 与 Shadertoy 入门教程 [Three.js 与 Shadertoy](https://threejs.org/manual/zh/shadertoy.html)。

### 10. UI 文字编码（uint → 字符串）

- **关键问题**
  - 4 个 ASCII 字符如何打包成一个 `uint`
  - 小端字节序在 GLSL 中如何还原
  - 这种"硬编码文字"相对 `texture(font)` 的优缺点
- **代码位置**：[pbr_show_Image.glsl#L691-L764](./pbr_show_Image.glsl#L691-L764)
- **延伸资料**：Shadertoy 上的 [text rendering 教程](https://www.shadertoy.com/view/4sXfDs) 与 iq 的 font SDF 实现。

### 11. 色彩空间与 Gamma 校正

- **关键问题**
  - 输入颜色 `pow(c, 2.2)` 与输出 `pow(c, 1/2.2)` 的完整管线
  - 为什么环境贴图也需要 `EnvRemap`
  - 线性空间 vs sRGB 空间混合时的常见错误
- **代码位置**：[pbr_show_Image.glsl#L614-L617](./pbr_show_Image.glsl#L614-L617)、[pbr_show_Image.glsl#L683](./pbr_show_Image.glsl#L683)
- **延伸资料**：PBRT 第 5.4.2 节 *Gamma*、[What every coder should know about gamma](https://blog.johnnovak.net/2016/09/21/what-every-coder-should-know-about-gamma/)。

### 12. 能量守恒与 AO 衰减

- **关键问题**
  - `specular *= pow(ndotv+ao, roughnessE) - 1. + ao` 这一行的物理含义
  - 为什么 specular 比 diffuse 更需要 AO 衰减
  - GTAO / HBAO 等 SSAO 算法与简单球面 AO 的区别
- **代码位置**：[pbr_show_Image.glsl#L678-L680](./pbr_show_Image.glsl#L678-L680)
- **延伸资料**：Jimenez 2016 *Practical Real-Time Strategies for Accurate Indirect Occlusion*。

### 13. 对应 PBRT 章节交叉阅读

下表给出本 shader 各部分与 PBRT（第 3 版）的对应关系，便于结合理论阅读：

| Shader 部分 | PBRT 章节 |
|------------|-----------|
| BRDF 模型 / Cook-Torrance | 第 8.1 ~ 8.4 节 |
| Fresnel / Schlick | 第 8.2 节 |
| GGX / Trowbridge-Reitz | 第 8.4.3 节 |
| Smith 几何函数 | 第 8.4.2 节 |
| 环境光与球谐 | 第 12.6 节 |
| 光线步进 / Raymarching | 第 3.7 节（思想相近） |
| 色彩空间 | 第 5.4.2 节 |

### 14. 推荐的进阶实践

1. **将本 shader 的 BRDF 项替换为 Multiple-Scattering GGX**（Heitz 2016），观察能量补偿后粗糙金属暗部变亮的差异。
2. **加入 Clearcoat / Sheen 层**（Disney Principled BRDF 扩展），实现车漆或织物效果。
3. **把 IBL 从"双贴图混合"升级为完整 prefiltered map + BRDF LUT**，对比性能与画质。
4. **加入多光源与软阴影**，结合 SDF 距离场快速生成阴影。
5. **接入 KHR_pbr_nextgen 规范**，对比本 shader 与工业级 PBR 实现的差异。

---

> 本 README 随学习进度持续更新，建议结合源代码与对应 PBRT 章节交叉阅读。
