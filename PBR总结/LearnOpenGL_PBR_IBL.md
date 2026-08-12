
LearnOpenGL PBR IBL是对UE实现的近似，UE4又是对PBR的近似
# 前置知识

## 相机拍照得到的是啥
在 PBR 和辐射度量学里，相机拍照得到的是 **radiance（辐射亮度）**——这件事听起来理所当然，但细究起来有个微妙之处：**传感器物理上吸收的其实是 irradiance（辐照度，单位面积的功率）**。那为什么我们说相机"记录 radiance"？下面把这个链条讲透。

### 一、辐射度量学的基本量

先把四个核心量摆清楚：

| 量 | 符号 | 定义 | 量纲 |
|---|---|---|---|
| **Radiant energy** | Q | 辐射能量 | J |
| **Radiant flux (power)** | Φ | 单位时间能量 | W |
| **Irradiance** | E | 落到**单位面积**上的功率 | W/m² |
| **Radiance** | L | 单位面积、单位立体角发出的功率 | W/(m²·sr) |

**关键区别**：
- **Irradiance E**：不管方向，只关心"打到一个表面单位面积上有多少功率"
- **Radiance L**：关心"从某个方向、单位面积、单位立体角"发出的功率——**它同时编码了方向和空间信息**

### 二、相机传感器物理上接收的是 Irradiance

光线穿过镜头，会聚到 CMOS/CCD 的某个像素上。像素是一个**有面积的物理表面**，光子打上去被吸收，产生电子。从这个意义上：

> 传感器每个像素测量的，是**落到该像素感光区域上的 irradiance E**——单位面积收到的辐射功率。

如果故事到这里结束，我们应该说"相机测的是 E"。但为什么渲染里都说"相机采集 radiance L"？

### 三、成像几何把 E 和 L 锁死了

秘密在**透镜的成像公式**。考虑一个理想薄透镜：

```
场景点 P ──┐
          ├── 透镜 ──┐
          │          ├── 传感器像素
场景点 Q ─┘          └─
```

对于透镜成像，有一个基本关系（来自辐射度量学的**延伸的亮度守恒定理**）：

$$L_{pixel} = \frac{1}{(\text{magnification})^2} \cdot L_{scene} \cdot \tau_{lens}$$

而在聚焦成像的条件下，传感器上的 **irradiance E_sensor** 与场景点的 **radiance L_scene** 的关系为：

$$E_{sensor} = \frac{\pi}{4} \cdot L_{scene} \cdot \left(\frac{D}{f}\right)^2 \cdot \tau_{lens} \cdot \cos^4\theta$$

其中：
- D = 光圈直径
- f = 焦距
- τ_lens = 透镜透射率
- θ = 视场角

**关键洞察**：虽然传感器测的是 E，但 **E 与场景的 L 成正比**，比例系数完全由镜头参数（D/f、τ、θ）决定。这意味着：

> 一旦镜头参数固定，**传感器上的 irradiance 就是场景 radiance 的一个线性缩放**。所以我们完全可以等价地说"相机测量的是 radiance"——因为两者只差一个已知的常数因子。

### 四、为什么渲染方程里 L 是自然的量

PBR 的核心是 **Rendering Equation（Kajiya, 1986）**：

$$L_o(p, \omega_o) = L_e(p, \omega_o) + \int_{\Omega} f_r(p, \omega_i, \omega_o) \cdot L_i(p, \omega_i) \cdot \cos\theta_i \, d\omega_i$$

这个方程里**所有项都是 radiance**：
- $L_o$：出射 radiance
- $L_i$：入射 radiance
- $f_r$：BRDF，量纲 sr⁻¹
- $\cos\theta_i \, d\omega_i$：将 irradiance 转换为投影立体角

**为什么用 L 而不是 E？** 因为 L 是**沿光线方向传播的守恒量**：

> 💡 **亮度守恒定理（Conservation of Radiance）**：在真空/均匀介质中传播时，radiance L 沿光线方向保持不变（不考虑吸收/散射）。

这是 radiance 最迷人的性质——它在自由空间中**不随距离衰减**（你看到远处星星的 radiance 和近处恒星的 radiance 在物理上是同一量级，只是立体角小导致总能量少）。而 irradiance 会随距离平方衰减（$E \propto 1/r^2$），因为它累积的是一个面积上的功率。

**因此**：
- 光线追踪里，我们追踪的是 **radiance 沿光线的传播**
- Rendering Equation 求解的是 **radiance 的分布**
- 相机放置在场景里，它"看到"的自然是沿视线方向到达的 **radiance**

### 五、从相机到像素的完整链条

```
场景点 P 发射 radiance L(P→camera)
   ↓ 沿直线传播，L 守恒
进入镜头，透镜收集立体角 Δω 内的光线
   ↓ 透镜透射（乘以 τ_lens，除以放大率²）
会聚到传感器像素，转化为 irradiance E_pixel
   ↓ 积分时间 Δt，量子效率 QE
产生电子数 N_e ∝ E_pixel × Δt × QE
   ↓ 模数转换
输出数字值 DN ∝ L(P→camera)  [差一个镜头常数因子]
```

**所以最终**：
- **物理上**：传感器测 irradiance
- **渲染/建模上**：因为 irradiance ∝ radiance（镜头参数固定），我们直接说"相机输出 radiance"——这不仅是惯例，更是**因为 radiance 是沿光线守恒的量，是整个光学管道的自然语言**

### 六、PBR 中的实际含义

这就是为什么在 PBR 里：

1. **BRDF 把 irradiance 转成 radiance**：$L_o = \int f_r \cdot E_i \, d\omega$ 的积分形式中，$\cos\theta_i \, d\omega_i$ 把入射 radiance 转换成 irradiance，f_r 再把它转成出射 radiance
2. **相机 ray 的终点值是 radiance**：光线打到表面，用 rendering equation 算出的 $L_o$ 就是这条光线带回的 radiance
3. **最终帧缓冲存的是 radiance**（线性空间），之后再 tone mapping + gamma 编码成显示器的 sRGB 值
4. **物理相机参数（光圈、快门、ISO）**本质都是在调节"场景 radiance → 传感器 irradiance → 数字值"的映射比例

> 💡 **一个反直觉的事实**：你手机拍出的照片，每个像素的值 ∝ 场景对应方向的 **radiance**，而不是 irradiance。这也是为什么同样亮度的物体，无论离相机 1 米还是 10 米，在照片上看起来一样亮（只要都在焦点内）——因为 radiance 不随距离衰减。而如果你测量落在传感器上的光强（irradiance），它会随距离平方衰减，但镜头面积也在相应调节入射立体角，两者抵消，最终锁定为 radiance。

---

**一句话总结**：相机传感器物理上吸收的是 irradiance，但由于透镜成像的几何关系，**传感器 irradiance 与场景 radiance 成正比**（比例由光圈、焦距、透射率决定）。而 radiance 是沿光线方向守恒的量，是 rendering equation 的自然语言，所以 PBR 渲染和摄影测量中都等价地说"相机采集的是 radiance"——这既是物理事实的简化表达，也是数学上的最优选择。

如果你想进一步了解"为什么 radiance 沿光线守恒"（亮度定理的推导），或者"tone mapping 怎么把 radiance 映射到显示值"，可以继续聊。


# diffuse irradiance
          
## Diffuse Irradiance 中的 Environment Map

### 一、它是什么

**Environment Map(环境贴图)** = 把场景周围所有方向的光照信息打包成一张图,使每个纹素对应空间中的一个方向。在 LearnOpenGL 的 PBR 章节里特指 **HDR Cubemap(立方体贴图)**,由原始 HDRI 转换而来。

### 二、它的来源:四步流程

```
HDRI 照片(.hdr 文件)
   ↓  ① stbi_loadf 加载
HDR Texture 2D(等距柱状投影,equirectangular)
   ↓  ② EquirectangularToCubemap shader 转换
envCubemap(立方体贴图)  ← 这就是 "environment map"
   ↓  ③ IrradianceConvolution shader 卷积
irradianceMap(辐照度图)
   ↓  ④ 运行时 shader 采样
PBR 漫反射间接光
```

#### 第 1 步:加载 HDRI 文件

```cpp
stbi_set_flip_vertically_on_load(true);
float *data = stbi_loadf("newport_loft.hdr", &width, &height, &nrComponents, 0);
glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_FLOAT, data);
```

- **HDRI(High Dynamic Range Image)**:真实世界拍摄的全景照,常见格式 `.hdr` / `.exr`
- **格式**:等距柱状投影(equirectangular),把球面展开成 2:1 的长方形
- **关键点**:`GL_RGB16F` 浮点格式,保留真实亮度(太阳可能 > 1.0)

#### 第 2 步:转换成立方体贴图(envCubemap)

为什么转换?因为等距柱状贴图采样时在两极会严重变形,立方体贴图更适合实时渲染。

**转换原理**:用一个单位立方体(6 面)的渲染过程,每个面的 fragment shader 按其方向向量去采样原 HDR 2D 纹理。

```glsl
// fragment shader
const vec2 invAtan = vec2(0.1591, 0.3183);
vec2 SampleSphericalMap(vec3 v) {
    vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
    uv *= invAtan;     // atan/asin → [0,1]
    uv += 0.5;
    return uv;
}

void main() {
    vec2 uv = SampleSphericalMap(normalize(WorldPos));
    vec3 color = texture(equirectangularMap, uv).rgb;
    FragColor = vec4(color, 1.0);
}
```

**C++ 侧**:渲染 6 次,每次绑定 cubemap 的一个面到 FBO:

```cpp
glm::mat4 captureViews[6] = { /* 6 个 lookAt:±X, ±Y, ±Z */ };
for (int i = 0; i < 6; ++i) {
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, envCubemap, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    renderCube();  // 画单位立方体
}
```

**结果**:`envCubemap` 就是 LearnOpenGL 文中说的 environment map —— 一张 512×512 的 HDR cubemap,可以直接用作天空盒,也可作为后续卷积的输入。

#### 第 3 步:卷积成 Irradiance Map

把 envCubemap 每个方向上的半球光照累加,得到漫反射辐照度:

```glsl
vec3 irradiance = vec3(0.0);
vec3 up = vec3(0.0, 1.0, 0.0);
vec3 right = cross(up, normal);
up = cross(normal, right);

float sampleDelta = 0.025;
for (float phi = 0.0; phi < 2.0*PI; phi += sampleDelta) {
    for (float theta = 0.0; theta < 0.5*PI; theta += sampleDelta) {
        vec3 tangentSample = vec3(sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta));
        vec3 sampleVec = tangentSample.x*right + tangentSample.y*up + tangentSample.z*normal;
        irradiance += texture(envCubemap, sampleVec).rgb * cos(theta) * sin(theta);
    }
}
```

#### 第 4 步:运行时使用

```glsl
vec3 irradiance = texture(irradianceMap, N).rgb;
vec3 diffuse = irradiance * albedo;
```

### 三、关键概念辨析

| 名字 | 形态 | 用途 | 由谁产生 |
|------|------|------|---------|
| **HDRI** | 2D 等距柱状 HDR 图 | 原始素材 | 现实世界拍摄 / 离线渲染 |
| **HDR Texture 2D** | GL_TEXTURE_2D, RGB16F | 中间产物 | stbi_loadf 加载 |
| **envCubemap** | GL_TEXTURE_CUBE_MAP, RGB16F | 天空盒 + 卷积输入 | EquirectangularToCubemap shader |
| **irradianceMap** | GL_TEXTURE_CUBE_MAP, RGB16F | PBR 漫反射 IBL | IrradianceConvolution shader |
| **prefilterMap** | GL_TEXTURE_CUBE_MAP, RGB16F + mipmap | PBR 镜面 IBL 第一部分 | PrefilterEnvMap shader |
| **brdfLUT** | GL_TEXTURE_2D, RG16F | PBR 镜面 IBL 第二部分 | BRDFIntegration shader |

### 四、为什么必须用 HDR?

LearnOpenGL 强调用 HDR 的原因:

1. **物理正确**:太阳的辐射度远超 1.0,LDR 会丢失亮度信息
2. **卷积正确性**:irradiance 卷积是平均,若用 LDR,亮区被截断,平均结果偏暗
3. **反射正确**:镜面反射直接采样原始值,LDR 会让高光区失真

### 五、一句话总结

> Environment Map 是 LearnOpenGL PBR 教程中由 HDRI 照片转换而来的 **HDR 立方体贴图**,它代表场景周围所有方向的入射光信息。它本身可以直接用作天空盒背景,同时是后续 irradiance / prefilter / BRDF LUT 等所有 IBL 预计算步骤的**原始输入**。

Sources:
- [PBR 环境光的diffuse部分学习 - CSDN](https://blog.csdn.net/qq_35158695/article/details/87871997)
- [LearnOpenGL 学习笔记 PBR - CSDN](https://blog.csdn.net/hijackedbycsdn/article/details/131731655)
- [世界环境 - Blender Manual](https://docs.blender.org/manual/zh-hans/dev/render/lights/world.html)

## Environment Map 的物理本质

### 一、存的物理量：**Radiance（辐射亮度）**

Environment map 每个纹素存的物理量是 **Radiance L(ω)**，单位 `W/(sr·m²)`。

#### 为什么是 radiance？

HDR 环境照（HDRI）是用相机拍下的全景图，每个像素记录的是**从该方向到达相机的光**。根据辐射度量学：

- **Irradiance E**：单位面积接收的功率 `W/m²` —— 是积分量
- **Radiance L**：单位立体角单位面积的功率 `W/(sr·m²)` —— 是微分量

相机的每个像素对应一个微小方向（立体角），记录的正是该方向的 radiance。所以：

```
environment map[方向 ω] = L_env(ω)  从该方向来的辐射亮度
```

#### Radiance 的关键性质

> **Radiance 沿光线传播不变**（在无散射吸收的介质中）

这意味着：
- HDRI 照片在远处拍的 → 光经过长距离传播 → radiance 不变
- 物体表面接收到的该方向光 = cubemap 上对应方向的纹素值

这个性质是 environment map 能"一图两用"的物理基础。

### 二、为什么能作天空背景？

#### 渲染天空的物理过程

人眼/相机从某方向 $\omega$ 看向天空：

$$\text{看到的光} = \text{沿 } \omega \text{ 方向到达相机的 radiance} = L_{env}(\omega)$$

shader 实现：

```glsl
vec3 skyColor = texture(envCubemap, viewDir).rgb;
```

cubemap 直接按视线方向采样,取出的就是该方向的 radiance,显示出来就是天空。

#### 几何解释

Environment map 本质是"包裹场景的无穷大球面",每个纹素表示该方向无穷远处发来的光。相机射线无论朝哪个方向射出,最终都会"打到"这个球面,取到该方向的 radiance。

### 三、为什么能用来计算 Irradiance？

#### 表面接收光的物理过程

一个表面法线为 N 的点,它从整个上半球 $\Omega$ 接收光,接收到的总 irradiance 是:

$$E(N) = \int_\Omega L_{env}(\omega) \cdot \cos(\theta) \, d\omega$$

即:**把半球上每个方向的 radiance 乘以余弦权重累加**。

shader 实现(卷积):

```glsl
vec3 irradiance = vec3(0.0);
for (each direction ω in hemisphere Ω) {
    irradiance += texture(envCubemap, ω).rgb * dot(N, ω) * dω;
}
```

每个 `texture(envCubemap, ω)` 取出的就是 $L_{env}(\omega)$，正是物理积分公式里的被积量。

### 四、两种用途的统一性

两种用途本质是**同一个物理量的不同使用方式**:

| 用途 | 操作 | 物理意义 |
|------|------|---------|
| 天空背景 | $\text{texture}(\text{cubemap}, \omega)$ 直接显示 | 取单方向的 radiance 给相机看 |
| 计算 irradiance | $\int \text{texture}(\text{cubemap}, \omega) \cdot \cos\theta \, d\omega$ | 把所有方向的 radiance 积分给表面收 |

**核心统一点**:两者都基于"environment map 存的是入射 radiance"这一事实。

```
                    environment map (存 radiance)
                          ↓
              ┌───────────┴───────────┐
              ↓                       ↓
        直接采样某方向            积分半球所有方向
              ↓                       ↓
        天空背景(给相机看)      Irradiance(给表面收)
```

- 相机看 = 取一个方向的 radiance
- 表面收 = 积分所有方向的 radiance
- 两者是 radiance 的"点查询"和"半球积分"关系

### 五、为什么不存 Irradiance 而存 Radiance?

因为 **radiance 是最原始、最通用的量**:

1. **可恢复 irradiance**:积分 radiance 得 irradiance ✓
2. **可作背景显示**:直接读取 radiance ✓
3. **可作镜面反射采样**:反射方向取 radiance = 看到环境的反射 ✓
4. **可作 BRDF 计算**:任何 BRDF 都可基于 radiance 积分 ✓

反过来不行:irradiance 是积分量,**丢失了方向信息**,无法从中还原单方向 radiance。

所以 environment map 存 radiance 是**信息量最大**的选择,任何下游计算都能从中派生。

### 六、一句话总结

> Environment map 存的是 **radiance**(每方向的辐射亮度),因为 radiance 沿光线传播不变。
> 作背景时:直接取某方向 radiance 给相机看;
> 算 irradiance 时:把半球所有方向 radiance 积分给表面收。
> 两者是"点采样"和"半球积分"的关系,本质都基于 environment map 是入射 radiance 的查询表。




# Specular IBL

这个是在生成采样向量的时候用的吧？本身积分是不依赖wo的          
## Split Sum 中 `N = R = V` 假设的理解

先澄清一个关键点：**这个假设属于 split sum 的「第一部分」（pre-filtered environment map），不是第二部分**。第二部分（BRDF LUT）反而是在「修正」这个假设带来的误差。下面拆解。

### 一、问题背景：为什么需要假设？

完整镜面反射积分：

$$\int_\Omega L(\omega_i) \cdot f_r(\omega_i, \omega_o) \cdot \cos(\theta) \, d\omega_i$$

- **漫反射**预计算简单：$f_r = \text{albedo}/\pi$ 是常数，积分只依赖 $\omega_i$ → 可以预卷积成辐照度图
- **镜面反射**麻烦：BRDF 同时依赖 $\omega_i$ 和 $\omega_o$ → 是 4D 问题（2D 方向 × 2D 方向），无法预计算所有组合

Epic 的拆分：

$$\int L(\omega_i) \cdot f_r(\omega_i,\omega_o) \cdot \cos\theta \, d\omega_i \approx \left[ \int L(\omega_i) \cdot \ldots \, d\omega_i \right] \cdot \left[ \int f_r(\omega_i,\omega_o) \cdot \cos\theta \, d\omega_i \right]$$

### 二、第一部分的困境

第一部分要卷积环境贴图,但**卷积核(BRDF)依赖 $\omega_o$**,而预计算时我们不知道运行时 $\omega_o$ 是什么。

**Epic 的妥协假设**:

```glsl
vec3 N = normalize(w_o);   // 把法线当作出射方向
vec3 R = N;                 // 反射方向 = 法线
vec3 V = R;                 // 视线方向 = 反射方向
```

即 **N = R = V**。

### 三、为什么 `V = R` 就推出 `N = V`？

这是理解的关键。反射公式：

$$R = 2(N \cdot V) \cdot N - V \quad \text{// V 关于 N 的反射}$$

假设 `R = V`(反射方向等于视线方向):

$$V = 2(N \cdot V) \cdot N - V$$
$$2V = 2(N \cdot V) \cdot N$$
$$V = (N \cdot V) \cdot N$$

因为 N 和 V 都是单位向量,`V = (N·V)·N` 成立的唯一条件是 **N·V = 1**,即 **N = V**。

几何直观:只有当视线**垂直入射**表面(视线方向 = 法线方向)时,反射方向才等于视线方向本身——这是个 0° 入射的特殊情况。

### 四、为什么 `ωo` 是「出射方向」= V?

这是 BRDF 的约定:

| 符号 | 含义 | 物理对应 |
|------|------|---------|
| $\omega_i$ (wi) | 入射方向 | 光源 → 表面 |
| $\omega_o$ (wo) | 出射方向 | 表面 → 眼睛 = **V (view direction)** |

在 BRDF 定义里,$\omega_o$ 就是「出射方向」,也就是观察方向 V。所以 LearnOpenGL 写 `vec3 N = normalize(w_o)` 是把**出射方向(视线)**当作法线来用。

### 五、这个假设带来什么后果？

#### 优点(为什么这么做)

1. **降维**:卷积不再依赖 $\omega_o$ → 第一部分变成只依赖 N 和 roughness 的 2D 问题
2. **可预计算**:每个粗糙度级别卷积一次,存进 cubemap 的 mip chain
3. **运行时廉价**:只需一次 `textureLod(prefilterMap, R, lod)` 采样

#### 缺点(误差)

- 真实场景中 N·V 很少等于 1(只有正对表面时才成立)
- **掠射角(grazing angle)误差大**:当 N·V → 0(几乎平行表面看)时,真实镜面反射会拉长成高光带,但假设下预计算的结果无法体现
- 这就是 [Frostbite 文章](https://blog.selfshadow.com/publications/s2016-shading-course/) 里提到的"掠射角镜面反射丢失"

#### 第二部分(BRDF LUT)的修正作用

第二部分预计算:

$$\int f_r(\omega_i, \omega_o) \cdot \cos\theta \, d\omega_i \to F_0 \cdot \text{scale} + \text{bias} \quad \text{(2D LUT: N·V × roughness)}$$

它**保留了 N·V 的真实依赖**(LUT 的横轴就是 N·V),所以即使第一部分假设了 N=V,第二部分仍然按真实 N·V 查表,部分补偿了第一部分的误差。

### 六、完整流程串起来

```
运行时 shader:
  N = 表面法线
  V = 视线方向
  R = reflect(-V, N)              // 真实反射方向
  NdotV = saturate(dot(N, V))     // 真实 N·V

  // 第一部分:用假设(N=R=V)预计算的prefilter图,按真实R采样
  prefilteredColor = textureLod(prefilterMap, R, roughness * maxMip)

  // 第二部分:用真实 N·V 和 roughness 查 LUT,修正第一部分的假设误差
  envBRDF = texture(brdfLUT, vec2(NdotV, roughness)).xy

  // 组合
  specularIBL = prefilteredColor * (F0 * envBRDF.x + envBRDF.y)
```

### 七、一句话总结

> **假设 N = R = V 的本质**:在预卷积环境贴图时,假装视线永远垂直于表面($N \cdot V=1$),从而消除对 $\omega_o$ 的依赖,使 4D 积分降为 2D 可预计算。代价是掠射角反射失真,这个失真由第二部分 BRDF LUT(按真实 $N \cdot V$ 查表)来部分修正。

所以你看到的两部分是**配合关系**:第一部分做了简化假设让预计算可行,第二部分保留真实 N·V 来补偿。这就是 split sum "split"的精髓——把误差拆到可修正的部分。

Sources:
- [笔记]OpenGL-镜面反射IBL - 哔哩哔哩
- Learn OpenGL 笔记7.4 PBR-Specular IBL - CSDN
- Games202 第五讲 SDF, split sum - 哔哩哔哩




### 一、数学定义

#### 通用数学定义

连续空间二维卷积:

```
(f * g)(x, y) = ∫∫ f(x', y') · g(x - x', y - y') dx' dy'
```

- `f`:输入信号(如图像)
- `g`:卷积核(kernel/filter)
- 输出每个位置 = **输入与核的加权累加**

离散形式(数字图像处理):

```
(f * g)[i, j] = Σ_{m,n} f[i-m, j-n] · g[m, n]
```

#### IBL 中的卷积定义

在 PBR 环境贴图语境下,"卷积"被借用来描述**半球积分**:

```
Output(ωo) = ∫_Ω L_env(ωi) · W(ωi, ωo) · cos(θi) dωi
             └────┬────┘   └────┬────┘
             输入信号    卷积核(权重函数)
```

- **输入信号 `f`** = environment cubemap(各方向的 radiance)
- **卷积核 `g`** = 权重函数 $W(\omega_i, \omega_o)$（BRDF 的某部分 + cos）
- **输出** = 预计算贴图(irradiance map / prefilter map)

| 场景 | 卷积核 W | 输出 |
|------|---------|------|
| **Diffuse Irradiance** | $\cos\theta_i / \pi$（Lambert） | irradianceMap |
| **Specular Prefilter** | $D(h) \cdot G(v,l) \cdot V / (4 \cdot \cos)$（Cook-Torrance，假设 N=V=R） | prefilterMap |

### 二、原理

#### 为什么叫"卷积"?

因为它满足**卷积的核心性质**:

1. **加权累加**:输出每个位置 = 输入所有位置按核加权的积分
2. **核平移不变性**:对每个输出方向 $\omega_o$,核的形状相同(只是旋转到对齐 $\omega_o$)
3. **可分离/可预计算**:核固定 → 可离线烘焙

#### 几何直观

把 cubemap 想象成一个"发光球的内表面":

```
                卷积核 W
                 ▲
                 │
        ┌────────┴────────┐
        │  半球 Ω (面朝 ωo) │
        │  ┌─────────────┐ │
        │  │ L(ωi)·cosθ  │ │ → 累加 → Output(ωo)
        │  │  各方向radiance│ │
        │  └─────────────┘ │
        └─────────────────┘
                 ↑
              输出方向 ωo
```

对每个输出方向 $\omega_o$,**把以 $\omega_o$ 为轴的整个上半球的所有 radiance 按权重累加**,得到该方向的卷积结果。

### 三、代码实现

#### 1. Diffuse Irradiance 卷积

[LearnOpenGL irradiance_convolution.frag](https://learnopengl.com/PBR/IBL/Diffuse-irradiance):

```glsl
void main() {
    vec3 N = normalize(WorldPos);     // 输出方向 = 法线
    vec3 irradiance = vec3(0.0);

    // 构建以 N 为轴的切线空间
    vec3 up    = abs(N.y) < 0.999 ? vec3(0,1,0) : vec3(1,0,0);
    vec3 right = cross(up, N);
    up         = cross(N, right);

    float sampleDelta = 0.025;
    float nrSamples = 0.0;
    for (float phi = 0.0; phi < 2.0*PI; phi += sampleDelta) {
        for (float theta = 0.0; theta < 0.5*PI; theta += sampleDelta) {
            // 球面坐标 → 笛卡尔(切线空间)
            vec3 tangentSample = vec3(
                sin(theta)*cos(phi),
                sin(theta)*sin(phi),
                cos(theta)
            );
            // 切线空间 → 世界空间
            vec3 sampleVec = tangentSample.x*right + tangentSample.y*up + tangentSample.z*N;

            // 卷积核:cos(θ)·sin(θ)
            //   cos(θ) = Lambert 余弦权重
            //   sin(θ) = 球面坐标的立体角微元 dω = sinθ dθ dφ
            irradiance += texture(envCubemap, sampleVec).rgb
                        * cos(theta) * sin(theta);
            nrSamples++;
        }
    }
    irradiance = PI * irradiance / float(nrSamples);   // 归一化
    FragColor = vec4(irradiance, 1.0);
}
```

**核心三要素**:
1. 遍历半球所有方向 $\omega_i$(球面坐标 $\varphi, \theta$ 嵌套循环)
2. 取输入信号 `texture(envCubemap, ωi).rgb` = $L(\omega_i)$
3. 乘核权重 `cos(θ)·sin(θ)` = Lambert 余弦 × 立体角微元

#### 2. Specular Prefilter 卷积(重要性采样)

[LearnOpenGL prefilter.frag](https://learnopengl.com/PBR/IBL/Specular-IBL):

```glsl
void main() {
    vec3 N = normalize(WorldPos);
    vec3 R = N;          // 假设 N = R = V
    vec3 V = R;

    vec3 prefilteredColor = vec3(0.0);
    float totalWeight = 0.0;

    const uint SAMPLE_COUNT = 1024u;
    for (uint i = 0u; i < SAMPLE_COUNT; ++i) {
        // 重要性采样:按 GGX NDF 分布生成样本
        vec2 Xi = Hammersley(i, SAMPLE_COUNT);
        vec3 H  = ImportanceSampleGGX(Xi, N, roughness);
        vec3 L  = normalize(2.0 * dot(V, H) * H - V);  // 反射方向

        float NdotL = max(dot(N, L), 0.0);
        if (NdotL > 0.0) {
            // 卷积核 = GGX·cos(θ) (隐含在重要性采样分布中)
            prefilteredColor += texture(envCubemap, L).rgb * NdotL;
            totalWeight      += NdotL;
        }
    }
    prefilteredColor = prefilteredColor / totalWeight;
    FragColor = vec4(prefilteredColor, 1.0);
}
```

**与 diffuse 的差异**:
- 卷积核不同：从 $\cos\theta/\pi$ 变为 $\text{GGX} \cdot V \cdot \cos\theta$（更复杂）
- 采样方式不同:从均匀采样变为**重要性采样**(按 GGX 分布采,大部分样本集中在反射峰附近)
- 依赖粗糙度:每个 mip 级别对应一个 roughness

### 四、作用

#### 1. 把"运行时积分"变为"运行时查表"

原本渲染方程要求每个像素实时积分整个半球 → 不可行。

卷积后:

```
运行时:color = texture(irradianceMap, N).rgb * albedo / π;
```

**一次纹理采样**代替**几千次采样积分**。

#### 2. 离线烘焙不变量

卷积核(irradiance 的 Lambert,prefilter 的 GGX)是材质无关的固定函数 → 可预计算成静态贴图。

#### 3. 降维

把 4D 函数 $f(\omega_i, \omega_o)$ 通过卷积近似成 2D 函数 `g(N)` 或 `g(R, roughness)`,可直接存入 cubemap。

### 五、效果对比

#### 未卷积 vs 卷积

| 情况 | 视觉效果 | 性能 |
|------|---------|------|
| 直接用 envCubemap 作漫反射 | 高光斑点当漫反射用,金属感错乱 | 快但错 |
| 卷积后的 irradianceMap | 漫反射柔和,方向感正确(Lambert) | 运行时 1 次采样 |

#### 卷积核大小 vs 模糊程度

```
roughness = 0.0   卷积核极窄 → 几乎是原始 cubemap(镜面反射)
roughness = 0.5   卷积核中等 → 中等模糊(半镜面)
roughness = 1.0   卷积核宽   → 大面积模糊(漫反射+粗糙)
```

这与图像处理中"高斯卷积核越大图越糊"是同一个原理——**核越宽,高频信息被平均掉越多**。

#### Diffuse vs Specular 卷积的视觉差异

```
envCubemap(原始)         irradianceMap(diffuse 卷积)
┌──────────────┐         ┌──────────────┐
│ 高频细节多    │    →    │ 极度模糊      │
│ 太阳可见      │         │ 太阳被抹平    │
│ 颜色对比强    │         │ 颜色平滑过渡  │
└──────────────┘         └──────────────┘
        ↓
prefilterMap(specular 卷积, mip0~mip4)
┌──────────┬──────────┬──────────┬──────────┐
│ mip0     │ mip1     │ mip2     │ mip3     │
│ 近似原图  │ 轻模糊    │ 中模糊    │ 重模糊    │
│ rough=0  │ rough=.25│ rough=.5 │ rough=1  │
└──────────┴──────────┴──────────┴──────────┘
```

### 六、与图像处理卷积的关系

两者**本质完全一样**,只是定义域不同:

| 维度 | 图像处理卷积 | IBL 卷积 |
|------|------------|---------|
| 定义域 | 2D 像素网格 | 球面方向 |
| 输入 | 像素颜色 | radiance |
| 核 | 高斯/Sobel/box | Lambert/GGX |
| 权重 | 对称 2D 分布 | 球面余弦分布 |
| 输出 | 滤波后图像 | 预计算光照贴图 |

LearnOpenGL 中提到的 "卷积核(半球的每个方向)" 就是在球面上做与 2D 高斯模糊等价的事——**把输入信号按核权重做加权平均,得到更平滑的输出**。

### 七、一句话总结

> **Convolution = 把输入信号(envCubemap 的 radiance)按固定核(Lambert 余弦 / GGX 分布)在半球上做加权累加,得到预计算贴图(irradianceMap / prefilterMap)。**
>
> 数学上是 $\int L(\omega_i) \cdot W(\omega_i,\omega_o) \, d\omega_i$;代码上是嵌套循环 + 纹理采样 + 加权累加;作用是把运行时昂贵的积分变成运行时一次纹理采样;效果是按核的"宽度"对环境贴图做不同程度的模糊。

# ImportanceSampleGGX 的实现意义与"PDF消失"之谜

## 1. ImportanceSampleGGX 的"重要性"在哪里

它做的事是**逆 CDF 变换**：把 Hammersley 给出的均匀低差异样本 $(\xi_1, \xi_2) \in [0,1]^2$，变成服从 GGX 分布的半程向量 $H$。

由于 GGX 各向同性，方位角 $\phi$ 均匀分布；极角 $\theta$ 的边际 CDF 可以解析求逆，得到：

$$
\cos\theta_H = \sqrt{\frac{1-\xi_2}{1+(\alpha^2-1)\xi_2}},\qquad \alpha = \text{roughness}^2
$$

这正是 LearnOpenGL 代码里的那一行：

```glsl
float a = roughness*roughness;                              // α
float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));  // α² = a*a
```

它对应的半向量 PDF（在立体角度量下）是：

$$
p_H(H) = D(H)\,(N\cdot H)
$$

这一步是整个 importance sampling 的"心脏"：**不需要任何拒绝采样**，直接把均匀样本"扭曲"成与 NDF 形状一致的样本分布。样本自动集中在 BRDF 贡献大的方向上 → 方差急剧下降 → 同样的样本数能得到稳定得多的结果。

如果不做这一步（直接均匀采样半球），在低 roughness 时几乎所有样本都浪费在 BRDF 几乎为 0 的地方，结果会是一片噪点。

---

## 2. "Importance sampling 不该除以 PDF 吗？"

**该除，而且确实除了 —— 只是被解析地消掉了，所以代码里看不到 `/pdf`。**

### 2.1 严格做法（Karis 论文）

预过滤贴图要算的是（split-sum 第一项，且采用 Epic 的近似 $V=N=R$）：

$$
I = \int_\Omega L_i(L)\,f_r(L,V)\,(N\cdot L)\,d\omega_L
$$

按 $H$ 采样、通过 $L = \text{reflect}(-V,H)$ 得到 $L$。注意 $H\to L$ 的雅可比：

$$
d\omega_L = 4\,(V\cdot H)\,d\omega_H \;\;\xrightarrow{V=N}\;\; d\omega_L = 4\,(N\cdot H)\,d\omega_H
$$

所以 $L$ 的 PDF 是：

$$
p_L(L) = p_H(H)\cdot\frac{d\omega_H}{d\omega_L} = D(H)(N\cdot H)\cdot\frac{1}{4(N\cdot H)} = \frac{D(H)}{4}
$$

代入蒙特卡洛估计：

$$
I \approx \frac{1}{N}\sum_i \frac{L_i\,\dfrac{D\,G\,F}{4\,(N\cdot V)(N\cdot L)}\,(N\cdot L)}{D/4}
\;\;\xrightarrow{N\cdot V=1}\;\;
\frac{1}{N}\sum_i L_i\cdot G\cdot F
$$

**$D$、$\cos\theta_H$、$(N\cdot L)$ 全部和 PDF 抵消掉了**，分子只剩 $L_i \cdot G \cdot F$。

这才是真正的"重要性采样 + 除以 pdf"——只不过除完之后，PDF 项被 BRDF 里的 $D$ 和 $\cos$ 项约掉了，所以 Karis 的代码里你看不到 `/ pdf`。

### 2.2 LearnOpenGL 的进一步简化

LearnOpenGL 的预过滤着色器里实际写的是：

```glsl
prefilteredColor += texture(environmentMap, L).rgb * NdotL;
totalWeight      += NdotL;
...
prefilteredColor /= totalWeight;
```

它**没有**采用 Karis 的严格估计 $\frac{1}{N}\sum L_i\,G\,F$，而是用 $N\cdot L$ 作权重做一个**加权平均**。等价于把 $G\cdot F$ 近似看成常数 1（或说用一个余弦权重去"冒充"$G\cdot F$）。

这是一个**额外的工程近似**，之所以可用，是因为：

1. ImportanceSampleGGX 已经把样本集中到了 BRDF 显著的方向上，光这一步就消掉了绝大部分方差；
2. Split-sum 本身就是近似，$V=N$ 的假设已经引入了误差，再丢掉 $G\cdot F$ 不会显著恶化；
3. 在低 roughness 时 $G\cdot F\approx 1$，高 roughness 时 $N\cdot L$ 的衰减方向与 $G$ 一致，能近似补偿。

但要注意：**严格说 LearnOpenGL 这段代码是有偏差的**，在掠射角、高 roughness 下会比 Karis 公式偏亮/偏暗。Frostbite、UE 等工业实现里通常会用 Karis 的 $\sum L_i\,G\,F$ 形式（甚至加上 PDF 的 mip 选择，也就是搜索结果 2 里 `omegaS = 1/(N·pdf)` 那段）。

---

## 3. 一句话总结

| 问题 | 答案 |
|---|---|
| ImportanceSampleGGX 重要性在哪 | 通过逆 CDF 把均匀样本变成服从 $D(H)(N\cdot H)$ 的样本，**几乎零成本**地把方差降下来 |
| 为什么代码里没有 `/pdf` | 严格公式里 PDF 与 BRDF 中的 $D$、$\cos$ 项**解析抵消**；LearnOpenGL 进一步用 $N\cdot L$ 加权平均**近似**掉了剩下的 $G\cdot F$ |

所以你的直觉完全正确——importance sampling 本来就该除以 pdf。只是在 GGX + $V=N$ 这一特殊配置下，pdf 在代数上被消干净了，才"看不见"。如果想看显式的 pdf 项，去读 Frostbite 的预过滤代码（搜索结果 2 中 `pdf = distributionIBL(...) * NdotH / (4 * VdotH)`），那里 pdf 是显式参与 mip 选择的。


# 为什么是 `prefilteredColor / totalWeight` 而不是 `/ N`？

你的疑惑非常合理——这正是这段代码最容易让人困惑的地方。答案分两个层次。

---

## 1. 表层原因：`totalWeight ≠ N`

循环里有跳过下半球的逻辑：

```glsl
if (NdotL > 0.0)
{
    prefilteredColor += texture(environmentMap, L).rgb * NdotL;
    totalWeight      += NdotL;
}
```

- 当 $N\cdot L \le 0$ 时（反射方向落到表面下方），这个样本被丢弃，**既不累加到颜色，也不累加到权重**。
- 被丢弃的样本数随 roughness 增大而增多（粗糙表面反射方向散得更开，更容易打到背面）。
- 所以 `totalWeight` 既不等于 $N$，也不是固定值，**随 roughness 变化**。

如果直接 `/ N`，结果会随 roughness 变暗（粗糙表面被丢弃的样本多，但分母还是 $N$，颜色被"稀释"了）。除以 `totalWeight` 就是为了**消除这种样本丢弃带来的偏差**。

---

## 2. 深层原因：这是**加权平均**，不是蒙特卡洛估计

这才是更关键的数学原因。看清楚两种写法的差别：

### 写法 A（你期望的"标准"重要性采样）

```glsl
prefilteredColor += L_i * G * F;    // pdf 已被 BRDF 中的 D 约掉
// 最后：
prefilteredColor /= N;              // 标准蒙特卡洛 1/N
```

这是 Karis 论文里的严格形式，估计的是：
$$
I = \int_\Omega L_i\,f_r\,(N\cdot L)\,d\omega_L \;\approx\; \frac{1}{N}\sum_i L_i\,G\,F
$$

### 写法 B（LearnOpenGL 实际用的）

```glsl
prefilteredColor += L_i * NdotL;
totalWeight      += NdotL;
// 最后：
prefilteredColor /= totalWeight;
```

它在估计**另一个东西**——一个**加权平均**：

$$
\frac{\sum_i L_i\,(N\cdot L_i)}{\sum_i (N\cdot L_i)}
\;\;\xrightarrow{N\to\infty}\;\;
\frac{\int_\Omega L_i\,(N\cdot L)\,d\omega_L}{\int_\Omega (N\cdot L)\,d\omega_L}
$$

分母 $\int (N\cdot L)\,d\omega$ 不是 1，也不是 $N$，而是**权重之和**。所以必须用 `totalWeight`，不能用 `N`。

---

## 3. 为什么 LearnOpenGL 用写法 B？

写法 B 等价于把 BRDF 的 $G\cdot F$ 部分**近似为常数 1**，只剩一个 $\cos\theta$ 权重。然后通过**归一化**（除以权重之和）得到一个与样本数、与丢弃样本数量都无关的"加权平均辐照度"。

这是 Karis 在 UE4 演讲里给出的工程简化：

| 步骤 | 严格 Karis | LearnOpenGL 简化 |
|---|---|---|
| BRDF 中的 $D$ | 与 pdf 抵消 | 与 pdf 抵消 |
| BRDF 中的 $G\cdot F$ | 保留在分子 | 近似为 1（丢弃） |
| $\cos\theta = N\cdot L$ | 通过 $d\omega_H \to d\omega_L$ 雅可比抵消 | **保留作为权重** |
| 归一化 | $1/N$ | $1/\sum w_i$（加权平均） |

**关键点**：写法 B 是个有偏近似，但它有个非常好的性质——**结果与样本数无关**（只要样本足够多，加权平均收敛到同一个值）。这意味着你可以用很少的样本得到稳定的结果，代价是在掠射角和高 roughness 下不够准确。

---

## 4. 一句话回答你的问题

> "每次计算不是已经乘了 NdotL 吗？"

是的，`NdotL` 是**权重**。乘了权重之后，必须除以**权重之和**才能得到加权平均；除以 $N$ 得到的是加权和，会因为下半球样本被丢弃、roughness 不同而出现亮度漂移。

打个比方：考试算加权平均分，权重是学分。你不能用"总学分×科目数"做分母，必须用"实际选了的课的学分之和"做分母——哪怕你只选了一部分课。这里 `totalWeight` 就是"实际采纳样本的权重之和"。