# 图形渲染管线：从模型到屏幕像素的全流程

> 本文档系统介绍实时图形渲染管线的完整流程，从 3D 模型数据到屏幕窗口像素的每一步。每个阶段都包含：数学原理、软件实现、GPU 硬件固定功能实现、算法基础。

---

## 目录

- [一、总体流程概览](#一总体流程概览)
- [二、应用阶段（Application Stage）](#二应用阶段application-stage)
- [三、顶点处理阶段](#三顶点处理阶段)
- [四、图元装配与裁剪](#四图元装配与裁剪)
- [五、投影与视口变换](#五投影与视口变换)
- [六、光栅化阶段](#六光栅化阶段)
- [七、片段处理阶段](#七片段处理阶段)
- [八、逐片段测试与混合](#八逐片段测试与混合)
- [九、输出到帧缓冲与显示](#九输出到帧缓冲与显示)
- [十、现代管线的演进](#十现代管线的演进)
- [附录 A：数学符号约定](#附录-a数学符号约定)
- [附录 B：参考文献](#附录-b参考文献)

---

## 一、总体流程概览

### 1.1 管线全图

```
┌─────────────────────────────────────────────────────────────────┐
│                    应用阶段 (CPU)                                │
│  模型加载 → 视锥剔除 → 状态设置 → Draw Call                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ 顶点数据 + 索引 + Uniform
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  顶点着色器 (Vertex Shader, 可编程)                              │
│  顶点变换：Model → View → Projection                            │
│  输出：Clip Space 坐标 (x, y, z, w)                              │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  曲面细分 / 几何着色器 (可选, 可编程)                             │
│  Tessellation: HS → TS → DS                                     │
│  Geometry Shader: 图元级增删                                    │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  图元装配 (Primitive Assembly, 固定功能)                         │
│  索引 → 三角形/线/点                                            │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  裁剪 (Clipping, 固定功能)                                       │
│  Cohen-Sutherland / Liang-Barsky 在视锥体内裁剪                  │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  透视除法 (Perspective Divide, 固定功能)                         │
│  (x, y, z, w) → (x/w, y/w, z/w) = NDC                          │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  视口变换 (Viewport Transform, 固定功能)                         │
│  NDC → 窗口坐标 (pixel_x, pixel_y, depth)                       │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  光栅化 (Rasterization, 固定功能)                                │
│  三角形 → 像素片段 (Fragments)                                  │
│  算法：Edge Function (Pineda 1988)                              │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  片段着色器 (Fragment Shader, 可编程)                            │
│  纹理采样、光照、颜色计算                                        │
│  输出：片段颜色 + 深度                                           │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  逐片段测试 (Per-Fragment Operations, 固定功能)                  │
│  像素所有权 → 裁剪 → 深度测试 → 模板测试 → 混合                 │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  帧缓冲 (Framebuffer)                                           │
│  颜色缓冲 + 深度缓冲 + 模板缓冲                                  │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  显示 (Display)                                                 │
│  前缓冲 → 扫描输出 → 显示器                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 阶段分类

| 阶段 | 类型 | 执行者 | 可编程 |
|------|------|--------|--------|
| 应用阶段 | 软件 | CPU | 完全自由 |
| 顶点着色器 | 硬件 | GPU | 是 (VS) |
| 曲面细分 | 硬件 | GPU | 是 (HS/DS) |
| 几何着色器 | 硬件 | GPU | 是 (GS) |
| 图元装配 | 硬件 | GPU | 否 |
| 裁剪 | 硬件 | GPU | 否 |
| 透视除法 | 硬件 | GPU | 否 |
| 视口变换 | 硬件 | GPU | 否 |
| 光栅化 | 硬件 | GPU | 否 |
| 片段着色器 | 硬件 | GPU | 是 (FS) |
| 深度/模板测试 | 硬件 | GPU | 否 |
| 混合 | 硬件 | GPU | 部分 |

### 1.3 数据流

```
顶点数据 (VBO)
   │
   │  位置、法线、UV、颜色...
   ▼
[VS] 顶点 → Clip Space 坐标 + 传递属性
   │
   ▼
[PA]  3 个顶点 → 1 个三角形
   │
   ▼
[Clip] 裁剪到视锥体内
   │
   ▼
[PD]  透视除法 → NDC
   │
   ▼
[VT]  NDC → 窗口坐标
   │
   ▼
[Rast] 三角形 → 片段 (每个像素一个)
   │
   ▼
[FS]  片段 → 颜色 + 深度
   │
   ▼
[Test] 深度/模板测试
   │
   ▼
[Blend] 混合到帧缓冲
   │
   ▼
[FB]   帧缓冲像素
```

---

## 二、应用阶段（Application Stage）

### 2.1 阶段职责

应用阶段在 CPU 上执行，主要任务：

1. **模型加载**：从文件（OBJ/FBX/glTF）读取顶点、索引、材质
2. **场景图遍历**：确定哪些物体可见
3. **视锥剔除 (Frustum Culling)**：剔除视锥外的物体
4. **遮挡剔除 (Occlusion Culling)**：剔除被遮挡的物体
5. **状态设置**：绑定 shader、纹理、缓冲区
6. **Draw Call 提交**：向 GPU 发送绘制命令

### 2.2 数学原理：视锥剔除

视锥是 6 个平面围成的截头锥体。对每个物体的包围球（Bounding Sphere）做平面测试：

```
平面方程：Ax + By + Cz + D = 0
法向量 N = (A, B, C)

点 P 到平面的有符号距离：
d = N · P + D

若 d > +r  → 球在平面外侧（不可见）
若 d < -r  → 球在平面内侧（可见）
否则       → 相交（保守可见）
```

6 个平面都测试通过 → 物体在视锥内。

### 2.3 软件实现

```cpp
struct BoundingSphere { Vec3 center; float radius; };

bool InFrustum(const Frustum& frustum, const BoundingSphere& bs) {
    for (int i = 0; i < 6; ++i) {
        float d = dot(frustum.planes[i].normal, bs.center) + frustum.planes[i].d;
        if (d < -bs.radius) return false;  // 完全在平面外
    }
    return true;
}
```

### 2.4 GPU 硬件实现

应用阶段在 CPU 上完成，GPU 不参与。但现代 GPU 提供：
- **Indirect Draw**：CPU 只提交一次命令，GPU 自己循环绘制
- **GPU Driven Pipeline**：用 Compute Shader 在 GPU 上做剔除（如 Unreal 5 的 Nanite）

### 2.5 算法基础

- **层次包围盒 (BVH)**：空间加速结构，O(log N) 查询
- **八叉树 (Octree)**：空间划分
- **SAP (Sweep and Prune)**：宽相位碰撞检测算法

---

## 三、顶点处理阶段

### 3.1 顶点着色器（Vertex Shader）

顶点着色器对每个顶点独立执行，主要任务：
1. 顶点位置变换（Model → View → Projection）
2. 传递属性（UV、法线、颜色）到片段着色器
3. 顶点级光照（如 Gouraud 着色）

### 3.2 数学原理：坐标变换

#### 3.2.1 齐次坐标

3D 点 `(x, y, z)` 用 4D 齐次坐标 `(x, y, z, w)` 表示：
- `w = 1`：点
- `w = 0`：方向（向量）
- `w ≠ 0`：等价于 `(x/w, y/w, z/w, 1)`

#### 3.2.2 Model 变换（模型 → 世界）

```
P_world = M_model · P_local

M_model = T · R · S
```

其中：
- `T`：平移矩阵
- `R`：旋转矩阵（绕 X/Y/Z 轴）
- `S`：缩放矩阵

平移矩阵：
```
T = [1 0 0 tx]
    [0 1 0 ty]
    [0 0 1 tz]
    [0 0 0 1 ]
```

绕 Y 轴旋转 θ：
```
Ry = [cosθ  0  sinθ  0]
     [0     1  0     0]
     [-sinθ 0  cosθ  0]
     [0     0  0     1]
```

#### 3.2.3 View 变换（世界 → 观察）

观察矩阵将相机变换到原点，朝向 -Z 方向：

```
P_view = M_view · P_world

M_view = (M_camera_world)^(-1)
```

LookAt 矩阵：
```
M_view = [Rx Ry Rz -dot(R, eye)]
         [Ux Uy Uz -dot(U, eye)]
         [Fx Fy Fz -dot(F, eye)]
         [0  0  0   1          ]
```

其中：
- `F`：前向（forward，相机朝向）
- `U`：上向（up）
- `R`：右向（right = cross(F, U)）

#### 3.2.4 Projection 变换（观察 → 裁剪空间）

**透视投影矩阵**：
```
P_proj = [2n/(r-l)  0         (r+l)/(r-l)   0            ]
         [0         2n/(t-b)  (t+b)/(t-b)   0            ]
         [0         0         -(f+n)/(f-n)  -2fn/(f-n)   ]
         [0         0         -1            0            ]
```

其中 `n` = 近平面，`f` = 远平面，`l/r/t/b` = 视锥在近平面的左/右/上/下边界。

变换后顶点在 **Clip Space**（裁剪空间），`w` 分量 = 视空间深度的负值（`-z_view`）。

**正交投影矩阵**：
```
P_ortho = [2/(r-l)  0        0           -(r+l)/(r-l)]
          [0        2/(t-b)  0           -(t+b)/(t-b)]
          [0        0        -2/(f-n)    -(f+n)/(f-n)]
          [0        0        0            1          ]
```

正交投影 `w` 始终 = 1，无透视效果。

#### 3.2.5 法线变换

法线不能用 Model 矩阵直接变换，需要用 **逆转置矩阵**：

```
N_world = (M_model)^(-T) · N_local
```

证明：保持切线 `T` 与法线 `N` 正交：
```
T_world · N_world = (M · T_local) · (M^(-T) · N_local)
                  = T_local · M^T · M^(-T) · N_local
                  = T_local · N_local
                  = 0  ✓
```

### 3.3 软件实现

```cpp
// 顶点着色器（软件版）
struct VSInput {
    Vec3 position;  // local space
    Vec3 normal;
    Vec2 uv;
};

struct VSOutput {
    Vec4 clipPos;   // clip space
    Vec3 worldNormal;
    Vec2 uv;
};

VSOutput VertexShader(const VSInput& in, const Uniforms& u) {
    VSOutput out;
    Vec4 worldPos = u.model * Vec4(in.position, 1.0f);
    Vec4 viewPos  = u.view  * worldPos;
    out.clipPos   = u.proj  * viewPos;
    out.worldNormal = normalize(transpose(inverse(u.model)) * Vec4(in.normal, 0)).xyz();
    out.uv = in.uv;
    return out;
}
```

### 3.4 GPU 硬件实现

GPU 顶点着色器是 **SIMT (Single Instruction Multiple Threads)** 执行：
- 每个顶点分配一个线程
- 多个线程组成 warp/wavefront（NVIDIA 32 线程，AMD 64 线程）
- 同一 warp 内的线程锁步执行相同指令

硬件单元：
- **Vertex Fetch Unit**：从 VBO 取顶点数据
- **Uniform Buffer**：存储 Model/View/Proj 矩阵
- **ALU 阵列**：执行矩阵乘法
- **Post-VS Cache**：缓存 VS 输出

### 3.5 算法基础

- **齐次坐标**：August Ferdinand Möbius, 1827
- **矩阵变换**：线性代数基础
- **SIMT 执行模型**：NVIDIA Tesla 架构（2006）引入

---

## 四、图元装配与裁剪

### 4.1 图元装配（Primitive Assembly）

将顶点按图元类型组合：
- `GL_TRIANGLES`：每 3 个顶点 → 1 个三角形
- `GL_TRIANGLE_STRIP`：连续 3 个顶点 → 1 个三角形（共享边）
- `GL_TRIANGLE_FAN`：第 1 个顶点为中心，与相邻 2 个顶点组成三角形

### 4.2 裁剪（Clipping）

#### 4.2.1 数学原理

裁剪在 **Clip Space** 进行，对每个顶点 `(x, y, z, w)` 测试 6 个平面：

```
-w ≤ x ≤ +w
-w ≤ y ≤ +w
-w ≤ z ≤ +w   (OpenGL, z 范围 [-1, 1])
0  ≤ z ≤ +w   (DirectX, z 范围 [0, 1])
```

#### 4.2.2 Cohen-Sutherland 算法（线段裁剪）

为每个端点计算 6 位 outcode：
```
bit 0: 左 (x < -w)
bit 1: 右 (x > +w)
bit 2: 下 (y < -w)
bit 3: 上 (y > +w)
bit 4: 近 (z < -w)
bit 5: 远 (z > +w)
```

- 两个端点 outcode 都 = 0 → 完全在内
- 两个端点 outcode AND ≠ 0 → 完全在外
- 否则 → 与平面求交点，递归裁剪

#### 4.2.3 Sutherland-Hodgman 算法（多边形裁剪）

对多边形的每条边，依次与 6 个裁剪平面求交：

```
输入：多边形顶点列表 [v0, v1, ..., vn]
对每个裁剪平面 P：
    新列表 = []
    对每条边 (s, e)：
        if e 在 P 内：
            if s 在 P 外：
                新列表.append(交点(s, e, P))
            新列表.append(e)
        else if s 在 P 内：
            新列表.append(交点(s, e, P))
    多边形 = 新列表
输出：裁剪后的多边形
```

三角形裁剪后可能变成 1~7 边形，需要重新三角化。

#### 4.2.4 交点计算

线段 `(s, e)` 与平面 `x = w` 的交点参数 `t`：

```
s.x + t(e.x - s.x) = s.w + t(e.w - s.w)
t = (s.w - s.x) / ((s.w - s.x) - (e.w - e.x))
```

交点属性（UV、颜色等）按相同 `t` 插值：

```
attr = attr_s + t * (attr_e - attr_s)
```

### 4.3 软件实现

```cpp
// Sutherland-Hodgman 多边形裁剪
std::vector<Vertex> ClipAgainstPlane(std::vector<Vertex> polygon, Plane plane) {
    std::vector<Vertex> output;
    int n = polygon.size();
    for (int i = 0; i < n; ++i) {
        Vertex curr = polygon[i];
        Vertex next = polygon[(i + 1) % n];
        bool currInside = IsInside(curr, plane);
        bool nextInside = IsInside(next, plane);
        if (currInside) {
            if (!nextInside) {
                output.push_back(Intersect(curr, next, plane));
            }
            output.push_back(curr);
        } else if (nextInside) {
            output.push_back(Intersect(curr, next, plane));
        }
    }
    return output;
}
```

### 4.4 GPU 硬件实现

GPU 的裁剪单元（Clipper）是固定功能：
- **Cull Unit**：背面剔除（基于三角形绕组）
- **Clip Unit**：Sutherland-Hodgman 实现
- **Guard Band**：硬件在视锥外扩展一个区域，小三角形不裁剪直接光栅化（性能优化）

背面剔除算法：
```
屏幕空间三角形面积 = 0.5 * |cross(v1-v0, v2-v0)|
若面积 < 0 且开启背面剔除 → 丢弃
```

### 4.5 算法基础

- **Cohen-Sutherland**：1967, MIT
- **Sutherland-Hodgman**：Ivan Sutherland, Gary Hodgman, 1974
- **Liang-Barsky**：梁友栋, Brian Barsky, 1984（更高效）

---

## 五、投影与视口变换

### 5.1 透视除法（Perspective Divide）

#### 5.1.1 数学原理

将 Clip Space `(x, y, z, w)` 变换到 **NDC (Normalized Device Coordinates)**：

```
x_ndc = x_clip / w_clip
y_ndc = y_clip / w_clip
z_ndc = z_clip / w_clip
```

NDC 范围：
- OpenGL：`[-1, 1]³` 立方体
- DirectX：`[0, 1]` 深度，`[-1, 1]` XY

#### 5.1.2 为什么需要透视除法

透视投影矩阵把 `z_view` 编码到 `w` 中（`w = -z_view`）。除以 `w` 后：
- 远处的物体（`z_view` 大）→ `w` 大 → 除后 `x_ndc, y_ndc` 小 → 屏幕上更靠近中心
- 这就是"近大远小"的透视效果

#### 5.1.3 透视正确插值

属性（UV、颜色）在三角形内的插值必须考虑透视：

```
错误（仿射插值）：
attr = (1-u-v) * attr0 + u * attr1 + v * attr2

正确（透视插值）：
attr / w = (1-u-v) * attr0/w0 + u * attr1/w1 + v * attr2/w2
attr = (插值后的 attr/w) / (插值后的 1/w)
```

GPU 在光栅化时自动做透视正确插值。

### 5.2 视口变换（Viewport Transform）

#### 5.2.1 数学原理

NDC `[-1, 1]` 映射到窗口像素坐标：

```
x_window = (x_ndc + 1) / 2 * width  + x_offset
y_window = (1 - y_ndc) / 2 * height + y_offset   (Y 翻转)
z_window = (z_ndc + 1) / 2 * (zFar - zNear) + zNear
```

其中 `width, height` 是视口大小，`x_offset, y_offset` 是视口偏移。

#### 5.2.2 矩阵形式

```
M_viewport = [width/2    0          0                    x_offset + width/2 ]
             [0          -height/2  0                    y_offset + height/2]
             [0          0          (zFar-zNear)/2       (zFar+zNear)/2     ]
             [0          0          0                    1                  ]
```

### 5.3 软件实现

```cpp
Vec3 ViewportTransform(Vec4 ndc, Viewport vp) {
    Vec3 window;
    window.x = (ndc.x + 1) * 0.5f * vp.width  + vp.x;
    window.y = (1 - ndc.y) * 0.5f * vp.height + vp.y;
    window.z = (ndc.z + 1) * 0.5f * (vp.zFar - vp.zNear) + vp.zNear;
    return window;
}
```

### 5.4 GPU 硬件实现

GPU 的 **Viewport Transform Unit** 是固定功能：
- 输入：NDC 坐标
- 输出：窗口坐标 + 深度值
- 配置：`glViewport(x, y, w, h)` + `glDepthRange(n, f)`

硬件实现是简单的乘加运算，每个顶点 1 个周期完成。

### 5.5 算法基础

- **透视投影**：Brunelleschi, 1415（文艺复兴透视画法）
- **齐次坐标除法**：Möbius, 1827
- **透视正确插值**：Heckbert, 1989

---

## 六、光栅化阶段

### 6.1 阶段职责

将屏幕空间的三角形转换为像素片段（Fragments）。每个片段对应一个像素的潜在颜色和深度。

### 6.2 数学原理：Edge Function

#### 6.2.1 Edge Function 定义

给定边 `(a → b)` 和点 `p`：

```
E(p) = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
```

几何意义：叉积的 z 分量 = 三角形 `abp` 面积的 2 倍。

- `E > 0`：`p` 在边 `a→b` 左侧
- `E < 0`：`p` 在边 `a→b` 右侧
- `E = 0`：`p` 在边上

#### 6.2.2 点在三角形内判定

三角形 `t0, t1, t2` 的三条边：`t1→t2`, `t2→t0`, `t0→t1`。

```
E0 = edge(t1, t2, p)
E1 = edge(t2, t0, p)
E2 = edge(t0, t1, p)

inside = (E0 ≥ 0 ∧ E1 ≥ 0 ∧ E2 ≥ 0) ∨
         (E0 ≤ 0 ∧ E1 ≤ 0 ∧ E2 ≤ 0)
```

#### 6.2.3 重心坐标

```
area = edge(t0, t1, t2)   // 三角形面积 × 2

b0 = E0 / area   // t0 的权重
b1 = E1 / area   // t1 的权重
b2 = E2 / area   // t2 的权重

属性插值：
attr = b0 * attr0 + b1 * attr1 + b2 * attr2
```

#### 6.2.4 增量计算（核心优化）

Edge function 是线性的，可沿像素行/列增量：

```
E(x+1, y) = E(x, y) + (a.y - b.y)   // X 方向增量
E(x, y+1) = E(x, y) + (b.x - a.x)   // Y 方向增量
```

每像素只需 3 次加法（3 条边各 1 次）。

### 6.3 软件实现

```cpp
void RasterizeTriangle(float* framebuffer, int W, int H,
                       Vec4 t0, Vec4 t1, Vec4 t2,
                       const Attr& a0, const Attr& a1, const Attr& a2) {
    // 1. 计算包围盒
    int minX = max(0, (int)floor(min({t0.x, t1.x, t2.x})));
    int maxX = min(W-1, (int)ceil(max({t0.x, t1.x, t2.x})));
    int minY = max(0, (int)floor(min({t0.y, t1.y, t2.y})));
    int maxY = min(H-1, (int)ceil(max({t0.y, t1.y, t2.y})));

    // 2. 三角形面积
    float area = Edge(t0, t1, t2);
    if (fabs(area) < 1e-10f) return;
    float invArea = 1.0f / area;

    // 3. 遍历包围盒内像素
    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            float px = x + 0.5f, py = y + 0.5f;  // 像素中心

            float e0 = Edge(t1, t2, px, py);
            float e1 = Edge(t2, t0, px, py);
            float e2 = Edge(t0, t1, px, py);

            bool inside = (e0>=0 && e1>=0 && e2>=0) || (e0<=0 && e1<=0 && e2<=0);
            if (!inside) continue;

            // 重心坐标
            float b0 = e0 * invArea;
            float b1 = e1 * invArea;
            float b2 = e2 * invArea;

            // 透视正确插值
            float w = b0/t0.w + b1/t1.w + b2/t2.w;
            float invW = 1.0f / w;
            float b0p = (b0/t0.w) * invW;
            float b1p = (b1/t1.w) * invW;
            float b2p = (b2/t2.w) * invW;

            // 属性插值
            Attr attr = a0*b0p + a1*b1p + a2*b2p;

            // 深度插值
            float z = b0*t0.z + b1*t1.z + b2*t2.z;

            // 写入片段
            ProcessFragment(x, y, z, attr);
        }
    }
}
```

### 6.4 GPU 硬件实现

#### 6.4.1 分块光栅化（Tiled Rasterization）

现代 GPU 采用 **分块（Tile）** 架构：

1. **Setup Engine**：计算三角形的 edge function 系数
2. **Tile Culling**：把屏幕分成 8×8 或 16×16 的块，剔除不与三角形相交的块
3. **Scan Conversion**：在块内用 edge function 遍历像素

#### 6.4.2 Top-Left Rule

为避免相邻三角形共享边像素被重复绘制，GPU 用 **top-left rule**：
- **Top edge**：水平边，且方向向左（`a.y == b.y` 且 `a.x > b.x`）
- **Left edge**：向下方向的边（`a.y > b.y`，屏幕坐标 Y 向下）

Top-left 边用 `E ≥ 0`，其他边用 `E > 0`。

#### 6.4.3 深度插值

GPU 用 **z 的线性插值**（不是 1/z）：

```
z = b0 * z0 + b1 * z1 + b2 * z2
```

因为投影矩阵已经把 z 变换为非线性空间，使得屏幕空间的 z 是线性的。

#### 6.4.4 Early-Z 测试

在片段着色器**之前**做深度测试（如果片段着色器不修改深度）：
- 减少不必要的片段着色器调用
- 大幅提升性能

### 6.5 算法基础

- **Edge Function**：Juan Pineda, SIGGRAPH 1988
- **Tiled Rasterization**：McCormack & McMahan, 1999
- **Top-Left Rule**：DirectX SDK 文档
- **Early-Z**：NVIDIA NV30 (GeForce FX), 2003

---

## 七、片段处理阶段

### 7.1 片段着色器（Fragment Shader / Pixel Shader）

对每个片段执行，计算最终颜色和深度。

#### 7.1.1 典型任务

1. **纹理采样**：从纹理图集读取颜色
2. **光照计算**：Phong / PBR
3. **法线映射**：从法线贴图重建法线
4. **颜色混合**：多个纹理/材质混合
5. **雾效**：距离衰减
6. **Alpha 测试**：丢弃透明片段

#### 7.1.2 数学原理：纹理采样

**双线性插值（Bilinear Filtering）**：

```
给定 UV (u, v)，纹理大小 (W, H)：
x = u * W - 0.5
y = v * H - 0.5

x0 = floor(x), x1 = x0 + 1
y0 = floor(y), y1 = y0 + 1

fx = x - x0, fy = y - y0

C = tex[x0,y0] * (1-fx)(1-fy) +
    tex[x1,y0] * fx * (1-fy) +
    tex[x0,y1] * (1-fx) * fy +
    tex[x1,y1] * fx * fy
```

**Mipmap**：预计算的多级纹理，避免远处走样：

```
level = log2(像素在纹理空间的覆盖半径)
level = clamp(level, 0, maxLevel)

在 level 和 level+1 之间三线性插值
```

**各向异性过滤（Anisotropic Filtering）**：在斜视角时沿主轴方向多次采样，减少模糊。

#### 7.1.3 数学原理：Phong 光照

```
ambient  = k_a * I_a
diffuse  = k_d * I * max(0, dot(N, L))
specular = k_s * I * pow(max(0, dot(R, V)), shininess)

color = ambient + diffuse + specular
```

其中：
- `N`：法线
- `L`：光源方向
- `R`：反射方向 = `2 * dot(N, L) * N - L`
- `V`：视线方向

#### 7.1.4 数学原理：PBR（基于物理的渲染）

**Cook-Torrance BRDF**：

```
f(l, v) = k_d * Lambert + k_s * Cook-Torrance

Lambert = albedo / π

Cook-Torrance = DFG / (4 * dot(n,l) * dot(n,v))

D = GGX NDF（法线分布函数）
F = Fresnel-Schlick（菲涅尔项）
G = Smith Geometry（几何遮蔽）
```

### 7.2 软件实现

```cpp
Vec4 FragmentShader(const FSInput& in, const Uniforms& u) {
    // 纹理采样
    Vec4 baseColor = SampleTexture2D(u.albedoTex, in.uv, u.sampler);

    // 法线从切线空间变换到世界空间
    Vec3 N = normalize(in.worldNormal);
    if (u.normalMapping) {
        Vec3 tangentN = SampleTexture2D(u.normalTex, in.uv).xyz * 2 - 1;
        N = normalize(TBN * tangentN);
    }

    // 光照
    Vec3 L = normalize(u.lightPos - in.worldPos);
    Vec3 V = normalize(u.cameraPos - in.worldPos);
    Vec3 H = normalize(L + V);

    float diff = max(0, dot(N, L));
    float spec = pow(max(0, dot(N, H)), u.shininess);

    Vec3 color = baseColor.rgb * (u.ambient + u.lightColor * diff) +
                 u.specular * spec;

    return Vec4(color, baseColor.a);
}
```

### 7.3 GPU 硬件实现

#### 7.3.1 SIMT 执行

片段着色器在 **SIMD 通道** 上执行：
- NVIDIA：warp = 32 通道
- AMD：wavefront = 64 通道
- Intel：slice = 8-32 通道

同一 warp 内的片段锁步执行相同指令。

#### 7.3.2 纹理单元（Texture Unit / TMU）

专用硬件单元：
- **Address Generator**：计算 texel 地址
- **Cache**：L1 (16-32KB) + L2 (256KB-1MB)
- **Filter Unit**：双线性/三线性/各向异性过滤硬件
- **Decompression**：BC1-BC7 / ASTC / ETC 纹理压缩解码

#### 7.3.3 寄存器与共享内存

- **GPR (General Purpose Registers)**：每个线程私有
- **Shared Memory**：warp 内共享（CUDA `__shared__`）
- **L1 Cache**：SM 内共享

### 7.4 算法基础

- **Phong 光照**：Bui Tuong Phong, 1973
- **Cook-Torrance BRDF**：Robert Cook, Kenneth Torrance, 1982
- **GGX NDF**：Walter et al., 2007
- **PBR**：Disney 2012 演讲
- **Mipmap**：Williams, 1983
- **各向异性过滤**：McCormack et al., 1999

---

## 八、逐片段测试与混合

### 8.1 测试顺序（OpenGL 规范）

```
1. Pixel Ownership Test    （窗口是否可见）
2. Scissor Test             （矩形裁剪）
3. Multisampling            （MSAA 解析）
4. Alpha Test               （废弃，OpenGL 3.0+）
5. Stencil Test             （模板测试）
6. Depth Test               （深度测试）
7. Blending                 （混合）
8. Dithering                （抖动）
9. Logic Op                 （废弃）
```

### 8.2 深度测试（Depth Test）

#### 8.2.1 数学原理

```
片段深度 z_fragment 与深度缓冲 z_buffer 比较：

比较函数（如 GL_LESS）：
z_fragment < z_buffer ? 通过 : 丢弃

通过后：
z_buffer = z_fragment
```

#### 8.2.2 深度缓冲精度

- **16-bit**：精度低，远处 z-fighting
- **24-bit**：标准
- **32-bit float**：高精度

**Z-fighting**：两个面距离太近时深度值相同，闪烁。解决：
- 偏移（`glPolygonOffset`）
- 提高深度缓冲精度
- 调整近平面（不要过近）

#### 8.2.3 Reversed-Z

```
传统：near=0.1, far=1000, z 范围 [0, 1]
Reversed-Z：near=1000, far=0.1, z 范围 [1, 0]
```

利用浮点精度在 0 附近更密集的特性，反转 Z 后近处精度更高，减少 z-fighting。

### 8.3 模板测试（Stencil Test）

#### 8.3.1 数学原理

```
片段模板值 s_fragment 与模板缓冲 s_buffer 比较：

比较函数（如 GL_EQUAL）：
(s_fragment & mask) OP (s_buffer & mask) ? 通过 : 丢弃

通过后，根据 sfail/dppass/zpass 更新模板缓冲：
GL_KEEP / GL_ZERO / GL_REPLACE / GL_INCR / GL_DECR / GL_INVERT
```

#### 8.3.2 应用

- **轮廓描边**：先画模型，模板+1；再放大画，模板=0 处显示
- **阴影体（Shadow Volume）**：模板计数阴影内外
- **反射**：模板限定反射区域

### 8.4 混合（Blending）

#### 8.4.1 数学原理

```
C_final = src * srcFactor + dst * dstFactor
```

常见混合模式：
- **不透明**：`src=1, dst=0`（关闭混合）
- **Alpha 混合**：`src=srcAlpha, dst=1-srcAlpha`
- **加法**：`src=1, dst=1`
- **乘法**：`src=0, dst=srcColor`
- **预乘 Alpha**：`src=1, dst=1-srcAlpha`

#### 8.4.2 预乘 Alpha

纹理颜色预先乘以 alpha：
```
RGB_premultiplied = RGB * A
```

混合时：
```
C_final = src + dst * (1 - srcAlpha)
```

优势：
- 边缘无黑边
- 线性空间混合正确
- 双线性插值正确

### 8.5 软件实现

```cpp
bool DepthTest(int x, int y, float z, DepthBuffer& db, CompareFunc func) {
    float stored = db.Get(x, y);
    bool pass = false;
    switch (func) {
        case LESS:    pass = z <  stored; break;
        case LEQUAL:  pass = z <= stored; break;
        case GREATER: pass = z >  stored; break;
        // ...
    }
    if (pass) db.Set(x, y, z);
    return pass;
}

Vec4 Blend(Vec4 src, Vec4 dst, BlendMode mode) {
    switch (mode) {
        case ALPHA_BLEND:
            return src * src.a + dst * (1 - src.a);
        case ADDITIVE:
            return src + dst;
        // ...
    }
}
```

### 8.6 GPU 硬件实现

#### 8.6.1 ROP (Render Output Unit)

GPU 的 **ROP** 单元负责：
- 深度测试
- 模板测试
- 混合
- 写入帧缓冲

每个 ROP 单元处理多个像素（NVIDIA 通常 8-16 像素/周期）。

#### 8.6.2 Tile-Based Rendering（移动 GPU）

移动 GPU（Mali, Adreno, PowerVR）采用 **TBR (Tile-Based Rendering)**：
1. 几何阶段：把三角形分到不同的 tile
2. 片段阶段：每个 tile 独立光栅化，深度/模板在片上 SRAM 完成
3. 最后写回主内存

优势：减少带宽，降低功耗。

#### 8.6.3 TBDR (Tile-Based Deferred Rendering)

PowerVR 的 **TBDR** 进一步：
- 隐藏表面消除（HSR）在片上完成
- 被遮挡的片段不执行片段着色器
- 比 Early-Z 更高效

### 8.7 算法基础

- **Z-Buffer**：Edwin Catmull, 1974
- **模板缓冲**：OpenGL 1.0 (1992)
- **Reversed-Z**：Eugene Lapidous, 2001
- **预乘 Alpha**：Jim Blinn, 1994
- **TBR**：ARM Mali 架构白皮书

---

## 九、输出到帧缓冲与显示

### 9.1 帧缓冲（Framebuffer）

帧缓冲包含多个附件：
- **颜色缓冲 (Color Buffer)**：RGBA 像素
- **深度缓冲 (Depth Buffer)**：每像素深度
- **模板缓冲 (Stencil Buffer)**：每像素模板值
- **累积缓冲 (Accumulation Buffer)**：废弃

深度+模板常合并为 **D24S8** 格式（24-bit 深度 + 8-bit 模板）。

### 9.2 双缓冲（Double Buffering）

```
后缓冲 (Back Buffer)   ← 渲染目标
前缓冲 (Front Buffer)  ← 显示器读取

渲染完成 → SwapBuffers() → 交换前后缓冲
```

避免撕裂（tearing）：渲染中显示器读取到半成品画面。

### 9.3 VSync（垂直同步）

```
显示器刷新率：60Hz / 120Hz / 144Hz
VSync：只在显示器垂直回扫时交换缓冲

VSync ON  → 无撕裂，但可能掉帧
VSync OFF → 可能撕裂，但帧率不受限
```

### 9.4 三缓冲（Triple Buffering）

```
前缓冲 + 后缓冲 1 + 后缓冲 2

GPU 渲染到后缓冲 1 → 完成后切换到后缓冲 2
显示器从前缓冲读取
VSync 时交换前缓冲与最近完成的后缓冲
```

优势：GPU 不阻塞，帧率更平滑。

### 9.5 显示输出

```
帧缓冲 (VRAM)
   │
   ▼
RAMDAC (CRT) / TMDS (DVI/HDMI) / LVDS (笔记本屏)
   │
   ▼
显示器扫描输出
```

**扫描时序**：
- 水平同步（HSync）：每行结束
- 垂直同步（VSync）：每帧结束
- 消隐期（Blanking）：电子枪回扫时间

### 9.6 色彩空间转换

帧缓冲通常是 **sRGB** 或 **Linear**：

```
Linear → sRGB：gamma 编码
  sRGB = 1.055 * linear^(1/2.4) - 0.055  (linear > 0.0031308)

sRGB → Linear：gamma 解码
  linear = sRGB / 12.92                     (sRGB ≤ 0.04045)
  linear = ((sRGB + 0.055) / 1.055)^2.4    (sRGB > 0.04045)
```

**HDR (High Dynamic Range)**：
- 帧缓冲用 float16/float32
- Tone Mapping 转换到 LDR
- 常用 ACES filmic tone mapping

### 9.7 算法基础

- **双缓冲**：早期图形工作站
- **VSync**：CRT 时代遗留
- **Gamma 校正**：Charles Poynton, 1993
- **ACES Tone Mapping**：Narkowicz 2015, Academy 2013

---

## 十、现代管线的演进

### 10.1 可编程管线演进

| 年份 | API/特性 | 意义 |
|------|----------|------|
| 1992 | OpenGL 1.0 | 固定管线 |
| 2001 | DirectX 8 | 顶点/片段着色器 |
| 2002 | OpenGL 2.0 | GLSL |
| 2006 | DirectX 10 | 几何着色器 |
| 2009 | DirectX 11 | 曲面细分、计算着色器 |
| 2014 | Mantle / Vulkan / DX12 | 底层 API |
| 2020 | Mesh Shader | 取代顶点/几何着色器 |

### 10.2 Mesh Shader（NVIDIA Turing+）

传统管线：
```
VS → (Tess) → (GS) → Rasterizer
```

Mesh Shader：
```
Task Shader → Mesh Shader → Rasterizer
```

- 直接在 GPU 上生成图元
- 无需顶点缓冲
- 适合程序化几何、LOD、粒子

### 10.3 可变光栅化（VRS, Variable Rate Shading）

```
屏幕不同区域用不同着色率：
- 中心：1x 着色率（清晰）
- 边缘：2x / 4x 着色率（省性能）
- VR 注视点：1x，外围 4x
```

DirectX 12 / Vulkan 1.2 支持。

### 10.4 光线追踪（Ray Tracing）

硬件加速光线追踪（NVIDIA RTX, AMD RDNA2）：
- **BVH (Bounding Volume Hierarchy)** 加速结构
- **RT Core** 专用硬件
- 反射、折射、阴影、全局光照

混合管线：
```
光栅化 → G-Buffer → 光线追踪（光照）→ 输出
```

### 10.5 GPU Driven Pipeline

把传统 CPU 工作移到 GPU：
- **GPU 视锥剔除**：Compute Shader
- **GPU 间接绘制**：IndirectDraw
- **GPU LOD 选择**：基于距离自动选择
- **Cluster Rendering**：Unreal Nanite

### 10.6 算法基础

- **Mesh Shader**：NVIDIA Turing 白皮书, 2018
- **VRS**：NVIDIA Turing, 2018
- **RTX**：NVIDIA, 2018
- **Nanite**：Unreal Engine 5, 2021
- **BVH**：Kay & Kajiya, 1986

---

## 附录 A：数学符号约定

| 符号 | 含义 |
|------|------|
| `P_local` | 模型局部空间坐标 |
| `P_world` | 世界空间坐标 |
| `P_view` | 观察空间坐标 |
| `P_clip` | 裁剪空间坐标 (含 w) |
| `P_ndc` | 归一化设备坐标 (除以 w 后) |
| `P_window` | 窗口像素坐标 |
| `M_model` | 模型变换矩阵 |
| `M_view` | 观察变换矩阵 |
| `M_proj` | 投影变换矩阵 |
| `M_mvp` | M_proj · M_view · M_model |
| `N` | 法线 |
| `L` | 光源方向 |
| `V` | 视线方向 |
| `H` | 半程向量 = normalize(L + V) |
| `BRDF` | 双向反射分布函数 |

### 坐标空间流程

```
Local Space  →  World Space  →  View Space  →  Clip Space  →  NDC  →  Window Space
   │               │               │              │            │          │
   │  M_model      │  M_view       │  M_proj      │  /w        │  Viewport│
   └───────────────┴───────────────┴──────────────┴────────────┴──────────┘
```

---

## 附录 B：参考文献

### 经典论文

1. **Pineda, J.** (1988). "A Parallel Algorithm for Polygon Rasterization". SIGGRAPH.
2. **Catmull, E.** (1974). "A Subdivision Algorithm for Computer Display of Curved Surfaces". PhD Thesis.
3. **Phong, B.T.** (1973). "Illumination for Computer Generated Pictures". CACM.
4. **Cook, R.L., Torrance, K.E.** (1982). "A Reflectance Model for Computer Graphics". SIGGRAPH.
5. **Williams, L.** (1983). "Pyramidal Parametrics". SIGGRAPH.
6. **Sutherland, I., Hodgman, G.** (1974). "Reentrant Polygon Clipping". CACM.
7. **Heckbert, P.** (1989). "Texture Mapping Polygons in Perspective". NYIT Tech Report.

### 教科书

1. **Akenine-Möll, T., Haines, E., Hoffman, N.** (2018). *Real-Time Rendering*, 4th Edition.
2. **Pharr, M., Jakob, W., Humphreys, G.** (2023). *Physically Based Rendering*, 4th Edition. (https://www.pbr-book.org)
3. **Shirley, P., Marschner, S.** (2021). *Fundamentals of Computer Graphics*, 5th Edition.
4. **Marschner, S., Westin, W.** (2021). *Graphics Programming*.
5. **Foley, J., van Dam, A.** (2013). *Computer Graphics: Principles and Practice*, 3rd Edition.

### GPU 架构

1. **NVIDIA**. *Turing Architecture Whitepaper*, 2018.
2. **NVIDIA**. *Pascal Architecture Whitepaper*, 2016.
3. **AMD**. *RDNA Architecture Whitepaper*, 2019.
4. **ARM**. *Mali GPU Architecture*, 2019.
5. **Intel**. *Gen12 Architecture*, 2019.

### API 规范

1. **Khronos Group**. *Vulkan 1.3 Specification*, 2022.
2. **Microsoft**. *DirectX 12 Documentation*, 2022.
3. **Khronos Group**. *OpenGL 4.6 Specification*, 2017.
4. **Apple**. *Metal Specification*, 2022.

### 在线资源

1. **The Graphics Codex**. https://graphicscodex.com/
2. **Learn OpenGL**. https://learnopengl.com/
3. **Scratchapixel**. https://www.scratchapixel.com/
4. **Real-Time Rendering Resources**. https://www.realtimerendering.com/

---

## 总结

图形渲染管线是一个从 3D 模型到 2D 像素的复杂流水线，涉及：

| 阶段 | 核心数学 | 关键算法 | GPU 硬件 |
|------|----------|----------|----------|
| 应用 | 视锥剔除 | BVH / Octree | CPU + Compute Shader |
| 顶点 | 矩阵变换 | 齐次坐标 | Vertex Shader (SIMT) |
| 裁剪 | 平面方程 | Sutherland-Hodgman | Clip Unit |
| 投影 | 透视除法 | 齐次坐标 / w | Fixed Function |
| 视口 | 线性映射 | NDC → 像素 | Viewport Unit |
| 光栅化 | Edge Function | Pineda 1988 | Raster Engine (Tiled) |
| 片段 | BRDF / 纹理 | Phong / PBR | Fragment Shader + TMU |
| 测试 | 深度比较 | Z-Buffer (Catmull 1974) | ROP |
| 混合 | Alpha 混合 | 预乘 Alpha | Blend Unit |
| 显示 | Gamma / Tone | sRGB / ACES | RAMDAC / TMDS |

每个阶段都有：
- **数学基础**：线性代数、几何学、微积分
- **软件实现**：CPU 上的参考实现
- **硬件实现**：GPU 固定功能或可编程单元
- **算法基础**：数十年的图形学研究积累

理解这条管线，是理解所有实时图形应用（游戏、VR/AR、CAD、可视化）的基础。
