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
10. [概念关系总图](#10-概念关系总图)
11. [阴影技术](#11-阴影技术)
12. [术语速查表](#12-术语速查表)

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

#### 探针到底存的是什么

Probe 在**位置上是三维空间的一个点**，但在**数据上不是只存一个颜色**，而是存一个**球面函数**——"从这个点看向四面八方，来的光是什么样的"。通常用 SH 压缩成几个系数（Unity 常用 L2 SH：9 个系数 × RGB = 27 个 float）。可以把它想成"空间里挂了一个隐形小球，记住了自己周围 360° 的环境光"。

Probe 存哪种光是理解它的关键：

| 光类型 | Probe 存不存 | 原因 |
|---|---|---|
| **间接光** | ✅ 主要存这个 | 多次反弹后方向性弱、低频，适合 SH 压缩 |
| **漫反射分量** | ✅ 主要存这个 | 余弦卷积把光进一步模糊成低频信号（见 8.1 节） |
| **直接光** | ❌ 一般不存 | 实时灯已在算；硬阴影/高光是高频信息，SH 表示不了；存了会和实时灯"叠两次光" |
| **镜面反射** | ❌ 基本不存 | 镜面是高频、方向性极强的信号，需要 cubemap 逐像素精度，27 个 float 远远不够 |

> 例外：若引擎选择"烘焙直接光"模式（如 Unity 的 Baked Lights 模式，实时灯被禁用或仅作预览），probe / lightmap 也会包含直接光——此时不存在重复计算的问题。

#### 与 Reflection Probe 的分工

| | Light Probe | Reflection Probe |
|---|---|---|
| 服务对象 | 漫反射（动态物体/角色的环境漫射光） | 镜面反射（金属、光滑表面） |
| 存储格式 | SH 系数（L2 ≈ 27 float） | Cubemap（128²、256² 或更高，多 mip 对应不同粗糙度） |
| 能量范围 | 低频（模糊的环境光） | 中高频（可辨认的反射图像） |

两者是两套并行系统，各干各的活——SH 存不下镜面，cubemap 存漫反射又太浪费，频率特性决定了这个分工。

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

#### 图集共享：不是"每个物体一张"

一个常见误解是"每个静态物体一张 lightmap"。实际是**所有静态物体"拼"进同一张（或几张）lightmap 图集（Atlas）**，就像很多小图片拼成一张大图，每个物体只占其中一小块：

- 烘焙前引擎为每个静态物体生成**第二套 UV（Lightmap UV）**，把所有参与烘焙的物体合理地摊开、排布到 0~1 的 UV 方块里，彼此不重叠、留边距
- 运行时每个物体用自己的 Lightmap UV 采样这张公共图：`indirectLight = tex2D(_Lightmap, lightmapUV)`
- Lightmap 里存的物理量是每个 texel 的 irradiance（通常也烘入直接光和阴影，取决于烘焙模式）

为什么共享图集而不是一人一张：

| 原因 | 说明 |
|---|---|
| Draw Call / 纹理切换 | 每物体一张 → 切换巨多，性能爆炸 |
| 显存 | 大量小图的边角浪费严重 |
| 一致性 | 同一张图里间接光、阴影统一计算，物体间更协调 |

出现**多张** lightmap 的场景（不是按物体分，而是按管理单位分）：

1. **场景太大**：一张放不下 → 分页，物体记录 `Lightmap Index` + 本页内 UV 偏移缩放
2. **烘焙参数不同**：室内/室外分开
3. **质量分级**：近处高精度、远处低精度
4. **流式加载**：大世界按需加载

#### Lightmap UV 的硬性要求（为什么不能复用普通 UV）

| | 普通纹理 UV | Lightmap UV |
|---|---|---|
| 目的 | 采样材质细节（颜色/法线/金属度） | 采样烘焙好的光照 |
| 重叠 | 可以（对称物体左右共用一块贴图省空间） | **禁止**——空间中两个不同位置的面共享 texel，光照必然有一边错误（如一边向阳一边背阴） |
| 镜像 | 可以（省贴图空间） | **禁止**——镜像的两块表面朝向不同方向，但共享同一份光照，间接光/法线相关计算必错 |
| 边距 | 无所谓 | **必须留 padding**（见下） |
| 均匀性 | 相对宽松 | 要求均匀展开，避免局部光照分辨率失衡 |

> 一句话：普通 UV 为"省空间/好看"优化，Lightmap UV 为"算光正确"优化，目标冲突，必须两套。

#### 接缝 padding：防光照渗色

GPU 双线性过滤在 UV 岛边界会取相邻纹素插值。若两个物体的 UV 岛紧挨着，采样点靠近边界时插值会混入邻居的光照颜色——**渗色（Light Bleeding）**：

```text
无 padding： | 物体A像素 | 物体B像素 |   → 边界采样互相偷色（红墙旁的白墙泛红）
有 padding： | A像素 | A像素 | 空白边缘 | B像素 | → 插值只混到接近自身的颜色
```

典型翻车：红墙白墙 UV 相邻 → 白墙边缘泛红；阴影区与非阴影区相邻 → 亮暗交界出现黑线/亮线。解决方法是在每个 UV 岛周围留 2~4 像素的边距，并用边缘颜色外扩（dilation）填充，而不是留黑。

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

Unity 的 Light Probe Group 把探针点做 **Delaunay 四面体化**，运行时插值流程：

1. **空间查询**：找到物体包围盒中心所在的四面体（或最近的四面体）
2. **重心坐标**：物体位置 $\mathbf{p}$ 用四面体 4 个顶点表示 $\mathbf{p} = \sum w_i \mathbf{p}_i$（$w_i \geq 0$，$\sum w_i = 1$）
3. **插值 SH 系数**（不是插值颜色，是对 27 个系数分别线性插值）：

$$
c_{\text{result}}[k] = \sum_{i} w_i \cdot c_i[k]
$$

**为什么可以直接插系数**：SH 系数是球面函数在正交基上的投影权重，本身线性——两个 probe 之间光场平滑变化时，系数也平滑变化，线性插值系数 ≈ 在两个光场之间平滑过渡。这比"先算颜色再插值"好得多：插值后的系数仍能用**任意法线**求值，物体上各朝向的表面都能得到正确方向的环境光。而规则网格布局（Irradiance Volume）则用 8 个角点做三线性插值，原理等价。

4. **着色**：用插值后的系数 + 表面法线求 irradiance（Unity 中即 `ShadeSH9(float4(normal, 1))`，见 8.1 节）

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

#### 用 SH 从法线计算 Irradiance（运行时求值推导）

对朗伯表面，法线 $\mathbf{n}$ 接收的环境漫反射光为：

$$
E(\mathbf{n}) = \int_{\Omega(\mathbf{n})} L(\omega_i) \max(0, \mathbf{n} \cdot \omega_i) \, d\omega_i
$$

直接算这个积分要采样 cubemap 上百次。SH 的做法是把积分变成**两组系数的点积**：

| 积分中的项 | SH 处理 | 时机 |
|---|---|---|
| 入射光 $L(\omega)$ | 投影成系数 $L_l^m$ | 烘焙时，一次 |
| 余弦核 $\max(0, \mathbf{n} \cdot \omega)$ | 有解析的固定系数 $A_l$ | 常数，与场景无关 |

余弦核的 SH 卷积系数（Ramamoorthi & Hanrahan 2001）：

$$
A_0 = \pi, \quad A_1 = \frac{2\pi}{3} \approx 0.667\pi, \quad A_2 = \frac{\pi}{4} = 0.25\pi, \quad A_{l \geq 3} \approx 0
$$

运行时求值：

$$
E(\mathbf{n}) = \sum_{l=0}^{2} A_l \sum_{m=-l}^{l} L_l^m \, Y_l^m(\mathbf{n})
$$

即：用当前法线算出 9 个基函数值 $Y_l^m(\mathbf{n})$，与烘焙好的系数做加权和——**每个颜色通道仅 9 次乘加**，非常便宜。Unity 的 `ShadeSH9(float4(normal, 1))` 封装的就是这一步。

**为什么 L2（9 系数）就够**：不是因为环境光本身低频，而是**漫反射的余弦卷积把光场变成了低频信号**——$A_{l\geq3}$ 被强烈衰减（$A_2/A_1 \approx 0.375$，$A_3 \approx 0$），高频成分在积分时天然被抹掉。对典型环境，L0 直流项就占了 irradiance 能量的绝大部分（约 85% 以上，随环境而异），L1 提供方向梯度（天空在上、地面在下），L2 补充低频渐变；L2 截断的平均误差远小于 1%（Ramamoorthi & Hanrahan 的结论）。这也解释了 3.6 节的结论：**Light Probe 只存间接漫反射**——高频的镜面与阴影信息在余弦卷积后本就不剩什么，SH 自然存不下也不需要存。

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

### 10.1 两个正交的分类视角

所有光照概念都可以放进"**来源 × 表面响应**"的二维矩阵里理解：

**视角一：光从哪来（弹了几次）**

| 弹射次数 | 名称 | 例子 |
|---|---|---|
| 0 次（光源直入眼睛） | 看到光源本身 | 直视灯泡、太阳 |
| 1 次（光源→表面→眼睛） | **直接光** | 实时渲染的主体 |
| 2 次+（光源→A→B→眼睛） | **间接光 = GI** | 红墙染红白地、角落不纯黑 |

**视角二：表面怎么响应（BRDF）**——同一束入射光打到同一表面**同时**产生两种分量（比例由材质决定）：

| BRDF 分量 | 行为 | 视觉 |
|---|---|---|
| Diffuse | 进入表面内部散射后均匀射出 | 柔和、无清晰高光 |
| Specular | 表面直接反弹 | 清晰反射/高光 |

两个视角相乘得到完整的六分法：直接漫反射、直接镜面、间接漫反射、间接镜面、环境漫反射、环境镜面。**环境光不是独立的第三类来源**——它是"来自无限远/包围整个场景的光源"（天空光的巨大面光源），同样按 diffuse/specular 分解处理。

### 10.2 核心包含与映射关系

| 关系 | 说明 |
|---|---|
| GI = 直接光 + 间接光 | GI 是间接光解算的工程化总称，不是"间接光"的子集或超集之外的东西 |
| 环境光 ⊆ 间接光（通常） | 天空光可视为巨型二级光源；工程上单列因为它的表示方式（cubemap/SH）特殊 |
| Lightmap → 间接漫反射（静态表面） | 逐 texel 存 irradiance；也可含烘焙直接光/阴影 |
| Light Probe → 间接漫反射（动态物体） | SH 压缩的空间采样，与 Diffuse IBL 本质同构（都是 irradiance，格式不同） |
| Reflection Probe / Specular IBL → 间接镜面 | cubemap 按粗糙度预过滤（mip） |
| IBL = Diffuse IBL + Specular IBL | 同一张 HDR 环境图派生两套数据 |
| SH ⊆ 存储格式（不是光的类型） | 低频球面函数的压缩编码，用于 irradiance；存不了高频镜面/硬阴影 |
| AO ⊆ 环境光的可见性因子 | 几何对环境光的遮挡近似，调制 ambient 项 |

### 10.3 技术总树

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

## 11. 阴影技术

### 11.1 物理层面：阴影的本质

#### 阴影在渲染方程中的位置

阴影不是独立的光照项，而是直接光计算中的**可见性因子** $V \in \{0, 1\}$（或面光源下的 $V \in [0,1]$）：

$$
L_{\text{direct}} = \sum_{k} L_k^{\text{light}} \cdot f_r \cdot \textcolor{red}{V_k} \cdot \cos\theta_k
$$

- 点光源：$V_k$ 是二值的——遮挡或不遮挡，对应**硬阴影**
- 面光源：$V_k = \dfrac{\text{未被遮挡的光源面积}}{\text{光源总面积}} \in [0,1]$——部分遮挡，对应**软阴影**

#### 本影、半影、伪本影

```text
        光源(直径D)
       ██████████
        \  |  /           ← 光源边缘的视线穿过遮挡物边缘
         \ | /
      ┌───█───┐  遮挡物(宽度B)
      └───█───┘
        ╲ │ ╱
   本影 umbra │ 半影 penumbra
   (光源完全被挡)  (光源部分被挡)
         │ 伪本影 antumbra
         │ (光源完全露出轮廓，
          └  但比未遮挡时暗？否——遮挡物视角小于光源)
```

| 区域 | 定义 | 光源可见比例 | 亮度 |
|---|---|---|---|
| **本影（Umbra）** | 光源**完全**被遮挡 | 0 | 最暗 |
| **半影（Penumbra）** | 光源**部分**被遮挡 | (0, 1) | 中间过渡 |
| **伪本影（Antumbra）** | 遮挡物在光源前的角尺寸**小于**光源 | 接近 1（轮廓外环） | 略暗于全亮 |

日食是标准示例：本影里看到全食，半影里看到偏食，更远处（月球角尺寸小于太阳）是伪本影。

#### 半影宽度的几何公式（相似三角形）

设光源直径 $D$、光源到遮挡物距离 $L_{lb}$、遮挡物到接收面距离 $L_{br}$：

$$
w_{\text{penumbra}} = D \cdot \frac{L_{br}}{L_{lb}} = L_{br} \cdot \underbrace{\frac{D}{L_{lb}}}_{\text{光源角尺寸 } \alpha}
$$

**太阳的算例**：太阳直径约 $1.39\times10^6$ km，日地距离 $1.5\times10^8$ km，角尺寸 $\alpha \approx 0.0093$ rad ≈ 0.53°。则：

- 遮挡物后方 1 m 处：半影宽度 ≈ 9.3 mm
- 电线杆后方 10 m 处：半影宽度 ≈ 9.3 cm

**结论：太阳物理上是面光源，其阴影也是软的**——只是半影宽度通常很小，肉眼在近距离难察觉，远处（云影、高楼影子投在地面）则明显变软。**"方向光产生硬阴影"本身就是工程近似**。

#### 软硬的决定因素：光源角尺寸

$$
\text{阴影软硬} \propto \text{光源角尺寸 } \alpha = \frac{D}{L_{lb}} \times L_{br}
$$

| 光源 | 角尺寸 | 阴影 |
|---|---|---|
| 数学点光源 | 0 | 纯硬阴影（理想化，现实中不存在） |
| 方向光（太阳近似） | → 0 | 近似硬阴影（真实太阳有 0.53°） |
| 室内灯泡（近距离） | 较大 | 明显软阴影 |
| 阴天全天空 | 180°（整个半球） | 无清晰边界的极软阴影（均匀漫射） |

### 11.2 软阴影 vs 硬阴影对比

| | 硬阴影 | 软阴影 |
|---|---|---|
| **光源模型** | 点光源 / 方向光（零角尺寸） | 面光源（有限角尺寸） |
| **边缘** | 二值跳变（0 → 1） | 渐变过渡带（半影） |
| **本影/半影** | 只有"影/非影" | 本影 + 半影（+ 伪本影） |
| **可见性 $V_k$** | $\{0, 1\}$ | $[0, 1]$ 连续 |
| **物理真实性** | 理想化极限 | 真实世界的普遍情况 |
| **计算难度** | 一次遮挡查询 | 需对光源面积积分（或采样多次遮挡查询） |
| **实时技术** | Shadow Map 单次采样 + bias | PCF / PCSS / VSM / RT 面光源采样 |
| **离线技术** | Shadow Ray（点光） | 面光源上多重采样 Shadow Ray（MIS） |
| **视觉特点** | 边缘锐利但易走样、显生硬 | 自然、接触处硬远处软（contact hardening） |

### 11.3 只有面积光才能产生软阴影吗？

**物理层面：是的。**

半影的本质是**部分遮挡**——接收点能看到一部分光源、看不到另一部分。这要求光源在遮挡物方向上有**非零的角尺寸**（存在多个不同的"光源点"视角）。数学点光源从任何接收点看都只是一个方向，遮挡判定只能是二值的，不存在部分遮挡，因此物理上不可能产生软阴影。

**工程层面：不是——软阴影可以"伪造"。**

| 伪造手段 | 原理 | 物理正确性 |
|---|---|---|
| **PCF** | 对硬阴影做固定宽度滤波 | 不正确（半影宽度与几何无关） |
| **PCSS** | 用遮挡距离估计半影宽度，自适应滤波 | 半影宽度物理启发，半影内部过渡仍非解析 |
| **VSM/ESM/MSM** | 深度分布的统计量近似可见性 | 近似，有 light bleeding |
| **SDF 软阴影** | 光线步进时用锥与场景相交比例 | 近似但质量高、成本可控 |
| **艺术家参数** | 引擎里直接给点光源一个 radius/filter 参数 | 纯视觉需求（抗锯齿 + 美观） |

另外一个工程动机：即使光源真的是点光源，**PCF 滤波仍是必需的**——Shadow Map 分辨率有限，单次采样的硬阴影边缘会严重走样（锯齿/噪声），滤波同时承担了**抗锯齿**和"看起来像软阴影"两个职责。

### 11.4 工程层面：Shadow Map 家族

#### 基本流水线（1978, Williams）

```text
1. 从光源视角渲染场景，只存深度 → Shadow Map（一张深度纹理）
2. 主 pass 渲染时，把着色点变换到光源空间，比较深度：
      d_fragment ≤ d_shadowmap + bias  →  在光照区（V=1）
      d_fragment >  d_shadowmap + bias  →  在阴影中（V=0）
```

#### 经典问题与对策

| 问题 | 原因 | 对策 |
|---|---|---|
| **Shadow Acne**（条纹自阴影） | 深度比较精度 + 表面坡度 | depth bias、slope-scaled bias、normal offset |
| **Peter Panning**（影子脱脚） | bias 过大，接触处漏光 | bias 适度 + front-face culling 渲染 SM |
| **分辨率不足** | 光源空间 texel 覆盖过大 | 提高 SM 分辨率、CSM、 stencil optimizations |
| **走样** | 深度函数不可线性滤波（平均深度 ≠ 平均可见性） | PCF 系列（见下） |

#### 滤波软化技术谱系

| 技术 | 原理 | 半影宽度 | 成本 | 主要缺陷 |
|---|---|---|---|---|
| **PCF**（Percentage Closer Filtering） | 采样点周围取 N×N 个 SM 深度，各自比较后**平均可见性**（深度不能平均，可见性才能平均） | 固定 | 低（硬件 PCF 2×2/3×3/5×5） | 半影宽度恒定，接触处不硬化 |
| **PCSS**（Percentage-Closer Soft Shadows） | 先 blocker search 求平均遮挡深度，估计半影宽度，再按该宽度做 PCF | **可变** $w = D_{\text{light}} \cdot \frac{d_{\text{recv}} - d_{\text{block}}}{d_{\text{block}}}$（正是 11.1 的物理公式） | 中（blocker search + 可变采样数） | 采样数需求高、噪声 |
| **VSM**（Variance Shadow Map） | 存深度的一阶矩、二阶矩（μ, σ²），用 Chebyshev 不等式估计 $P(d \geq t)$ | 可变（矩可预滤波/mipmap） | 低（可 blur 预滤波） | **Light bleeding**（多层遮挡渗光） |
| **ESM**（Exponential Shadow Map） | 存 $e^{cd}$，指数函数使和的可滤波性好于深度本身 | 可变 | 低 | c 大时精度溢出、渗光 |
| **MSM**（Moment Shadow Mapping） | 存 4 阶矩，分段线性重建深度分布 | 可变 | 中 | 比 VSM 精确，渗光显著减少 |

> PCF 的关键洞察：**深度不可平均，但"是否遮挡"（0/1）可以平均**——平均 N 个二值判定就得到 [0,1] 的部分可见性，这正是半影的物理含义（光源被遮挡的比例）。

#### 大场景适配

| 技术 | 问题 | 方案 |
|---|---|---|
| **CSM**（Cascaded SM） | 方向光覆盖大范围时近处分辨率不足 | 按相机距离分 3~5 层，近层小范围高分辨率 |
| **Cube Shadow Map** | 点光源 6 个方向 | 6 面 cubemap（或 dual paraboloid 2 面） |
| **Face Index 优化** | 聚光灯/点光 | 只渲染视锥内的面 |
| **Virtual Shadow Map**（UE5） | 全场景统一超高分辨率 | 16K×16K 虚拟分页 + 按需缓存 |

### 11.5 光线追踪与 SDF 阴影

#### RT Shadow（物理正确的软阴影）

在面光源上采样 $N$ 个点，每个点发一条 shadow ray，统计可见比例：

$$
V = \frac{1}{N} \sum_{i=1}^{N} V(\mathbf{x} \to \mathbf{y}_i), \quad \mathbf{y}_i \sim p(\text{光源表面})
$$

- **物理正确**：$V$ 收敛到真实的部分遮挡比例，半影宽度、contact hardening 全部自然涌现
- **代价**：噪声 → 需要 denoiser（RTX Denoiser / ReSTIR）；离线渲染用 MIS 与 BRDF 采样组合
- RTX 时代（UE5/Unity HDRP）已是高端实时选项，配合硬件 BVH 加速

#### SDF Soft Shadow（解析式软阴影）

基于场景的带符号距离场（SDF），光线步进时跟踪"射线到场景的最小比例因子"（Inigo Quilez 公式）：

$$
\text{shadow}(\mathbf{p}) = \min_{\text{step}} \; k \cdot \frac{d_{\text{sdf}}(\mathbf{p}_{\text{step}})}{t}
$$

- $k$ 控制软度，遮挡越远半影越宽——**天然符合** 11.1 的物理直觉
- 无需 Shadow Map、无 acne、成本与步进步数相关
- 依赖场景 SDF（UE 的 Distance Fields、raymarching demo 场景）

### 11.6 其他廉价/特殊方案

| 方案 | 原理 | 适用 |
|---|---|---|
| **Baked Shadow**（lightmap 内） | 离线烘入静态阴影 | 静态物体（§7.1） |
| **Blob Shadow** | 贴一张渐变圆片 | 极低端设备/装饰 |
| **Capsule Shadow** | 角色近似为胶囊，解析软阴影 | UE 角色在远级联中的软影 |
| **Contact Shadow** | 屏幕空间短距 ray march | 补接触处细节（CSM 近层间隙） |
| **Distance Field Ambient Shadow** | SDF AO 变体 | UE 的 DFAO |
| **SSDO / SSAO 阴影分量** | 屏幕空间直接遮挡 | 近似局部软影 |

### 11.7 技术选型总表

| 技术 | 软/硬 | 物理正确性 | 实时成本 | 典型引擎 |
|---|---|---|---|---|
| Shadow Map + bias | 硬 | 二值近似 | ★ | 全部 |
| PCF | 定宽软 | 不正确 | ★★ | 全部 |
| PCSS | 变宽软 | 半影宽度正确 | ★★★ | 主机/PC 大作 |
| VSM / ESM / MSM | 可滤波软 | 统计近似 | ★★ | 部分（UE VSM） |
| CSM | 硬（配 PCF 软化） | 同 SM | ★★ | UE/Unity 方向光标配 |
| Virtual SM（UE5） | 硬+滤波 | 同 SM | ★★★ | UE5 |
| SDF Soft Shadow | 变宽软 | 近似 | ★★ | UE/raymarch |
| RT Shadow + Denoiser | 完全软 | **物理正确** | ★★★★ | UE5/Unity HDRP（RTX） |
| 面光源解析（LTC + 可见性） | 完全软 | 解析近似 | ★★★ | 小型面光（无 SM） |

#### 阴影与 GI 的分工

Shadow Map 系技术只处理**直接光的可见性**；间接光的"被遮挡"不是阴影而是 AO / GI 的可见性问题（§5.1），lightmap 中烘掉的静态阴影则同时含直接与间接成分。区分两者是避免"影子太黑"（漏掉间接补光）的关键——正确的阴影本影亮度应等于该点的间接光，而非纯黑。

---

## 12. 术语速查表

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
| PCF | Percentage Closer Filtering | 平均多次阴影比较结果得到软边 |
| PCSS | Percentage-Closer Soft Shadows | 按遮挡距离自适应半影宽度的 PCF |
| VSM | Variance Shadow Map | 存深度均值/方差，可预滤波的软阴影 |
| ESM | Exponential Shadow Map | 存指数深度，可滤波的软阴影 |
| MSM | Moment Shadow Mapping | 存 4 阶矩的高精度可滤波软阴影 |
| Light Bleeding | — | 可滤波阴影图中多层遮挡处渗光的伪影 |
