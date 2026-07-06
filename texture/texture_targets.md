# 纹理 Target 类型完全总结

> 本文档系统总结 GPU 图形 API 中所有主流的纹理 Target 类型（1D / 2D / 3D / Cube / Array / Multisample / Depth / Buffer 等），重点从 5 个维度展开：
> 1. **创建**（OpenGL / Vulkan / DirectX API）
> 2. **数据传输**（CPU 内存 ↔ GPU 显存）
> 3. **Shader 中的使用**（采样器类型与采样函数）
> 4. **坐标**（纹理坐标体系）
> 5. **数据在内存和显存中的分布**（CPU 端布局、GPU 端 tiling、对齐要求）

---

## 一、纹理 Target 全景图

| Target 类型 | 维度 | 典型用途 | OpenGL 枚举 | DirectX 资源视图 | Vulkan |
|---|---|---|---|---|---|
| Texture1D | 1D | 渐变查找表、Toon 曲线 | `GL_TEXTURE_1D` | `Tex1D` | `VK_IMAGE_TYPE_1D` |
| Texture2D | 2D | 漫反射/法线贴图、UI | `GL_TEXTURE_2D` | `Tex2D` | `VK_IMAGE_TYPE_2D` |
| Texture3D | 3D | 体素、医学数据、Volume Rendering | `GL_TEXTURE_3D` | `Tex3D` | `VK_IMAGE_TYPE_3D` |
| TextureCube | 6 面立方体 | Skybox、IBL、环境反射 | `GL_TEXTURE_CUBE_MAP` | `TexCube` | `VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT` |
| Texture1DArray | 1D 数组 | 纹理图集、tile 数组 | `GL_TEXTURE_1D_ARRAY` | `Tex1DArray` | `VK_IMAGE_VIEW_TYPE_1D_ARRAY` |
| Texture2DArray | 2D 数组 | 动画帧、地形图层 | `GL_TEXTURE_2D_ARRAY` | `Tex2DArray` | `VK_IMAGE_VIEW_TYPE_2D_ARRAY` |
| TextureCubeArray | Cube 数组 | 动态环境光照、阴影立方体数组 | `GL_TEXTURE_CUBE_MAP_ARRAY` | `TexCubeArray` | `VK_IMAGE_VIEW_TYPE_CUBE_ARRAY` |
| Texture2DMS | 多采样 2D | MSAA RenderTarget | `GL_TEXTURE_2D_MULTISAMPLE` | `Tex2DMS` | `VK_IMAGE_CREATE_MSAA_COMPATIBLE_BIT` |
| Texture2DMSArray | 多采样 2D 数组 | MSAA + 多层（Vulkan/DX12） | `GL_TEXTURE_2D_MULTISAMPLE_ARRAY` | `Tex2DMSArray` | `VK_IMAGE_VIEW_TYPE_2D_ARRAY + MSAA` |
| TextureBuffer | 缓冲区纹理 | 大表数据 uniform-like 采样 | `GL_TEXTURE_BUFFER` | `TexBuffer` | `VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER` |
| TextureRectangle | 2D 非归一化 | 视频帧、NDC 直接采样 | `GL_TEXTURE_RECTANGLE` | — (DX 无对应) | — |
| Depth/Stencil | 深度/模板 | Z-buffer、Shadow Map | `GL_DEPTH_COMPONENT` 等 | `DSV` | depth/stencil format |

> **重要概念**：
> - OpenGL 中"target" = 纹理对象绑定/上传的维度类别（`GL_TEXTURE_2D`, `GL_TEXTURE_3D`, ...）。
> - DirectX 中没有单一 target 概念，资源类型 + View 类型共同决定。
> - Vulkan 中 Image 的 `imageType` + 创建 flag 决定 target 类别，View 决定访问方式。

---

## 二、Texture1D（一维纹理）

### 1. 创建

```cpp
// OpenGL
GLuint tex;
glGenTextures(1, &tex);
glBindTexture(GL_TEXTURE_1D, tex);
glTexStorage1D(GL_TEXTURE_1D, 1, GL_RGBA8, 256);  // immutable storage
glTexSubImage1D(GL_TEXTURE_1D, 0, 0, 256, GL_RGBA, GL_UNSIGNED_BYTE, data);
```

```cpp
// DirectX 11
ID3D11Texture1D* tex;
D3D11_TEXTURE1D_DESC desc = {};
desc.Width = 256;
desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
desc.Usage = D3D11_USAGE_DEFAULT;
desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
device->CreateTexture1D(&desc, &initData, &tex);
```

### 2. 数据传输
- CPU → GPU：`glTexSubImage1D` / `D3D11_USAGE_DEFAULT + UpdateSubresource` / Vulkan `vkCmdCopyBufferToImage`
- GPU → CPU：`glGetTexImage` / `ID3D11DeviceContext::Map` / `vkCmdCopyImageToBuffer`

### 3. Shader 使用

```glsl
// OpenGL GLSL
uniform sampler1D u_tex;
vec4 c = texture(u_tex, 0.37);   // 1D 坐标 u
vec4 c2 = textureLod(u_tex, 0.37, 0.0);
```

```hlsl
// HLSL
Texture1D<float4> u_tex : register(t0);
float4 c = u_tex.Sample(samp, 0.37);
```

### 4. 坐标
- 仅 **u** 一个分量，范围通常 `[0, 1]`（normalized）或 `[0, width-1]`（pixel fetch）。
- 没有 `v` 维度。

### 5. 内存分布

**CPU 端**：
- 一维连续数组：`data[0], data[1], ..., data[width-1]`
- 元素大小 = `format` 字节数（RGBA8 = 4 字节）
- 总大小 = `width × bytes_per_pixel`
- 行内无 padding（1D 纹理没有行概念）

**GPU 端**：
- 与 CPU 几乎一致：GPU 把 1D 纹理视为 1×width 的 2D 图像
- 内部排布遵循 GPU 的 tiling（ARM Mali/Adreno 为 tiled，桌面 NVIDIA/AMD 为 linear 1D 几乎等价 linear）
- 对齐要求：通常 1D 纹理在现代 GPU 上几乎不需要特殊对齐

---

## 三、Texture2D（二维纹理）— 最常用

### 1. 创建

```cpp
// OpenGL
glBindTexture(GL_TEXTURE_2D, tex);
glTexStorage2D(GL_TEXTURE_2D, mipLevels, GL_RGBA8, width, height);
glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
```

```cpp
// Vulkan (image + view + sampler 分离)
VkImageCreateInfo ici = {};
ici.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
ici.imageType = VK_IMAGE_TYPE_2D;
ici.format = VK_FORMAT_R8G8B8A8_UNORM;
ici.extent = { width, height, 1 };
ici.mipLevels = mipLevels;
ici.arrayLayers = 1;
ici.samples = VK_SAMPLE_COUNT_1_BIT;
ici.tiling = VK_IMAGE_TILING_OPTIMAL;
ici.usage = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
vkCreateImage(device, &ici, nullptr, &image);
```

### 2. 数据传输

| 路径 | OpenGL | Vulkan |
|---|---|---|
| CPU 数组 → GPU | `glTexSubImage2D`, `glTexImage2D` | staging buffer + `vkCmdCopyBufferToImage` |
| GPU render target → texture | FBO + `glBlitFramebuffer` | `vkCmdBlitImage` |
| GPU texture → CPU 读回 | `glGetTexImage`, PBO | `vkCmdCopyImageToBuffer` |
| GPU ↔ GPU | copy image / framebuffer blit | `vkCmdCopyImage` |

### 3. Shader 使用

```glsl
uniform sampler2D u_tex;
vec4 c = texture(u_tex, vec2(0.5, 0.5));
vec4 c2 = textureLod(u_tex, uv, 2.0);  // 指定 mip
vec4 c3 = textureGrad(u_tex, uv, ddx, ddy);  // 显式梯度 → 显式 mip
```

### 4. 坐标
- (u, v) ∈ `[0, 1]²`（normalized）或 `[0, width-1] × [0, height-1]`（pixel fetch via `texelFetch`）
- 寻址模式：REPEAT / MIRRORED_REPEAT / CLAMP_TO_EDGE / CLAMP_TO_BORDER
- 滤波：NEAREST / LINEAR（mipmap 链上还有 NEAREST_MIPMAP_NEAREST 等 6 种组合）

### 5. 内存分布

**CPU 端 layout**（由 `glPixelStorei(UNPACK_ALIGNMENT, n)` 控制）：
```
n=1:  |R G B A|R G B A|R G B A|       紧接
n=4:  |R G B A|R G B A|R G B A|       默认
n=8:  |R G B A _ _ _ _|R G B A _ _ _ _|  自动 padding 到 8 字节
```
- 高度方向：无 padding（除非 `UNPACK_ROW_LENGTH` 设置）
- 默认 4 字节对齐（`GL_UNPACK_ALIGNMENT = 4`）

**GPU 端**：
- **Linear tiling**（Vulkan `VK_IMAGE_TILING_LINEAR`）：与 CPU 端一致，可直接 `vkMapMemory` 读
- **Optimal tiling**（Vulkan `VK_IMAGE_TILING_OPTIMAL` / OpenGL `GL_TEXTURE_2D` 默认）：
  - NVIDIA / AMD 桌面：基本是 `pitch × height`，`pitch` ≥ width × bpp
  - 移动 GPU（Adreno/Mali/PowerVR）：Z-ordered / Hilbert / rotated block tiling
  - 块大小常见 4×4、16×16、32×32 字节
  - 不允许 CPU 直接 mip，必须通过 staging buffer
- **Mipmap 链**：内存占用 × 4/3（总面积 = `W×H + W/2×H/2 + ... ≈ 4/3 × W×H`）

---

## 四、Texture3D（三维体纹理）

### 1. 创建

```cpp
// OpenGL
glBindTexture(GL_TEXTURE_3D, tex);
glTexStorage3D(GL_TEXTURE_3D, 1, GL_RGBA8, w, h, d);
glTexSubImage3D(GL_TEXTURE_3D, 0, 0, 0, 0, w, h, d,
                GL_RGBA, GL_UNSIGNED_BYTE, data);
```

### 2. 数据传输
- 数据是**一维数组**，按 `slice → row → pixel` 顺序排列
- 体积 = `w × h × d × bpp`
- 可通过 `glTexSubImage3D` 分片上传（节省临时内存）

### 3. Shader 使用

```glsl
uniform sampler3D u_vol;
vec3 uvw = vec3(0.5, 0.5, 0.5);
vec4 c = texture(u_vol, uvw);   // 三线性插值
// 体渲染遍历：
for (int i = 0; i < 128; ++i) {
    vec4 s = texture(u_vol, vec3(uv, (float)i / 128.0));
    color += s.rgb * s.a * (1.0 - alpha_acc);
    alpha_acc += s.a * (1.0 - alpha_acc);
    if (alpha_acc > 0.99) break;
}
```

### 4. 坐标
- (u, v, w) ∈ `[0, 1]³`
- w 维度在 3D 纹理的"深度"方向
- 仅支持 NEAREST 与 LINEAR 滤波（不支持 mipmap 内的各向异性插值），warp mode 可用 REPEAT/CLAMP

### 5. 内存分布

**CPU 端**：
```
data[z][y][x]  // z-major
= data[z * (h*w) + y * w + x]
```
- 每行无 padding（与 2D 一样受 `UNPACK_ALIGNMENT` 控制）
- 但**整个 3D 纹理作为一个大数组**上传，无层间 padding

**GPU 端**：
- 3D 纹理在 GPU 内部是**一组 2D slice**（slice 0, slice 1, ..., slice d-1）
- 每个 slice 的内部排布与 2D 纹理一致（pitch + tiling）
- 注意：DirectX 9/10 早期 GPU 的 3D 纹理性能很差（每帧只能 render 到单一 slice），现代 GPU 已统一
- Vulkan 中 3D image 与 2D array 区别：`arrayLayers = 1` 但 `depth = N`

---

## 五、TextureCube（立方体贴图）

### 1. 创建

```cpp
// OpenGL
glBindTexture(GL_TEXTURE_CUBE_MAP, tex);
for (int i = 0; i < 6; ++i) {
    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGBA8,
                 w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, faceData[i]);
}
// 面顺序：+X, -X, +Y, -Y, +Z, -Z
```

```cpp
// Vulkan: 6 层 2D image
VkImageCreateInfo ici = {};
ici.imageType = VK_IMAGE_TYPE_2D;
ici.arrayLayers = 6;
ici.flags = VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT;
// 然后用 VK_IMAGE_VIEW_TYPE_CUBE 创建 image view
```

### 2. 数据传输
- 6 个独立 2D 数据，**顺序**：+X, -X, +Y, -Y, +Z, -Z
- 可一次上传 6 面（OpenGL DDS 加载器常用此方式），也可逐面上传
- 文件格式：`.dds` (DDS_CUBEMAP)、`.ktx`、`.hdr` (cross layout)

### 3. Shader 使用

```glsl
uniform samplerCube u_sky;
vec3 dir = normalize(v_worldPos);
vec4 c = texture(u_sky, dir);   // 3D 方向向量作坐标
```

```glsl
// 手动 face 索引（用于 parallax-corrected cubemap）
vec3 dir = normalize(v_worldPos);
vec3 absDir = abs(dir);
float maxAxis = max(absDir.x, max(absDir.y, absDir.z));
vec2 uv = (dir.xy / dir.z + 1.0) * 0.5;  // 简化示意
```

### 4. 坐标
- 输入：**3D 方向向量**（不需归一化但通常会归一化）
- GPU 内部通过 `max(|x|, |y|, |z|)` 决定使用哪个面，剩下两维映射到该面 UV
- 立方体面坐标是**单 cube face 内部**的 (s, t)，与该面的 2D 纹理坐标完全一致

**面坐标系（左下原点 vs 左上原点，跨 API 差异）**：

| API | 起始角 | 顺/逆时针 | 备注 |
|---|---|---|---|
| OpenGL | 左下 | counter-clockwise (CCW) | Y 轴向上 |
| DirectX | 左上 | clockwise (CW) | Y 轴向下，UV 翻转 |
| Vulkan | 左上 | 可配置 | 与 DX 类似但灵活 |
| glTF 规范 | 左上 | CCW | 与现代游戏一致 |

→ **导致 cubemap 在不同引擎间互导需要 Y 翻转或旋转 180°**。

### 5. 内存分布

**CPU 端**：
- 6 个独立 2D 数组，每个 `w × h × bpp`
- 总大小 = `6 × w × h × bpp`
- 加载器需要按 OpenGL 顺序重组数据

**GPU 端**：
- 内部存储为 **arrayLayers = 6** 的 2D 数组（layer 0 = +X, ..., layer 5 = -Z）
- 每层一个独立的 2D slice，有自己的 pitch/tiling
- 支持完整 mipmap 链（用于 prefiltered IBL：粗糙度对应 mip 级别）
- IBL 中常用：mip 0 = sharp，mip N = 5° 漫反射近似

---

## 六、Texture Array（纹理数组：1D/2D/Cube Array）

### 6.1 Texture1DArray

#### 创建
```cpp
glBindTexture(GL_TEXTURE_1D_ARRAY, tex);
glTexStorage2D(GL_TEXTURE_1D_ARRAY, 1, GL_RGBA8, width, layerCount);
glTexSubImage2D(GL_TEXTURE_1D_ARRAY, 0, 0, 0, width, layerCount,
                GL_RGBA, GL_UNSIGNED_BYTE, data);
```

#### Shader 使用
```glsl
uniform sampler1DArray u_tex;
vec4 c = texture(u_tex, vec2(u, layerIndex));
```

#### 坐标
- (u, layer) → u 是一维坐标，layer ∈ [0, layerCount-1]
- 数据按 layer-major 存储

### 6.2 Texture2DArray

#### 创建
```cpp
glBindTexture(GL_TEXTURE_2D_ARRAY, tex);
glTexStorage3D(GL_TEXTURE_2D_ARRAY, 1, GL_RGBA8, w, h, layerCount);
glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, 0, w, h, layerCount,
                GL_RGBA, GL_UNSIGNED_BYTE, data);
```

#### Shader 使用
```glsl
uniform sampler2DArray u_tex;
vec4 c = texture(u_tex, vec3(u, v, layerIndex));
```

#### 用途
- 动画帧序列：layer = 时间索引
- 地形 splat：layer = 材质索引
- 阴影 cascade：layer = cascade level
- 关键优势：**单次 draw call 渲染多张纹理**（vs 多次绑定 + uniform）

#### 内存分布
**CPU 端**：
- `data[layer][y][x]`，layer-major
- 每层结构与 2D 纹理一致

**GPU 端**：
- 与 3D 纹理内部存储**完全相同**（都是一组 slice）
- 区别仅在 shader 坐标解释：array 用整数 layer，3D 用归一化 w
- Vulkan/DX12 中 `arrayLayers=N, depth=1` 表示 array；`arrayLayers=1, depth=N` 表示 3D

### 6.3 TextureCubeMapArray

#### 创建
```cpp
glBindTexture(GL_TEXTURE_CUBE_MAP_ARRAY, tex);
glTexStorage3D(GL_TEXTURE_CUBE_MAP_ARRAY, mipLevels, GL_RGBA8,
               faceSize, faceSize, 6 * cubeCount);
```

#### Shader 使用
```glsl
uniform samplerCubeArray u_envMaps;
vec4 c = texture(u_envMaps, vec4(dir, cubeIndex));
// vec4(dir.xyz, cubeIndex)  → 第 4 分量是 cube 数组索引
```

#### 用途
- 动态点光源阴影（每光源一个 cube shadow map）
- 多套 IBL 探针（每个房间/区域）
- 限制：`GL_MAX_ARRAY_TEXTURE_LAYERS` 通常 ≥ 256，cube array 算 6 层/cube

---

## 七、Multisample Texture（多重采样纹理）

### 7.1 Texture2DMultisample

#### 创建
```cpp
glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, tex);
glTexStorage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, samples /*=4,8,16*/,
                          GL_RGBA8, w, h, GL_TRUE /*fixedSampleLocations*/);
```

#### 与 FBO 配合
```cpp
glBindFramebuffer(GL_FRAMEBUFFER, fbo);
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                       GL_TEXTURE_2D_MULTISAMPLE, msTex, 0);
glBindFramebuffer(GL_FRAMEBUFFER, 0);

// 渲染完后 blit 到普通 2D 纹理做后处理
glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
glBindFramebuffer(GL_DRAW_FRAMEBUFFER, resolveFbo);
glBlitFramebuffer(0, 0, w, h, 0, 0, w, h,
                  GL_COLOR_BUFFER_BIT, GL_LINEAR);
```

#### Shader 使用
**限制：multisample 纹理无法直接被 fragment shader 采样！**
- 仅 vertex shader 中通过 `texelFetch` 读取单个 sample
- 常规使用流程：渲染到 MSAA target → resolve 到 2D → 在 PS 中采样
- **例外**：`NV_texture_multisample` 扩展（OpenGL 4.0+ 核心已支持）允许 PS 中 `textureSamples` 获取 sample 数 + `texelFetch` 读特定 sample
- DX12/Vulkan 1.2+ 支持 `Sample(uint sampleIndex)` HLSL intrinsic

```hlsl
// HLSL: DX12 风格 MSAA sampling
Texture2DMS<float4> u_ms : register(t0);
float4 c = u_ms.Load(int3(px, 0), sampleIdx);
```

#### 坐标
- 与 2D 纹理相同 (u, v)，但没有 mipmap 概念
- 内部按 sample 索引访问：每个 pixel 有 N 个 sample

#### 内存分布
- 总内存 = `width × height × samples × bpp`
- 4xMSAA + RGBA8 + 1080p = 1920 × 1080 × 4 × 4 = **33 MB**（vs 普通 2D 的 8.3 MB）
- GPU 上每个 pixel 的 N 个 sample 物理位置由厂商决定（tiled shader 优化）
- Vulkan/DX11 之后：sample 位置固定 / programmable 两种模式

### 7.2 Texture2DMultisampleArray
- 同上但有多个 layer
- Vulkan 中通过 `VK_IMAGE_CREATE_MSAA_COMPATIBLE_BIT` + `arrayLayers > 1` 实现
- OpenGL：`GL_TEXTURE_2D_MULTISAMPLE_ARRAY`（4.3+）

---

## 八、Texture Buffer（缓冲区纹理）

### 1. 创建

```cpp
GLuint tex, buffer;
glGenBuffers(1, &buffer);
glBindBuffer(GL_TEXTURE_BUFFER, buffer);
glBufferData(GL_TEXTURE_BUFFER, sizeof(data), data, GL_STATIC_DRAW);

glGenTextures(1, &tex);
glBindTexture(GL_TEXTURE_BUFFER, tex);
glTexBuffer(GL_TEXTURE_BUFFER, GL_RGBA32UI, buffer);
```

### 2. 与普通 UBO/SSBO 区别
- 像 sampler 一样在 shader 中可被索引（`texelFetch`）
- 比 UBO 大（128 KB+ vs 64 KB GL minimum）
- 比 SSBO 快（`texelFetch` 是只读硬件路径）
- 不可滤波、不可 mipmap、不可用 `texture()` 函数，只能 `texelFetch`

### 3. Shader 使用

```glsl
uniform samplerBuffer u_buf;
vec4 v = texelFetch(u_buf, int(gl_InstanceID * 16 + gl_VertexID));
```

### 4. 坐标
- 整数索引（**不是归一化的**），范围 [0, size/bpp-1]
- 不支持 wrap

### 5. 内存分布
- CPU 端：与普通 VBO/UBO 一样
- GPU 端：位于显存中，由 VBO/SSBO 机制管理；sampler 包装一个 buffer
- 限制：buffer 大小通常有上限（GL_MAX_TEXTURE_BUFFER_SIZE）

---

## 九、TextureRectangle（矩形纹理，非归一化 2D）

### 创建
```cpp
glBindTexture(GL_TEXTURE_RECTANGLE, tex);
glTexImage2D(GL_TEXTURE_RECTANGLE, 0, GL_RGBA8, w, h, 0,
             GL_RGBA, GL_UNSIGNED_BYTE, data);
```

### 特点
- 坐标用**像素坐标**（不是 [0,1]）
- 无 mipmap
- 不可 REPEAT，只能 CLAMP
- 用途：视频帧、后处理 NDC 采样、图像处理
- DirectX 与 Vulkan 都没有直接对应——通常用普通 2D 纹理 + pixel fetch 模拟

```glsl
uniform sampler2DRect u_tex;
vec4 c = texture(u_tex, gl_FragCoord.xy);
```

---

## 十、Depth / Stencil Texture（深度纹理）

### 1. 创建

```cpp
// OpenGL: 作为 FBO 深度附件创建
glBindTexture(GL_TEXTURE_2D, depthTex);
glTexStorage2D(GL_TEXTURE_2D, 1, GL_DEPTH_COMPONENT24, w, h);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);

glBindFramebuffer(GL_FRAMEBUFFER, fbo);
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                       GL_TEXTURE_2D, depthTex, 0);
```

### 2. 数据传输
- 一般不直接 CPU 上传——深度纹理由 GPU 在光栅化阶段自动写入
- 可作为 sampler 在 PS 中采样（用于 shadow mapping）
- 读回：`glReadPixels(GL_DEPTH_COMPONENT, ...)`，注意深度值范围归一化问题

### 3. Shader 使用

```glsl
// 阴影比较采样（hardware PCF）
uniform sampler2DShadow u_shadow;
float visibility = texture(u_shadow, vec3(uv, depthRef));
// vec3(u, v, refDepth)：硬件自动比较 texel vs refDepth
```

```glsl
// 常规采样（仅取深度值）
uniform sampler2D u_depth;
float d = texture(u_depth, uv).r;  // .r 是深度，[0, 1] 归一化
float linearD = perspective * d;  // 反推线性深度
```

### 4. 坐标
- 与 2D 纹理相同
- 深度比较模式：硬件用 refDepth 与 texel 深度比较
- 深度格式：通常 16/24/32 位浮点；stencil 是 8 位

### 5. 内存分布
- 物理排布与 2D 纹理一致
- DirectX 中常与 stencil 共享一个 surface（`DXGI_FORMAT_R24G8_TYPELESS`）
- Vulkan 中 `imageAspect` 决定访问 depth 还是 stencil
- 注意：HZB / HiZ 是 depth 纹理的特殊 mip 形式，**GPU 硬件自动生成**，不可编程

---

## 十一、压缩纹理 (Compressed Texture) 与 Target 关系

> 压缩格式是"内部格式"的属性，与 target 类型正交，但有重要兼容性约束：

| Target | 常用压缩格式 | 块大小 |
|---|---|---|
| 2D / 2DArray | BC1/2/3 (DXT), BC4/5, BC6H/7, ETC2, ASTC | 4×4 ~ 12×12 |
| 3D | BC1~7, ETC2（受 API 支持限制） | 同上 |
| Cube | BC1~7, ASTC | 同上 |
| Multisample | **不支持压缩**（OpenGL ES 也不支持） | — |
| 1D / Buffer | **不支持压缩** | — |

**内存分布关键点**：
- 压缩数据是**块对齐**的：每 4×4 pixel 一块
- 整图必须是块的整数倍，否则 padding
- CPU 上传时**不需要**先解压，GPU 解码器直接读压缩数据
- 块大小 8~16 字节/4×4 = 4~1 bpp 有效

---

## 十二、共享内存组织总结表

| Target | CPU 数据布局 | CPU 总大小公式 | GPU 排布 | 关键限制 |
|---|---|---|---|---|
| 1D | `[w]` | `w × bpp` | linear ~1D | 通常 w ≤ 16384 |
| 2D | `[h][w]` | `w × h × bpp` | tiled (mobile) / linear-pitch (desktop) | 16384² max dim |
| 3D | `[d][h][w]` | `w × h × d × bpp` | 多 slice, 每 slice 自带 pitch | depth 限制 2048 |
| Cube | `6 × [h][w]` | `6 × w × h × bpp` | arrayLayers=6 | 面必须正方形 |
| 1DArray | `[N][w]` | `N × w × bpp` | N slice | N ≤ GL_MAX_ARRAY_TEXTURE_LAYERS |
| 2DArray | `[N][h][w]` | `N × w × h × bpp` | N slice, slice 内同 2D | 同上 |
| CubeArray | `6M × [h][w]` | `6 × M × w × h × bpp` | 6M slice | M 限制 |
| 2DMS | — | `w × h × samples × bpp` | sample 位置固定/programmable | samples ∈ {2,4,8,16,32,64} |
| 2DMSArray | — | `N × w × h × samples × bpp` | 同上 × N | — |
| Buffer | `[size/bpp]` | `size` | 显存 buffer | 不可滤波 |
| Rectangle | `[h][w]` | `w × h × bpp` | linear | 无 mip, 无 repeat |
| Depth | `[h][w]` | `w × h × depthBits/8` | linear-pitch 或 tiled | stencil 共存 |

---

## 十三、跨 API 关键差异速查

### OpenGL ↔ Vulkan 概念映射

| OpenGL | Vulkan |
|---|---|
| Texture Object (GLuint) | `VkImage` + `VkImageView` + `VkSampler` 三件套 |
| `GL_TEXTURE_2D` (target) | `VK_IMAGE_TYPE_2D` + `VK_IMAGE_VIEW_TYPE_2D` |
| `glTexStorage2D` | `vkCreateImage` + `vkBindImageMemory` |
| `glTexSubImage2D` | staging buffer + `vkCmdCopyBufferToImage` |
| `GL_TEXTURE_CUBE_MAP` | `VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT` |
| `glBindTexture(unit, tex)` | descriptor set binding |
| `GL_TEXTURE_2D_MULTISAMPLE` | `samples = N` in `VkImageCreateInfo` |

### DirectX ↔ OpenGL 关键差异

| 维度 | OpenGL | DirectX |
|---|---|---|
| Y 方向 | 左下原点，UV (0,0) 在左下 | 左上原点，UV (0,0) 在左上 |
| 立方体面 | OpenGL 顺序 +X,-X,+Y,-Y,+Z,-Z | DXGI 顺序 +X,-X,+Y,-Y,+Z,-Z（一致） |
| 立方体贴图 Y 翻转 | 不需要 | 加载时需要翻转或采样时 `1-v` |
| 压缩纹理 | `GL_COMPRESSED_RGBA_S3TC_DXT5_EXT` | `DXGI_FORMAT_BC5_UNORM` |
| Multisample | `glTexStorage2DMultisample` | `ID3D11Texture2D::CreateTexture2D(desc)` |
| Depth/Stencil | `GL_DEPTH_COMPONENT` | `DXGI_FORMAT_D24_UNORM_S8_UINT` |
| 不可变存储 | `glTexStorage2D` (4.2+) | `ID3D11Device::CreateTexture2D` 默认 immutable |

---

## 十四、最佳实践与陷阱

### 1. 行对齐 (UNPACK_ALIGNMENT)
- OpenGL 默认 `UNPACK_ALIGNMENT = 4`
- 若一行字节数**不是 4 的倍数**（如 RGB 8-bit 宽度非 4 倍数），需显式 `glPixelStorei(UNPACK_ALIGNMENT, 1)`

### 2. 立方体跨平台
- OpenGL ↔ DirectX 互导：需要 Y 翻转（v 坐标取反）或预旋转
- 推荐：始终在 CPU 端加载时归一化到 OpenGL 顺序 + 翻转 Y，运行时按需再处理

### 3. Mipmap 内存预算
- 完整 mipmap 链 = `1 + 1/4 + 1/16 + ... ≈ 4/3` 倍
- 对 2D 来说：`4/3 × W × H × bpp`
- 高分辨率 4K 纹理 8 bpp 完整 mip ≈ **85 MB**（单 texture！）

### 4. Multisample 选择
- MSAA samples 4 / 8 已经够用
- 16x MSAA 边际收益小，开销大
- 移动端：尽量避免 4x+，多用 post-process AA (TAA/FXAA/SMAA)

### 5. 3D 纹理 vs 2DArray
- 二者 GPU 内部存储**几乎相同**（都是 N 个 slice）
- 选择依据：
  - 数据有真实第三维（CT 数据、距离场）→ 3D
  - 离散切片（动画帧、材质表）→ 2DArray
- 2DArray 性能通常更优（layer 寻址 cache 友好）

### 6. Sampler 与 Immutable Texture
- OpenGL 4.5+ 推荐使用 `glTextureStorageXX` + `glBindTextureUnit` + 单独 `glCreateSamplers`
- 分离后 sampler 可被多张纹理共享

### 7. GPU 端不可直接读
- Optimal tiling 的纹理**CPU 端无法直接映射**
- 调试时用 `glGetTexImage` 或 `vkCmdCopyImageToBuffer` 到 staging 再读

### 8. 压缩纹理限制
- 宽度/高度必须是 4 的倍数
- 整图大小向上取整到 4×4
- mip 1 = `floor(w/2)` 等，必须同样对齐

---

## 十五、参考与延伸阅读

- OpenGL 4.6 规范 § 8 (Textures)
- Vulkan 1.3 规范 § 11 (Images)
- Direct3D 11/12 文档：Resources, Views, Samplers
- cubemap 跨平台细节见同目录 `cubemap_and_perspective_notes.md`
- 压缩纹理细节见 `BC2 block布局.md` 及相关 PDF
- 纹理格式 / DDS 文件结构见 `DDSFileStructure.png`
