# 建筑物双模型 A→B 纹理映射问题汇总

> 背景：针对同一个建筑物，生成两套相近的模型 A、B，分别有各自的 UV 与纹理。目标是将 A 的纹理贴图映射到 B 模型上，使 B 模型保留一套 UV，即可替换不同纹理图。

---

## 问题一：如何把 A 的纹理映射到 B 模型上？

### 方法一：Blender Data Transfer（拓扑相近时推荐）

适用于 A、B 顶点位置接近的情况。

1. 把 A、B 都导入 Blender，对齐到同一位置。
2. 选中 B 模型 → 添加 **Data Transfer** 修饰器。
3. Source Object 选 A，勾选 **UVs**，方法选 **Nearest Face**。
4. 调整 `Max Distance` 直至 B 全部顶点被映射（显示成彩色）。
5. **Apply** 修饰器，B 即获得 A 的 UV。
6. 把 A 的纹理指定给 B 即可。

- 优点：操作快、一键完成
- 缺点：A、B 顶点差距大时会有拉伸/接缝

### 方法二：贴图烘焙（拓扑差异大时推荐）

不直接搬运 UV，而是把 A 模型带纹理"投影"到 B 的 UV 上。

1. 在 Blender 中把 A、B 重叠对齐。
2. B 保留自己的 UV（若 B 尚无 UV，先做一次 UV unwrap）。
3. 创建一个新图像（最终要用的尺寸，例如 4096×4096）。
4. 选中 B，进入 **Shader Editor**，给 B 加一张 Image Texture 节点，指定为新图像。
5. 切到 **Render Properties → Bake**：
   - Bake Type：**Diffuse**（或 Emit）
   - 勾选 **Selected to Active**
   - 先选 A，再加选 B（最后选中的为目标）
6. 点击 **Bake**，结果就是 A 的纹理按 B 的 UV 烘焙出来。

B 拿到一张符合自身 UV 的图后，后续只要换不同图即可。

### 方法三：脚本批量（自动化 / 大量模型）

```python
import trimesh
import numpy as np
from PIL import Image

a = trimesh.load('a.glb')
b = trimesh.load('b.glb')

# 采样 A 上每个像素对应的 3D 点
tex_a = Image.open('a_albedo.png').convert('RGB')
w, h = tex_a.size
points_world = []
for y in range(h):
    for x in range(w):
        u, v = (x + 0.5) / w, 1 - (y + 0.5) / h
        # 根据 A 的 UV 表反查 3D 坐标（需遍历面）
        ...

# 用 B 的 UV 把这些 3D 点投影回 B 的纹理空间
```

更稳的做法是直接调用 Blender 的烘焙或 **xatlas** 库做 atlas 重打包。

### 方法选择

| 情况 | 建议方法 |
|---|---|
| A、B 拓扑一致或很接近 | **Data Transfer**（最快） |
| A、B 拓扑不同但形状一致 | **Bake Diffuse, Selected to Active**（最稳） |
| 需要程序化、批量处理 | 写脚本走烘焙流水线 |
| A、B 差距很大 | 重新做 UV，或用 photogrammetry 重新生成 |

### 关键前提

两套模型必须先**对齐坐标系、缩放比例一致**，否则 UV/烘焙会错位。Blender 里把 A 的原点设到 B 上、`Ctrl+A → Scale` 后再烘焙效果最好。

---

## 问题二：烘焙图像保存后比原始图像暗，是什么原因？

最常见原因：**色彩空间（Color Space）不匹配**；其次是 **灯光被烘进去**。逐个排查：

### 1. 色彩空间不对（最常见 ⭐）

原图是 sRGB 彩色，但烘焙目标被设成了 Non-Color（或反过来）。

**Blender 修复方法：**
- **Image Editor** 中打开原图 → Sidebar (N) → **Image** 面板 → Color Space 设为 **sRGB**
- 烘焙前给目标新建的 Image Texture 节点，Color Space 设为 **sRGB**（不要选 Non-Color）
- Render Properties → **Color Management** → View Transform 选 **Standard**（不要 Filmic），Look 选 **None**

Substance Painter / Marmoset 导入时也要勾选 sRGB。

### 2. 灯光 / 阴影被烘进 Diffuse

烘焙 Diffuse 时没关掉光照，渲染的是"贴图 × 直接光 × 间接光"，自然会变暗。

**Blender 修复方法：**
- 选 **Emit** 类型烘焙（最稳，纯粹复制表面颜色，不受灯光影响）
- 或 Diffuse → Contributions：
  - 取消勾选 **Direct**
  - 取消勾选 **Indirect**
  - 保留勾选 **Color**
- 这样就只采原图色，不受场景灯影响

### 3. 渲染器色彩管理

- Filmic / AgX 等 view transform 会"压暗"高光，让直接 bake 出来也偏暗
- 临时切到 **Standard** + Look = **None** 烘焙，再切回去

### 4. 输出格式

- 存为 **PNG / EXR**，不要用低质量 JPG
- 8 位 sRGB 是正常贴图格式；存成 16 位 float + Non-Color 会变暗一截

### 快速验证脚本

```python
from PIL import Image
import numpy as np

orig = np.array(Image.open('a_albedo.png').convert('RGB'))
bake = np.array(Image.open('b_bake.png').convert('RGB'))

print('orig mean:', orig.mean(), 'bake mean:', bake.mean())
# 差异 < 5% 算正常；明显小很多就是暗了
```

### 推荐万能流程

| 步骤 | 设置 |
|---|---|
| 原图 Color Space | sRGB |
| 烘焙目标 Color Space | sRGB |
| Bake Type | **Emit** |
| View Transform | Standard |
| Look | None |
| 输出 | PNG 8bit |

按此配置烘焙，基本是 1:1 复制原图，不会再变暗。

---

## 问题三：反映射后纹理异常（第二张图大部分显示蓝色基础色）

### 现象描述

> **图 1：正确的纹理效果**（请在此处插入 `correct_texture.png`）—— 屋顶瓦片清晰、墙体纹理正确。
>
> **图 2：反映射后的结果**（请在此处插入 `remap_result.png`）—— 大面积显示蓝色基础材质，仅局部出现零散贴图。

![正确的纹理](./images/correct_texture.png)

*（图 1：原模型 A 的正确纹理显示效果）*

![反映射后异常](./images/remap_result.png)

*（图 2：反映射后大面积变成蓝色基础色 + 零散贴图）*

### 原因分析

第二张图大面积**蓝色基础材质**（默认色）+ 零散贴图，说明**很多面没找到对应的源面**。

### 最可能的原因

#### 1. A、B 没有对齐（最常见 ⭐）

反映射本质是按空间位置找 A 上的对应面。如果两模型没重合，射线打不到 A。

**检查：**
- A、B 的 **原点是否在同一位置**（Object → Set Origin → Origin to Geometry）
- A、B 的 **缩放是否一致**（`Ctrl+A → Scale` 全部应用）
- 视图里 A 和 B 是否完全重叠（可临时给 A 加个 Wireframe 看轮廓）

#### 2. 法线方向不一致

反映射射线沿目标面**法线**打出去。如果 A 那侧的对应面**法线朝向反了**（朝内），射线就穿过而没命中。

**检查：**
- 进入 Edit Mode → 选中所有面 → **Mesh → Normals → Recalculate Outside**
- A、B 都做一遍
- Viewport 开启 **Face Orientation**（Overlay 菜单）：蓝色正面、红色反面

#### 3. 用了 Nearest Face 但距离阈值太小

Blender Data Transfer 修饰器里 Max Distance 不够大，远处顶点找不到对应。

**修复：**
- 把 Max Distance 调到能覆盖整个模型大小
- 或改用 **Projected Face**（按法线方向投影匹配，更适合形状接近的模型）

#### 4. 烘焙参数问题（Selected to Active）

Bake 设置里：
- **Cage → Extrusion** 调大一些（默认 0.15 不够就加到 0.5+）
- 勾上 **Custom Cage**，手动给 B 加一个略大于 B 的壳
- 烘焙时确保 A 在 B 内部，且 A 的所有面**包含 B 的对应位置**

#### 5. UV 已经被手动改过 / 源模型 B 自身 UV 就是错的

若 B 的 UV 被破坏过，反映射回去当然也是乱的。

**检查：**
- 在 UV Editor 里打开 B 的 UV，看是否完整、合理
- 若 B 的 UV 本身有问题，先用 Smart UV Project 或 Unwrap 重做

### 快速排查顺序

| 步骤 | 检查 | 修复 |
|---|---|---|
| 1 | A、B 位置/缩放 | 对齐 + Apply Scale |
| 2 | 法线方向 | Recalculate Outside |
| 3 | 朝向 | B 的 +Z 与 A 的 +Z 一致 |
| 4 | 转移方式 | 改用 Projected Face |
| 5 | 距离阈值 | 加大 Max Distance |
| 6 | Cage | 加大 Extrusion |

### 蓝色区域特别多怎么办？

蓝色 = 没采到任何 A 的面 → 几乎肯定是 **A、B 空间没重合** 或 **法线错**。先解决这两个再试。

**调试技巧：** 临时把 A 的材质设成亮红色（Emission = 1），再反映射一次，看 B 上哪些位置被染红——红的就是采到 A 的地方，能直观判断是否对齐。

---

## 问题四：烘焙中的 Cage 是什么？有什么效果？

### 定义

Cage 是烘焙时**目标物体外面包的一层"壳"**（不可见），用来**控制射线从哪里发出**去找源物体的面。

它是 Blender 中 "Selected to Active" 烘焙流程里的核心参数之一。

### 工作原理

- **不勾 Cage**：射线从 B 自身表面出发，沿法线方向打到 A。
- **勾上 Cage**：射线从 B 外扩后的壳（cage）表面出发，去打 A。

示意图：

```
Extrusion = 0     射线从 B 表面出发
                  ─────→  A

Extrusion = 0.3   射线从 B 外扩 0.3 单位的壳出发
              ─────→  A
         ─────  ← cage 表面（外扩壳）
         ┌─────┐
         │  B  │
         └─────┘
```

### Extrusion 参数

Cage 壳相对 B 表面的**外扩距离**：

- 默认 0.15（Blender 单位），A、B 大小不同需要相应调整
- 值太小：射线打不到 A（→ 出现蓝色空白/破洞）
- 值太大：会采到其他物体的面（→ 纹理串色、错乱）

### Max Ray Distance 参数

Max Ray Distance（最大射线距离）是**射线能"看"多远**的限制参数：

- **默认 0（= 无限远）**：射线不限制长度，能打到场景中任何被命中的面
- **> 0**：射线一旦超过这个距离还没命中，就算 miss（采到默认色/黑）
- **作用**：避免"远距离误采"——当场景中除了 A 还有别的物体时，限制射线长度可防止错误采样到其他物体

#### 与 Extrusion 的关系

两者**互相配合**控制射线：

| 维度 | Extrusion | Max Ray Distance |
|---|---|---|
| 控制内容 | 射线**起点**（从 cage 壳表面出发） | 射线**终点**（最多能看多远） |
| 默认值 | 0.15 | 0（无限） |
| 加大效果 | 起点外移 | 看得更远 |
| 减小效果 | 起点内收 | 看不远（容易 miss） |
| 典型单位 | 米（与模型同尺度） | 米（与模型同尺度） |

简化理解：

```
                    Max Ray Distance
                    ◄──────────────►
A 表面  ←─────  ←─  cage 壳表面
                       ↑
                       起点
```

**经验值**：Max Ray Distance ≈ 2 ~ 5 倍的 Extrusion，足以覆盖 cage 壳到 A 表面之间可能的最大间距，又不至于过远。

### 为什么要用 Cage

| 场景 | 作用 |
|---|---|
| 薄壁（墙体、叶片） | 让射线从"壳"出发，能找到正确一面 |
| A、B 间距不一 | 用同一参数统一处理，烘焙均匀 |
| 凹凸细节 | 避免自相交导致的噪点/破洞 |
| 复杂表面 | 手动控制采样范围，更精确 |

### Custom Cage（自定义 Cage）

当 Extrusion 数值无法满足精度要求时，可勾上 **Custom Cage**，**指定一个网格**作为 cage 形状：

1. 复制 B（`Shift+D`）
2. 进入 Edit Mode → 全选 → `Alt+S`（沿法线挤出面，形成壳）
3. 给这个壳改个名字（比如 "Cage"）
4. Bake 时 **Cage Object** 选它

自定义 cage 比单一 Extrusion 更精确，**特别适合法线贴图烘焙**（对偏移极其敏感）。

### 各类贴图推荐 Extrusion 与 Max Ray Distance 值

| 贴图类型 | 推荐 Extrusion | 推荐 Max Ray Distance | 比例 | 原因 |
|---|---|---|---|---|
| 法线贴图 (Normal) | 0.05 ~ 0.1 | 0.15 ~ 0.3 | ≈ 3x | 偏移稍大就破坏法线方向 |
| 漫反射 / 颜色 (Diffuse) | 0.1 ~ 0.3 | 0.3 ~ 1.0 | ≈ 3x | 容差较大 |
| 粗糙度 (Roughness) | 0.1 ~ 0.2 | 0.3 ~ 0.6 | ≈ 3x | 中等敏感 |
| 金属度 (Metallic) | 0.1 ~ 0.2 | 0.3 ~ 0.6 | ≈ 3x | 中等敏感 |
| 高度 / 置换 (Displacement) | 0.05 ~ 0.15 | 0.15 ~ 0.5 | ≈ 3x | 偏移直接变形 |
| 环境光遮蔽 (AO) | 0.2 ~ 0.5 | 0.5 ~ 1.5 | ≈ 3x | 越长采样越广 |

> 通用公式：`Max Ray Distance = Extrusion × 3 ± 一定容差`，简单场景可按 3x 直接换算。

### 常见症状与 Cage / Max Ray Distance 调整

| 烘焙结果 | 原因 | 调整 |
|---|---|---|
| 大面积蓝色/黑色 | Extrusion 太小 / Max Ray Distance 太小 | 加大 Extrusion 或 Max Ray Distance |
| 邻面纹理串色 | Extrusion 太大 | 减小 Extrusion |
| 远处物体纹理被错误采到 | Max Ray Distance 太大（默认 0 = 无限） | 适当减小 Max Ray Distance |
| 薄壁有破洞/锯齿 | 壳没包住薄壁 | 用 Custom Cage 手动调形 |
| 法线贴图偏移 | Extrusion 偏大 | 减小到 0.05 |
| 接缝处黑线 | 自相交 | 用 Custom Cage |
| 部分区域始终采到错误面 | Max Ray Distance 与 Extrusion 不匹配 | 同步调，按 3x 比例 |

### A→B 场景下的使用建议

1. **先用默认 Extrusion 试一次**（0.15，Max Ray Distance 保持 0）
2. **查看 bake 结果**，哪里缺/串色针对性调
3. 颜色类贴图问题 → 加大 Extrusion 到 0.2~0.3，Max Ray Distance 保持默认
4. 法线类贴图问题 → 改用 Custom Cage，Max Ray Distance 不要超过 0.3
5. 场景中有多个物体可能干扰 → 设置 Max Ray Distance = Extrusion × 3，避免误采
6. 都不行 → 检查 A、B 空间是否真的重合（问题三的步骤 1~3）

---

## 附录：完整工作流推荐

1. **预处理**：A、B 统一应用 Scale，统一坐标原点，统一朝向。
2. **法线修复**：A、B 都 Recalculate Outside。
3. **UV 准备**：确认 B 的 UV 完整可用。
4. **传递方式选择**：
   - 拓扑相近 → Data Transfer 修饰器（Nearest Face / Projected Face）
   - 拓扑差异大 → Bake Diffuse, Selected to Active
5. **色彩管理**：原图 sRGB，目标 sRGB，View Transform = Standard，Look = None。
6. **烘焙类型**：优先用 Emit 避免灯光影响。
7. **验证**：bake 完后用 Python 比较原图与 bake 结果的平均亮度，差异 < 5% 为正常。
8. **收尾**：将 B 的 UV 导出，纹理换成不同素材即可复用同一 UV。

**注意事项**:
![alt text](<blender bake engine gpu.png>)
![alt text](<blender bake setting.png>)

1. 需要使用png, dds格式不大行, jpg不确定
2. 模型应该尽量对齐，对的越齐越准