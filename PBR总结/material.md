# PBR 主流模型参数对比：UE / Disney / Blender / OpenPBR

本文对比四个主流 PBR 模型的**参数命名、含义、参数值变化对应的视觉效果**，并分析它们之间的异同。

参考：
- [Unreal Engine Physically Based Materials](https://docs.unrealengine.com/5.3/en-US/physically-based-materials-in-unreal-engine/)
- [Blender Principled BSDF](https://docs.blender.org/manual/en/latest/render/shader_nodes/shader/principled.html)
- [OpenPBR Surface Specification v1.1.1](https://academysoftwarefoundation.github.io/OpenPBR/)
- [Disney Principled BRDF (Burley 2012)](https://media.disneyanimation.com/uploads/production/publication/s2012_pbs_disney_brdf_notes_v3.pdf)
- [OpenPBR Novel Features and Implementation Details (Portsmouth, Kutz, Hill 2025)](https://arxiv.org/html/2512.23696v1)

## 1. 四个 PBR 模型背景

| 模型 | 来源 | 类型 | 设计目标 |
|------|------|------|----------|
| **Disney Principled** | Disney Animation (Brent Burley, 2012) | 离线/电影 | 统一艺术直觉与物理正确性 |
| **UE Default Lit** | Epic Games (Unreal Engine 4+) | 实时 | 实时性能下的 PBR 材质 |
| **Blender Principled BSDF** | Blender 基金会 | 离线/实时（Eevee/Cycles） | 跨软件兼容的统一着色器 |
| **OpenPBR Surface** | Autodesk + Adobe (ASWF, 2023+) | 离线（VFX/动画） | 跨引擎、跨软件的开放标准 |

### 谱系关系

```
Disney Principled (2012)
        ├──→ Pixar RenderMan 实现
        ├──→ Unreal Engine 4 Default Lit
        └──→ Blender Principled BSDF (Blender 2.79+)

Autodesk Standard Surface (2019) + Adobe Standard Material (2021)
        └──→ OpenPBR Surface (2023+, 2025 v1.1)
                └──→ 目标: MaterialX / USD / Arnold / Omniverse
```

---

## 2. 参数总览对比

### 2.1 Disney Principled BRDF（原始 2012 版）

10 个核心参数，按"控制什么"分组：

| 参数名（英文） | 中文 | 取值范围 | 视觉效果 |
|--------------|------|----------|----------|
| `baseColor` | 基础色 | RGB [0,1] | 整体漫反射/金属反射颜色 |
| `subsurface` | 次表面 | [0,1] | 0=纯漫反射, 1=纯次表面散射（蜡烛、皮肤） |
| `metallic` | 金属度 | [0,1] | 0=绝缘体(塑料/木材/石头), 1=纯金属 |
| `specular` | 高光强度 | [0,1] | 沿法向的非金属镜面反射率（默认 0.5） |
| `specularTint` | 高光染色 | [0,1] | 0=无色高光, 1=基础色高光（奇特效） |
| `roughness` | 粗糙度 | [0,1] | 0=镜面反射, 1=完全漫反射 |
| `anisotropic` | 各向异性 | [0,1] | 0=圆形高光, 1=拉长高光（拉丝金属） |
| `sheen` | 边缘光泽 | [0,1] | 0=无, 1=丝绸/天鹅绒边缘反射 |
| `sheenTint` | 光泽染色 | [0,1] | 0=无色光泽, 1=基础色光泽 |
| `clearcoat` | 清漆 | [0,1] | 0=无清漆, 1=白色清漆层（汽车漆） |
| `clearcoatGlossiness` | 清漆光泽 | [0,1] | 0=粗糙清漆, 1=光滑清漆 |

### 2.2 Unreal Engine - Default Lit (UE 4/5)

| 参数（UE） | 中文 | 取值范围 | 对应 Disney | 视觉效果 |
|-----------|------|----------|-------------|----------|
| `Base Color` | 基础色 | RGB [0,1] | baseColor | 整体颜色，非金属=漫反射，金属=反射 |
| `Metallic` | 金属度 | [0,1] | metallic | 0=绝缘体，1=纯金属；UE 建议当作二元（不要 0.5） |
| `Specular` | 高光强度 | [0,1]（默认 0.5） | specular | 非金属沿法向的 F0 反射率（0~8%） |
| `Roughness` | 粗糙度 | [0,1] | roughness | 0=镜面，1=完全漫反射 |
| `Normal` | 法线 | 切线空间 RGB | (无 Disney) | 表面凹凸细节 |
| `Emissive Color` | 自发光颜色 | RGB × intensity | (无) | 自发光颜色 |
| `Ambient Occlusion` | 环境光遮蔽 | [0,1] | (无) | 缝隙阴影 |
| `Opacity` | 不透明度 | [0,1] | (无) | 整体透明度 |
| `World Position Offset` | 世界位置偏移 | 矢量 | (无) | 顶点位移 |
| `Subsurface Color` | 次表面色 | RGB | (无) | SSS 模型专用 |
| `Clear Coat` | 清漆 | [0,1] | clearcoat | 清漆层强度 |
| `Clear Coat Roughness` | 清漆粗糙度 | [0,1] | clearcoatGlossiness | 清漆层粗糙度 |
| `Anisotropy` | 各向异性 | [-1,1] | anisotropic | 高光拉伸方向和强度 |
| `Anisotropy Rotation` | 各向异性旋转 | [0,1] | (无) | 拉丝方向旋转 |
| `Tangent` | 切向 | 矢量 | (无) | 控制各向异性方向 |
| `Shading Model` | 着色模型 | 枚举 | (无) | Default Lit/Subsurface/Skin/Cloth/Hair |

### 2.3 Blender Principled BSDF（Blender 3.0+，4.0 调整顺序）

| 参数（Blender） | 中文 | 取值范围 | 对应 Disney | 视觉效果 |
|----------------|------|----------|-------------|----------|
| `Base Color` | 基础色 | RGB [0,1] | baseColor | 漫反射/金属反射颜色 |
| `Subsurface` | 次表面 | [0,1] | subsurface | 次表面散射混合 |
| `Subsurface Radius` | 次表面半径 | RGB [0,∞) | (Disney 用单一值) | RGB 通道独立散射距离 |
| `Subsurface Color` | 次表面颜色 | RGB | (无) | 次表面基础色 |
| `Subsurface IOR` | 次表面 IOR | [1,∞) | (无) | SSS 折射率 |
| `Subsurface Anisotropy` | 次表面各向异性 | [-1,1] | (无) | SSS 方向性 |
| `Metallic` | 金属度 | [0,1] | metallic | 0=绝缘体，1=纯金属 |
| `Specular` | 高光 | [0,1]（可 >1） | specular | 非金属 F0 反射率（默认 0.5） |
| `Specular Tint` | 高光染色 | [0,1] | specularTint | 高光偏向基础色 |
| `Roughness` | 粗糙度 | [0,1] | roughness | 0=镜面，1=漫反射 |
| `Anisotropic` | 各向异性 | [-1,1] | anisotropic | 高光拉长 |
| `Anisotropic Rotation` | 各向异性旋转 | [0,1] | (无) | 拉丝方向 |
| `Sheen Weight` | 光泽权重 | [0,1] | sheen | 丝绸/天鹅绒边缘反射（4.0 新名称） |
| `Sheen Roughness` | 光泽粗糙度 | [0,1] | (Disney 旧名 sheen) | 4.0 新增，控制光泽模糊 |
| `Sheen Tint` | 光泽染色 | [0,1] | sheenTint | 光泽颜色 |
| `Coat Weight` | 清漆权重 | [0,1] | clearcoat | 4.0 改名（原 Clearcoat） |
| `Coat Roughness` | 清漆粗糙度 | [0,1] | clearcoatGlossiness | 4.0 改名 |
| `Coat Color` | 清漆颜色 | RGB | (无) | 4.0 新增，原仅白色 |
| `Coat IOR` | 清漆 IOR | [1,∞) | (无) | 4.0 新增 |
| `IOR` | 折射率 | [1,∞) | (无) | 透射用 |
| `Transmission Weight` | 透射权重 | [0,1] | (Disney 无) | 0=不透明，1=玻璃 |
| `Transmission Roughness` | 透射粗糙度 | [0,1] | (无) | 透射模糊度 |
| `Emission Color` | 自发光颜色 | RGB | (无) | 自发光 |
| `Emission Strength` | 自发光强度 | [0,∞) | (无) | 自发光强度 |
| `Alpha` | 不透明度 | [0,1] | (无) | 透明度 |
| `Normal` | 法线 | 切线空间 RGB | (无) | 表面法线 |
| `Coat Normal` | 清漆法线 | 切线空间 RGB | (无) | 清漆层法线 |
| `Tangent` | 切向 | 矢量 | (无) | 各向异性方向 |

实现代码在intern\cycles\kernel\osl\shaders\node_principled_bsdf.osl openshadinglanguage

### 2.4 OpenPBR Surface v1.1

按"组（Group）"组织参数：

#### Geometry / 几何

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `geometry_opacity` | 几何不透明度 | [0,1] | 整体透明（α 混合） |
| `geometry_thin_walled` | 薄壁模式 | bool | true=双面薄壁（如纸张、布），false=实体 |
| `geometry_normal` | 几何法线 | 切线空间 RGB | 表面法线（共享各层） |

#### Base / 基础层（基底层）

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `base_weight` | 基础权重 | [0,1] | 整个基础层贡献（默认 1.0） |
| `base_color` | 基础色 | RGB [0,1] | 非金属漫反射色，金属反射色 |
| `base_metalness` | 金属度 | [0,1] | 0=纯绝缘，1=纯金属；支持 0~1 混合 |
| `base_diffuse_roughness` | 漫反射粗糙度 | [0,1] | 0=光滑漫反射（Oren-Nayar），1=极粗糙（默认 0） |

#### Specular / 镜面反射

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `specular_weight` | 镜面权重 | [0,1] | 镜面反射强度（默认 1.0） |
| `specular_color` | 镜面色 | RGB [0,1] | 替代"specular tint"，更精确控制 F82 色调 |
| `specular_roughness` | 镜面粗糙度 | [0,1] | 主高光模糊度 |
| `specular_roughness_anisotropy` | 镜面各向异性 | [0,1] | 0=各向同性，1=最大拉长 |
| `specular_ior` | 镜面 IOR | [1,∞) | F82 计算用 IOR（默认 1.5） |

#### Transmission / 透射

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `transmission_weight` | 透射权重 | [0,1] | 0=不透明，1=全透射（玻璃） |
| `transmission_color` | 透射色 | RGB | 光穿透后剩余的颜色 |
| `transmission_depth` | 透射深度 | [0,∞) | 单位距离内光被吸收的量 |
| `transmission_scatter` | 透射散射 | RGB [0,1] | 体内散射比例 |
| `transmission_scatter_anisotropy` | 散射各向异性 | [-1,1] | 散射方向性 |
| `transmission_dispersion_scale` | 色散尺度 | [0,1] | Abbe 数缩放 |
| `transmission_dispersion_abbe_number` | Abbe 数 | [0,∞) | 色散程度（玻璃棱镜效果） |

#### Subsurface / 次表面

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `subsurface_weight` | 次表面权重 | [0,1] | SSS 混合度（0=glossy-diffuse，1=全 SSS） |
| `subsurface_color` | 次表面色 | RGB | SSS 漫反射色 |
| `subsurface_radius` | 次表面半径 | RGB [0,∞) | RGB 通道独立散射距离 |
| `subsurface_radius_scale` | 半径缩放 | [0,∞) | 全局缩放 |
| `subsurface_scatter_anisotropy` | 散射各向异性 | [-1,1] | 各向异性 SSS |

#### Coat / 清漆

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `coat_weight` | 清漆权重 | [0,1] | 清漆层强度（默认 0=关闭） |
| `coat_color` | 清漆色 | RGB [0,1] | 默认白色（可做染色清漆） |
| `coat_roughness` | 清漆粗糙度 | [0,1] | 清漆高光模糊度 |
| `coat_roughness_anisotropy` | 清漆各向异性 | [0,1] | 清漆高光拉长 |
| `coat_ior` | 清漆 IOR | [1,∞) | 清漆反射强度 |
| `coat_darkening` | 清漆暗化 | [0,1] | 1=完全暗化（吸收性清漆），0=无 |

#### Fuzz / 绒毛

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `fuzz_weight` | 绒毛权重 | [0,1] | 绒毛层强度（默认 0） |
| `fuzz_color` | 绒毛色 | RGB [0,1] | 绒毛反射色 |
| `fuzz_roughness` | 绒毛粗糙度 | [0,1] | 绒毛模糊度 |

#### Emission / 自发光

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `emission_luminance` | 发光亮度 | [0,∞) | 物理单位 cd/m² |
| `emission_color` | 发光色 | RGB [0,1] | 自发光颜色 |

#### Thin-film / 薄膜干涉

| 参数 | 中文 | 取值范围 | 视觉效果 |
|------|------|----------|----------|
| `thin_film_weight` | 薄膜权重 | [0,1] | 薄膜干涉强度 |
| `thin_film_thickness` | 薄膜厚度 | [0,∞) nm | 决定干涉色（微米级） |
| `thin_film_ior` | 薄膜 IOR | [1,∞) | 薄膜折射率（默认 1.5） |

---

## 3. 参数效果对照表（核心参数）

| 概念 | Disney | UE | Blender | OpenPBR |
|------|--------|-----|---------|---------|
| **基础色** | baseColor | Base Color | Base Color | base_color |
| **金属度** | metallic | Metallic | Metallic | base_metalness |
| **高光强度** | specular | Specular | Specular | specular_weight + specular_ior |
| **粗糙度** | roughness | Roughness | Roughness | specular_roughness |
| **次表面** | subsurface | (用 SSS 着色模型) | Subsurface | subsurface_weight |
| **各向异性** | anisotropic | Anisotropy | Anisotropic | specular_roughness_anisotropy |
| **边缘光泽** | sheen | (用 Cloth 着色模型) | Sheen Weight | fuzz_weight |
| **清漆** | clearcoat | Clear Coat | Coat Weight | coat_weight |
| **透射** | (无) | (用 Translucent) | Transmission Weight | transmission_weight |
| **自发光** | (无) | Emissive Color | Emission Color | emission_color + emission_luminance |
| **法线** | (无) | Normal | Normal | geometry_normal |
| **薄膜干涉** | (无) | (无) | (无) | thin_film_thickness |

---

## 4. 异同分析

### 4.1 共同点

| 维度 | 说明 |
|------|------|
| **微表面理论** | 四个模型都基于 Cook-Torrance 微表面 BRDF |
| **GGX NDF** | 主流实现都使用 GGX / Trowbridge-Reitz 法线分布 |
| **能量守恒** | 都强调能量守恒（多散射 GGX / Kulla-Conty 近似） |
| **金属-绝缘分离** | 都有 metallic 参数（除 Disney 极简版用 metallic 权重外） |
| **粗糙度** | 统一的 [0,1] 粗糙度参数 |
| **PBR 工作流贴图** | 都支持 baseColor + metallic + roughness 三张主贴图 |
| **法线贴图** | 都有切线空间法线输入 |
| **次表面/透射** | 都通过权重或专用模型支持 |

### 4.2 关键差异

| 维度 | Disney | UE | Blender | OpenPBR |
|------|--------|-----|---------|---------|
| **设计目标** | 通用单节点艺术着色器 | 实时游戏引擎 | DCC 软件通用 | 跨引擎开放标准 |
| **次表面参数** | 单一权重值 | 用单独 Shading Model 切换 | RGB 独立半径 + 多个参数 | weight + radius + scatter + color |
| **金属混合** | 二元化（建议 0/1） | 二元化（建议 0/1） | 二元化（建议 0/1） | **支持中间值**（specular_weight 独立） |
| **透射模型** | 不内置 | 用 Translucent 模型 | 权重 + 粗糙度 | **独立的 transmission 组**，含色散 |
| **清漆色** | 仅白色 | 白色 + 粗糙度 | 4.0 增加了 Color + IOR | **coat_color + coat_ior + coat_darkening** |
| **薄膜干涉** | 不支持 | 不支持 | 不支持 | **内置 thin_film 组**（基于物理微米厚度） |
| **绒毛/光泽** | sheen（简化） | 用 Cloth 着色模型 | sheen（4.0 改进为微纤维） | **fuzz**（基于微纤维理论，比 sheen 更准确） |
| **漫反射粗糙度** | 无（Lambert） | 无 | 无 | **Oren-Nayar 模型**（`base_diffuse_roughness`） |
| **自发光** | 无 | Emissive Color | Color + Strength 分离 | **luminance + color**（物理单位） |
| **薄壁/双面** | 不支持 | 通过 Translucent 实现 | 通过设置实现 | **geometry_thin_walled**（明确语义） |
| **几何不透明度** | 无 | Opacity | Alpha | **geometry_opacity**（独立于体积散射） |
| **Fresnel 模型** | Schlick 简化 | Schlick | Schlick | **F82-tint 模型**（更精确的双色菲涅尔） |
| **清漆暗化** | 不支持 | 不支持 | 不支持 | **coat_darkening**（吸收性清漆物理正确） |
| **色散** | 不支持 | 不支持 | 不支持 | **transmission_dispersion**（玻璃棱镜色散） |

### 4.3 参数命名差异

| 概念 | 各模型命名 |
|------|------------|
| 基础色 | baseColor / Base Color / Base Color / base_color |
| 金属度 | metallic / Metallic / Metallic / base_metalness |
| 粗糙度 | roughness / Roughness / Roughness / specular_roughness |
| 镜面强度 | specular / Specular / Specular / specular_weight (+ specular_ior) |
| 边缘光泽 | sheen / (Cloth 模型) / Sheen / fuzz_weight |
| 清漆 | clearcoat / Clear Coat / Coat (4.0 改名) / coat_weight |
| 透射 | (无) / (无) / Transmission / transmission_weight |
| 自发光 | (无) / Emissive Color / Emission / emission_luminance |

### 4.4 Blender 4.0 vs 3.x 变化（重要）

| 旧名称 (Blender ≤ 3.6) | 新名称 (Blender 4.0+) | 变化 |
|------------------------|----------------------|------|
| Clearcoat | Coat Weight | 重命名，强调权重含义 |
| Clearcoat Roughness | Coat Roughness | 同步重命名 |
| (无) | Coat Color | 新增（原来仅白色） |
| (无) | Coat IOR | 新增（原来固定 1.5） |
| Sheen | Sheen Weight | 强调权重 |
| (无) | Sheen Roughness | 新增（基于微纤维理论） |

### 4.5 视觉差异示例

| 场景 | 相同参数值 | 视觉差异原因 |
|------|-----------|--------------|
| **玻璃杯** | transmission_weight=1.0 | UE/Blender 用简化 Schlick；OpenPBR 加色散和 transmission_depth，更接近真实玻璃 |
| **汽车漆** | coat_weight=1.0, base_metalness=1.0 | UE/Blender 是白色清漆+金属；OpenPBR 可加 coat_color（染色彩漆）和 coat_darkening（吸收性漆） |
| **皮肤** | subsurface_weight=0.5 | OpenPBR 的次表面包含 scatter_anisotropy（前向散射），更接近真实皮肤 |
| **泡沫/肥皂泡** | thin_film_thickness=300nm | 只有 OpenPBR 内置薄膜干涉；UE/Blender 需用 iridescence 节点 |
| **拉丝金属** | anisotropic=1.0 | UE/Blender 用 0-1 标量；OpenPBR 用 specular_roughness_anisotropy（与 specular_roughness 复合） |
| **天鹅绒** | sheen=1.0 | Disney/UE 旧版用简单 K因子；Blender 4.0 和 OpenPBR 改用微纤维理论，边缘反射更自然 |
| **潮湿岩石** | base_diffuse_roughness=0.3 | 只有 OpenPBR 用 Oren-Nayar 模型，其他用 Lambert（更平滑） |

---

## 5. 参数与游戏/电影/工业领域的适用性

| 模型 | 实时游戏 | VFX 离线 | 工业设计 | 跨软件资产交换 |
|------|----------|----------|----------|----------------|
| **Disney** | ★★★ | ★★★ | ★★ | ★★ |
| **UE** | ★★★★★ | ★ | ★★ | ★★ |
| **Blender** | ★★★ | ★★★★ | ★★★ | ★★★ |
| **OpenPBR** | ★★ | ★★★★★ | ★★★★ | ★★★★★ |

说明：
- **UE** 专为实时优化（最简单最稳定）
- **Blender** 在 Cycles（离线）和 Eevee（实时）都可用，平衡好
- **Disney** 是事实标准（被 UE 和 Blender 借鉴）
- **OpenPBR** 是新一代标准（VFX 工业首选，跨引擎互操作）

---

## 6. 选择建议

| 场景 | 推荐模型 | 理由 |
|------|----------|------|
| **游戏开发** | UE Default Lit | 性能最优，工具链完整 |
| **3D 资产创作** | Blender Principled BSDF | 通用、与 UE/RenderMan 兼容 |
| **VFX 电影** | OpenPBR / Arnold 标准表面 | 物理精确、跨软件互操作 |
| **学习 PBR 原理** | Disney 2012 论文 → Blender 实践 | 概念清晰、文档丰富 |
| **跨引擎素材（USD/MaterialX）** | OpenPBR | ASWF 主导，USD/MTLX 友好 |
| **建筑可视化** | OpenPBR 或 Blender | 物理精确、易调整 |

---

## 7. 总结

四个 PBR 模型代表**同一理念**（Cook-Torrance 微表面理论）在**不同工程约束**下的实现：

- **Disney** = 概念奠基者（2012）
- **UE** = 实时工程的代表（2014+）
- **Blender** = DCC 软件中的通用方案（2015+）
- **OpenPBR** = 跨引擎的开放标准（2023+，2025 v1.1）

**演进趋势**：
1. 从"简化 Schlick"到"F82-tint" Fresnel
2. 从"sheen"到"fuzz"（微纤维理论）
3. 从"单一 SSS 权重"到"完整次表面组（radius+scatter+anisotropy）"
4. 从"无薄膜"到"内置物理薄膜"
5. 从"不透明金属"到"decoupled metalness"（OpenPBR 未来）
6. 从"Schlick F0"到"specular_weight + IOR"独立控制

对于 CG 学习者，建议路径：
**Disney 论文（理论）→ Blender 实操（实践）→ UE 应用（实时）→ OpenPBR 标准（未来）**

# sheen vs coat vs tint辨析
这三者里 **sheen（在 OpenPBR 里叫 fuzz）和 coat 是两层独立的光学层**，而 **tint 不是一层**——它是附在 sheen/fuzz 或 coat 上的"染色颜色"参数。所以严格说，你要比较的是"两层 + 一个颜色附属参数"。

## 一句话区分

- **Sheen / Fuzz**：模拟物体表面微纤维/绒毛的多次散射，在掠射角产生柔和的边缘光晕。布料、天鹅绒、桃绒、灰尘
- **Coat**：模拟物体表面一层透明的清漆/涂层，本身产生镜面反射，同时因吸收介质而微微染色下层。车漆、清漆木器、油漆表面
- **Tint**：不是一个光学层，而是 sheen 或 coat 上的**颜色参数**，用来给那一层的反射或透射"上色"

## 物理本质对比

| 维度 | Sheen / Fuzz | Coat | Tint |
|---|---|---|---|
| **物理现象** | 微纤维末端的多次散射（体积散射） | 介电质清漆层的界面反射 + 层内吸收 | 不是独立现象，是染色参数 |
| **层位** | OpenPBR 中最顶层，位于 coat 之上 | coat 之下、base 之上 | 附在 fuzz 或 coat 上 |
| **是否反射** | 是，但宽而柔（非锐利高光） | 是，锐利镜面高光（受 roughness 控制） | 否 |
| **是否染下层** | **否**，透射部分是灰度的，不染 base | **是**，coat_color 通过吸收染色下层 | 本身就是那个"染料" |
| **典型材质** | 天鹅绒、缎面、布料、桃绒、灰尘 | 车漆、清漆、漆面、涂料 | —— |

## Sheen / Fuzz 的细节

基于 Zeltner et al. 2022 的微片（microflake）体积模型，在 OpenPBR 中称为 **fuzz**：

- **fuzz_weight**：微纤维层的覆盖密度，0 表示关闭
- **fuzz_color**：微纤维单次散射反照率，**只染 fuzz 自身的反射**，多次散射后透射到下层的部分是灰度的，所以**不会给 base 染色**
- **fuzz_roughness**：控制微片形状
  - **低值** → 微片呈高度纤维状（沿法线方向的细长纤维），产生强掠射角光泽，典型**天鹅绒/缎面**观感
  - **高值** → 微片呈球形，散射各向同性，产生**粉尘/绒尘**观感

> 💡 关键认知：sheen/fuzz 是**体积散射层**，不是表面反射层。所以它"包裹"在 coat 外面，但**不影响 coat 的反射**——coat 的镜面高光该多锐利还是多锐利。

## Coat 的细节

清漆层是 OpenPBR 中介于 fuzz 和 base 之间的介电质 slab：

- **coat_weight**：涂层覆盖率/存在权重，0~1
- **coat_color**：涂层**透明度颜色**，通过模拟层内吸收来染色下层基色。**注意：它不影响 coat 自身镜面反射的颜色（反射保持白色），只染色它下面的 specular 和 base 层**
- **coat_roughness**：涂层粗糙度。当 coat 粗糙时，**base 层的镜面反射也会变模糊**——因为光在到达 base 之前要先穿过粗糙的涂层散射一次
- **coat_ior**：涂层折射率，影响反射强度和染色随角度的饱和度变化
- **coat_darkening**：涂层因多次内部反射饱和并压暗下层的程度，1.0 为物理最大值，0 关闭

> 💡 一个反直觉点：**coat 染色只发生在"穿透涂层到达下层又返回"的光路上**，所以涂层越厚/ IOR 越高/ darkening 越大，下层被染得越明显；而涂层自己的镜面反射始终是中性色。

## Tint 的角色

"Tint" 这个词在不同系统里指代不同，但本质都是**颜色乘法参数**：

- **Blender Principled BSDF**：Sheen 和 Coat 各有自己的 Tint 参数——`Sheen Tint` 控制绒毛反射颜色（白→绿），`Coat Tint` 控制涂层吸收染色（白→蓝）
- **OpenPBR**：对应 `fuzz_color` 和 `coat_color`，语义同上
- **USD / Omniverse OmniPBR**：`Albedo Tint` 是乘在最终反照率上的颜色，`Clearcoat Tint` 是涂层的染色

所以 tint **永远依附于某个光学层**，它自己不构成一层。

## 三者叠加时的层序

OpenPBR 从上到下的真实层序：

```
fuzz (sheen)        ← 最顶，微纤维多次散射，fuzz_color 只染自己
    ↓
coat                ← 清漆层，coat_color 染色下层，自身反射中性
    ↓
base-subsrate       ← 基层（漫反射/金属/次表面/透射）
    ↓
emission            ← 自发光，位于 base 内但 coat/fuzz 之下，所以发光会被涂层吸收染色
```

> ⚠️ 这意味着：如果你给一个车漆材质同时开 coat 和 fuzz，**fuzz 在 coat 之外**——绒毛反射不会被清漆的镜面高光盖住，但清漆的高光也不会被绒毛染。两层互不干扰，各自有自己的 tint 参数。

## 实践选择

- 做**布料/天鹅绒/绒面** → 用 **fuzz/sheen**，调 `fuzz_weight` + `fuzz_color` + `fuzz_roughness`（低 roughness 出天鹅绒，高 roughness 出粉尘）
- 做**车漆/清漆/漆面木器** → 用 **coat**，调 `coat_weight` + `coat_roughness` + `coat_ior` + `coat_color`（染色下层）+ `coat_darkening`
- 想让布料表面再有一层清漆感 → **两层都开**，fuzz 在外、coat 在内，各调各的 tint
- **tint 不是开关**，是你在调 sheen 或 coat 时顺手设置的颜色参数——决定那一层反射/透射的"染料色"

你是在哪个渲染器里用（Blender / Arnold / V-Ray / Omniverse）？不同软件对 sheen 和 coat 的参数命名略有差异，告诉我具体环境能给到对应的参数对照。

# MaterialX 与 OpenPBR 总结

本章综合 MaterialX 与 OpenPBR 的关系、各自定位、生态集成和演进趋势，便于深入理解现代 PBR 标准化方向。

参考：
- [MaterialX 官网](https://materialx.org/)
- [OpenPBR Surface Specification](https://academysoftwarefoundation.github.io/OpenPBR/)
- [NVIDIA Developer Blog: OpenUSD + MaterialX + OpenPBR](https://developer.nvidia.cn/blog/unlock-seamless-material-interchange-for-virtual-worlds-with-openusd-materialx-and-openpbr/)
- [UE 5.4 Interchange MaterialX Reference](https://dev.epicgames.com/documentation/zh-cn/unreal-engine/interchange-materialx-reference-in-unreal-engine?application_version=5.4)

## 1. 各自是什么

| 项目 | 类型 | 诞生 | 核心目标 | 当前状态 |
|------|------|------|----------|----------|
| **MaterialX** | 材质**描述**格式（XML/库） | ILM, 2012；ASWF 2021 | 跨软件、跨渲染器、跨平台的材质**交换**标准 | v1.39.3（2025-03） |
| **OpenPBR Surface** | 材质**着色模型**（uber-shader） | Autodesk + Adobe, 2023；ASWF 维护 | 跨引擎统一的物理正确材质**定义** | v1.1.1（2025） |

**关键区别**：MaterialX 是"如何描述材质图"（格式/语法），OpenPBR 是"描述什么材质"（语义/参数集）。两者**互补**——OpenPBR 的参考实现本身就是用 MaterialX 写成的（`openpbr_surface.mtlx`）。

## 2. MaterialX 详解

### 是什么
- **MaterialX** = 独立于渲染器的开源文件格式 + C++ 库
- 用 XML（`.mtlx` 扩展名）序列化"着色图（shader graph）"或直接在 USD 中作为 UsdShade 节点图
- 2021 年成为 **Academy Software Foundation (ASWF)** 第 7 个托管项目
- 许可证：**Apache 2.0**

### 用途
- **VFX 跨软件交付**：Maya → Houdini → Blender → Nuke 之间保持材质一致
- **实时预览 → 离线渲染**：同一份材质可在 UE/Unity 预览，最终在 RenderMan/Arnold 输出
- **数字资产交换**：USD/MaterialX 双格式打包，跨平台复用
- **AI 训练数据**：用 Python 脚本（`import MaterialX`）解析 `.mtlx`，用于材质理解和生成
- **非真实感渲染（NPR）**：1.38.9 起内置 NPR 节点库
- **虚拟制片 / 数字孪生**：与 OpenUSD 深度集成，支持全栈 USD 化

### 内容（核心特性）

#### 数据模型
| 概念 | 描述 |
|------|------|
| **Material Graph** | 材质图（节点+连接） |
| **NodeDef** | 节点类型定义（`nodedef`） |
| **NodeGraph** | 节点实例的连接图 |
| **Input / Output** | 节点端口 |
| **Parameter** | 参数（可被实例覆盖） |
| **GeomProp** | 几何属性（UV/Normal/Position/Tangent） |
| **Token / Material Assign** | 材质与几何表面的绑定 |

#### 节点库分类
- **核心节点**：数学、转换、判断
- **图案节点**：噪声（Perlin/Worley/Unified）、程序化纹理
- **PBR 节点**：Disney Principled（1.39.2+）、Standard Surface、OpenPBR Surface
- **应用节点**：分层、混合、几何变换
- **非真实感节点**（1.38.9+）：描边、卡通着色
- **颜色管理节点**：色彩空间转换、颜色校正（1.38.6+ Unified Color Correct）

#### 后端（Backend）系统
MaterialX 用**可插拔后端**生成可执行着色代码：
- **MDL**（NVIDIA）— 最完整
- **OSL**（Sony Pictures Imageworks）— 离线渲染
- **GLSL**（OpenGL/Vulkan）— 实时
- **MSL**（Metal）— Apple 平台（1.38.7+）
- **HSL/HLSL** — DirectX

**示例**：`MaterialX (.mtlx) → MDL 后端 → 蒸馏为 HLSL/PTX/C++ → 任意渲染器执行`

#### 标准着色模型支持
- **Standard Surface**（Autodesk）
- **OpenPBR Surface**（1.39.0 起官方支持）
- **Disney Principled**（1.39.2+）
- **UsdPreviewSurface**（Pixar）
- **Lama**（RenderMan）
- **Chiang Hair BSDF**（1.39.2+）

#### 版本演进亮点
| 版本 | 时间 | 重要变化 |
|------|------|----------|
| 1.38.6 | 2022-11 | Unified Noise / Color Correct 节点；OSL closure 集成 |
| 1.38.7 | 2023-04 | MaterialX Graph Editor；MSL 支持 |
| 1.38.8 | 2023-09 | iOS 构建支持；PyPI Python 分发；Web Viewer 拖放 |
| 1.38.9 | 2024-02 | 首次 GPU 环境预滤波；NPR 节点库 |
| 1.39.0 | 2024-07 | **OpenPBR Surface 官方支持**；OSL v1.14、MDL v1.10 |
| 1.39.1 | 2024-09 | Standard Surface ↔ OpenPBR 翻译图；Lama 公共定义对齐 |
| 1.39.2 | 2025-01 | **Chiang Hair BSDF + Disney Principled**；通用 Color Ramps |
| 1.39.3 | 2025-03 | OpenUSD 对齐；ShaderGen 优化 |

### MaterialX 在主流软件中的支持
| 软件 | 支持程度 | 用途 |
|------|----------|------|
| **Houdini (Karma)** | ★★★★★ 原生 | 离线/实时渲染 |
| **Maya (Arnold)** | ★★★★★ 原生 | VFX 主力 |
| **Blender** | ★★★ 实验性 | 4.x 起部分支持 |
| **Unreal Engine** | ★★★★ Interchange 框架 | 实时导入 + 翻译为 Substrate |
| **Unity (HDRP)** | ★★★ 实验性 | 通过插件 |
| **NVIDIA Omniverse** | ★★★★★ 原生 | USD + MaterialX 全栈 |
| **3ds Max (Arnold)** | ★★★★ | VFX 辅助 |

## 3. OpenPBR Surface 详解

### 是什么
- **OpenPBR** = "Open Physically Based Rendering" 的缩写
- 跨软件、跨引擎的**统一物理材质定义**（uber-shader）
- 由 **Autodesk**（Arnold 团队）和 **Adobe**（Standard Material 团队）联合开发
- 2023 年首次发布，托管于 **ASWF**
- 用 **MaterialX 语言** 描述（参考实现：`openpbr_surface.mtlx`）
- 许可证：**Apache 2.0**

### 用途
- **统一艺术家语言**：一套参数名，跨 Maya/Blender/Houdini/UE/Omniverse 都一致
- **替代 Autodesk Standard Surface 和 Adobe Standard Material**（两者合并产物）
- **多渲染器资产交换**：用同一份 OpenPBR 材质，可在 Arnold/RenderMan/Karma/UE 渲染
- **物理精确 PBR**：F82-tint Fresnel、Oren-Nayar 漫反射、吸收性清漆、薄膜干涉、色散
- **USD 生态整合**：AOUSD 材质工作组推荐格式

### 内容（核心特性）
- **9 个参数组**：Geometry / Base / Specular / Transmission / Subsurface / Coat / Fuzz / Emission / Thin-film
- **60+ 参数**（vs Standard Surface 的 ~50 个，Disney 的 11 个）
- **物理单位**：emission 用 `luminance` (cd/m²) 而非归一化值
- **内置薄壁模式**（thin-walled）：纸张、布、叶子等双面薄物体
- **完整次表面组**：radius + scatter + anisotropy 独立控制
- **薄膜干涉**（thin-film）：基于物理微米厚度，肥皂泡、油膜、珍珠等
- **绒毛**（fuzz）：基于微纤维理论，比 sheen 更物理

### OpenPBR 的关键创新（vs Disney/UE）
1. **F82-tint Fresnel**：替代简化 Schlick，更精确的双色菲涅尔
2. **specular_weight + specular_ior 解耦**：可独立调整反射强度和 IOR
3. **transmission_dispersion**：内置色散（玻璃棱镜）
4. **coat_darkening**：吸收性清漆（黑漆面下金属变暗）
5. **base_diffuse_roughness**：Oren-Nayar 漫反射（粗糙漫反射面如赤陶）
6. **decoupled metalness**：specular_weight 与金属度独立，允许中间态
7. **thin_film**：唯一内置薄膜干涉的标准
8. **geometry_thin_walled**：明确的薄壁/双面语义

### OpenPBR 在主流软件中的支持
| 软件 | 支持程度 | 用途 |
|------|----------|------|
| **Maya (Arnold)** | ★★★★★ 官方 | VFX 主力 |
| **Houdini (Karma)** | ★★★★★ 官方 | 跨平台离线/实时 |
| **Blender** | ★★ 计划中 | 5.x 可能原生支持 |
| **Unreal Engine** | ★★★★ Substrate 翻译 | 实时引擎 |
| **NVIDIA Omniverse** | ★★★★★ 官方 | USD/MaterialX 生态核心 |
| **3ds Max (Arnold)** | ★★★★ | VFX 辅助 |
| **Katana** | ★★★★ | 灯光/look-dev |

## 4. MaterialX 与 OpenPBR 的关系

### 层级关系
```
OpenUSD（场景描述）— 容器
  └── UsdShade（节点图）
       ├── 直接节点（厂商特定）
       └── MaterialX 节点库 ←—— 标准化桥梁
            ├── 通用节点（噪声/转换/数学）
            ├── Standard Surface
            ├── UsdPreviewSurface
            ├── Disney Principled
            └── OpenPBR Surface ←—— uber-shader
                 （用 MaterialX 语法定义）
```

### 互补性

| 维度 | MaterialX | OpenPBR |
|------|-----------|---------|
| **类型** | 格式规范 + C++ 库 | 着色模型规范 |
| **粒度** | 可任意复杂（无数节点） | 固定参数集（uber-shader） |
| **灵活性** | 高（自由组合节点） | 中（限定在 OpenPBR 参数空间） |
| **易用性** | 中（需要理解节点图） | 高（一个统一着色器） |
| **目标** | 表达一切可能的材质 | 定义常用材质的标准 |
| **性能** | 取决于图复杂度 | 固定开销，可优化 |
| **实施** | 任何支持 MaterialX 的引擎 | 任何实现 OpenPBR 着色器的引擎 |

### 实际工作流
1. **复杂自定义材质** → 用 MaterialX 自由组合
2. **常规 80% 材质** → 直接用 OpenPBR Surface 节点
3. **跨软件交换** → 两者都用 `.mtlx` 格式，互不冲突

## 5. 生态集成全景

### 三大标准的协作（NVIDIA 2024 提出的工作流）
```
OpenUSD（场景容器）
  └─ UsdShade（材质表示）
       └─ MaterialX（标准化节点图）
            └─ MDL（NVIDIA 高级着色语言）
                 └─ HLSL/PTX/C++（目标平台代码）
                      └─ 任何渲染器执行
```

**关键节点**：
- **AOUSD 材质工作组**（2024）：定义 USD 中材质表示策略
- **NVIDIA Omniverse**：原生支持整个栈
- **OpenPBR**：作为 MaterialX 库中的 uber-shader 节点

### UE 5.4 的实现细节
UE 通过 `Interchange` 框架支持 MaterialX，导入时使用以下翻译函数：
- `MX_StandardSurface` → UE Standard Surface
- `MX_OpenPBR_Opaque` / `MX_OpenPBR_Translucent` → UE Substrate
- `MX_USDPreviewSurface` → USD Preview Surface
- `MX_SurfaceUnlit` → 无光照材质

**重要**：OpenPBR 材质在 UE 中默认用 Standard Surface 翻译，用 Substrate 材质可获得更高保真度（实验性）。

## 6. 演进趋势与未来

### 趋势 1：从"工具链"到"标准"
- 过去：每家公司私有材质格式
- 现在：MaterialX（格式）+ OpenPBR（语义）成为事实标准
- 未来：USD 主导的端到端资产交换

### 趋势 2：从"美术驱动"到"物理驱动"
- Disney 2012：艺术直觉 + 简化的物理
- OpenPBR 2023+：物理优先（cd/m²、IOR、Abbe 数、微米厚度）

### 趋势 3：从"单一模型"到"模块化"
- MaterialX 提供模块化节点组合
- OpenPBR 提供标准化模块（Coat / Fuzz / Thin-film 可独立启用）

### 趋势 4：AI 辅助
- MaterialX Python 绑定让 AI 可读/写/验证材质
- OpenPBR 标准化让 AI 训练数据质量更高
- 文本 → 材质（即将成为可能）

### 趋势 5：实时 + 离线融合
- 同一份 OpenPBR 材质，UE 实时预览，Arnold 离线输出
- 视觉一致性是核心目标

## 7. 学习路径建议

### 入门者
1. **理解 PBR 基础**（Disney 论文）
2. **学会一种工具的材质编辑**（Blender Principled BSDF 即可）
3. **尝试导出 USD/MaterialX**（Blender → MaterialX）

### 中级者
1. **掌握 OpenPBR 参数语义**（参考 [OpenPBR 文档](https://academysoftwarefoundation.github.io/OpenPBR/)）
2. **多软件对比**（同一材质在 Maya/Blender/Houdini 中的表现）
3. **学会着色图组合**（MaterialX 节点图）

### 高级者
1. **参与 ASWF 贡献**（[MaterialX GitHub](https://github.com/AcademySoftwareFoundation/MaterialX)）
2. **写自定义节点 / MDL 后端**
3. **大规模管线的 OpenPBR 资产生产**（VFX 流程）

## 8. 关键概念速查

| 概念 | 一句话 |
|------|--------|
| **MaterialX** | 跨软件材质交换的 XML 标准（语法层） |
| **OpenPBR** | 跨引擎统一的 PBR 着色模型（语义层） |
| **OpenUSD** | 跨软件场景描述（容器层） |
| **UsdShade** | USD 中的材质节点图规范 |
| **MDL** | NVIDIA 高级着色语言（生成层） |
| **uber-shader** | 一个包含所有材质类型的统一着色器 |
| **Shading graph** | 节点 + 连接的材质构建方式 |
| **Standard Surface** | Autodesk 的前代统一着色模型（被 OpenPBR 取代） |
| **Standard Material** | Adobe 的前代统一着色模型（被 OpenPBR 取代） |
| **Substrate** | UE 5 的分层材质框架（OpenPBR 翻译目标） |
| **F82-tint** | OpenPBR 的双色菲涅尔模型（替代 Schlick） |
| **Decoupled metalness** | OpenPBR 解耦金属度与镜面权重（可独立调整） |

## 9. 推荐资源

### 官方文档
- [MaterialX 官网](https://materialx.org/)
- [MaterialX GitHub](https://github.com/AcademySoftwareFoundation/MaterialX)
- [OpenPBR 规范](https://academysoftwarefoundation.github.io/OpenPBR/)
- [OpenPBR GitHub](https://github.com/AcademySoftwareFoundation/OpenPBR)
- [OpenUSD 官网](https://openusd.org/)

### 技术博客
- [NVIDIA: OpenUSD + MaterialX + OpenPBR](https://developer.nvidia.cn/blog/unlock-seamless-material-interchange-for-virtual-worlds-with-openusd-materialx-and-openpbr/)
- [Pixar USD 文档](https://openusd.org/release/index.html)
- [Autodesk AREA: OpenPBR](https://area.autodesk.com/blogs/the-area/openpbr/)

### 论文
- [OpenPBR: Novel Features and Implementation Details (2025)](https://arxiv.org/html/2512.23696v1)
- [MaterialX: Building a Universal Material Format (2017)](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/47389.pdf)

