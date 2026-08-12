# 光照技术体系：概念、原理与实现

> 综合整理计算机图形学中光照相关的概念、技术、原理与实现

---

## 目录

1. [光照基础概念](#1-光照基础概念)
2. [光源类型与采样](#2-光源类型与采样)
3. [环境光照技术](#3-环境光照技术)
4. [全局光照（GI）](#4-全局光照gi)
5. [遮蔽与环境光](#5-遮蔽与环境光)
6. [反射技术](#6-反射技术)
7. [光照预处理与烘焙](#7-光照预处理与烘焙)
8. [光照传输数学工具](#8-光照传输数学工具)
9. [引擎实现对比](#9-引擎实现对比)

---

## 1. 光照基础概念

### 1.1 物理量

| 物理量 | 符号 | 单位 | 含义 |
|---|---|---|---|
| 辐射通量（Radiant Flux） | $\Phi$ | W | 单位时间通过的能量 |
| 辐射照度（Irradiance） | $E$ | W/m² | 单位面积接收的通量 |
| 辐射亮度（Radiance） | $L$ | W/(m²·sr) | 单位面积单位立体角的通量 |
| 辐射强度（Radiant Intensity） | $I$ | W/sr | 单位立体角的通量 |

核心关系：

$$
L_o(\mathbf{x}, \omega_o) = L_e(\mathbf{x}, \omega_o) + \int_{\Omega} f_r(\mathbf{x}, \omega_i, \omega_o) \, L_i(\mathbf{x}, \omega_i) \, \cos\theta_i \, d\omega_i
$$

### 1.2 光照分类

| 概念 | 定义 | 数学对应 |
|---|---|---|
| **自发光（Emission）** | 表面自身发出的光 | LTE 中的 $L_e$ 项 |
| **直接光（Direct Lighting）** | 从光源经一次反射到达相机的光 | LTE 积分中 $L_i$ 直接来自光源 |
| **间接光（Indirect Lighting）** | 经多次反射/折射后到达相机的光 | LTE 积分中 $L_i$ 来自其他表面的 $L_o$ |
| **环境光（Ambient）** | 来自周围环境的整体光照 | 传统图形学中的常数近似 |
| **GI（全局光照）** | 直接光 + 间接光 | LTE 非自发光项的完整解 |

### 1.3 BRDF / BSDF

| 概念 | 含义 | 典型模型 |
|---|---|---|
| **Diffuse（漫反射）** | 光均匀散射到所有方向 | Lambert, Oren-Nayar |
| **Specular（镜面反射）** | 光在镜面方向集中反射 | Phong, Blinn-Phong |
| **Glossy（光泽反射）** | 介于漫反射和镜面之间 | Cook-Torrance, GGX |
| **Reflection（反射）** | 光从表面弹回 | 镜面 BRDF |
| **Refraction（折射）** | 光穿过透明介质 | BTDF（Snell 定律） |
| **Transmission（透射）** | 光穿过物体 | BSDF = BRDF + BTDF |
| **Subsurface Scattering（次表面散射）** | 光进入半透明介质后扩散 | BSSRDF |

### 1.4 光照分解

一个像素的最终颜色可以分解为：

$$
L_{\text{pixel}} = \underbrace{L_e}_{\text{自发光}} + \underbrace{L_{\text{direct}}}_{\text{直接光}} + \underbrace{L_{\text{indirect}}}_{\text{间接光}}
$$

其中：

$$
L_{\text{direct}} = \sum_{k} L_k^{\text{light}} \cdot f_r \cdot V_k \cdot \cos\theta_k
$$

$$
L_{\text{indirect}} = \int_{\Omega} f_r \cdot L_i^{\text{bounce}} \cdot \cos\theta \, d\omega
$$

---

## 2. 光源类型与采样

### 2.1 点光源（Point Light）

#### 数学表示

$$
E(\mathbf{x}) = \frac{\Phi}{4\pi r^2}, \quad L_i = \frac{I}{r^2} \cdot \text{dir}
$$

从点光源到表面点 $\mathbf{x}$ 的辐射照度按距离平方衰减。

#### 采样方法

| 方法 | 原理 | 适用场景 |
|---|---|---|
| **直接采样** | 光源是零体积点，方向唯一确定，无需随机采样 | 实时渲染、离线渲染 |
| **Shadow Ray** | 从交点向光源方向发射阴影光线判断遮挡 | 所有 PT/RT 渲染器 |

#### 特点

- **物理真实性**：不严格物理正确（零体积点光源在现实中不存在），但数学方便
- **问题**：无法产生软阴影、无面积
- **近似真实**：用多个点光源近似面光源

### 2.2 方向光（Directional Light）

#### 数学表示

$$
L_i(\mathbf{x}, \omega) = L_0 \cdot \delta(\omega - \omega_d)
$$

所有光线平行，方向 $\omega_d$ 固定，无距离衰减。

#### 采样方法

| 方法 | 原理 |
|---|---|
| **直接采样** | 方向固定，Shadow Ray 沿 $-\omega_d$ 方向 |
| **Cascaded Shadow Map** | 实时渲染中用多级 Shadow Map 覆盖大范围 |

#### 特点

- 模拟太阳光
- 无距离衰减（或不物理的线性衰减）
- 产生硬阴影

### 2.3 面光源（Area Light）

#### 数学表示

$$
L_i(\mathbf{x}, \omega) = \int_{A_{\text{light}}} L_e(\mathbf{x}', \omega) \cdot V(\mathbf{x}, \mathbf{x}') \cdot \frac{\cos\theta' \cdot \cos\theta}{r^2} \, dA'
$$

对光源表面积分，考虑可见性 $V$ 和几何项。

#### 采样方法

| 方法 | 原理 | 适用场景 |
|---|---|---|
| **均匀面积采样** | 在光源表面均匀采样点 | 离线 PT |
| **重要性采样** | 按立体角/贡献采样 | 离线 PT 降噪 |
| **LTC（Linearly Transformed Cosines）** | 用线性变换把余弦分布映射到多边形面光源 | 实时渲染 |
| **Representative Point Method** | 用一个代表点近似面光源 | 实时渲染 |
| **Sphere/Disk Analytic** | 球形/圆盘面光源的解析解 | 实时渲染 |

#### 特点

- 产生软阴影
- 物理正确
- 计算代价高（需要对面积分）

### 2.4 聚光灯（Spot Light）

#### 数学表示

$$
I(\theta) = I_0 \cdot \cos^n\theta \quad (\theta < \theta_{\text{cutoff}})
$$

点光源 + 角度衰减。

#### 采样

- 与点光源类似，Shadow Ray + 角度裁剪
- 实时渲染中用 Shadow Map

### 2.5 IBL / 环境光（Infinite Area Light）

#### 数学表示

$$
L_i(\mathbf{x}, \omega) = L_{\text{env}}(\omega), \quad \forall \mathbf{x}
$$

来自无限远的环境贴图，$L_i$ 只与方向有关，与位置无关。

#### 采样方法

| 方法 | 原理 | 适用场景 |
|---|---|---|
| **均匀半球采样** | 在半球均匀采样方向 | 离线 PT（高噪声） |
| **亮度重要性采样** | 按环境贴图亮度分布采样 | 离线 PT（PBRT 默认） |
| **多级 Mipmap 采样** | 按粗糙度选择 mip 层级 | 实时 Specular IBL |
| **球谐投影** | 把环境光投影到 SH 基函数 | 实时 Diffuse IBL |
| **Prefiltered Env Map** | 预卷积不同粗糙度的环境贴图 | 实时 Specular IBL |

详见 [第 3 节](#3-环境光照技术)。

### 2.6 光源采样策略对比

| 光源类型 | 实时方法 | 离线方法 | 软阴影 |
|---|---|---|---|
| 点光源 | Shadow Map | Shadow Ray | 否 |
| 方向光 | CSM | Shadow Ray | 否 |
| 面光源 | LTC / RPS | 面积采样 + MIS | 是 |
| 聚光灯 | Shadow Map | Shadow Ray | 否 |
| IBL | SH / Prefiltered Map | 重要性采样 | N/A |

### 2.7 多重重要性采样（MIS）

当同时有 BRDF 采样和光源采样两条路径时，用 MIS 加权合并：

$$
\hat{L} = \sum_{i} w_i \cdot \frac{f(\omega_i)}{p_i(\omega_i)}
$$

Veach 提出的 Balance / Power Heuristic 保证方差最低。这是现代 PT 的标配。

---

## 3. 环境光照技术

### 3.1 IBL（Image-Based Lighting）

#### 原理

用一张 HDR 环境贴图表示来自四面八方的入射光，提供 LTE 中的 $L_i(\omega)$。

$$
L_o = \int_{\Omega} f_r \cdot L_{\text{env}}(\omega_i) \cdot \cos\theta_i \, d\omega_i
$$

#### 分类

| 子问题 | 方法 | 说明 |
|---|---|---|
| **Diffuse IBL** | Irradiance Map / SH | 低频，可用少数系数近似 |
| **Specular IBL** | Prefiltered Env Map + BRDF LUT | 按粗糙度预卷积 |
| **Background** | 直接采样环境贴图 | Primary Ray 未命中时 |

### 3.2 Diffuse IBL

#### Irradiance Map（辐照度贴图）

对每个法线方向 $\mathbf{n}$，预计算半球积分：

$$
E(\mathbf{n}) = \int_{\Omega(\mathbf{n})} L_{\text{env}}(\omega_i) \cdot \cos\theta_i \, d\omega_i
$$

结果存成一张 Cube Map，运行时用法线 $\mathbf{n}$ 查表。

| 特点 | 说明 |
|---|---|
| 分辨率 | 通常 32×32×6，因为低频 |
| 内存 | 中等 |
| 质量 | 漫反射足够 |
| 局限 | 不考虑遮挡 |

#### Spherical Harmonics（球谐函数）

把 $L_{\text{env}}(\omega)$ 投影到 SH 基函数：

$$
L_{\text{env}}(\omega) \approx \sum_{l=0}^{n} \sum_{m=-l}^{l} c_l^m \, Y_l^m(\omega)
$$

| 阶数 | 系数个数 | 适用 |
|---|---|---|
| 1 阶 (L1) | 4 | 常数 + 方向光近似 |
| 2 阶 (L2) | 9 | 常见实时渲染 |
| 3 阶 (L3) | 16 | 高质量 |

Diffuse 卷积后 SH 自动降一阶（因为 $\cos\theta$ 卷积会衰减高频），所以 **2 阶 SH 存储 3 阶环境光的 diffuse 结果**。

| 特点 | 说明 |
|---|---|
| 内存 | 极小（9~16 个 float3） |
| 质量 | 极低频，高频细节丢失 |
| 适用 | 动态物体 Diffuse GI、移动端 |

### 3.3 Specular IBL（Split Sum Approximation）

Epic Games 在 Unreal Engine 4 中提出的近似（LearnOpenGL PBR/IBL/Specular-IBL）：

$$
L_o \approx \left( \sum_k \text{PrefilteredEnvMap}(\omega_r, \text{roughness}) \right) \times \left( \text{BRDF LUT}(\mathbf{n} \cdot \mathbf{v}, \text{roughness}) \right)
$$

将 LTE 的镜面积分拆为两部分：

| 部分 | 预计算方法 | 存储形式 |
|---|---|---|
| **Prefiltered Environment Map** | 按 NDF 对环境贴图卷积，不同 mip 对应不同 roughness | Cube Map Mipmap |
| **BRDF Integration LUT** | 预计算 $\int f_r \cdot \cos\theta \, d\omega$ 的 scale 和 bias | 2D LUT (R=scale, G=bias) |

| 特点 | 说明 |
|---|---|
| 分辨率 | Prefiltered Map 通常 128×128×6，多级 mip |
| 内存 | 中等 |
| 质量 | 中高频镜面反射 |
| 局限 | 单次弹射近似，无多 bounce 间接镜面 |

### 3.4 环境贴图表示

| 格式 | 投影方式 | 优点 | 缺点 |
|---|---|---|---|
| **Equirectangular（等距圆柱）** | 经纬度展开 | 简单、通用 | 两极畸变 |
| **Cube Map** | 6 个面 | 均匀、GPU 原生支持 | 需要 6 张纹理 |
| **Dual Paraboloid** | 两个抛物面投影 | 比 Cube Map 少纹理 | 有畸变 |
| **Octahedral** | 八面体投影 | 均匀、紧凑 | 需要重映射 |

### 3.5 天空盒（Skybox）

天空盒是 IBL 的一种可视化呈现，用于渲染远景背景。

| 技术 | 原理 | 适用 |
|---|---|---|
| **Cube Map Skybox** | 6 面纹理包裹相机 | 经典方案 |
| **Equirectangular Skybox** | 经纬度纹理映射到球面 | HDR 环境贴图常见 |
| **Procedural Sky** | 大气散射模型实时计算 | 动态日夜循环 |
| **Sky Dome** | 顶部半球几何体 | 简单方案 |

天空盒与环境贴图的关系：

```text
环境贴图 (HDR) ──作为背景渲染──> 天空盒
环境贴图 (HDR) ──作为光照计算──> IBL
```

同一张 HDR 环境贴图既用于背景显示（天空盒），也用于光照计算（IBL）。

### 3.6 Light Probe（光照探针）

#### 原理

在场景中特定位置采样环境光照，存储成 SH 或 Cube Map，供附近物体查询。

#### 类型

| 类型 | 说明 | 适用 |
|---|---|---|
| **Static Probe** | 离线烘焙，不可移动 | 静态场景 |
| **Real-time Probe** | 运行时实时捕获（渲染 Cube Map） | 动态场景 |
| **Baked Probe** | 烘焙到 Irradiance Volume | 静态 GI + 动态物体 |

#### 与 IBL 的关系

Light Probe 是 IBL 的**空间化**——IBL 假设光照来自无限远（全场一致），Light Probe 则在场景不同位置放置不同的环境光采样点，捕捉光照的空间变化。

```text
IBL (无限远) ──空间化──> Light Probe (逐位置)
Light Probe (离散点) ──网格化──> Irradiance Volume (体素网格)
```

---

## 4. 全局光照（GI）

### 4.1 GI 的组成

$$
\text{GI} = \text{Direct Lighting} + \text{Indirect Lighting}
$$

| 组成 | 来源 | 求解方法 |
|---|---|---|
| 直接光 | 光源直达 | NEE / Shadow Map |
| 一次间接光 | 光源→表面A→表面B | Lightmap / Probe / PT 1 bounce |
| 多次间接光 | 多次反射 | PT / Photon Mapping / VPL |

### 4.2 离线 GI 方法

| 方法 | 原理 | 无偏性 | 适用 |
|---|---|---|---|
| **Path Tracing** | 从相机随机走路径 | 无偏 | 通用 |
| **BDPT** | 双向路径 + 连接 | 无偏 | 困难光路 |
| **MLT** | MCMC 路径采样 | 无偏 | Caustics |
| **Photon Mapping** | 光子追踪 + 密度估计 | 有偏一致 | Caustics、SDS |
| **VCM** | BDPT + Photon Mapping | 一致 | 通用 |
| **Radiosity** | 有限元求矩阵解 | 有偏 | 纯漫反射 |

### 4.3 实时 GI 方法

| 方法 | 原理 | 代表引擎 |
|---|---|---|
| **Lightmap** | 离线烘焙静态 GI 到纹理 | UE, Unity |
| **Irradiance Volume** | 空间网格存储 SH irradiance | UE, Unity |
| **Light Probe** | 离散点采样环境光 | UE, Unity |
| **LPV（Light Propagation Volume）** | 体素传播间接光 | CryEngine, UE |
| **VXGI（Voxel Cone Tracing）** | 体素化场景 + 锥追踪 | UE (实验) |
| **SDFGI** | SDF 加速光线步进 | UE5 |
| **Lumen** | Surface Cache + SDF + Probe 混合 | UE5 |
| **SSAO / SSDO / SSR** | 屏幕空间近似 | 通用 |
| **RTX RT** | 硬件光线追踪 | UE5, Unity HDRP |
| **RTX PT** | 硬件路径追踪（实验） | UE5, Unity HDRP |

### 4.4 Lumen（UE5）架构

Lumen 是目前最复杂的实时混合 GI 方案：

```text
Lumen = Surface Cache (表面缓存)
      + SDF Tracing (距离场光线追踪)
      + Radiance Probe (辐射探针)
      + Screen Space GI (屏幕空间 GI)
      + Hardware RT (可选加速)
```

| 组件 | 作用 |
|---|---|
| Surface Cache | 缓存场景表面的反照率、法线、辐照度 |
| SDF Tracing | 用全局 SDF 做快速光线求交，计算遮挡 |
| Radiance Probe | 网格化探针采样间接光，用 SH 编码 |
| Screen Space GI | 屏幕空间补充细节 |
| Hardware RT | DXR 加速高质量反射/GI（可选） |

---

## 5. 遮蔽与环境光

### 5.1 Ambient Occlusion（AO）

#### 原理

AO 近似一个点被周围几何遮挡的程度：

$$
A(\mathbf{x}) = \frac{1}{\pi} \int_{\Omega} V(\mathbf{x}, \omega) \cdot \cos\theta \, d\omega
$$

其中 $V$ 是可见性函数（未遮挡为 1，遮挡为 0）。

#### 物理意义

AO 回答的是"这个点能接收到多少环境光"——被周围几何挡住越多，AO 值越低（越暗）。

| 特点 | 说明 |
|---|---|
| 不依赖光源 | 只依赖几何形状 |
| 不考虑方向 | 标量值 [0, 1] |
| 近似间接光 | 模拟环境光被遮挡后的阴影 |

#### AO 变体

| 方法 | 原理 | 适用 |
|---|---|---|
| **AO（离线）** | 全场景射线追踪计算可见性 | 离线渲染 |
| **SSAO** | 屏幕空间采样深度缓冲 | 实时，通用 |
| **HBAO** | 屏幕空间水平基准方向遮蔽 | 实时，更精确 |
| **GTAO** | Ground Truth AO，近似离线 AO | 实时，高质量 |
| **VXAO** | 体素化场景计算 AO | 实时，高质量 |
| **RTAO** | 硬件光线追踪 AO | RTX 实时 |

### 5.2 Ambient Light

#### 传统 Ambient

$$
L_{\text{ambient}} = k_a \cdot I_{\text{ambient}}
$$

一个常数近似所有间接光，不基于物理。

#### 物理化 Ambient

| 进化 | 方法 |
|---|---|
| 常数 Ambient | Phong 模型中的 $k_a \cdot I_a$ |
| 方向 Ambient | Hemispheric Ambient（上半球/下半球不同颜色） |
| SH Ambient | 球谐系数表示方向性环境光 |
| IBL | 物理正确的环境光 |
| AO × Ambient | AO 调制环境光 |

### 5.3 Diffuse（漫反射）

#### 原理

光线均匀散射到所有方向，BRDF 为常数：

$$
f_r^{\text{diffuse}} = \frac{\rho}{\pi}
$$

#### 完整 Diffuse 项

$$
L_{\text{diffuse}} = \frac{\rho}{\pi} \int_{\Omega} L_i(\omega_i) \cos\theta_i \, d\omega_i = \frac{\rho}{\pi} \cdot E(\mathbf{n})
$$

$E(\mathbf{n})$ 就是 Irradiance，可用 Irradiance Map 或 SH 预计算。

---

## 6. 反射技术

### 6.1 反射的物理基础

镜面反射遵循反射定律：入射角 = 反射角。

$$
\omega_r = 2(\omega_i \cdot \mathbf{n})\mathbf{n} - \omega_i
$$

### 6.2 实时反射方法

| 方法 | 原理 | 质量 | 适用 |
|---|---|---|---|
| **Planar Reflection** | 翻转相机渲染反射平面 | 高 | 地面、水面 |
| **Cube Map Reflection** | 预渲染 Cube Map | 中 | 通用 |
| **SSR（Screen Space Reflection）** | 屏幕空间光线步进 | 中 | 通用，有局限 |
| **RT Reflection** | 硬件光线追踪反射 | 高 | RTX |
| **IBL Specular** | Prefiltered Env Map | 中 | 环境反射 |

### 6.3 SSR（Screen Space Reflection）

#### 原理

在屏幕空间对深度缓冲做 Ray Marching，找到反射命中点。

| 步骤 | 说明 |
|---|---|
| 1. 反射方向 | 根据法线和视线方向计算反射向量 |
| 2. Ray Marching | 在屏幕空间沿反射方向步进 |
| 3. 深度测试 | 比较步进点深度与深度缓冲 |
| 4. 命中处理 | 命中则采样颜色，未命中则 fallback 到 IBL |

| 优点 | 缺点 |
|---|---|
| 无需预计算 | 屏幕外信息缺失 |
| 动态更新 | 走样、噪点 |
| 性能可调 | 半分辨率渲染 |

---

## 7. 光照预处理与烘焙

### 7.1 Lightmap（光照贴图）

#### 原理

离线计算静态物体表面的间接光照，烘焙到 UV 纹理。

$$
\text{Lightmap}(\mathbf{u}) = \int_{\Omega} f_r \cdot L_i^{\text{indirect}} \cdot \cos\theta \, d\omega
$$

#### 流程

```text
1. UV 展开：将静态网格的 UV 展开到第二套 UV
2. 光照计算：离线 PT / Photon Mapping 计算 GI
3. 烘焙到纹理：每个 texel 存储辐照度
4. 运行时采样：着色器读取 Lightmap × Albedo
```

#### 类型

| 类型 | 存储 | 特点 |
|---|---|---|
| **普通 Lightmap** | RGB 颜色 | 最简单 |
| **Directional Lightmap** | RGB + 主方向 | 增加方向性 |
| **SH Lightmap** | SH 系数 | 完整方向性 |
| **High Precision Lightmap** | HDR float | 支持高动态范围 |

#### 烘焙引擎

| 引擎 | 烘焙器 | 方法 |
|---|---|---|
| **Unreal** | Lightmass | Photon Mapping + Final Gather |
| **Unity** | Progressive Lightmapper | Path Tracing (GPU) |
| **Unity** | Enlighten | Radiosity (实时预计算) |
| **Blender** | Cycles Bake | Path Tracing |

### 7.2 Irradiance Volume（辐照度体积）

#### 原理

在三维空间放置网格化的 Light Probe，每个探针存储 SH irradiance。

#### 流程

```text
1. 在场景中放置探针网格
2. 每个探针离线计算 SH irradiance（含直接/间接光）
3. 运行时：物体位置 → 三线性插值最近 8 个探针 → SH irradiance
4. 着色：SH irradiance × Albedo / π
```

| 优点 | 缺点 |
|---|---|
| 支持动态物体 | 内存占用大 |
| 方向性信息（SH） | 精度受网格密度限制 |
| 运行时极快 | 只适合低频光照 |

### 7.3 Light Probe（光照探针）

#### 与 Irradiance Volume 的关系

| | Light Probe | Irradiance Volume |
|---|---|---|
| 布局 | 稀疏、手工放置 | 规则网格 |
| 数据 | SH / Cube Map | SH |
| 插值 | 最近邻 / 三角权重 | 三线性 |
| 适用 | 精确局部光照 | 均匀空间覆盖 |

#### 探针插值

```text
动态物体位置 P
  → 找到包围 P 的四面体（探针为顶点）
  → 计算重心坐标权重
  → 加权混合 4 个探针的 SH 系数
```

---

## 8. 光照传输数学工具

### 8.1 Spherical Harmonics（球谐函数）

#### 定义

$$
Y_l^m(\theta, \phi) = \sqrt{\frac{(2l+1)(l-|m|)!}{4\pi(l+|m|)!}} \, P_l^{|m|}(\cos\theta) \, e^{im\phi}
$$

#### 在光照中的应用

| 应用 | 说明 |
|---|---|
| **Diffuse IBL 编码** | 环境光投影到 SH，存储 9~16 个系数 |
| **Diffuse 卷积** | $\cos\theta$ 卷积使 SH 自动降频 |
| **Light Probe 存储** | 探针用 SH 存储方向 irradiance |
| **Precomputed Radiance Transfer (PRT)** | 预计算光传输矩阵，用 SH 压缩 |

#### 特性

| 阶数 | 系数 | 频率 |
|---|---|---|
| L0 | 1 | 常数（平均亮度） |
| L1 | 4 | 线性方向 |
| L2 | 9 | 二阶方向 |
| L3 | 16 | 三阶方向 |

### 8.2 Precomputed Radiance Transfer（PRT）

#### 原理

把光传输（包括遮挡、互反射）预计算为 SH 矩阵，运行时只需矩阵乘法。

$$
L_o \approx \mathbf{T} \cdot \mathbf{L}_{\text{env}}^{\text{SH}}
$$

| 矩阵 | 含义 |
|---|---|
| $\mathbf{L}_{\text{env}}^{\text{SH}}$ | 环境光的 SH 系数 |
| $\mathbf{T}$ | 预计算的光传输矩阵（含遮挡、BRDF、互反射） |

| 优点 | 缺点 |
|---|---|
| 运行时极快 | 只支持低频光照 |
| 含遮挡信息 | 预计算耗时长 |
| 支持动态环境光 | 几何/材质必须静态 |

### 8.3 Monte Carlo Integration

$$
\int f(x) \, dx \approx \frac{1}{N} \sum_{k=1}^{N} \frac{f(x_k)}{p(x_k)}
$$

| 方差缩减技术 | 原理 |
|---|---|
| **Importance Sampling** | 按 $f(x)$ 分布采样 |
| **MIS** | 多种采样策略加权组合 |
| **Russian Roulette** | 概率终止低贡献路径 |
| **Next Event Estimation** | 主动采样光源而非等待碰巧命中 |

### 8.4 Linearly Transformed Cosines（LTC）

#### 原理

Epic Games 提出，用线性变换把余弦分布映射到任意微表面 NDF：

$$
f_r^{\text{rough}} \approx M \cdot \cos\theta
$$

从而把面光源积分转化为多边形余弦积分的解析解。

#### 流程

```text
1. 预计算 LUT：每个 (roughness, θ) 对应一个变换矩阵 M
2. 运行时：用 M 变换面光源顶点
3. 解析积分：计算变换后多边形的余弦加权积分
```

| 优点 | 缺点 |
|---|---|
| 实时面光源软阴影 | 只支持 GGX BRDF |
| 解析解，无噪声 | 不支持多次弹射 |
| 质量高 | LUT 预计算离线 |

---

## 9. 引擎实现对比

### 9.1 实时光照特性对比

| 特性 | UE5 Lumen | Unity HDRP | Blender EEVEE | Blender Cycles |
|---|---|---|---|---|
| **直接光** | Rasterization | Rasterization | Rasterization | PT |
| **GI 方案** | Lumen 混合 | Lightmap + Probe + RT | Light Probe | PT |
| **反射** | SSR + Lumen + RT | SSR + RT | SSR | PT |
| **AO** | GTAO + RTAO | GTAO + RTAO | SSAO | PT |
| **IBL** | SH + Prefiltered Map | SH + Prefiltered Map | SH + Reflection Map | PT 重要性采样 |
| **阴影** | CSM + RT Shadow | CSM + RT Shadow | Shadow Map | Shadow Ray |
| **核心方法** | 混合 | 混合 | Rasterization | Path Tracing |

### 9.2 GI 技术选型决策

```text
是否需要实时？
├── 是
│   ├── 场景静态？
│   │   ├── 是 → Lightmap + Light Probe
│   │   └── 否 → Lumen / SDFGI / VXGI
│   └── 有 RTX 硬件？
│       ├── 是 → RT GI + Denoiser
│       └── 否 → SSR + SSAO + SH IBL
└── 否（离线）
    └── Path Tracing / BDPT / VCM
```

### 9.3 IBL 实现对比

| 引擎 | Diffuse IBL | Specular IBL | 编码 |
|---|---|---|---|
| **UE5** | SH (L2) | Prefiltered Map | SH 9 系数 + Mipmap Cube |
| **Unity HDRP** | SH (L2) | Prefiltered Map | SH 9 系数 + Mipmap Cube |
| **Blender Cycles** | PT 采样 | PT 采样 | 无近似，直接积分 |
| **Blender EEVEE** | Irradiance Grid | Reflection Cubemap | 网格 + Cube Map |

---

## 10. 概念关系总图

```text
光照技术体系
│
├── 光源表示
│   ├── 解析光源（点/方向/面/聚光）
│   ├── IBL（环境贴图）
│   └── 自发光网格
│
├── 直接光计算
│   ├── Shadow Map（实时）
│   ├── Shadow Ray（离线）
│   ├── NEE + MIS（PT）
│   └── LTC（实时面光源）
│
├── 间接光计算（GI）
│   ├── 离线：PT / BDPT / MLT / Photon Mapping / VCM
│   ├── 实时混合：Lumen / SDFGI / VXGI / LPV
│   ├── 预烘焙：Lightmap / Irradiance Volume
│   └── 屏幕空间：SSAO / SSDO / SSR
│
├── 环境光表示
│   ├── IBL
│   │   ├── Diffuse：Irradiance Map / SH
│   │   └── Specular：Prefiltered Map + BRDF LUT
│   ├── Light Probe
│   ├── Irradiance Volume
│   └── 天空盒
│
├── 遮蔽
│   ├── AO / SSAO / HBAO / GTAO
│   └── RTAO
│
├── 数学工具
│   ├── Monte Carlo + MIS
│   ├── Spherical Harmonics
│   ├── LTC
│   └── PRT
│
└── 反射
    ├── Planar Reflection
    ├── SSR
    ├── Cube Map Reflection
    ├── RT Reflection
    └── IBL Specular
```

---

## 11. 术语速查表

| 术语 | 全称 | 一句话解释 |
|---|---|---|
| GI | Global Illumination | 直接光 + 间接光 |
| IBL | Image-Based Lighting | 用环境贴图作为光源 |
| SH | Spherical Harmonics | 球面函数的正交基，压缩环境光 |
| AO | Ambient Occlusion | 环境光被几何遮挡的程度 |
| SSAO | Screen Space Ambient Occlusion | 屏幕空间近似 AO |
| SSR | Screen Space Reflection | 屏幕空间近似反射 |
| NEE | Next Event Estimation | 主动采样光源而非等待碰巧命中 |
| MIS | Multiple Importance Sampling | 多种采样策略加权组合 |
| LTC | Linearly Transformed Cosines | 用线性变换解析计算面光照 |
| PRT | Precomputed Radiance Transfer | 预计算光传输矩阵 |
| LPV | Light Propagation Volume | 体素传播间接光 |
| VXGI | Voxel Global Illumination | 体素锥追踪 GI |
| SDFGI | Signed Distance Field GI | SDF 加速 GI |
| CSM | Cascaded Shadow Map | 多级 Shadow Map |
| LUT | Look-Up Table | 预计算查找表 |
| BSSRDF | Bidirectional Scattering Surface Reflectance Distribution Function | 次表面散射分布函数 |
