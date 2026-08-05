# Blender 烘焙纹理格式指南

## 一、烘焙输出格式（Bake 目标图像）

### 推荐格式对比

| 格式 | 位深 | 颜色空间 | 适用场景 | 推荐度 |
|------|------|---------|---------|--------|
| **PNG 8-bit** | 8 | sRGB / Linear | 漫反射、反照率、颜色类 | ✅ 通用首选 |
| **PNG 16-bit** | 16 | Linear | 高精度需求、HDR 纹理 | ✅ 推荐 |
| **OpenEXR** | 32 float | Linear | 多通道、HDR、AOVs、PBR 工作流 | ✅ 专业首选 |
| **TIFF 16-bit** | 16 | Linear | 兼容老流水线 | ⚠️ 可用 |
| **TIFF 32-bit float** | 32 float | Linear | 科学数据、高动态范围 | ⚠️ 可用 |
| **HDR (Radiance)** | 32 | Linear | 环境贴图 | ⚠️ 仅环境 |
| **Targa (.tga)** | 8 | sRGB | 老游戏引擎 | ❌ 不推荐 |
| **JPEG** | 8 | sRGB | **绝对不要** | ❌ 压缩损失 |
| **BMP** | 8 | sRGB | 无压缩但无 alpha | ❌ 不推荐 |

### 按 Bake Type 推荐输出格式

| Bake Type | 推荐格式 | 颜色空间 | 理由 |
|-----------|---------|---------|------|
| **Diffuse/Albedo/Color** | PNG 8-bit sRGB | sRGB | 颜色数据，人眼感知 |
| **Emit (Emission)** | PNG 16-bit Linear | Linear | 发光强度，HDR 数据 |
| **Combined** | PNG 16-bit Linear 或 EXR | Linear | 含光照，可能 HDR |
| **Normal** | PNG 16-bit Linear | Non-Color | 精确向量，禁插值失真 |
| **Roughness/Metallic** | PNG 16-bit Linear | Non-Color | 物理参数 |
| **Displacement** | EXR 或 PNG 16-bit | Linear | 高度场，需精度 |
| **Position** | EXR | Linear | 世界坐标，浮点 |
| **Ambient Occlusion** | PNG 8-bit sRGB 或 Linear | sRGB 或 Linear | 灰度遮罩 |
| **Shadow** | PNG 8-bit sRGB | sRGB | 遮罩图 |
| **Subsurface** | PNG 16-bit Linear | Linear | 物理参数 |

### 关键概念：颜色空间

| 颜色空间 | 数据性质 | 例子 |
|---------|---------|------|
| **sRGB** | 人眼感知非线性，显示用 | 漫反射颜色、纹理颜色 |
| **Linear** | 线性物理值，计算用 | 法线、粗糙度、HDR 光照 |
| **Non-Color** | 非颜色数据，不转换 | 法线、索引、遮罩 |

**铁律**：
- **法线/粗糙度/金属度 = Non-Color 或 Linear**
- **颜色/漫反射 = sRGB**
- **HDR/光照 = Linear + 浮点**

## 二、输入纹理格式（贴到模型上的源纹理）

### 推荐格式

| 格式 | 位深 | 颜色空间 | 适用 | 推荐度 |
|------|------|---------|------|--------|
| **PNG** | 8/16 | sRGB/Linear | 通用贴图 | ✅ 通用首选 |
| **TIFF (GeoTIFF)** | 16/32 | Linear | **地理数据、整数索引图** | ✅ 特殊用途 |
| **OpenEXR** | 32 float | Linear | HDR 环境贴图、位移贴图 | ✅ HDR |
| **HDR** | 32 | Linear | 玶境光、HDRI | ✅ 环境 |
| **JPEG** | 8 | sRGB | **避免**（压缩损失） | ❌ |
| **Targa** | 8 | sRGB | 老引擎兼容 | ⚠️ |

### 按数据类型推荐

| 数据类型 | 推荐格式 | 理由 |
|---------||------|------|
| **颜色纹理** (Albedo) | PNG 8-bit sRGB | 人眼感知，存储高效 |
| **法线贴图** | PNG 16-bit Non-Color | 精确向量，避免插值失真 |
| **粗糙度/金属度** | PNG 16-bit Linear | 物理参数，需线性 |
| **位移/高度图** | EXR 或 PNG 16-bit Linear | 高度场需高精度 |
| **环境贴图 (HDRI)** | HDR 或 EXR | 高动态范围 |
| **整数索引图** | **TIFF (GeoTIFF) Int16/32** | **保留整数值**，不被归一化 |
| **遮罩/权重图** | PNG 8-bit Linear | 灰度遮罩 |

### 整数索引图特别说明（你的场景）

你之前有 TIF 整数索引图（材质索引）。Blender 加载时的处理：

```
Blender 加载 TIFF 整数图：
  ├─ 尝试解释为颜色 → 归一化到 [0,1]
  ├─ 8-bit:  值 5 → 0.0196 (5/255)
  ├─ 16-bit: 值 5 → 0.000076 (5/65535)
  └─ 32-bit float: 值 5 → 5.0 (保留浮点值)
```

**建议**：
- 整数索引图 **不要直接在 Blender 中使用**
- 先外部转换为**唯一颜色 PNG**（见之前讨论）
- 然后在 Blender 中作为 Non-Color 纹理使用
- Bake 时用 **Emit + Non-Color**

## 三、Blender 烘焙设置关键项

### 输出图像设置（在 Image Editor 创建新图时）

```
Image → New Image:
  Width/Height: 2048×2048 或按需
  Color Space:    ← 根据数据类型选
    - sRGB       (颜色类)
    - Linear     (HDR、位置)
    - Non-Color  (法线、粗糙度、索引)
  32-Bit Float:    ← 高精度时勾选
    - Normal/Displacement: ✅ 勾选
    - Diffuse/Albedo:      ❌ 不勾
    - Index/数据:           ❌ 不勾
  Depth: 8 or 16 bit
```

**法则**：
- 数据纹理（法线、粗糙度、位移、索引）→ **32-bit Float + Non-Color**
- 颜色纹理（漫反射）→ **8-bit + sRGB**
- HDR 纹理（发光、光照）→ **32-bit Float + Linear**

### Bake 面板设置

```
Render Properties → Bake:
  Bake Type: <按需选>
  Margin: 4~8 px
  Margin Type: Adjacent Faces
  
  Influence:
    Direct: ☐
    Indirect: ☐
    Color: ☑      ← 一般只烘颜色
  
  Selected to Active:
    ☐ 或 ☑ (视 A→B 还是自烘焙)
    Extrusion: 0.05 m
    Max Ray Distance: 按模型间距设
```

## 四、推荐工作流总结

### 场景 1：标准 PBR 烘焙（游戏/实时）

```
输入:
  Albedo (PNG 8-bit sRGB)
  Normal (PNG 16-bit Non-Color)
  Roughness (PNG 16-bit Linear)
  Metallic (PNG 16-bit Linear)
  Emissive (PNG 16-bit Linear)

烘焙输出:
  → PNG 8-bit sRGB          (Diffuse/Albedo)
  → PNG 16-bit Non-Color    (Normal)
  Substance/Quixel → Blender → 游戏引擎
```

### 场景 2：材质索引图烘焙（你的场景）

```
输入:
  TIF 整数索引图 (材质 ID)
    ↓ [外部 Python 转换]
  彩色 PNG (唯一颜色映射)
    ↓
Blender:
  加载为 Non-Color + Closest 插值
  接 Emission → Material Output
  Bake Type: Emit
  输出: PNG 16-bit Non-Color
    ↓ [外部 Python 反查]
  B 模型的整数索引图 (TIF)
```

### 场景 3：HDR 光照烘焙

```
输入:
  HDRI 环境贴图 (HDR/EXR)
  光源、材质
    ↓
Blender:
  Bake Type: Combined 或 Diffuse
  输出: OpenEXR 32-bit float Linear
  → 供下游 GI/VFX 使用
```

## 五、常见坑

| 问题 | 原因 | 解决 |
|------|------|------|
| 法线贴图烘焙后偏色 | 输出用 sRGB | 改用 Non-Color |
| 索引图烘焙后出现混色 | 线性插值 | 输入设 Closest 插值，输出用 16-bit |
| HDR 数据被裁剪 | 8-bit 输出 | 改用 32-bit float EXR |
| 烘焙结果偏暗 | sRGB/Linear 混乱 | 数据用 Linear/Non-Color，颜色用 sRGB |
| 边缘缝 | Margin 太小 | Margin ≥ 4px |
| 烘焙到 B 模型偏移 | Selected to Active 未配置好 | 设 Extrusion + Max Ray Distance |

## 一句话总结

> **颜色类 → PNG 8-bit sRGB；数据类（法线/粗糙度/索引）→ PNG 16-bit Non-Color；HDR/光照 → EXR 32-bit Linear。整数索引图必须先外部转彩色 PNG 再进 Blender。**



# Blender 烘焙 DDS 纹理的支持情况

## 一、重要前提：Blender 对 DDS 的原生支持有限

Blender **不能直接把 Bake 目标设为 DDS 格式**。Bake 流程要求目标图像是 Blender 内部 Image 数据块，而 DDS 在 Blender 中的支持历经变化：

| Blender 版本 | DDS 支持情况 |
|-------------|-------------|
| 2.7x ~ 3.6 | 仅支持加载（BC1/BC3/BC7 部分格式），**不能保存为 DDS** |
| 4.0+ | 改进 DDS 加载（BC1~BC7），仍**不能直接保存 DDS** |
| 4.1+ | 实验性 DDS 写入支持（仅 BC1/BC3/BC7 部分） |
| 4.2+ | DDS Image Save 改进，但**仍非完整** |

**结论**：Blender 的 Bake 流程**不直接输出 DDS**，需要先烘焙到 PNG/EXR，再外部转换为 DDS。

## 二、Blender 能加载的 DDS 格式

| DDS 格式 | 别名 | 加载支持 | 用途 |
|---------|------|---------|------|
| **BC1** | DXT1 | ✅ | 不透明颜色纹理（4:1 压缩） |
| **BC1a** | DXT1a | ✅ | 1-bit alpha 颜色纹理 |
| **BC2** | DXT3 | ✅ | 显式 alpha 颜色纹理 |
| **BC3** | DXT5 | ✅ | 插值 alpha 颜色纹理（最常用） |
| **BC4** | ATI1 | ✅ (4.0+) | 单通道灰度（粗糙度/高度） |
| **BC5** | ATI2/3Dc | ✅ (4.0+) | 双通道法线贴图（最佳法线格式） |
| **BC6H** |  | ❌ 原生 | HDR 颜色（需插件） |
| **BC7** |  | ✅ (4.0+) | 高质量颜色+alpha |
| **R8G8B8A8** | Uncompressed | ✅ | 无压缩 RGBA |
| **R16G16B16A16_FLOAT** | Half Float | ❌ 原生 | HDR（需转换） |
| **R32G32B32A32_FLOAT** | Full Float | ❌ 原生 | HDR（需转换） |

## 三、推荐工作流：PNG/EXR 烘焙 → 外部转 DDS

### 完整流程

```
Blender Bake:
  目标图 = PNG 16-bit 或 EXR 32-bit float
  Color Space = Non-Color / Linear / sRGB (按数据类型)
        │
        ▼
导出 PNG/EXR
        │
        ▼
外部工具转换为 DDS:
  - NVIDIA Texture Tools (nvcompress / nvtt)
  - compressonator (AMD)
  - texconv (微软 DirectXTex)
  - Python + Wand/Pillow + DDS 插件
  - Substance 3D Painter/Sampler
        │
        ▼
最终 DDS 纹理
```

### 各类纹理的推荐转换参数

| 纹理类型 | Bake 输出 | 转 DDS 格式 | 工具命令示例 (texconv) |
|---------|----------|------------|----------------------|
| **Diffuse/Albedo** | PNG 8-bit sRGB | BC1 (无 alpha) 或 BC7 (有 alpha) | `texconv -f BC1_UNORM -srgb in.png` |
| **Normal Map** | PNG 16-bit Non-Color | **BC5** (双通道，最佳) | `texconv -f BC5_UNORM -inormal in.png` |
| **Normal Map** (兼容老引擎) | PNG 16-bit Non-Color | BC3 (RGB+alpha) | `texconv -f BC3_UNORM in.png` |
| **Roughness/Metallic/AO** | PNG 16-bit Linear | **BC4** (单通道) | `texconv -f BC4_UNORM in.png` |
| **Emissive/HDR** | EXR 32-bit Linear | **BC6H** (HDR 压缩) | `texconv -f BC6H_UF16 in.exr` |
| **Packed ORM** (Occlusion-Roughness-Metallic) | PNG 8-bit Linear | BC7 (三通道) | `texconv -f BC7_UNORM in.png` |
| ** displacement** | EXR 16-bit Linear | R16_UNORM 或 BC4 | `texconv -f BC4_UNORM in.exr` |

## 四、关键技巧

### 1. 法线贴图特殊处理

**必须用 BC5（3Dc）而非 BC1/BC3**：

```
原因：BC1/BC3 是颜色压缩，会破坏法线向量的精度
BC5: 
  - 红通道 = X 分量 (R)
  - 绿通道 = Y 分量 (G)
  - 蓝通道 = 运行时重建 Z = sqrt(1 - X² - Y²)
  - 压缩质量高，专为法线设计
```

**Blender 烘焙时**：
```
Bake Type: Normal
输出: PNG 16-bit Non-Color
Space: Tangent (游戏) 或 World (离线)
```

### 2. Mipmap 生成

DDS 的精髓是 **mipmap chain**，但 Blender 烘焙的 PNG 没有 mipmap。转换时必须生成：

```
texconv -m 10 -f BC7_UNORM in.png   ← 生成最多 10 级 mipmap
nvcompress -m10 -bc7 in.png out.dds
```

**技巧**：
- mipmap 数 = floor(log2(max(width, height))) + 1
- 法线贴图的 mipmap 要用**特殊滤波**（避免单位向量变短）
  - `texconv -inormal` 自动处理
  - 或手动：mipmap 后重新归一化

### 3. Alpha 通道处理

```
Alpha 用途              推荐格式
─────────────────────────────────
无 alpha                 BC1
1-bit alpha (cutout)     BC1a
渐变 alpha (树叶/头发)   BC3 或 BC7
高质量 alpha (UI)        BC7
```

### 4. sRGB vs Linear 标志

DDS 文件头会标记 sRGB，**转换时要正确设置**：

```
颜色纹理 (Albedo/Diffuse):  -srgb      ← 标记 sRGB
数据纹理 (Normal/Roughness): -linear    ← 标记 Linear
```

引擎加载时会根据此标志决定是否做 gamma 解码。

### 5. 索引图/数据图不能压成 DDS 块压缩

```
整数索引图、material ID 图、遮罩图:
  - 不要用 BC1~BC7 (块压缩会破坏离散值)
  - 用 R8_UNORM 或 R16_UINT (无压缩)
  - texconv -f R8_UNORM in.png
```

## 五、限制与坑

### 限制 1: 尺寸必须是 2 的幂 (PO2)

```
DDS 块压缩要求: width 和 height 都是 4 的倍数
传统 GPU 要求:   2 的幂 (256/512/1024/2048/4096)
现代 GPU:        只需 4 的倍数即可

Blender Bake 时:
  尽量设 1024/2048/4096 (PO2)
  避免 1920×1080 (非 PO2，需裁剪)
```

### 限制 2: Blender 加载 DDS 后不能编辑

```
DDS 加载到 Blender:
  - 仅作为 Image Texture 使用
  - 不能在 Image Editor 中修改
  - 不能作为 Bake 目标
  - 重新打包时会转回 PNG/TGA
```

### 限制 3: 块压缩有损失

```
BC1 (DXT1):  8:1 压缩, 颜色质量较低
BC3 (DXT5):  4:1 压缩, alpha 质量好
BC7:         3:1 压缩, 质量最高
BC5:         2:1 压缩, 法线专用
BC6H:        6:1 压缩, HDR 专用

无损替代:
  R8G8B8A8 (无压缩): 文件大 4 倍
  R16G16B16A16 (half float): HDR 无损
```

### 限制 4: BC6H/BC7 需要硬件支持

```
BC6H (HDR):     DirectX 11+ / OpenGL 4.2+
BC7 (高质量):   DirectX 10+ / OpenGL 4.x
老硬件/移动端:   仅支持 BC1~BC3
```

### 限制 5: Blender 4.x 实验性 DDS 保存仍有限制

```
Blender 4.1+ "Save As DDS":
  - 仅支持 BC1/BC3/BC7 (少数格式)
  - 无 mipmap 生成
  - 无 BC5/BC6H
  - 无 sRGB 标志选项
  → 实用性有限，仍推荐外部工具
```

## 六、推荐工具链

### 首选：texconv (微软 DirectXTex)

```
下载: https://github.com/Microsoft/DirectXTex/releases

常用命令:
  # 颜色纹理 (BC7, sRGB, 10 级 mipmap)
  texconv -f BC7_UNORM -srgb -m 10 in.png
  
  # 法线贴图 (BC5, 自动处理法线 mipmap)
  texconv -f BC5_UNORM -inormal -m 10 in.png
  
  # 粗糙度 (BC4, 单通道)
  texconv -f BC4_UNORM -m 10 in.png
  
  # HDR 发光 (BC6H)
  texconv -f BC6H_UF16 -m 10 in.exr
```

### 次选：NVIDIA Texture Tools

```
nvcompress:
  -bc1     DXT1
  -bc3     DXT5
  -bc5     3Dc (法线)
  -bc6h    HDR
  -bc7     高质量
  -m10     10 级 mipmap
  
  nvcompress -bc7 -m10 in.png out.dds
```

### 批量处理 (Python 脚本)

```python
import subprocess
from pathlib import Path

jobs = [
    ("albedo.png",    "BC7_UNORM", "-srgb"),
    ("normal.png",    "BC5_UNORM", "-inormal"),
    ("roughness.png", "BC4_UNORM", ""),
    ("metallic.png",  "BC4_UNORM", ""),
    ("emissive.exr",  "BC6H_UF16", ""),
]

for src, fmt, extra in jobs:
    cmd = ["texconv", "-f", fmt, "-m", "10", extra, src]
    subprocess.run(cmd)
```

## 七、一句话总结

> **Blender 不能直接烘焙到 DDS（4.x 仅实验性支持少数格式）。正确流程：Bake 到 PNG 16-bit / EXR → 用 texconv/nvcompress 外部转换 → 选择合适的 BC 格式（颜色 BC7、法线 BC5、灰度 BC4、HDR BC6H）→ 生成 mipmap → 设置正确的 sRGB/Linear 标志。**

需要我提供完整的 texconv 批处理脚本（含 mipmap 和格式选择）吗？


先读 EXR 确认是否真的全 0。
        
            
toolName: run_command
            
status: success
          
command: python -c "
import OpenEXR, Imath
import numpy as np
import os, glob
