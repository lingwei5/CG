# PBR 知识点总结

> 系统整理 PBR（Physically Based Rendering）的核心概念：物理现象 → 渲染方程 → 微表面理论 → BRDF 类型 → 编辑器参数 → 公式总结。

---

# 第一章：物理现象及 PBR 涉及的物理量名词

## 1.1 八个核心光传输现象

### 1. Reflection（反射）

**定义**：光在两种介质的**界面**上改变传播方向，返回原介质。

**物理机制**：
- 满足反射定律：入射角 = 反射角（θᵢ = θᵣ）
- 反射率由 **Fresnel 方程** 决定
- 镜面反射（specular）：表面光滑 → 平行光仍平行
- 漫反射：表面粗糙 → 各方向散射

**PBR 中的体现**：
- Cook-Torrance 公式中的 `F` 项（Fresnel）
- 镜面反射 BRDF 项
- 金属表面的高光（reflection lobe）
- 微表面理论（microfacet theory）

**关键参数**：F0（法向入射反射率），决定材质"高光的基础亮度"。

---

### 2. Refraction（折射）

**定义**：光从一种介质进入**另一种介质**时，在界面改变传播方向。

**物理机制**：
- 满足 **Snell 定律**：n₁ sin θ₁ = n₂ sin θ₂
- 介质 1 和介质 2 有**不同的折射率 n**
- 涉及**两种不同物质**的界面

**PBR 中的体现**：
- BSDF（Bidirectional Scattering Distribution Function）涵盖折射
- 透明材质（玻璃、水）的渲染
- IOR（Index of Refraction）参数：
 - 空气: 1.0 | 水: 1.33 | 玻璃: 1.5 | 钻石: 2.42

**重要区分**：refraction 特指**跨界面**传播。

---

### 3. Transmission（透射）

**定义**：光**穿过同一种物质内部**的传播过程。

**物理机制**：
- 光在**同一介质**内行进
- 通常伴随**吸收**（Beer-Lambert 定律）
- 可能伴随**散射**（subsurface scattering）

**PBR 中的体现**：
- 半透明材质（皮肤、蜡、玉、牛奶）
- **Subsurface Scattering (SSS)**
- **Beer-Lambert 定律**：`T = exp(-σₜ * d)`

**与 refraction 的关系**：
```
入射界面（refraction） → 介质内部（transmission） → 出射界面（refraction）
```

---

### 4. Scattering（散射）

**定义**：光在传播过程中偏离原方向。

**物理机制**：
- 光与粒子相互作用后改变方向
- **弹性散射**（能量不变）：瑞利散射、米氏散射
- **非弹性散射**（拉曼、布里渊）

**PBR 中的体现**：
- **Micro-scale scattering**：微表面散射（microfacet 理论），由 **NDF（D 项）** 描述
- **Volume scattering**：参与介质（雾、烟、皮肤），由 **phase function** 描述
- **Subsurface scattering**：材质内部短距离散射

**重要区分**：散射强调的是**方向改变**，不涉及界面或介质变化。

---

### 5. Dispersion（色散）

**定义**：介质**折射率随波长变化**，导致不同颜色光以不同角度折射。

**物理机制**：
- 折射率 n = n(λ)，是波长的函数
- 短波（蓝）折射率 > 长波（红）折射率

**PBR 中的体现**：
- 钻石的火彩（fire）
- 透镜色差（chromatic aberration）
- 简化 PBR 通常**忽略**色散

**常见参数**：阿贝数（Abbe number）—— 色散的倒数

---

### 6. Diffraction（衍射）

**定义**：光绕过障碍物或通过小孔时**偏离直线传播**的现象。

**物理机制**：
- **Huygens-Fresnel 原理**：每个点都是次波源
- 当障碍物/孔径尺寸**接近波长**时衍射显著

**PBR 中的体现**：
- CD/DVD 光盘表面的彩虹色（光栅衍射）
- PBR 中常用 **iridescence（彩虹色）** 模拟

---

### 7. Interference（干涉）

**定义**：两束或多束**相干光**叠加时，强度重新分布。

**物理机制**：
- **相干条件**：频率相同、振动方向相同、相位差恒定
- 相长干涉 / 相消干涉

**PBR 中的体现**：
- **薄膜干涉（thin film interference）** —— 肥皂泡、油膜、蝴蝶翅膀
- 由上下表面反射的两束光干涉产生彩虹色

---

### 8. Polarization（偏振）

**定义**：光的**电场振动方向**具有特定取向。

**物理机制**：
- 自然光：各方向都有
- 线偏振 / 圆偏振 / 椭圆偏振
- 偏振态改变发生在反射（Brewster 角）、折射、散射

**PBR 中的体现**：
- 实际 PBR 引擎**通常不处理**偏振
- 偏振渲染是研究领域话题

---

## 1.2 关键对比表

### 按"是否涉及界面"分类

| 现象 | 是否涉及界面 | PBR 主流引擎是否考虑 |
|---|---|---|
| Reflection | ✅ 表面界面 | ✅ 总是 |
| Refraction | ✅ 两种介质界面 | ✅ 透明材质 |
| Transmission | 介质内部 + 进出界面 | ✅ 半透明 / SSS |
| Scattering | ❌ 介质内部 | ✅ NDF（micro）/ phase function（volume） |
| Dispersion | ✅ 界面（n 随 λ 变） | ⚠️ 高端引擎才支持 |
| Diffraction | ✅ 障碍物/孔径 | ❌ 通常忽略（除 iridescence） |
| Interference | 两束光叠加 | ⚠️ 薄膜干涉有简化模型 |
| Polarization | 各场景 | ❌ 通常不处理 |

### 按"能量守恒涉及"分类

| 现象 | 入射 → 出射的能量分配 |
|---|---|
| Reflection (F) | 决定多少能量被反射 |
| Refraction (1-F) | 决定多少能量进入第二种介质 |
| Transmission | 在介质内部，被吸收 + 散射 |
| Scattering | 在介质内改变方向，不改变总能量（弹性） |
| Dispersion | 不同波长能量按不同角度分配 |
| Diffraction | 能量绕过障碍物，分布改变 |
| Interference | 不改变总能量，只改变空间分布 |
| Polarization | 改变振动方向，不改变总能量 |

---

## 1.3 PBR 工作流中的现象映射

| 现象 | PBR 参数 | 视觉表现 |
|---|---|---|
| Reflection | F0, F90, roughness | 镜面高光、菲涅尔反射 |
| Refraction | IOR | 玻璃、水的弯曲 |
| Transmission | thickness, attenuation | 半透明物体内部 |
| Micro Scattering | roughness, NDF (D 项) | 粗糙度 |
| Volume Scattering | scattering coefficient, phase | 雾、烟、皮肤 |
| Dispersion | Abbe number | 钻石火彩 |
| Diffraction | grating density, iridescence | CD 表面、彩虹色 |
| Interference | film thickness, IOR | 肥皂泡、油膜、蝴蝶 |
| Polarization | （通常无） | 偏振太阳镜效果 |

---

## 1.4 容易混淆的术语对比

### Reflection vs Refraction

| | Reflection | Refraction |
|---|---|---|
| 位置 | 同一介质侧 | 跨介质 |
| 方向 | 反射（θᵢ = θᵣ） | 折射（Snell 定律） |
| 能量 | F（部分） | 1 - F（部分） |
| 例子 | 镜面 | 玻璃透光 |

### Transmission vs Refraction

| | Transmission | Refraction |
|---|---|---|
| 位置 | 介质内部 | 界面处 |
| 是否改变方向 | 不一定 | 一定改变（Snell 定律） |
| 介质数量 | 同一种介质 | 两种介质 |
| 例子 | 光在水中直行 | 光从空气进入水 |

### Scattering vs Reflection

| | Scattering | Reflection |
|---|---|---|
| 是否光滑表面 | 任何表面 | 平滑或按 microfacet |
| 方向分布 | 各向同性 / 复杂 | Fresnel 决定的反射方向 |
| 物理本质 | 粒子与光作用 | 边界条件求解 |

### Dispersion vs Diffraction

| | Dispersion | Diffraction |
|---|---|---|
| 起因 | 折射率 n 随波长变 | 障碍物/孔径 |
| 物理过程 | 折射 | 波动传播 |
| 视觉效果 | 白光变彩光 | 边缘模糊、彩虹 |
| 例子 | 棱镜、钻石 | 单缝、CD 光栅 |

### Interference vs Diffraction

| | Interference | Diffraction |
|---|---|---|
| 光源 | 多束**相干光** | 单一波前被分割 |
| 经典解释 | 叠加原理 | Huygens-Fresnel 原理 |
| 例子 | 双缝、薄膜 | 单缝、圆孔 |

---

# 第二章：Rendering Equation（渲染方程）

> 用微元法（infinitesimal calculus）的视角理解渲染方程、立体角、BRDF 等核心概念。

## 2.1 核心思想

渲染方程本质上是一个**积分方程**——把"所有方向来的光"加起来：

```
总反射 = Σ(每个方向来的光 × 该方向的权重) × 微元
 = ∫ 入射光 × BRDF × cosθ × dω
```

## 2.2 辐射度量学基础

### 辐射通量（Radiant Flux）Φ

单位时间通过某区域的总能量，单位：W（瓦特）。

### 辐照度（Irradiance）E

单位面积接收的辐射通量：

```
E = dΦ / dA 单位: W/m²
```

### 辐射亮度（Radiance）L

单位投影面积、单位立体角的辐射通量：

```
L = d²Φ / (dA·cosθ · dω) 单位: W/(m²·sr)
```

这是渲染中最核心的量——"从某个方向看，某个点有多亮"。

### 各量关系

```
Φ ──÷dA──→ E（辐照度）
 ──÷(dA·cosθ·dω)──→ L（辐射亮度）

L 是 E 在方向上的"密度"
E = ∫(Ω) L·cosθ·dω
```

## 2.3 立体角 dω 的微元理解

### 什么是立体角

平面角 θ 是弧长/半径，立体角 ω 是**面积/半径²**：

```
平面角: dθ = dl / r (单位: 弧度 rad)
立体角: dω = dA / r² (单位: 球面度 sr)
```

### 微元推导

在球面上取一个微元面片：

```
 球面微元 dA
 ┌─────┐
 ╱ ╲
 │ r │ ← 半径 r
 ╲ ╱
 └─────┘
 ● 球心

dω = dA / r²
```

球坐标下：

```
dA = (r·dθ) × (r·sinθ·dφ) = r² · sinθ · dθ · dφ
dω = dA / r² = sinθ · dθ · dφ
```

**关键**：dω 是**无量纲**的（面积/面积），但单位是 sr（球面度）。

### 全空间积分

```
∫_半球 dω = ∫(0→2π) ∫(0→π/2) sinθ dθ dφ = 2π sr
∫_全球 dω = 4π sr
```

## 2.4 反射方程（Reflection Equation）

### 从"一束光"开始

考虑从方向 ωᵢ 来的**一束光**，打在表面点 p 上：

```
 入射光 Lᵢ(p, ωᵢ)
 ╲
 ╲ θᵢ
 ─────────●───────── 表面
 │╲
 │ ╲ θₒ
 │ ╲
 观察方向 ωₒ
```

### 辐照度的微元

入射光 Lᵢ 是辐射亮度，要得到表面接收的辐照度，需要乘以投影面积：

```
dE(p, ωᵢ) = Lᵢ(p, ωᵢ) · cosθᵢ · dωᵢ
 ↑ ↑ ↑
 入射辐射亮度 投影因子 立体角微元
```

**cosθᵢ 的微元意义**：

```
入射光方向
 ╲
 ╲ θ
 ╲
 ─────●───── 表面
 │
 │ dA (实际面积)
 │
 dA⊥ = dA·cosθ (投影面积)
```

光"看到"的面积是 dA·cosθ，不是 dA。所以单位面积接收的功率要乘 cosθ。

### BRDF 的微元意义

BRDF（双向反射分布函数）定义为：

```
fᵣ(p, ωᵢ → ωₒ) = dLₒ(p, ωₒ) / dE(p, ωᵢ)
 = dLₒ(p, ωₒ) / (Lᵢ(p, ωᵢ) · cosθᵢ · dωᵢ)
```

**微元理解**：BRDF 是"单位入射辐照度产生的出射辐射亮度"。

### 积分得到反射方程

把**所有入射方向**的贡献加起来：

```
Lₒ(p, ωₒ) = ∫(Ω) fᵣ(p, ωᵢ → ωₒ) · Lᵢ(p, ωᵢ) · cosθᵢ · dωᵢ
 ↑ ↑ ↑ ↑
 出射辐射亮度 BRDF 入射光 投影×微元
```

## 2.5 完整渲染方程（The Rendering Equation）

加上自发光项：

```
Lₒ(p, ωₒ) = Lₑ(p, ωₒ) + ∫(Ω) fᵣ(p, ωᵢ → ωₒ) · Lᵢ(p, ωᵢ) · cosθᵢ · dωᵢ
 ↑ ↑
 自发光 反射部分
```

**各项含义**：

| 符号 | 名称 | 含义 | 单位 |
|---|---|---|---|
| Lₒ(p, ωₒ) | 出射辐射亮度 | 从点 p 沿 ωₒ 方向发出的光 | W/(m²·sr) |
| Lₑ(p, ωₒ) | 自发光辐射亮度 | 表面自身发出的光 | W/(m²·sr) |
| Lᵢ(p, ωᵢ) | 入射辐射亮度 | 从 ωᵢ 方向到达点 p 的光 | W/(m²·sr) |
| fᵣ | BRDF | 反射特性函数 | 1/sr |
| cosθᵢ | 投影因子 | 入射角余弦 | 无量纲 |
| dωᵢ | 立体角微元 | 入射方向微元 | sr |
| Ω | 半球域 | 上半球所有方向 | — |

## 2.6 关键洞察

### 为什么是 cosθ 而不是别的

```
光通量 Φ = L · dA⊥ · dω = L · (dA·cosθ) · dω
辐照度 E = dΦ/dA = L · cosθ · dω
```

cosθ 来自**投影面积**，是几何必然，不是经验系数。

### 为什么积分域是半球 Ω

光从表面**下方**来（cosθ < 0）不会照亮表面（不透明材质），所以只积上半球。

### 能量守恒的微元验证

对于理想 Lambert 表面（fᵣ = ρ/π）：

```
∫(Ω) fᵣ · cosθ · dω = (ρ/π) · ∫(Ω) cosθ · dω
 = (ρ/π) · π = ρ ≤ 1 ✅
```

### 数值计算：蒙特卡洛

```
Lₒ ≈ (1/N) · Σᵢ [fᵣ(ωᵢ→ωₒ) · Lᵢ(ωᵢ) · cosθᵢ / pdf(ωᵢ)]
```

## 2.7 Lo 与 Li 的物理量辨析（Radiance vs Irradiance）

### 结论先行

在渲染方程中，**`Lₒ` 和 `Lᵢ` 都是 Radiance（辐射亮度）**，不是 Irradiance。

- **`Lₒ(p, ωₒ)`** = 从点 p 沿方向 ωₒ **出射的 Radiance**（outgoing）
- **`Lᵢ(p, ωᵢ)`** = 从方向 ωᵢ **入射到点 p 的 Radiance**（incoming）

下标 `o`/`i` 只表示**方向**（出射/入射），**不表示物理量类型**——两者都是 Radiance。

### 为什么必须是 Radiance

**Radiance 的核心特性**：沿光线传播时 **Radiance 守恒**（在无吸收的真空中）。即从光源表面某点沿方向 ω 发出的 Radiance = 沿该光线到达接收点 p 的 Radiance，中途不变，不用做几何衰减。所以反射方程中光源贡献直接用 `Lᵢ(p, ωᵢ)`（来自环境图某方向的入射 Radiance）就能代表光线的"强度"。

**Irradiance 不具备这个特性**：Irradiance **没有方向**，是标量（已经对整个半球积分）。而 `Lᵢ` 是带方向的，必须是 Radiance，所以 **Lᵢ 不可能是 Irradiance**。

### 两者的转换公式

**Irradiance = Radiance 的半球积分**：

```
E(p) = ∫(Ω) Lᵢ(p, ωᵢ) · (n · ωᵢ) · dωᵢ
                    ↑       ↑        ↑
                Radiance  cosine  solid angle
```

物理意义：Irradiance 是所有方向入射的 Radiance 经余弦加权后的"总和"。

### 在反射率方程中的体现

```
Lₒ(p, ωₒ) = ∫(Ω) fᵣ(p, ωᵢ→ωₒ) · Lᵢ(p, ωᵢ) · (n·ωᵢ) · dωᵢ
                ↑           ↑              ↑            ↑        ↑
             BRDF     入射 Radiance     Radiance    余弦项  立体角
```

右侧积分出来正好是 Irradiance（带 BRDF 调制后）。BRDF `fᵣ` 的作用：把 Irradiance 重新分配到各个出射方向 ωₒ 上，转回 Radiance。整个方程其实是 **Radiance → (积分成 Irradiance) → (BRDF 调制) → (变回 Radiance)**。

### Diffuse 情形下的转换推导

对 Lambert 漫反射 `fᵣ = k_d·c/π`（常数 BRDF），可提到积分外：

```
Lₒ(p, ωₒ) = (k_d·c/π) · ∫(Ω) Lᵢ(p, ωᵢ) · (n·ωᵢ) dωᵢ
                       ↑                      ↑
                     常数 BRDF            这部分就是 Irradiance E(p)
```

即：

```
Lₒ = (k_d·c/π) · E(p)
                  ↑
            用 Irradiance 算 Radiance
```

这正是 LearnOpenGL Diffuse IBL 节代码的逻辑：

```glsl
vec3 irradiance = texture(irradianceMap, n).rgb;   // 预计算的 E(p)
vec3 diffuse    = irradiance * albedo / PI;         // 即 (k_d·c/π)·E(p) = Lₒ
```

### Irradiance Map 烘焙的本质

卷积着色器中双重 for 循环计算的正是上面公式中的积分：

```glsl
irradiance += texture(environmentMap, sampleVec).rgb * cos(theta) * sin(theta);
//                 ↑ Radiance (Lᵢ)                                  ↑
//                                                  球面坐标的立体角微元 dω = sin θ dθ dφ
```

**对照积分公式**：

```
E(p) = ∫(Ω) Lᵢ(p, ωᵢ) · cosθ · dωᵢ
     ≈ Σ Lᵢ(sampleVec) · cosθ · (sinθ·Δθ·Δφ)
                              ↑
                       球坐标下 dω = sinθ·dθ·dφ
```

完美对应：`texture(envMap, sampleVec).rgb` = `Lᵢ`（Radiance），`cos(theta)` = 余弦项，`sin(theta)·Δθ·Δφ` = `dω`。**所以 Irradiance Map 存储的每个纹素值 = 该法线方向上半球内所有入射 Radiance 的余弦加权积分**，即 Irradiance E(p)。

### 数据流总结

```
环境 cubemap (每个纹素 = Radiance Lᵢ)
        ↓ 半球积分 + 余弦加权
   Irradiance Map (每个纹素 = Irradiance E)
        ↓ 采样 E(n) 乘以 albedo/π
   最终漫反射颜色 = Lₒ (Radiance, 出射方向)
```

### 常见误区澄清

| 混淆点 | 正确理解 |
|---|---|
| "Lᵢ 是 Irradiance 吧？" | ❌ Lᵢ 是 **Radiance**，带方向的入射光 |
| "Irradiance Map 存的是 Radiance 吗？" | ❌ 存的是 **Irradiance**，已对半球积分 |
| "BRDF 把 Irradiance 转成 Radiance？" | ✅ 正确，BRDF 是 Irradiance→Radiance 的转换函数 |
| "Lₒ 是 Irradiance？" | ❌ Lₒ 是 **Radiance**，出射方向的光亮度 |
| "为什么 Irradiance 没方向？" | ✅ 因为它已对所有方向积分，是标量 |

**核心记忆点**：
- **带方向 (ω) 的量** → Radiance（如 `Lᵢ`, `Lₒ`）
- **不带方向、已积分的量** → Irradiance（如 `E(p)`, irradiance map 纹素值）
- **二者关系**：`Irradiance = ∫ Radiance · cosθ · dω`

## 2.8 BRDF 积分为什么仍是 Radiance

### 关键：BRDF 的单位把 Irradiance "重新变回" Radiance

#### 从单位量纲看本质

三个量的量纲：

| 量 | 单位 | 含义 |
|---|---|---|
| Radiance `L` | `W · sr⁻¹ · m⁻²` | 每单位面积每立体角的功率 |
| Irradiance `E` | `W · m⁻²` | 每单位面积的功率（已对方向积分） |
| **BRDF** `fᵣ` | **`sr⁻¹`** | **每立体角的倒数** |

**核心洞察**：BRDF 的单位是 `sr⁻¹`，正好是立体角的倒数。所以：

```
Irradiance · BRDF · dω = (W · m⁻²) · (sr⁻¹) · (sr)
                       = W · m⁻² · sr⁻¹
                       = Radiance
```

量纲对得上！BRDF 的作用就是**把 Irradiance 重新分配到出射方向 ωₒ 上，恢复出 Radiance 的量纲**。

### 从反射率方程拆解理解

```
Lₒ(p, ωₒ) = ∫(Ω) fᵣ(p, ωᵢ→ωₒ) · Lᵢ(p, ωᵢ) · (n·ωᵢ) · dωᵢ
```

拆开看每个乘积项的物理意义：

```
                            Lᵢ(p, ωᵢ) · (n·ωᵢ) · dωᵢ
                            ↑        ↑          ↑        ↑
                          Radiance  cos θ    立体角
                          
                          ↑ 这一坨积分起来 = Irradiance E(p)
                          
     fᵣ(p, ωᵢ→ωₒ) · [上面的积分]
        ↑                    
     BRDF              累加到出射方向 ωₒ 的 Radiance
```

**步骤拆解**：

1. **`Lᵢ · cos θ · dωᵢ`** = 某一方向入射光对接收点贡献的 Irradiance 微元 `dE`
2. **`∫(Ω) ... dωᵢ`** = 把所有方向加起来 → **Irradiance E(p)**
3. **`fᵣ · dE`** = BRDF 把这部分 Irradiance **按某种比例**转换成出射方向 ωₒ 的 Radiance 微元
4. **`∫ fᵣ · dE`** = 累加所有方向的贡献 → 出射方向 ωₒ 的总 Radiance `Lₒ`

### BRDF 的本质定义：Irradiance→Radiance 的转换器

BRDF 的严格定义：

```
fᵣ(p, ωᵢ→ωₒ) = dLₒ(p, ωₒ) / dEᵢ(p, ωᵢ)
              = dLₒ / (Lᵢ · cosθ · dωᵢ)
```

**直接读出**：BRDF = **出射 Radiance 微元** ÷ **入射 Irradiance 微元**。

变形看转换过程：

```
dLₒ(p, ωₒ) = fᵣ(p, ωᵢ→ωₒ) · dEᵢ(p, ωᵢ)
            = fᵣ · Lᵢ · cosθ · dωᵢ
```

这正好就是反射率方程**积分号里面的项**！所以：

```
Lₒ(p, ωₒ) = ∫ dLₒ = ∫ fᵣ · Lᵢ · cosθ · dωᵢ
```

**结论**：反射率方程其实是**无数个 `dLₒ`（出射 Radiance 微元）的累加**，结果当然还是 Radiance。

### 直观图像：BRDF 像一个"方向分配器"

想象一点接收 100W/m² 的 Irradiance：

```
入射光来自四面八方 (Irradiance E = 100 W/m²)
                    ↓
        点 p 的表面接收
                    ↓
          BRDF 做方向分配
                    ↓
    ┌──────────────┼──────────────┐
    ↓              ↓              ↓
 镜面方向       漫反射方向     其他方向
 Lₒ=80 W/sr/m²  Lₒ=15 W/sr/m²  Lₒ=5 W/sr/m²
```

- 入射端：**所有方向汇成一个标量**（Irradiance，没方向）
- BRDF：根据材质决定"这股能量往哪些出射方向发多少"
- 出射端：**每个方向重新带上方向信息**（Radiance，有方向）

所以 BRDF 的核心作用是 **"去方向化 → 重新加方向"**：先通过积分把方向信息丢掉（变成 Irradiance），再通过 BRDF 把能量按出射方向重新分配（变回 Radiance）。

### Lambert 漫反射的特例验证

对 Lambert 材质，BRDF 是常数 `fᵣ = k_d·c/π`，可以提出积分号：

```
Lₒ = (k_d·c/π) · ∫(Ω) Lᵢ · cosθ · dωᵢ
       ↑                  ↑
     常数 BRDF          Irradiance E(p)
```

验证量纲：

```
(k_d·c/π) · E
= (无量纲) · (sr⁻¹) · (W · m⁻²)     // 注意 1/π 中的 π 来自立体角积分
= W · sr⁻¹ · m⁻²
= Radiance   ✓
```

其中 `1/π` 的来历：Lambert 表面对所有出射方向均匀反射，要把入射 Irradiance 平均分到半球立体角 `2π` 上，并考虑余弦项 `cosθₒ` 的积分 `∫(Ω) cosθₒ dωₒ = π`，所以归一化系数是 `1/π`。

### 完整数据流总结

```
Lᵢ(p, ωᵢ)  [Radiance, 带方向 ωᵢ]
     │
     │ × (n · ωᵢ) × dωᵢ       ← 提取一个方向的能量贡献
     ↓
dEᵢ(p, ωᵢ)  [Irradiance 微元, 标量]
     │
     │ ∫(Ω) ... dωᵢ           ← 对所有入射方向求和
     ↓
E(p)  [Irradiance, 无方向]
     │
     │ × fᵣ(ωᵢ → ωₒ)          ← BRDF 把能量分配到出射方向 ωₒ
     ↓
dLₒ(p, ωₒ)  [Radiance 微元, 带方向 ωₒ]
     │
     │ ∫ ...                   ← 累加所有入射方向的贡献
     ↓
Lₒ(p, ωₒ)  [Radiance, 带方向 ωₒ]
```

### 一句话答案

**BRDF 本身的单位是 `sr⁻¹`，它把 Irradiance（`W/m²`）乘上之后，量纲就恢复成 Radiance（`W·sr⁻¹·m⁻²`），并指定了出射方向 ωₒ。** 整个反射率方程就是"入射 Radiance → 积分成 Irradiance → 被 BRDF 重新分配成出射 Radiance"的过程，所以最终结果还是 Radiance。

---

# 第三章：微表面理论（Microfacet Theory）

## 3.1 核心思想

真实表面在微观尺度上是凹凸不平的。微表面理论将表面建模为**大量微小镜面（microfacets）的集合**：

- 每个微表面是**完美镜面**（只沿反射方向反射）
- 宏观 BRDF = 所有微表面反射的统计平均
- 粗糙度控制微表面法线的分散程度

```
宏观表面（看起来是平的）
 ════════════════════
微观表面（实际是凹凸的）
 ╱╲ ╱╲ ╱╲ ╱╲
 ╱ ╲╱ ╲╱ ╲╱ ╲
```

## 3.2 微表面 BRDF 的一般形式

```
fᵣ(ωᵢ, ωₒ) = D(h) · F(ωₒ, h) · G(ωᵢ, ωₒ, h) / (4 · (n·ωᵢ) · (n·ωₒ))
```

其中 **h = normalize(ωᵢ + ωₒ)** 是半角向量（half vector）。

**三项的含义**：

| 项 | 全称 | 物理含义 |
|---|---|---|
| **D(h)** | Normal Distribution Function (NDF) | 有多少微表面法线指向 h 方向 |
| **F(ωₒ, h)** | Fresnel 项 | 在 h 方向上反射了多少光 |
| **G(ωᵢ, ωₒ, h)** | Geometry（Shadowing-Masking） | 有多少微表面没有被遮挡 |

## 3.3 D 项：法线分布函数（NDF）

### 物理含义

NDF 描述微表面法线的统计分布。D(h) 越大，表示越多微表面的法线指向 h 方向。

### 常见 NDF

#### GGX / Trowbridge-Reitz（最常用 ⭐）

```
D(h) = α² / (π · ((n·h)² · (α² - 1) + 1)²)
```

- α = roughness²（Disney 映射）
- 特点：高光有"长尾"，更接近真实材质

#### Beckmann

```
D(h) = exp(-tan²θₕ / α²) / (π · α² · cos⁴θₕ)
```

- 比 GGX 更窄的高光
- 适合中等粗糙度的材质

#### Blinn-Phong（已过时）

```
D(h) = n+2/2π · (n·h)^n
```

- n 是 shininess 参数
- 不满足能量守恒

### NDF 对比

| NDF | 高光形状 | 适用场景 |
|---|---|---|
| GGX | 长尾（真实） | 通用，现代标准 |
| Beckmann | 中等 | 中等粗糙度 |
| Blinn-Phong | 窄 | 已过时 |

## 3.4 F 项：Fresnel 反射

### 物理含义

Fresnel 方程描述光在介质界面的反射率随入射角的变化。

- 垂直入射（θ = 0°）：反射率最低 = F0
- 掠射（θ → 90°）：反射率 → 1（所有材质都变镜面）

### 反射律与折射律（Fresnel 方程的物理基础）

Fresnel 方程建立在两个更基本的几何光学定律之上：

#### 反射律（Law of Reflection）

> 入射角等于反射角，且入射光线、反射光线、法线共面。

θᵢ = θᵣ

- 最早由 **欧几里得（Euclid，约公元前 300 年）** 在《反射光学》（*Catoptrics*）中系统描述
- 后由 **Hero of Alexandria（约公元 60 年）** 用"光走最短路径"原理给出物理解释
- 最终由 **Fermat（1657 年）** 用最小时间原理（Fermat's Principle）严格证明

#### 折射律（Law of Refraction / Snell's Law）

> 入射角正弦与折射角正弦之比等于两种介质折射率之反比。

n₁ sinθ₁ = n₂ sinθ₂

或等价地：

sinθ₁/sinθ₂ = n₂/n₁

- 由荷兰数学家 **Willebrord Snellius（Snell，1621 年）** 通过实验发现
- 法国哲学家 **René Descartes（1637 年）** 独立推导并在《屈光学》（*La Dioptrique*）中发表
- 因此也称为 **Snell-Descartes 定律**
- 同样可由 Fermat 最小时间原理导出

#### 反射律与折射律的关系

| | 反射 | 折射 |
|---|---|---|
| 公式 | θᵢ = θᵣ | n₁ sinθ₁ = n₂ sinθ₂ |
| 提出者 | Euclid（约 300 BC） | Snell（1621）/ Descartes（1637） |
| 物理原理 | Fermat 最小时间原理 | Fermat 最小时间原理 |
| 能量分配 | Fresnel 方程决定反射/折射比例 | 同左 |

> **关键**：反射律和折射律只决定光线的**方向**，而 Fresnel 方程决定光在反射和折射之间的**能量分配比例**。

### Schlick 近似（最常用 ⭐）

```
F(θ) = F0 + (1 - F0) · (1 - cosθ)⁵
```

其中 F0 是法向入射反射率：

```
F0 = ((n₁ - n₂) / (n₁ + n₂))²
```

**F0 公式中 n₁、n₂ 的含义**：

| 符号 | 含义 | 典型值 |
|---|---|---|
| **n₁** | 入射光所在介质的折射率（IOR） | 空气 ≈ 1.000293 ≈ **1.0** |
| **n₂** | 折射光所在介质（即物体材质）的折射率 | 水 1.33，玻璃 1.5，钻石 2.42 |

- 当光从空气射入材质时：n₁ ≈ 1，n₂ = 材质的 IOR
- 当光从材质内部射向空气（如漫反射的出射）：n₁ = 材质 IOR，n₂ ≈ 1
- F0 仅取决于两种介质的折射率之比，与入射角无关

**常见材质的 F0**：

| 材质 | F0（sRGB 近似） |
|---|---|
| 水 | (0.02, 0.02, 0.02) |
| 塑料 / 玻璃 | (0.04, 0.04, 0.04) |
| 宝石 | (0.05-0.17) |
| 铁 | (0.56, 0.57, 0.58) |
| 铜 | (0.95, 0.64, 0.54) |
| 金 | (1.00, 0.71, 0.29) |
| 铝 | (0.91, 0.92, 0.93) |

## 3.5 G 项：几何遮蔽（Geometry / Shadowing-Masking）

### 物理含义

微表面之间会相互遮挡：

- **Shadowing**：入射光被前面的微表面挡住
- **Masking**：反射光被前面的微表面挡住

### Smith 遮蔽函数

```
G(ωᵢ, ωₒ, h) = G₁(ωᵢ) · G₁(ωₒ)
```

其中 G₁ 是单方向遮蔽项。

### 常见 G 项

#### Smith GGX（最常用 ⭐）

```
G₁(ω) = 2 / (1 + √(1 + α² · tan²θ))
```

#### Smith Beckmann

```
G₁(ω) = 2 / (1 + erf(a) + 1/(a√π)·exp(-a²))
其中 a = 1/(α·tanθ)
```

### G 项对比

| G 项 | 特点 |
|---|---|
| Smith GGX | 现代标准，配合 GGX NDF |
| Smith Beckmann | 配合 Beckmann NDF |
| Cook-Torrance (1982) | 原始版本，已过时 |
| Neumann | G = (n·ωᵢ)(n·ωₒ) / max(...)，最简单 |

## 3.6 分母 4(n·ωᵢ)(n·ωₒ) 的来源

分母来自微表面 BRDF 推导中的 Jacobian 变换：

```
dωₕ / dωₒ = 1 / (4 · (ωₒ·h))
```

结合 (ωₒ·h) = (ωᵢ·h)（半角向量性质），得到分母 `4(n·ωᵢ)(n·ωₒ)`。

---

# 第四章：各种 BRDF / BSDF / BTDF / BSSRDF

## 4.1 函数族概览

| 函数 | 全称 | 描述 |
|---|---|---|
| **BRDF** | Bidirectional Reflectance Distribution Function | 反射：光从哪来、反射到哪去 |
| **BTDF** | Bidirectional Transmittance Distribution Function | 透射：光穿过表面 |
| **BSDF** | Bidirectional Scattering Distribution Function | BRDF + BTDF 的统称 |
| **BSSRDF** | Bidirectional Scattering Surface Reflectance Distribution Function | 次表面散射：光进入表面、内部散射、从别处出来 |

```
BRDF: 光从 A 方向来 → 从 B 方向反射出去（同一点）
BTDF: 光从 A 方向来 → 穿过表面从 C 方向出去（同一点）
BSSRDF: 光从 A 方向来 → 进入表面 → 内部散射 → 从 D 点、E 方向出去
```

## 4.2 常见 BRDF 模型

### Lambert（漫反射）

```
f_lambert = c / π
```

- 最简单的漫反射模型
- 假设出射光在所有方向均匀分布
- 除以 π 保证能量守恒（∫(Ω) cosθ·dω = π）
- 完全不考虑 specular

### Phong（经验模型，已过时）

```
f_phong = kd/π + ks · (r·v)^n / (n·l)
```

- 经验公式，不满足能量守恒
- n 控制高光锐度（shininess）
- 现代 PBR 已不再使用

### Blinn-Phong（Phong 的改进）

```
f_blinn_phong = kd/π + ks · (n·h)^n / (n·l)
```

- 用半角向量 h 替代反射向量 r
- 计算更快，但仍不守恒

### Cook-Torrance（微表面 BRDF ⭐）

```
f_cook_torrance = kd · c/π + ks · (D·F·G) / (4·(n·l)·(n·v))
```

- 基于微表面理论
- 满足能量守恒
- 现代 PBR 的基础

### Oren-Nayar（粗糙漫反射）

```
f_oren_nayar = c/π · (A + B · max(0, cos(φᵢ-φₒ)) · sinα · tanβ)
```

- 考虑表面粗糙度对漫反射的影响
- 粗糙表面边缘更亮（backscattering）
- 适合：石膏、沙地、月球表面

### Disney BRDF（2012）

```
f_disney = diffuse + specular + sheen + clearcoat
```

- 艺术家友好的参数化
- 5 个核心参数：baseColor, subsurface, metallic, specular, roughness 等
- 被广泛用于电影和游戏

### glTF 2.0 PBR（标准 ⭐）

```
f_gltf = (1-F)(1-metalness)·c/π + D·F·G/(4·(n·l)·(n·v))
```

- 基于 Cook-Torrance + GGX
- Metallic-Roughness 工作流
- 行业标准交换格式

## 4.3 BSDF（BRDF + BTDF）

BSDF 将反射和透射统一处理：

```
f_bsdf = f_brdf + f_btdf
```

**BTDF 的关键差异**：
- 折射方向由 Snell 定律决定（而非反射定律）
- 分母不同（涉及折射率比）
- 需要处理全内反射（TIR）

## 4.4 BSSRDF（次表面散射）

```
Lₒ(p, ωₒ) = ∫(A) ∫(Ω) S(pᵢ, ωᵢ; pₒ, ωₒ) · Lᵢ(pᵢ, ωᵢ) · cosθᵢ · dωᵢ · dA
```

- 比 BRDF 多了一个**空间维度**的积分
- 光从 pᵢ 进入，从 pₒ 出来
- 典型材质：皮肤、牛奶、玉石、蜡

**常见模型**：
- **Diffusion Profile**：用扩散方程近似
- **Burley Normalized Diffusion**（Disney SSS）
- **Path Tracing BSSRDF**：完整模拟

## 4.5 BRDF 模型对比

| 模型 | 能量守恒 | 微表面 | 漫反射 | 镜面反射 | 适用场景 |
|---|---|---|---|---|---|
| Lambert | ✅ | ❌ | ✅ | ❌ | 最简漫反射 |
| Phong | ❌ | ❌ | ✅ | ✅ | 已过时 |
| Blinn-Phong | ❌ | ❌ | ✅ | ✅ | 已过时 |
| Cook-Torrance | ✅ | ✅ | ✅ | ✅ | 现代 PBR 基础 |
| Oren-Nayar | ✅ | ❌ | ✅ | ❌ | 粗糙漫反射 |
| Disney | ✅ | ✅ | ✅ | ✅ | 电影/游戏 |
| glTF 2.0 | ✅ | ✅ | ✅ | ✅ | 行业标准 |

---

# 第五章：编辑器中的材质参数与公式的关系

## 5.1 Metallic-Roughness 工作流（glTF / Unreal / Unity）

### 核心参数

| 编辑器参数 | 物理含义 | 影响的公式项 |
|---|---|---|
| **Base Color (c)** | 表面颜色 / albedo | `kd · c/π` 中的 c |
| **Metallic** | 金属度 [0, 1] | `kd = (1-F)(1-metalness)` |
| **Roughness** | 粗糙度 [0, 1] | D 和 G 中的 α |
| **Normal Map** | 逐像素法线扰动 | n 方向 |
| **AO** | 环境光遮蔽 | 间接光照衰减 |
| **Emissive** | 自发光 | Lₑ 项 |

## 5.2 Roughness → α → D & G 的映射链

### 为什么需要映射？

直接使用 roughness 会导致高光"太窄"或"太宽"。不同引擎使用不同的映射函数。

### Disney 映射（最常用 ⭐）

```
α = roughness²
```

- roughness = 0.0 → α = 0.0（完美镜面）
- roughness = 0.5 → α = 0.25
- roughness = 1.0 → α = 1.0（完全粗糙）

**效果**：roughness 在 [0, 1] 范围内线性变化时，感知粗糙度也线性变化。

### 代入 GGX NDF

```
D(h) = α² / (π · ((n·h)² · (α² - 1) + 1)²)
 = roughness⁴ / (π · ((n·h)² · (roughness⁴ - 1) + 1)²)
```

### 代入 Smith GGX G 项

```
G₁(ω) = 2 / (1 + √(1 + α² · tan²θ))
 = 2 / (1 + √(1 + roughness⁴ · tan²θ))
```

### 完整映射链

```
编辑器 Roughness 滑块 [0, 1]
 │
 ▼
 α = roughness² (Disney 映射)
 │
 ├──→ D(h) = GGX(α) (高光形状)
 │
 └──→ G(ω) = Smith(α) (遮蔽)
```

## 5.3 Metallic → F0 的映射

### 介电体（Metallic = 0）

```
F0 = 0.04（默认，对应 IOR = 1.5 的玻璃/塑料）
```

### 金属（Metallic = 1）

```
F0 = BaseColor（金属没有漫反射，颜色来自 Fresnel 反射）
```

### 插值

```
F0 = lerp(0.04, BaseColor, metallic)
```

### 对漫反射的影响

```
kd = (1 - F) · (1 - metallic)
```

- metallic = 0（介电体）：kd = 1 - F（有漫反射）
- metallic = 1（金属）：kd = 0（无漫反射，纯镜面）

### 与折射律（Snell's Law）的关系

F0 的公式 F₀ = ((n₁ - n₂)/(n₁ + n₂))² 直接来源于折射律和 Fresnel 方程的边界条件：

#### 介电体（Metallic = 0）的 F0 与 IOR

介电体的折射率为**实数**，F0 可直接由 IOR 计算：

F₀ = ((1 - n)/(1 + n))² , (设 n₁ = 1 （空气）, n₂ = n)

| IOR (n) | F0 | 典型材质 |
|---|---|---|
| 1.0 | 0.00 | 空气（无反射） |
| 1.33 | 0.02 | 水 |
| 1.5 | 0.04 | 玻璃、塑料（glTF 默认值） |
| 1.6 | 0.05 | 宝石 |
| 2.0 | 0.11 | — |
| 2.42 | 0.17 | 钻石 |

> **glTF 默认 F0 = 0.04 的来源**：对应 IOR = 1.5，即大多数玻璃和塑料的折射率。

#### 金属（Metallic = 1）的 F0 与复折射率

金属的折射率为**复数** ñ = n + iκ（κ 为消光系数），F0 公式推广为：

F₀ = ((n - 1)² + κ^2)/((n + 1)² + κ^2)

- 金属的 κ 很大（如铜 κ ≈ 3.9），导致 F0 远高于介电体
- 不同波长的 n 和 κ 不同 → F0 有颜色（如金偏黄、铜偏红）
- 这就是为什么金属的 F0 = BaseColor（带颜色），而介电体的 F0 ≈ 0.04（无色）

| 金属 | n (红/绿/蓝) | κ (红/绿/蓝) | F0 (近似) |
|---|---|---|---|
| 铁 | 2.91 / 2.95 / 2.98 | 3.09 / 2.93 / 2.77 | (0.56, 0.57, 0.58) |
| 铜 | 0.27 / 0.97 / 1.13 | 3.63 / 2.53 / 2.39 | (0.95, 0.64, 0.54) |
| 金 | 0.18 / 0.42 / 1.37 | 3.42 / 2.35 / 1.77 | (1.00, 0.71, 0.29) |
| 铝 | 1.49 / 0.96 / 0.64 | 7.91 / 6.33 / 5.50 | (0.91, 0.92, 0.93) |

#### 完整映射链

```
折射律 (Snell's Law)
 │ n₁sinθ₁ = n₂sinθ₂
 │ 决定光线方向
 ▼
Fresnel 方程（边界条件）
 │ F₀ = (n₁-n₂/n₁+n₂)² （介电体，实数 IOR）
 │ F₀ = ((n-1)²+κ²)/((n+1)²+κ²) （金属，复数 IOR）
 │ 决定反射/折射能量分配
 ▼
编辑器参数
 │ Metallic = 0 → F₀ = 0.04（介电体默认）
 │ Metallic = 1 → F₀ = BaseColor（金属，复折射率导致有色 F₀）
 │ Metallic ∈ (0,1) → F₀ = lerp(0.04, BaseColor, metallic)
 ▼
Schlick 近似
 │ F(θ) = F₀ + (1-F₀)(1-cosθ)⁵
 │ 将 F₀ 推广到任意入射角
 ▼
BRDF 中的 F 项
 │ f_cook-torrance = D·F·G / (4(n·ωᵢ)(n·ωₒ))
 ▼
最终渲染结果
```

> **核心理解**：折射律（Snell's Law）是 Fresnel 方程的**几何前提**——它规定了光在界面处如何改变方向；Fresnel 方程在此基础上计算**能量分配**。编辑器中的 Metallic 参数本质上是在介电体（实数 IOR，无色 F₀）和金属（复数 IOR，有色 F₀）之间插值。

## 5.4 Specular-Glossiness 工作流（备用）

| 参数 | 物理含义 |
|---|---|
| **Diffuse** | 漫反射颜色 |
| **Specular** | 镜面反射颜色（= F0） |
| **Glossiness** | 光滑度 = 1 - roughness |

**与 Metallic-Roughness 的转换**：

```
BaseColor = Diffuse
Metallic = 根据 Specular 推算
Roughness = 1 - Glossiness
```

## 5.5 其他常见参数

### Clearcoat（清漆层）

```
f = f_base + f_clearcoat
```

- 模拟车漆、木地板上的透明涂层
- 额外的 specular lobe，通常 roughness 很低

### Sheen（光泽）

- 模拟布料边缘的微光
- Disney BRDF 中的 sheen 项

### Anisotropy（各向异性）

- 拉丝金属、CD 表面、头发
- NDF 不再是各向同性，而是椭圆分布

### IOR（折射率）

- 控制 F0：`F0 = (IOR-1/IOR+1)²`
- 控制折射方向（Snell 定律）

---

# 第六章：BRDF 公式总结

## 6.1 Cook-Torrance BRDF 中 kd / ks 的含义

### 简短回答

LearnOpenGL 关于"kd 是 refracted、ks 是 reflected"的说法**基本正确但不完全严谨**。更精确的表述：

| 系数 | 物理含义 | 严谨表述 |
|---|---|---|
| **ks** | 镜面（specular） | **在表面界面被反射**的光（受 Fresnel F 控制） |
| **kd** | 漫反射（diffuse） | **穿过表面进入材质、经多次散射后返回**的光（不是单次折射） |

### 标准推导（基于能量守恒）

入射光在界面处被分成两部分：

```
入射能量 = 反射能量（specular） + 透射能量（进入材质内部）
```

- **ks = F(h, v)** —— Fresnel 项，表示**被反射**的比例
- **kd = 1 - F** —— 剩余的**进入材质内部**的比例

> 注意：严格说不是简单的 `1 - F`，在金属工作流中还要考虑金属度。

### 完整 BRDF 公式

```
fr = kd * f_lambert + ks * f_cook-torrance

其中:
 f_lambert = c / π (漫反射)
 f_cook-torrance = (D * F * G) / (4 * (ωo·n)(ωi·n)) (镜面)

 kd = (1 - F) * (1 - metalness)
 ks = F0
```

**关键点**：

- 漫反射系数是 `(1 - F) * (1 - metalness)`，**不仅取决于 Fresnel，还取决于金属度**
- 金属的 kd = 0（所有能量都进 specular）
- 介电体的 kd = (1 - F)（剩余能量进入材质）

## 6.2 为什么漫反射项是 c / π？

`f_lambert = c / π` 中的 **除以 π** 来自**能量守恒的归一化**。

**推导过程**：

Lambert 漫反射假设出射辐射亮度 Lₒ 在所有方向均匀分布（与观察方向无关）：

```
Lₒ(ωₒ) = 常数（各向同性）
```

根据 BRDF 定义，对于均匀入射光 Lᵢ = 1：

```
Lₒ = ∫(Ω) f_lambert · Lᵢ · cosθ · dω
 = f_lambert · ∫(Ω) cosθ · dω （f_lambert 是常数）
```

计算半球积分：

```
∫(Ω) cosθ · dω = ∫(0→2π) ∫(0→π/2) cosθ · sinθ · dθ · dφ
 = 2π · ∫(0→π/2) cosθ · sinθ · dθ
 = 2π · [sin²θ / 2]₀^(π/2)
 = 2π · (1/2)
 = π
```

代入：

```
Lₒ = f_lambert · π
```

要满足能量守恒（反射率 ≤ 1），即 Lₒ ≤ 1：

```
f_lambert · π ≤ 1 → f_lambert ≤ 1/π
```

加上表面颜色 c（albedo），最终：

```
f_lambert = c / π
```

**物理意义**：

| 项 | 含义 |
|---|---|
| c | 表面颜色（albedo），决定反射多少光 |
| 1/π | 归一化因子，保证能量守恒 |
| c/π | 单位立体角的反射率 |

**直观理解**：半球立体角是 2π sr，但 cosθ 加权后有效积分是 π。除以 π 相当于把反射能量"均匀分摊"到半球各方向，保证总反射不超过入射。

**验证**：对于纯白表面（c = 1），总反射率：

```
∫(Ω) (1/π) · cosθ · dω = (1/π) · π = 1 ✅
```

## 6.3 关于 ks·f_cook-torrance 中"两个 F"的细节

原版 Cook-Torrance 公式的 specular 项里**确实存在两个 Fresnel 相关的量**：

```
fr_specular = ks · (D · F · G) / (4 · (ωo·n)(ωi·n))
 ↑ ↑
 外层 ks 内层 F
 (= F0) (= F(θ))
```

| 项 | 角色 | 物理意义 |
|---|---|---|
| **ks（外层）** | 镜面反射的**整体标量比例** | F0 = 法向入射反射率，材质本征属性 |
| **F（内层）** | 角度依赖的 **Fresnel 调制** | Schlick 近似: `F(θ) = F0 + (1-F0)(1-cosθ)⁵` |

**为什么会有两个**：

- **ks = F0** 决定宏观能量分配（多少光进 specular vs diffuse）
- **F(θ)** 决定单根光线在微表面上的角度依赖反射率
- 二者本质上不是同一物理量，但在 `ks = F0` 假设下退化为一个 F0 因子

### 现代实现的简化

实际 PBR 引擎（Unreal / glTF / Disney）通常**把 ks 折叠进 F0**，写成单一 F：

```hlsl
// 简化版：只有一个 F（带 F0 内置）
float3 F = F0 + (1 - F0) * pow(1 - cosTheta, 5); // Schlick 近似
float3 fr = (D * F * G) / (4 * cosθi * cosθo) + kd * c / π;
```

两种写法**完全等价**，区别只在于 F0 是显式写出（ks 形式）还是隐式藏在 F 里（折叠形式）。

## 6.4 LearnOpenGL 说法的瑕疵

| 说法 | 是否准确 | 备注 |
|---|---|---|
| kd 表示 refracted | ⚠️ 部分 | "refracted" 在光学里特指**单次透射**，但漫反射其实是**多次散射** |
| ks 表示 reflected | ✅ 准确 | 反射部分就是 Fresnel 反射 |
| 隐含 kd + ks = 1 | ❌ 不严谨 | 实际是 `kd + ks = 1` 仅在 metalness = 0 时成立 |

### 物理过程图示

```
入射光 ──┬── Fresnel 反射 ──→ 镜面反射（ks, F 项）
 │
 └── 透射进入材质 ──┬── 金属：被电子吸收，不返回（kd = 0）
 │
 └── 介电体：被散射返回表面 ──→ 漫反射（kd）
```

### 更严谨的术语建议

与其说"kd 是 refracted，ks 是 reflected"，不如说：

- **ks** = 在表面**界面被直接反射**的能量（Fresnel 控制）
- **kd** = **未在表面被反射**、进入材质并最终**散射回表面**的能量（能量守恒 + 金属度共同决定）

"散射回"比"refracted"更准确，因为：
- **折射（refraction）** = 单次穿过界面后沿 Snell 定律传播
- **漫反射（diffuse）** = 在材质内部经历多次反弹、各方向散射

## 6.5 能量守恒视角下的 PBR

任何 PBR 着色器都必须满足**能量守恒**：

```
入射能量 = 反射能量（specular F） + 进入材质能量

进入材质能量 = 漫反射返回（kd） + 透射出去 + 吸收
```

所以完整的 BRDF/BSDF 应该是：

```
ρ_total = ρ_specular + ρ_diffuse + ρ_transmission + ρ_absorption
 = 1（理想情况下）
```

不同 PBR 模型对这个方程做不同程度的简化：

| 模型 | 简化内容 |
|---|---|
| Lambert | 只算漫反射，忽略 F |
| Phong/Blinn-Phong | 经验公式，不严格守恒 |
| Cook-Torrance | 严格守恒：F 反射 + (1-F) 漫反射 |
| Disney BRDF | 加了 sheen, clearcoat, subsurface |
| 完整物理级 | 包含色散、干涉、偏振（罕见） |

## 6.6 参考标准

| 来源 | 术语 |
|---|---|
| Cook-Torrance 1982 论文 | "Fresnel term F gives fraction reflected at interface" |
| Disney BRDF | F = Fresnel reflection, (1-F) = energy entering material |
| glTF KHR_materials_pbrMetallicRoughness | 金属: 100% specular; 介电: split between specular/diffuse |

---

# 附录 A：参考资料

- **Cook & Torrance (1982)** — "A Reflectance Model for Computer Graphics"
- **Karis (2013)** — "Real Shading in Unreal Engine 4"（BRDF 分解）
- **Burley (2012)** — "Physically Based Shading at Disney"
- **Pharr, Jakob, Humphreys (2016)** — "Physically Based Rendering" 3rd Ed.
- **Heitz (2014)** — "Understanding the Masking-Shadowing Function"
- **KHR_materials_pbrMetallicRoughness** — glTF 2.0 PBR 扩展标准
- **LearnOpenGL** — https://learnopengl.com/PBR/Theory

---

# 附录 B：基本几何体公式速查（立体角相关）

> 体积、面积、周长等基础几何量的常用公式汇总。

## B.1 3D 几何体（体积 + 表面积）

### 球体 (Sphere)

| 项 | 公式 |
|---|---|
| 体积 V | (4/3)πr³ |
| 表面积 S | 4πr² |

### 立方体 (Cube)

| 项 | 公式 |
|---|---|
| 边长 a | — |
| 体积 V | a³ |
| 表面积 S | 6a² |
| 对角线 d | a√3 |

### 长方体 (Cuboid)

| 项 | 公式 |
|---|---|
| 边长 a, b, c | — |
| 体积 V | a · b · c |
| 表面积 S | 2(ab + bc + ca) |
| 对角线 d | √(a² + b² + c²) |

### 圆柱 (Cylinder)

| 项 | 公式 |
|---|---|
| 底面半径 r，高 h | — |
| 体积 V | πr²h |
| 侧面积 S_lateral | 2πrh |
| 表面积 S | 2πr² + 2πrh = 2πr(r + h) |

### 圆锥 (Cone)

| 项 | 公式 |
|---|---|
| 底面半径 r，高 h | — |
| 母线 l | √(r² + h²) |
| 体积 V | (1/3)πr²h |
| 侧面积 S_lateral | πrl |
| 表面积 S | πr² + πrl = πr(r + l) |

### 圆台 (Frustum)

| 项 | 公式 |
|---|---|
| 上下底半径 R, r，高 h | — |
| 母线 l | √((R-r)² + h²) |
| 体积 V | (1/3)πh(R² + Rr + r²) |
| 侧面积 S_lateral | π(R + r)l |
| 表面积 S | π[R² + r² + (R+r)l] |

### 棱柱 (Prism)

| 项 | 公式 |
|---|---|
| 底面积 A_base，高 h | — |
| 体积 V | A_base · h |
| 侧面积 S_lateral | 底面周长 · h |
| 表面积 S | 2·A_base + 底面周长·h |

### 棱锥 (Pyramid)

| 项 | 公式 |
|---|---|
| 底面积 A_base，高 h | — |
| 体积 V | (1/3) · A_base · h |
| 侧面积 S_lateral | (1/2) · 底面周长 · 斜高 |
| 表面积 S | A_base + (1/2) · 底面周长 · 斜高 |

### 椭球 (Ellipsoid)

| 项 | 公式 |
|---|---|
| 半轴 a, b, c | — |
| 体积 V | (4/3)πabc |
| 表面积 S | 近似公式（无闭式），常用 4π[(a^p·b^p + a^p·c^p + b^p·c^p)/3]^(1/p)，p≈1.6075 |

### 圆环 / 轮胎 (Torus)

| 项 | 公式 |
|---|---|
| 主半径 R，管半径 r | — |
| 体积 V | 2π²Rr² |
| 表面积 S | 4π²Rr |

### 半球 (Hemisphere)

| 项 | 公式 |
|---|---|
| 半径 r | — |
| 体积 V | (2/3)πr³ |
| 总表面积 S | 3πr²（曲面 2πr² + 底面 πr²） |

### 抛物面体 (Paraboloid)

| 项 | 公式 |
|---|---|
| 底半径 r，高 h | — |
| 体积 V | (1/2)πr²h（同底同高圆柱的一半） |

## B.2 2D 几何图形（面积 + 周长）

### 圆 (Circle)

| 项 | 公式 |
|---|---|
| 半径 r | — |
| 面积 A | πr² |
| 周长 C | 2πr |
| 弧长 L (角度 θ 弧度) | rθ |

### 椭圆 (Ellipse)

| 项 | 公式 |
|---|---|
| 长半轴 a，短半轴 b | — |
| 面积 A | πab |
| 周长 C (近似) | π[3(a+b) - √((3a+b)(a+3b))] |

### 正方形 (Square)

| 项 | 公式 |
|---|---|
| 边长 a | — |
| 面积 A | a² |
| 周长 C | 4a |
| 对角线 d | a√2 |

### 矩形 (Rectangle)

| 项 | 公式 |
|---|---|
| 长 a，宽 b | — |
| 面积 A | a·b |
| 周长 C | 2(a + b) |
| 对角线 d | √(a² + b²) |

### 三角形 (Triangle)

| 项 | 公式 |
|---|---|
| 底 b，高 h | — |
| 面积 A | (1/2)·b·h |
| 海伦公式 A | √[s(s-a)(s-b)(s-c)]，s = (a+b+c)/2 |

### 正 n 边形 (Regular Polygon)

| 项 | 公式 |
|---|---|
| 边长 a，n 边 | — |
| 内角 α | (n-2)·180°/n |
| 外接圆半径 R | a / (2 sin(π/n)) |
| 面积 A | (1/4)·n·a²·cot(π/n) |

### 扇形 (Circular Sector)

| 项 | 公式 |
|---|---|
| 半径 r，圆心角 θ (弧度) | — |
| 弧长 L | rθ |
| 面积 A | (1/2)r²θ |

### 弓形 (Circular Segment)

| 项 | 公式 |
|---|---|
| 半径 r，圆心角 θ (弧度) | — |
| 弦长 c | 2r·sin(θ/2) |
| 拱高 h | r(1 - cos(θ/2)) |
| 面积 A | (1/2)r²(θ - sin θ) |

### 梯形 (Trapezoid)

| 项 | 公式 |
|---|---|
| 上底 a，下底 b，高 h | — |
| 面积 A | (1/2)(a + b)·h |

### 平行四边形 (Parallelogram)

| 项 | 公式 |
|---|---|
| 底 b，高 h | — |
| 面积 A | b·h |

## B.3 常用转换 / 速记

- 棱柱 V = 底面积 × 高；棱锥 V = (1/3) × 底面积 × 高
- 球 V = (1/3) × 球表面积 × r = (S·r)/3
- 圆锥 V = 同底同高圆柱的 1/3
- 圆台 V = (1/3)πh(R² + Rr + r²)，r=0 → 圆锥，r=R → 圆柱
- 椭球 V = (4/3)πabc；椭圆 A = πab
- 抛物面体 V = 同底同高圆柱的 1/2

## B.4 补充公式

### 球冠 / 球缺 (Spherical Cap)

| 项 | 公式 |
|---|---|
| 球半径 R，拱高 h | — |
| 球冠体积 V | πh²(R - h/3) |
| 球冠表面积 S | 2πRh |
| 球冠底面半径 a | √[h(2R - h)] |

### 圆环面（Torus）

| 项 | 公式 |
|---|---|
| 主半径 R，管半径 r | — |
| 体积 V | 2π²Rr² |
| 表面积 S | 4π²Rr |

### 抛物面体（Paraboloid）

| 项 | 公式 |
|---|---|
| 底半径 r，高 h | — |
| 体积 V | (1/2)πr²h |
| 侧表面积 S | (πr/6h²)·[(r² + 4h²)^(3/2) - r³] |

---

# 七、蒙特卡洛方法与渲染方程

## 7.1 蒙特卡洛积分的基本思想

渲染方程是一个高维积分（对半球方向积分），在绝大多数场景中无法解析求解。蒙特卡洛方法（Monte Carlo Method）通过**随机采样**来数值估计积分值，是路径追踪（Path Tracing）等全局光照算法的数学基础。

**核心思想**：用有限个随机采样点的函数值的加权平均，来逼近积分。

## 7.2 蒙特卡洛估计量（Monte Carlo Estimator）

### 7.2.1 基本形式

对于定积分：

I = ∫(a→b) f(x) dx

蒙特卡洛估计量为：

I ≈ F_N = 1/N Σ(i=1→N) (f(Xᵢ))/(p(Xᵢ))

其中：
- N：采样点数量
- Xᵢ：从概率密度函数（PDF）p(x) 中抽取的随机样本
- p(Xᵢ)：样本 Xᵢ 处的概率密度值
- (f(Xᵢ))/(p(Xᵢ))：称为**样本贡献**（sample contribution）

### 7.2.2 无偏性（Unbiasedness）

蒙特卡洛估计量是**无偏的**（unbiased），即其期望等于真实积分值：

E[F_N] = E[1/N Σ(i=1→N) (f(Xᵢ))/(p(Xᵢ))] = 1/N Σ(i=1→N) E[(f(Xᵢ))/(p(Xᵢ))]

由于每个 Xᵢ 独立同分布：

E[(f(Xᵢ))/(p(Xᵢ))] = ∫ (f(x))/(p(x)) · p(x) dx = ∫ f(x) dx = I

因此 E[F_N] = I，无论 N 取何值，期望都等于真实积分。

### 7.2.3 方差与收敛速度

蒙特卡洛估计量的方差为：

Var[F_N] = 1/N · Var[(f(X))/(p(X))]

**关键结论**：
- 方差与 N 成反比，标准差与 √(N) 成反比
- 收敛速度为 O(1/√(N))，即误差减半需要 4 倍采样数
- 收敛速度**与积分维度无关**（这是蒙特卡洛相比传统数值积分的最大优势）

### 7.2.4 重要性采样（Importance Sampling）

选择不同的 PDF p(x) 会显著影响方差。**重要性采样**的核心原则是：

> 让 p(x) 的形状尽可能接近 f(x) 的形状，即 p(x) ∝ f(x)。

当 p(x) = (f(x))/(I)（即与 f(x) 完全成正比）时，方差为零——每个样本的贡献 (f(Xᵢ))/(p(Xᵢ)) = I 都是常数。

实际中无法做到完美匹配，但应尽量让 p(x) 在 f(x) 大的地方也大。

## 7.3 渲染方程的积分形式

回顾第二章的渲染方程（反射方程部分）：

Lₒ(p, ωₒ) = ∫(Ω⁺) fᵣ(p, ωᵢ, ωₒ) Lᵢ(p, ωᵢ) (ωᵢ · n) dωᵢ

这是一个对上半球 Ω⁺ 的积分，被积函数为：

g(ωᵢ) = fᵣ(p, ωᵢ, ωₒ) · Lᵢ(p, ωᵢ) · (ωᵢ · n)

其中：
- fᵣ：BRDF
- Lᵢ：入射 radiance
- ωᵢ · n = cosθᵢ：入射角余弦（Lambert 定律）

## 7.4 从积分到蒙特卡洛离散形式

### 7.4.1 直接应用蒙特卡洛估计量

将渲染方程直接代入蒙特卡洛估计量公式：

Lₒ(p, ωₒ) ≈ 1/N Σ(j=1→N) (fᵣ(p, ωⱼ, ωₒ) · Lᵢ(p, ωⱼ) · (ωⱼ · n))/(p(ωⱼ))

其中 ωⱼ 是从 PDF p(ω) 中采样的入射方向。

### 7.4.2 路径追踪中的递归展开

路径追踪的核心是递归地求解 Lᵢ(p, ωⱼ)——它本身也是另一个点的出射 radiance：

Lᵢ(p, ωⱼ) = Lₒ(p', -ωⱼ)

其中 p' 是从 p 沿方向 ωⱼ 发出的射线与场景的交点。

代入后得到递归形式：

Lₒ(p, ωₒ) ≈ 1/N Σ(j=1→N) (fᵣ(p, ωⱼ, ωₒ) · Lₒ(p', -ωⱼ) · (ωⱼ · n))/(p(ωⱼ))

### 7.4.3 单样本路径追踪（N=1）

实际路径追踪中通常每像素追踪多条路径，但每条路径的每次弹射只采样**一个方向**（N=1），以避免指数爆炸：

Lₒ(p, ωₒ) ≈ (fᵣ(p, ωᵢ, ωₒ) · Lᵢ(p, ωᵢ) · (ωᵢ · n))/(p(ωᵢ))

多条路径的结果取平均来降低噪声。

### 7.4.4 路径追踪的完整递推

设路径顶点序列为 p₀, p₁, p₂, ..., pₖ（p₀ 为相机，p₁ 为第一个交点），则路径贡献为：

L_path = Lₑ(pₖ → pₖ₋₁) · Π(i=1→k-1) (fᵣ(pᵢ₊₁ → pᵢ → pᵢ₋₁) · (ωᵢ · nᵢ))/(p(ωᵢ))

其中 Lₑ 是光源的自发光 radiance（路径终点）。

### 7.4.5 俄罗斯轮盘赌（Russian Roulette）

为避免无限递归，路径追踪使用俄罗斯轮盘赌来无偏地终止路径：

- 设定存活概率 q（通常取 0.5~0.9）
- 以概率 q 继续追踪，贡献除以 q
- 以概率 1-q 终止，贡献为 0

```
Lₒ = 1/q · L_next    (以概率 q)
Lₒ = 0               (以概率 1-q)
```

除以 q 保证了期望不变（无偏性）。

## 7.5 常见采样策略

### 7.5.1 均匀半球采样（Uniform Hemisphere Sampling）

p(ω) = 1/2π

最简单但方差大，因为大部分方向对最终颜色的贡献很小。

### 7.5.2 余弦加权采样（Cosine-Weighted Sampling）

p(ω) = cosθ/π

让采样密度与 cosθ 成正比，匹配 Lambert 定律中的余弦项，对漫反射表面效果好。

### 7.5.3 BRDF 重要性采样（BRDF Importance Sampling）

p(ω) ∝ fᵣ(p, ω, ωₒ) · (ω · n)

让采样密度匹配 BRDF 的形状。对于 Cook-Torrance BRDF，通常采样微表面法线分布 D(h)：

- 从 D(h) 采样半向量 h
- 通过 ωᵢ = 2(ωₒ · h)h - ωₒ 反射得到入射方向
- PDF 需要做 Jacobian 变换：p(ωᵢ) = (D(h) · (h · n))/(4 · (ωₒ · h))

### 7.5.4 多重重要性采样（MIS, Multiple Importance Sampling）

当被积函数包含多个"峰"时（如 BRDF 峰和光源峰），单一采样策略效果差。MIS 结合多种采样策略：

F_MIS = Σ(s) 1/Nₛ Σ(i=1→Nₛ) wₛ(Xₛ,ᵢ) · (f(Xₛ,ᵢ))/(pₛ(Xₛ,ᵢ))

其中 wₛ 是权重函数（常用 balance heuristic：wₛ(x) = (Nₛ pₛ(x))/(Σₖ Nₖ pₖ(x))）。

典型应用：**Next Event Estimation（NEE）**——BRDF 采样 + 光源采样结合。

## 7.6 蒙特卡洛在渲染中的完整流程

```
渲染方程（积分形式）
 │
 ▼
蒙特卡洛估计量（离散化）
 │
 ▼
路径追踪（递归求解 L_i）
 │
 ├── 重要性采样（降低方差）
 ├── 俄罗斯轮盘赌（无偏终止）
 └── MIS / NEE（处理多峰被积函数）
```

## 7.7 关键公式速查

| 概念 | 公式 |
|---|---|
| 蒙特卡洛估计量 | F_N = 1/N Σ(i=1→N) (f(Xᵢ))/(p(Xᵢ)) |
| 无偏性 | E[F_N] = I |
| 方差 | Var[F_N] = 1/N Var[f/p] |
| 收敛速度 | O(1/√(N)) |
| 渲染方程 MC 形式 | Lₒ ≈ 1/N Σ (fᵣ · Lᵢ · cosθ)/(p(ω)) |
| 均匀半球 PDF | p(ω) = 1/(2π) |
| 余弦加权 PDF | p(ω) = cosθ / π |
| 俄罗斯轮盘赌 | 以概率 q 继续，贡献 × 1/q |
| MIS balance heuristic | wₛ = (Nₛ pₛ)/(Σₖ Nₖ pₖ) |

---

# TODO

1. pbr理论到编辑器里的各种参数是怎么对应的 原理 各种资料都应该放到brdf总结里，之前放的很混乱 cgsummary里也有一些
2. summary里pbrt的几个pdf文档需要仔细学习
3. 不同的brdf的公式总结 ✅（已完成）
4. 这篇文档应该重新组织一下，把brdf的公式总结放到最后 ✅（已完成）
5. 蒙特卡洛数学基础 ✅（已完成）
