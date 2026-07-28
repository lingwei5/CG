


# 粒子渲染技术对比：point sprite / sprite 面片 / billboard / 粒子系统 / imposter / participating media

> 这一组技术都属于"用比真实几何更便宜的代理体来近似渲染"的范畴，常见于云、雾、烟、树木、草地、远景等场景。
> 下面以 **云的渲染** 为统一例子，对比它们的核心差异。

## 一、核心技术对比表

| 技术 | 几何代理 | 是否面向相机 | 是否随距离切换 | 是否带动画 | 适合对象 | 云渲染示例 |
|------|---------|------------|--------------|-----------|---------|----------|
| **Point Sprite** | 单个像素点（光栅化为小方块/小圆） | 否（点本身无朝向） | 否 | 可控 | 小颗粒、星点、远距离尘埃 | 远景天空中细密的"星云状"尘埃点 |
| **Sprite 面片** | 一个固定朝向的 quad（4 顶点） | 否（朝向固定） | 否 | UV 滚动 | 2D 装饰、远景贴图 | 天空盒上一张云贴图 |
| **Billboard** | 一个 quad，每帧重新朝向相机 | **是（轴向或全朝向）** | 否 | 可换贴图 | 树木、草地、爆炸、近景云 | 一团云永远面向相机的 quad |
| **粒子系统** | 大量 point sprite / billboard 的集合 | 单个粒子同上 | 否 | **是（生命周期/运动）** | 烟、火、雨、雪、动态云 | 由几千个云粒子组合成的体积云外观 |
| **Imposter（精灵代理）** | 一个 billboard，但贴图是从真实几何**离线/实时烘焙** | 是 | **是（距离切换 LOD）** | 否（可周期更新） | 远景树木、建筑、复杂云 | 远景云团用一张烘焙的云图代替真实 mesh |
| **Participating Media（参与介质）** | 不是面片，而是 3D 体素 / ray march 的**体积** | N/A | 否 | 可有风场动画 | 雾、云、烟、天空 | 真实的体积云，光线在云内多次散射 |

## 二、逐项详解（以云为例）

### 1. Point Sprite

**定义**：把每个粒子作为一个点（`GL_POINTS`），由 GPU 在光栅化阶段自动扩展成屏幕空间的小方块（带 `gl_PointSize`），并贴上贴图。

**特点**：
- **顶点数据最少**：1 顶点 = 1 粒子，无索引、无四边形拓扑。
- **始终面向屏幕**：因为是屏幕空间扩展，不需要 CPU 计算朝向。
- **大小受限**：`gl_PointSize` 有最大值限制（常见 64~1024 像素），大粒子不适合。
- **透视感弱**：所有点在屏幕上等大，不随深度自动透视缩放（需手动在 shader 中按 `1/depth` 缩放）。

**云渲染示例**：
```glsl
// vertex
gl_PointSize = pointSize / viewSpaceZ;
gl_Position = MVP * vec4(pos, 1.0);
```
适合表现**高空远景的细碎云絮**或云的"边缘粒子细节"，但无法表现大块云的体积感。

### 2. Sprite 面片

**定义**：手动构造一个 quad（4 顶点 + 2 三角形），贴上一张云贴图，**朝向在场景中固定**（不随相机变化）。

**特点**：
- 朝向固定，从背面看会"消失"或看到反向贴图。
- 比 billboard 便宜（无需每帧旋转），但视角受限。
- 适合平面装饰物，例如 UI、天空盒贴图。

**云渲染示例**：天空盒上贴一张大尺寸云贴图，相机在地面上移动时云"贴在天空上"。无法穿过云，也无法从上看下。

### 3. Billboard（公告板）

**定义**：一个 quad，但**每帧根据相机位置旋转**，使法线始终指向相机（或约束在某个轴上，如只绕 Y 轴旋转——"圆柱公告板"）。

**分类**：
- **全朝向 billboard**（spherical）：完全朝向相机，从任何角度都看到正面。
- **圆柱 billboard**（cylindrical）：只绕一个轴旋转，适合树木（Y 轴固定，俯视会失效）。
- **屏幕对齐 billboard**：直接在屏幕空间对齐，常用于 UI 粒子。

**云渲染示例**：
```glsl
// 构造相机空间下的 quad
vec3 right = cameraRight_world;
vec3 up    = cameraUp_world;
vec3 pos   = particlePos + (right * uv.x + up * uv.y) * size;
```
适合表现**单团云**，但相机穿过去时仍然只是一张片，没有内部结构。

### 4. 粒子系统

**定义**：大量 point sprite / billboard 的集合，每个粒子有**生命周期、速度、力场（重力、风）、颜色衰减**等属性。

**特点**：
- 强调"动态"：粒子随时间生成、运动、消亡。
- 由发射器（emitter）控制生成位置、初速度、速率。
- 可以用 GPU compute 或 transform feedback 做大规模并行模拟。

**云渲染示例**：由几千个带 alpha 软边的 billboard 粒子组成一团云，粒子有缓慢的"沸腾"动画。视觉上比单张 billboard 更立体，但仍然是"层叠的 2D"，相机穿过时仍会露出片状本质。

### 5. Imposter（精灵代理）

**定义**：billboard 的高级版本——**贴图不是美术预先画的，而是从真实 3D 模型渲染得到**。通常从多个视角烘焙一组图（或一张 atlas），运行时根据相机方向选取最接近的视角贴图。

**特点**：
- 远距离时几乎以假乱真，是 LOD 系统的"终极档"。
- 切换视角时可能有"跳变"，需要多视角插值或 dithering 过渡。
- 烘焙开销大，但运行时极快。

**云渲染示例**：把一团体积云离线渲染成 8 个视角的 atlas，远景时用 imposter 代替真实云几何，相机靠近时再切换回 mesh 或 raymarch。常用于云海远景。

### 6. Participating Media（参与介质）

**定义**：不使用任何面片，而是把云建模为**3D 体积数据**（密度场 σ(x)），光线在其中发生吸收、散射、发射。渲染时通过 **ray marching** 累加每一段的透射率与散射光。

**核心方程**（参与介质渲染方程）：
```
L_out = Σ [ T(t_i) · σ_s(t_i) · L_in(t_i) · Δt ]
T(t) = exp(-∫ σ_t(s) ds)     # Beer-Lambert 透射率
```

**特点**：
- **物理正确**：光线会在云内多次散射，产生 god ray、银边、暗核心等真实云特征。
- **开销最高**：每像素需要采样几十~几百次体积纹理。
- 通常配合 **噪声纹理**（Perlin/Worley）+ **ray march** + **multiple scattering 近似**（如 UE4 的 extensive scattering approximation）。

**云渲染示例**：UE5、Horizon Zero Dawn、Decima 引擎的体积云，都是 ray march + 噪声合成的参与介质。

## 三、云渲染的"技术阶梯"

以渲染一朵云为例，按效果从低到高、开销从小到大排列：

```
1. Sprite 面片      ── 一张云贴图贴在天空盒
   ↓ 增加相机朝向
2. Billboard        ── 一张云贴图始终朝向相机
   ↓ 增加粒子数与生命周期
3. 粒子系统         ── 几千个云粒子叠加
   ↓ 烘焙真实几何到贴图
4. Imposter         ── 远景用烘焙图，近景切换 mesh
   ↓ 把云当体积数据
5. Participating Media ── ray march 体积云，物理散射
```

## 四、性能与效果对比

| 维度 | Point Sprite | Sprite | Billboard | 粒子系统 | Imposter | Participating Media |
|------|-------------|--------|-----------|---------|----------|-------------------|
| 顶点数 / 对象 | 1 | 4 | 4 | 1~4 × N | 4 | 0（per-pixel） |
| 每帧 CPU 开销 | 低 | 低 | 中（需算朝向） | 中~高（模拟） | 低（切换贴图） | 极低（全 GPU） |
| 每像素 GPU 开销 | 极低 | 极低 | 低 | 低 × N | 低 | **高**（ray march） |
| 视角正确性 | 屏幕 | 差 | 好（全朝向）/ 中（圆柱） | 同 billboard | 接近真实 | 完美 |
| 相机穿越 | 不行 | 不行 | 不行（露馅） | 不行（露馅） | 切换 LOD | **可行** |
| 物理感（光照/阴影） | 无 | 无 | 无（除非 fake） | 弱 | 中（烘焙光照） | **强**（多次散射） |
| 适合距离 | 远景 | 任意 | 中近景 | 中近景 | 远景 | 任意 |

## 五、关键区别一句话总结

- **Point Sprite vs Billboard**：前者是 GPU 光栅化阶段自动扩展的点（屏幕空间），后者是手动构造的 quad（世界空间）。
- **Billboard vs Imposter**：前者贴图是美术画的，后者贴图是从真实模型烘焙的。
- **粒子系统 vs 参与介质**：前者是大量离散面片的叠加（粒子有边界），后者是连续的体积场（无粒子概念）。
- **Imposter vs 参与介质**：前者是 2D 贴图欺骗（视角切换有跳变），后者是 3D 物理积分（任意视角正确）。

## 六、实际应用建议

| 场景需求 | 推荐技术 |
|---------|---------|
| 远景天空装饰云（不交互） | Sprite 面片 / Billboard |
| 大量动态小云絮 | 粒子系统（point sprite） |
| 单团近距离云 | Billboard + 软边贴图 |
| 远景云海（千团云） | Imposter（烘焙 atlas） |
| 主机/PC 体积云 | Participating Media（ray march + 噪声） |
| 移动端云 | Billboard + 假散射 / 简化 ray march |
| 飞行模拟器（可穿越云） | **必须** Participating Media |

## 七、延伸阅读

- **Participating Media**：PBRT 第 11 章 *Volume Rendering*、Wrenninge 2015 *Production Volume Rendering*。
- **体积云**：Schneider 2015 *The Real-time Volumetric Cloudscapes of Horizon Zero Dawn*（SIGGRAPH）、UE5 *Volumetric Cloud* 文档。
- **Imposter**：Décoret 2003 *Billboard Clouds*、GIEC 2005 *Nuance*。
- **Billboard 与粒子系统**：PBRT 第 7.9 节、Three.js `Sprite` / `Points` 文档。
- **GPU 粒子**：Unity ECS 粒子示例、Unreal Niagara 文档。 


# billboard实现细节
Billboard 的核心就一句话：**在顶点着色器里，以面片中心为原点，沿着"相机的右向量"和"相机的上向量"把四边形的四个角展开**。这样四边形就永远平行于相机平面，也就"始终面向相机"了。

## 一、几何直觉：为什么这样做就对

相机在观察空间（Camera Space）里，右是 `(1,0,0)`、上是 `(0,1,0)`、前是 `(0,0,-1)`。如果我们能把一个 quad 放到世界空间里，并且让它的右方向对齐"相机右向量在世界空间的指向"、上方向对齐"相机上向量在世界空间的指向"——那么这个 quad 自然就平行于相机平面，正面朝向相机。

所以我们只需要两样东西：
1. **面片中心的世界坐标** `center`
2. **相机右/上向量在世界空间的表示** `cameraRight`、`cameraUp`

然后四个顶点这样算：

```
worldPos = center + cameraRight * (localX * sizeX) + cameraUp * (localY * sizeY)
```

其中 `localX, localY ∈ [-0.5, 0.5]` 是 quad 的原始局部坐标。

## 二、关键技巧：从哪里拿 cameraRight / cameraUp

不需要手动算相机基向量。**视矩阵（View Matrix）里直接存着这些值**：

```
cameraRight_world = vec3(View[0][0], View[1][0], View[2][0])
cameraUp_world    = vec3(View[0][1], View[1][1], View[2][1])
```

原理：View 矩阵的作用是把世界空间转到相机空间。它的逆矩阵（即从相机空间回到世界空间）的列向量就是相机基向量在世界空间的表示。而 View 矩阵是正交旋转矩阵，其逆等于转置，所以**直接取 View 矩阵的第一列和第二列**就分别得到 `cameraRight` 和 `cameraUp` 在世界空间的方向。

## 三、完整顶点着色器（世界空间 Billboard）

```glsl
#version 300 es
layout(location = 0) in vec2 vertexPosition;  // 局部坐标, 范围 [-0.5, 0.5]
layout(location = 2) in vec2 vertexUV;

uniform mat4 u_view;           // 视矩阵
uniform mat4 u_viewProj;       // 视图投影矩阵
uniform vec3 u_center;         // 面片中心世界坐标
uniform vec2 u_size;           // 面片尺寸 (世界单位)

out vec2 uv;

void main() {
    // 从视矩阵提取相机右/上向量 (世界空间)
    vec3 cameraRight = vec3(u_view[0][0], u_view[1][0], u_view[2][0]);
    vec3 cameraUp    = vec3(u_view[0][1], u_view[1][1], u_view[2][1]);

    // 在世界空间展开四边形
    vec3 worldPos = u_center 
                  + cameraRight * vertexPosition.x * u_size.x 
                  + cameraUp    * vertexPosition.y * u_size.y;

    gl_Position = u_viewProj * vec4(worldPos, 1.0);
    uv = vertexUV;
}
```

这就是标准的世界空间 Billboard，GPU Gems 和 OpenGL-Tutorial 都用的这个套路。

## 四、两种常见变体

### 1. 球形 Billboard（Spherical）—— 完全面向相机

上面那份代码就是球形的。**适合**：粒子、光晕、血条、名字标签、云团 sprite。

### 2. 圆柱形 Billboard（Cylindrical）—— 只绕世界 Y 轴转

树、草、路牌需要用这种——否则镜头压低时树会"躺倒"。做法是**强制 up 为世界 Y 轴**，right 由相机前方向在 XZ 平面上的投影决定：

```glsl
// 把相机前方向拍扁到 XZ 平面
vec3 camForward = -vec3(u_view[0][2], u_view[1][2], u_view[2][2]);
vec3 forwardFlat = normalize(vec3(camForward.x, 0.0, camForward.z));

vec3 right = normalize(cross(worldUp, forwardFlat));  // worldUp = (0,1,0)
vec3 up    = worldUp;

vec3 worldPos = u_center 
              + right * vertexPosition.x * u_size.x 
              + up    * vertexPosition.y * u_size.y;
```

### 3. 屏幕空间固定尺寸 Billboard

如果希望 billboard 在屏幕上**永远占同样像素大小**（不随距离缩小），就把中心点变换到裁剪空间，然后在 NDC 里做偏移：

```glsl
vec4 clipPos = u_viewProj * vec4(u_center, 1.0);
clipPos.xyz /= clipPos.w;  // 透视除法, 进入 NDC
clipPos.xy += vertexPosition * vec2(0.2, 0.05);  // 直接 NDC 偏移
gl_Position = clipPos;
```

适合血条、UI 标签。

## 五、CPU 端做法（不推荐但最简单）

如果只是单个物体（比如一个 NPC 的名字标签），可以直接在 CPU 每帧设置旋转：

```cpp
// 让面片的旋转 = 相机的旋转
billboard->transform.rotation = camera->transform.rotation;
```

原理是**让 quad 的模型矩阵旋转部分完全复制相机旋转**。这种做法单个物体没问题，但如果有几千个粒子，每帧在 CPU 改 Transform 会把主线程拖垮——所以粒子系统**必须在 GPU 顶点着色器里做**。

## 六、工程实现中的几个坑

> ⚠️ **坑 1：viewDir 与 up 几乎平行时坐标系退化**
> 当相机俯仰到接近垂直（看天/看地）时，`viewDir` 和 `(0,1,0)` 几乎平行，叉乘出来的 right 向量会不稳定。修复方法：

```glsl
vec3 up = abs(viewDir.y) > 0.999 ? vec3(0,0,1) : vec3(0,1,0);
vec3 right = normalize(cross(up, viewDir));
up = normalize(cross(viewDir, right));
```

> ⚠️ **坑 2：模型矩阵的旋转要被忽略**
> 如果 mesh 自身带有旋转，直接乘 MVP 会导致 billboard 不朝向相机。正确做法是**只取模型矩阵的平移部分**（第 4 列）作为 center，缩放部分用列向量长度提取，旋转部分完全丢弃，然后用相机基向量重建。

> ⚠️ **坑 3：合批（Batching）问题**
> 在 Unity 等引擎中，如果使用"在顶点着色器里读模型矩阵重建世界坐标"的方式，静态合批会改变顶点信息导致失败。解决方法是**把 center 作为顶点属性或 instance 属性传入**，而不是依赖模型矩阵。

> ⚠️ **坑 4：尺寸单位**
> `u_size` 是**世界单位**。如果想让 billboard 在屏幕上保持固定像素大小，必须改用上面"屏幕空间固定尺寸"的方案，或者在 CPU 端根据距离动态计算 `u_size`（size ∝ distance）。

## 七、完整流程归纳

```
输入: 面片中心 center, 尺寸 size, 视矩阵 View, 视图投影矩阵 VP
  ↓
1. 从 View 提取 cameraRight = (View[0][0], View[1][0], View[2][0])
2. 从 View 提取 cameraUp    = (View[0][1], View[1][1], View[2][1])
  ↓ (如果是圆柱形, 改为用 worldUp 和 projected forward 构造 right/up)
3. 每个顶点: worldPos = center + cameraRight * x * size.x + cameraUp * y * size.y
4. gl_Position = VP * vec4(worldPos, 1.0)
  ↓
输出: 永远平行于相机平面的四边形
```

**核心就这一步：用相机的右和上向量，把 quad 的四个角从局部空间"展开"到世界空间。** 剩下的都是变体——球形 vs 圆柱形、世界空间 vs 屏幕空间、固定尺寸 vs 距离缩放。

下面是一个**支持实例化（Instanced Rendering）的 Billboard 顶点着色器**。每个实例拥有独立的位置、尺寸和颜色，所有实例共用同一份四边形网格（4 个顶点）。

## 八、完整 GLSL 顶点着色器（核心 profile）

```glsl
#version 330 core

// ---- 每个顶点的属性（四边形网格，4 个顶点）----
layout(location = 0) in vec2 a_localPos;   // 局部坐标，范围 [-0.5, 0.5]
layout(location = 1) in vec2 a_uv;         // 纹理坐标

// ---- 每个实例的属性（由 glVertexAttribDivisor 分离）----
layout(location = 2) in vec3 a_instanceCenter;   // 实例中心世界坐标
layout(location = 3) in vec2 a_instanceSize;     // 实例尺寸（世界单位）
layout(location = 4) in vec4 a_instanceColor;    // 实例颜色

// ---- Uniforms ----
uniform mat4 u_viewProj;   // 视图投影矩阵
uniform mat4 u_view;       // 视矩阵（用于提取相机基向量）

// ---- 输出到片元着色器 ----
out vec2 v_uv;
out vec4 v_color;

void main()
{
    // 从视矩阵提取相机右向量和上向量（世界空间）
    // 视矩阵是正交矩阵，其转置 = 逆，所以列向量就是世界空间中的基向量
    vec3 cameraRight = vec3(u_view[0][0], u_view[1][0], u_view[2][0]);
    vec3 cameraUp    = vec3(u_view[0][1], u_view[1][1], u_view[2][1]);

    // 在世界空间中展开四边形
    vec3 worldPos = a_instanceCenter
                  + cameraRight * a_localPos.x * a_instanceSize.x
                  + cameraUp    * a_localPos.y * a_instanceSize.y;

    // 变换到裁剪空间
    gl_Position = u_viewProj * vec4(worldPos, 1.0);

    // 传递纹理坐标和颜色
    v_uv  = a_uv;
    v_color = a_instanceColor;
}
```

## CPU 端设置（OpenGL 3.3+）

### 1. 顶点属性指针与除数

```cpp
// 四边形网格：4 个顶点，顺序为 (-0.5,-0.5), (0.5,-0.5), (-0.5,0.5), (0.5,0.5)
float vertices[] = {
    -0.5f, -0.5f,  0.0f, 0.0f,
     0.5f, -0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f,  0.0f, 1.0f,
     0.5f,  0.5f,  1.0f, 1.0f
};
// 顶点属性
glEnableVertexAttribArray(0);
glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)0);
glEnableVertexAttribArray(1);
glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)(2*sizeof(float)));

// 实例属性（中心、尺寸、颜色）
// 假设 instanceData 是一个包含 N 个实例的结构体数组
struct InstanceData {
    glm::vec3 center;
    glm::vec2 size;
    glm::vec4 color;
};
std::vector<InstanceData> instances(N);
// ... 填充数据 ...

GLuint instanceVBO;
glGenBuffers(1, &instanceVBO);
glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
glBufferData(GL_ARRAY_BUFFER, N * sizeof(InstanceData), instances.data(), GL_DYNAMIC_DRAW);

// 设置实例属性指针
glEnableVertexAttribArray(2);
glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, sizeof(InstanceData), (void*)offsetof(InstanceData, center));
glVertexAttribDivisor(2, 1);   // 每个实例更新一次

glEnableVertexAttribArray(3);
glVertexAttribPointer(3, 2, GL_FLOAT, GL_FALSE, sizeof(InstanceData), (void*)offsetof(InstanceData, size));
glVertexAttribDivisor(3, 1);

glEnableVertexAttribArray(4);
glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, sizeof(InstanceData), (void*)offsetof(InstanceData, color));
glVertexAttribDivisor(4, 1);
```

### 2. 绘制调用

```cpp
glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, N);  // 四边形用 triangle strip
// 或者用 GL_TRIANGLES + 索引，这里为了简洁用 strip
```

## 变体：圆柱形 Billboard（只绕 Y 轴旋转）

如果希望 billboard 只绕世界 Y 轴旋转（适合树、草、路牌），替换 main 函数中的朝向计算：

```glsl
void main()
{
    // 相机前方向（世界空间）
    vec3 camForward = -vec3(u_view[0][2], u_view[1][2], u_view[2][2]);
    // 拍扁到 XZ 平面
    vec3 forwardFlat = normalize(vec3(camForward.x, 0.0, camForward.z));
    // 重新构建右手系
    vec3 worldUp = vec3(0.0, 1.0, 0.0);
    vec3 right   = normalize(cross(worldUp, forwardFlat));
    vec3 up      = cross(forwardFlat, right);  // 实际上就是 worldUp

    vec3 worldPos = a_instanceCenter
                  + right * a_localPos.x * a_instanceSize.x
                  + up    * a_localPos.y * a_instanceSize.y;

    gl_Position = u_viewProj * vec4(worldPos, 1.0);
    v_uv  = a_uv;
    v_color = a_instanceColor;
}
```

## 性能提示

- 实例属性尽量紧凑（本例中每个实例 9 个 float = 36 字节），避免冗余
- 如果颜色对所有实例相同，可以改为 uniform 而不是 per-instance 属性
- 对于大量实例（>10万），考虑使用 **SSBO（Shader Storage Buffer Object）** 或 **间接绘制（Indirect Drawing）** 以减少 CPU 提交开销
- 如果实例位置需要更新（如粒子系统），使用 `glMapBufferRange` 或 `glBufferSubData` 更新 VBO

