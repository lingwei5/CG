# 引擎 Light 体系分析（基于 LightWorld / 散射天空背景）

本文档基于以下来源对引擎中 Light 相关的类、成员及可能的实现进行合理推测：

- SDK 头文件：`sdk/include/ig/light/Light.h`、`LightWorld.h`、`LightOmni.h`、`LightProj.h`、`LightPoint.h`、`sdk/include/ig/render/Render.h`、`RClouds.h`
- 场景配置：`data/InfraRed/260616project/demo.world` 中 `sun` / `moon_light` 节点，以及 `render` 段（含嵌套 `cloud` 段）的全部参数
- 修复后的应用代码：`project/AppSnapshot-texture/NodeSnapShot.cpp` 的 `cb_changeViewMode`

---

## 1. 类继承体系

```
Node
 └── Light                  (light/Light.h, NODE_TYPE = LIGHT)
      ├── LightWorld        (light/LightWorld.h)  全局/太阳/月亮光，含散射
      ├── LightPoint        (light/LightPoint.h)  点光源
      ├── LightOmni         (light/LightOmni.h)   全向光（支持 cube map）
      └── LightProj         (light/LightProj.h)   投影光（聚光/透视投影）
```

`Light` 继承自 `Node`，因此光源本身是场景图节点，具备 `transform`、`enabled`、`light_mask`、`viewport_mask` 等节点通用属性，可以直接作为子节点挂在 `global` 节点下，参与 WGS 变换与裁剪。

---

## 2. Light 基类（`Light.h`）关键成员

### 2.1 颜色与强度

| 成员 | 含义 |
|------|------|
| `m_color` (vec4) | 光源基础颜色（RGBA），`sun` 节点为 `1,1,1,1`，`moon_light` 为 `0.501961,...` |
| `m_color_modulation` (vec4) | 动态调制颜色（运行期由环境/动画系统写入） |
| `m_multiplier` (float) | 全局强度乘子；`sun` 为 `2.5`，`moon_light` 为 `0.1` |

接口：`setMultiplier()`、`setColor()`（通过 J_PROPERTY 暴露）。

### 2.2 衰减与距离

| 成员 | 含义 |
|------|------|
| `m_attenuation` | 衰减系数，`.world` 中 `attenuation = 1` 表示无衰减 |
| `m_diffuse_scale` / `m_specular_scale` | 漫反射 / 镜面反射强度缩放 |
| `m_visible_distance` | 可见距离，`sun` 为 `1e9`（始终可见） |
| `m_shadow_distance` | 阴影影响距离，`sun` 为 `350`，`moon_light` 为 `100` |
| `m_fade_distance` | 距离淡出距离 |
| `m_render_distance` / `m_deferred_distance` | 渲染 / 延迟渲染距离 |

### 2.3 阴影

| 成员 | 含义 |
|------|------|
| `m_shadow` (bool) | 是否启用阴影，`sun`/`moon_light` 均为 `1` |
| `shadow_size` (int) | 阴影贴图尺寸级别；`sun` 为 `5`，`-1` 表示使用默认 |
| `m_shadow_scale` | 阴影强度缩放，`0~1` |
| `m_shadow_ambient` | 阴影环境光 |
| `m_shadow_bias` / `shadow_slope` | 阴影偏移 / 斜率偏移（抗 acne） |
| `m_enable_scissors` | 是否启用 scissors 裁剪优化，`.world` 中为 `1` |
| `m_light_mask` / `m_viewport_mask` | 光照掩码 / 视口掩码，决定哪些 surface 被照亮 |

### 2.4 方向

`Light` 重写了 `Node::setDirection()`，并提供 `lookAt(direction, up)` 与 `getDirection()`。`LightWorld` 类型的光源（太阳/月亮）通过 `transform` 矩阵的旋转部分确定方向，方向 = `-Z` 轴（lookAt 默认看向 -Z）。

### 2.5 序列化

`loadWorld(Package*)` / `saveWorld(Package*)` 负责 `.world` 文件中节点的读写。`.world` 文件里 `color`、`shadow`、`shadow_size`、`light_mask`、`shadow_distance`、`shadow_scale`、`attenuation`、`visible_distance`、`fade_distance`、`multiplier`、`enable_scissors` 等字段对应基类属性。

---

## 3. LightWorld 派生类（`LightWorld.h`）—— 本问题的核心

`LightWorld` 表示场景级全局光，主要用于太阳光 / 月光 / 全局环境光，是渲染天空背景和大气散射的关键。

### 3.1 两个核心枚举

```cpp
enum SCATTERING_MODE {
    SCATTERING_NONE,      // 0：不参与散射
    SCATTERING_GLOBAL,    // 1：全局散射（驱动天空背景与大气）
    SCATTERING_MAX
};

enum USEAGE_TYPE {
    USEAGE_GENERAL = 0,   // 通用全局光
    USEAGE_SUN,           // 1：太阳
    USEAGE_MOON,          // 2：月亮
    USEAGE_MAX
};
```

在 `.world` 中对应字段：

- `usage = 1;`  → `USEAGE_SUN`（太阳）
- `scattering = 1;` → `SCATTERING_GLOBAL`（启用全局散射，渲染天空）
- `moon_light` 节点：`usage = 2; scattering = 0;`（月亮，不参与散射）

### 3.2 关键成员

| 成员 | 含义 |
|------|------|
| `m_scattering` (SCATTERING_MODE) | 散射模式，决定该光源是否驱动大气散射与天空背景渲染 |
| `m_usage` (USEAGE_TYPE) | 用途分类，引擎据此识别"太阳方向"并喂给散射 shader |
| `m_need_update` (bool) | 脏标记，提示阴影/散射数据需要刷新 |
| `m_shadow_range` | 阴影有效范围（ZFar 相关） |
| `m_shadow_split_anchor_distance` | 级联阴影锚点距离 |
| `m_num_shadow_splits` | 级联阴影分割数，`sun` 为 `4` |
| `m_view` (dmat4) | 光源视图矩阵 |
| `m_z_range` (vec2) | 光源 Z 范围 |
| `m_projection` (mat4) | 光源投影矩阵 |
| `m_projections[4]` | 4 级级联阴影投影矩阵 |
| `m_xy_ranges[4]` | 各级联 XY 范围 |
| `m_frustum_sides_in_view[4]` / `m_frustum_len[5]` | 阴影视锥边/长 |

### 3.3 阴影更新

```cpp
void setShadowRange(float range);
void setShadowSplitAnchorDistance(float distance);
void setNumShadow_splits(int num);
void updateShadow();
```

`updateShadow()` 内部会基于相机 near/far 与 `shadow_distance` 计算级联视锥，并填充 `m_projections[]`、`m_xy_ranges[]`、`m_view`、`m_z_range`，供渲染器在阴影 pass 中使用。

### 3.4 序列化字段

`.world` 中 `LightWorld` 节点字段与成员对应：

```
color            -> Light::m_color
shadow           -> Light::m_shadow
shadow_size      -> Light::shadow_size
light_mask       -> Light::m_light_mask
shadow_distance  -> Light::m_shadow_distance
shadow_scale     -> Light::m_shadow_scale
attenuation      -> Light::m_attenuation
visible_distance -> Light::m_visible_distance
fade_distance    -> Light::m_fade_distance
multiplier       -> Light::m_multiplier
enable_scissors  -> Light::m_enable_scissors
usage            -> LightWorld::m_usage
scattering       -> LightWorld::m_scattering
shadow_range     -> LightWorld::m_shadow_range
shadow_split_anchor_distance -> LightWorld::m_shadow_split_anchor_distance
num_shadow_splits -> LightWorld::m_num_shadow_splits
```

---

## 4. 天空背景与散射实现推测

### 4.1 配置位置

天空背景由两段配置协同驱动：

1. **节点级**（`LightWorld` 节点）：`usage` + `scattering` 决定哪个光源充当太阳并参与散射。
2. **渲染级**（`render` 段）：`scattering_*` 系列参数控制散射大气模型本身。

`demo.world` 的 `render` 段：

```
scattering_radius = 6.360000e+06,6.420000e+06;   // 大气层内/外半径（米）
scattering_sun_power = 1;
scattering_sun_scale = 6.5;
scattering_sun_angle = 0.99997;                    // 太阳角度阈值
scattering_sun_threshold = 0;
scattering_sun_color = 1,1,1,1;
scattering_sun_exposure = 10;
scattering_moon_exposure = 0.2;
scattering_rayleigh = 0.000001;                    // Rayleigh 散射系数
scattering_rayleigh_height = 6000;                 // Rayleigh 高度（米）
scattering_mie_angstrom_beta = 0.005328;
scattering_mie_angstrom_alpha = 0;
scattering_mie_albedo = 0.9;
scattering_mie_height = 1200;                      // Mie 散射高度（米）
```

外加：

```
scattering_light_color_lut_path = "data/core/textures/environment/light_color.dds";
enable_environment = 1;
```

### 4.2 渲染管线推测

结合 `data/core/materials/mtl/atmosphere.mtl` 与 `data/core/shaders/render/scattering/` 推测：

1. **光源识别**：渲染器在每帧开始时遍历 `LightWorld` 节点，根据 `m_usage == USEAGE_SUN` 找到太阳，取其方向作为 `s_sun_direction_world` / `s_light_direction_world`；`m_usage == USEAGE_MOON` 找到月亮。
2. **散射开关**：仅当该太阳光的 `m_scattering == SCATTERING_GLOBAL` 时，渲染器才会启用 scattering pass（`RScattering`）。`SCATTERING_NONE` 则跳过天空背景与大气着色。
3. **LUT 预计算**：`atmosphere_transmittance` / `atmosphere_single_scattering` 材质在离屏 pass 中预计算透射率与单次散射查找表（基于 `scattering_rayleigh`、`scattering_mie_*`、`scattering_radius`）。
4. **天空背景绘制**：`atmosphere_render` 材质或 `DefaultSky` / `ObjectSky` 在 ambient pass 中依据 `transmittance_texture` + `scattering_texture` + `sun_direction` 渲染天空球。`scattering_sun_color`、`scattering_sun_exposure` 用于调色与曝光。
5. **环境系数 IBL**：`environment` 段的 `i0..i4` 提供不同 TOD 的环境立方体贴图，`Environment::updateIBL()` 计算球谐系数并写入 `Render::setEnvironmentCoefficients()`，作为天光漫反射/镜面反射的 IBL 来源。

### 4.3 AppSnapshot-texture 的修复点

修复前 `cb_changeViewMode` 同时操作了三件事：`setEnabled(true)`、`setUsage(USEAGE_SUN)`、`setScattering(SCATTERING_GLOBAL)`。由于 `sun` 节点在 `.world` 中已配置为 `usage=1, scattering=1, enabled=1`，重复设置 `usage` 并不会改变行为；真正驱动天空背景的是 **`scattering` 模式**。

修复后（`NodeSnapShot.cpp:1188-1216`）：

```cpp
if (m_view_mode == ViewMode_IR_Radiance ||
    m_view_mode == ViewMode_IR_Temperature)
{
    m_sun->setScattering(LightWorld::SCATTERING_NONE);  // 红外模式下关闭散射
}
else
{
    // m_sun->setEnabled(true);
    // m_sun->setUsage(LightWorld::USEAGE_SUN);
    m_sun->setScattering(LightWorld::SCATTERING_GLOBAL); // 可见光模式下开启散射
}
```

这印证了：

- **`scattering` 是开关**：决定渲染器是否执行天空背景/大气散射 pass。
- **`usage` 是身份**：决定该光源是否被当作太阳参与散射计算（`.world` 已正确设置，运行期无需重置）。
- **`enabled` 是可见性**：决定光源是否照亮场景（不影响天空背景渲染本身）。

---

## 5. 其它 Light 子类简述

### 5.1 LightPoint（`LightPoint.h`）

最简单的点光源，仅有 `m_radius`。通过 `setRadius()` 设置影响半径，`update_bounds()` 更新包围球。无阴影投影矩阵，常用于局部补光。

### 5.2 LightOmni（`LightOmni.h`）

全向光，支持立方体贴图（`TextureObject m_tex`）与阴影遮罩 `m_shadow_mask`。通过 `setImageTextureName()` 绑定 cube map，`getImageTexture()` 返回纹理。适合做带环境贴图的室内光源或 IBL 探针。

### 5.3 LightProj（`LightProj.h`）

投影光（聚光），具备透视投影参数：

- `m_fov` / `m_znear` / `m_zfar`
- `m_projection` (dmat4)
- `m_texture_name` 投影贴图

`update_projection()` 在参数变化时重建投影矩阵，`update_bounds()` 更新包围锥。常用于聚光灯、投影仪、手电筒效果。

---

## 6. .world 中 `sun` 与 `moon_light` 配置对照

| 字段 | sun | moon_light | 含义 |
|------|-----|------------|------|
| enabled | 1 | 0 | 月光默认禁用 |
| color | 1,1,1,1 | 0.501961,... | 月光更暗 |
| multiplier | 2.5 | 0.1 | 强度差异 |
| usage | 1 (SUN) | 2 (MOON) | 用途标识 |
| scattering | 1 (GLOBAL) | 0 (NONE) | 仅太阳驱动散射 |
| shadow_size | 5 | -1 | 月光用默认阴影尺寸 |
| shadow_distance | 350 | 100 | 阴影范围 |
| light_mask | 3 | 1 | 影响哪些 surface |
| shadow_range | 512 | 320 | 阴影 ZFar |

---

## 7. `render` 段字段与 `Render` 类成员对照

`.world` 文件中 `world/render` 段的所有字段均映射到 `Render` 类（`sdk/include/ig/render/Render.h`）的 J_PROPERTY 成员。`Render` 是渲染器主控类，集中管理场景级渲染开关、后处理参数、大气散射参数等。下表按 `.world` 出现顺序列出 `demo.world` 中 `render` 段的全部字段及其对应成员。

### 7.1 基础颜色与环境

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `ambient_color` | 0,0,0,0 | `m_ambient_color` (vec4) | 全局环境光颜色 |
| `background_color` | 0,0,0,0 | `m_background_color` (vec4) | 清屏背景色 |
| `scattering_light_color_lut_path` | "data/core/textures/environment/light_color.dds" | `m_scattering_light_color_lut_path` (jString) + `m_scattering_light_color_lut_texture` (SharedPtr\<Texture\>) | 散射光颜色 LUT 路径，供散射着色采样 |
| `environment_texture` | "" | `m_environment_texture_name` (jString) + `m_environment_texture` (Texture*) | IBL 环境立方体贴图，空表示使用 `environment` 段的 `i0..i4` |

### 7.2 视觉模式

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `vision_mode` | 0 | `m_vision_mode` (IG_VISION_MODE) | 视觉模式（NONE/IR/LLNV/RADAR_WEATHER/RADAR_ALT/GRAY） |
| `ir_mode` | 0 | `m_ir_mode` (IG_IR_MODE) | 红外子模式 |
| `black_white_switch` | 0 | `m_black_white_switch` (bool) | 黑白切换 |
| `radar_weather_lut` | 0 | `m_radar_weather_lut` (bool) | 雷达气象 LUT 开关 |
| `llnv_scale` | 1 | `m_llnv_scale` (float) | 微光夜视强度 |
| `env_temperature_kelvin` | 273 | `m_env_temperature_kelvin` (float) | 环境温度（开尔文），用于红外辐射计算 |

### 7.3 全局渲染开关

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_post_screen` | 1 | `m_enable_post_screen` (bool) | 后处理总开关 |
| `enable_environment` | 1 | `m_enable_environment` (bool) | 环境/IBL 开关，开启后散射与天空背景才生效 |
| `shading_high_quality` | 1 | `m_shading_high_quality` (bool) | 高质量着色 |
| `linear_depth` | 0 | `m_linear_depth` (bool) | 线性深度缓冲 |
| `texture_create_time_limit` | 0.016 | （渲染器内部，限制每帧纹理创建耗时） | 每帧纹理创建时间预算（秒） |
| `light_distance` | 1e9 | `m_light_distance` (float) | 光照有效距离 |
| `refraction_dispersion` | 1.15,1,0.85 | `refraction_dispersion` (vec3) | 折射色散（RGB） |

### 7.4 SSAO

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `ssao_quality` | 3 | `m_ssao_quality` (SSAO_QULITY) | SSAO 质量（0~3，0 为关闭） |
| （内部） | — | `m_ssao_radius` / `m_ssao_intensity` | SSAO 采样半径与强度（未在 demo.world 出现，使用默认） |

### 7.5 FXAA

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_fxaa` | 0 | `m_enable_fxaa` (bool) | FXAA 开关 |
| `fxaa_sample_offset` | 1 | `m_fxaa_sample_offset` (float) | FXAA 采样偏移 |

### 7.6 动画

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_animation` | 1 | `m_enable_animation` (bool) | 顶点/植被动画开关 |
| `animation_time` | 143070.640625 | `m_animation_time` (double) | 动画累计时间（秒） |
| `animation_scale` | 1 | `m_animation_scale` (float) | 动画缩放 |
| `animation_wind_angle` | 90 | `m_animation_wind_angle` (float) | 风向角度 |
| `animation_wind_speed` | 0 | `m_animation_wind_speed` (float) | 风速 |
| （内部） | — | `m_animation_wind` (vec3, READONLY) | 由角度与速度合成的风向向量 |
| （内部） | — | `m_animation_stem` / `m_animation_leaf` | 茎/叶动画强度 |

### 7.7 SSR（屏幕空间反射）

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_ssr` | 0 | `m_enable_ssr` (bool) | SSR 开关 |
| `ssr_increased_accuracy` | 0 | `m_ssr_increased_accuracy` (bool) | 高精度模式 |
| `ssr_resolution` | 1 | `m_ssr_resolution` (int) | 分辨率级别 |
| `ssr_num_steps` | 16 | `m_ssr_num_steps` (int) | 步进次数 |
| `ssr_step_size` | 0.2 | `m_ssr_step_size` (float) | 步长 |
| `ssr_threshold` | 1 | `m_ssr_threshold` (float) | 反射阈值 |
| `ssr_threshold_occlusion` | 1 | `m_ssr_threshold_occlusion` (float) | 遮挡阈值 |

### 7.8 雾

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_fog` | 0 | `m_enable_fog` (bool) | 雾开关 |
| `fog_use_environment` | 1 | `m_fog_use_environment` (bool) | 使用环境颜色 |
| `fog_density` | 0 | `m_fog_density` (float, CLAMP 0~1000) | 雾密度 |
| `fog_power` | 1 | `m_fog_power` (float, CLAMP EPS~128) | 雾幂指数 |
| `fog_visible_height` | 10000 | `m_fog_visible_height` (float) | 可见高度 |
| `fog_visible_height_fade` | 5000 | `m_fog_visible_height_fade` (float) | 高度淡出 |
| `fog_bottom` | -300 | `m_fog_bottom` (float) | 雾底高度 |
| `fog_top` | 3000 | `m_fog_top` (float) | 雾顶高度 |
| `fog_top_fade` | 4000 | `m_fog_top_fade` (float) | 顶部淡出 |
| `fog_color` | 1,1,1,1 | `m_fog_color` (vec4) | 雾颜色 |

### 7.9 TAA（时域抗锯齿）

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_taa` | 1 | `m_enable_taa` (bool) | TAA 开关 |
| `taa_frame_count` | 10 | `m_taa_frame_count` (float) | TAA 累计帧数 |
| `taa_super_sampling_scale` | 1 | `m_taa_super_sampling_scale` (int) | 超采样倍数 |

### 7.10 DOF（景深）

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_dof` | 0 | `m_enable_dof` (bool) | 景深开关 |
| `dof_focal_distance` | 20000 | `m_dof_focal_distance` (float, READONLY) | 焦距 |
| `dof_far_blur_range` | 1 | `m_dof_far_blur_range` | 远景模糊范围 |
| `dof_far_blur_radius` | 1 | `m_dof_far_blur_radius` | 远景模糊半径 |
| `dof_far_blur_power` | 1 | `m_dof_far_blur_power` | 远景模糊幂 |
| `dof_far_focal_range` | 20000 | `m_dof_far_focal_range` | 远焦范围 |
| `dof_far_focal_scale` | 1 | `m_dof_far_focal_scale` | 远焦缩放 |
| `dof_far_focal_power` | 1 | `m_dof_far_focal_power` | 远焦幂 |
| `dof_near_blur_range` | 1 | `m_dof_near_blur_range` | 近景模糊范围 |
| `dof_near_blur_radius` | 1 | `m_dof_near_blur_radius` | 近景模糊半径 |
| `dof_near_blur_power` | 1 | `m_dof_near_blur_power` | 近景模糊幂 |
| `dof_near_focal_range` | 20000 | `m_dof_near_focal_range` | 近焦范围 |
| `dof_near_focal_scale` | 1 | `m_dof_near_focal_scale` | 近焦缩放 |
| `dof_near_focal_power` | 1 | `m_dof_near_focal_power` | 近焦幂 |

### 7.11 Glow（辉光）

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_glow` | 0 | `m_enable_glow` (bool) | 辉光开关 |
| `glow_scale` | 1 | `m_glow_scale` (float, MIN 0) | 辉光缩放 |
| `glow_threshold` | 0.1 | `m_glow_threshold` (float, MIN 0) | 辉光阈值 |
| `glow_small_exposure` | 1 | `m_glow_small_exposure` | 小尺度曝光 |
| `glow_medium_exposure` | 1 | `m_glow_medium_exposure` | 中尺度曝光 |
| `glow_large_exposure` | 1 | `m_glow_large_exposure` | 大尺度曝光 |

### 7.12 Scattering（大气散射，驱动天空背景）

`.world` 中以 `scattering_` 前缀的字段全部属于散射子系统。其中部分在 `Render` 头文件有对应成员，部分属于 `RScattering` 子模块（头文件未随 SDK 公开）。

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `scattering_radius` | 6.36e6, 6.42e6 | （RScattering 内部，大气层内外半径） | 大气层半径（米），外半径-内半径=大气厚度 |
| `scattering_sun_power` | 1 | `m_scattering_sun_power` (float) | 太阳强度乘子 |
| `scattering_sun_scale` | 6.5 | `m_scattering_sun_scale` (float) | 太阳缩放 |
| `scattering_sun_angle` | 0.99997 | `m_scattering_sun_angle` (float) | 太阳角度阈值（dot 值） |
| `scattering_sun_threshold` | 0 | `m_scattering_sun_threshold` (float) | 太阳阈值 |
| `scattering_sun_color` | 1,1,1,1 | `m_scattering_sun_color` (vec4) | 太阳颜色 |
| `scattering_sun_exposure` | 10 | （RScattering 内部，太阳曝光） | 太阳曝光值 |
| `scattering_moon_exposure` | 0.2 | （RScattering 内部，月亮曝光） | 月亮曝光值 |
| `scattering_rayleigh` | 0.000001 | （RScattering 内部，Rayleigh 系数） | Rayleigh 散射系数 |
| `scattering_rayleigh_height` | 6000 | （RScattering 内部） | Rayleigh 散射高度（米） |
| `scattering_mie_angstrom_beta` | 0.005328 | （RScattering 内部） | Mie 散射 Angstrom β |
| `scattering_mie_angstrom_alpha` | 0 | （RScattering 内部） | Mie 散射 Angstrom α |
| `scattering_mie_albedo` | 0.9 | （RScattering 内部） | Mie 反照率 |
| `scattering_mie_height` | 1200 | （RScattering 内部） | Mie 散射高度（米） |

> 注：`Render.h` 仅暴露 `m_scattering_sun_power/scale/angle/threshold/color` 这 5 个直接成员；其余 `scattering_radius`、`scattering_*_exposure`、`scattering_rayleigh*`、`scattering_mie_*` 属于散射子系统 `RScattering`（头文件未随 SDK 公开），由 `Render` 在加载 `.world` 时转发给散射模块。`scattering_light_color_lut_path` 对应 `Render::m_scattering_light_color_lut_path`，加载为 `m_scattering_light_color_lut_texture`。

### 7.13 Volumetric（体积光）

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `enable_volumetric` | 0 | `m_enable_volumetric` (bool) | 体积光开关 |
| `volumetric_exposure` | 0.3 | `m_volumetric_exposure` (float, READONLY) | 体积光曝光 |
| `volumetric_length` | 0.5 | `m_volumetric_length` (float, READONLY) | 体积光长度 |
| （内部） | — | `m_volumetric_attenuation` (float, READONLY) | 衰减 |

### 7.14 HDR（高动态范围）

`enable_hdr` 对应 `m_enable_hdr`，其余 `hdr_*` 字段全部对应 `Render::m_hdr_*` 系列成员（见头文件 339-377 行）。

| 字段 | 对应成员 | 说明 |
|------|----------|------|
| `enable_hdr` | `m_enable_hdr` (bool) | HDR 总开关 |
| `hdr_exposure` | `m_hdr_exposure` | 曝光 |
| `hdr_adaptation` | `m_hdr_adaptation` | 自适应速度 |
| `hdr_min_luminance` / `hdr_max_luminance` | `m_hdr_min_luminance` / `m_hdr_max_luminance` | 亮度上下限 |
| `hdr_threshold` | `m_hdr_threshold` | 阈值 |
| `hdr_small/medium/large/bright_exposure` | `m_hdr_small/medium/large/bright_exposure` | 多尺度曝光 |
| `hdr_enable_cross` | `m_hdr_enable_cross` | 十字星开关 |
| `hdr_cross_color` / `hdr_cross_scale` / `hdr_cross_shafts` / `hdr_cross_length` / `hdr_cross_angle` / `hdr_cross_threshold` | `m_hdr_cross_*` | 十字星参数 |
| `hdr_enable_bokeh` | `m_hdr_enable_bokeh` | 散景开关 |
| `hdr_bokeh_*` | `m_hdr_bokeh_*` | 散景参数 |
| `hdr_enable_shaft` | `m_hdr_enable_shaft` | 光束开关 |
| `hdr_shaft_*` | `m_hdr_shaft_*` | 光束参数 |
| `hdr_enable_lens` | `m_hdr_enable_lens` | 镜头光晕开关 |
| `hdr_lens_color/scale/length/radius/threshold/dispersion/texture_name` | `m_hdr_lens_*` | 镜头光晕参数 |

### 7.15 颜色校正与锐化

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `color_brightness` | 0 | `m_color_brightness` (float, READONLY) | 亮度 |
| `color_contrast` | 0 | `m_color_contrast` (float, READONLY) | 对比度 |
| `color_saturation` | 1 | `m_color_saturation` (float, READONLY) | 饱和度 |
| `color_gamma` | 1 | `m_color_gamma` (float, READONLY) | Gamma |
| `enable_sharpen` | 0 | `m_enable_sharpen` (bool) | 锐化开关 |
| `sharpen_intensity` | 0.5 | `m_sharpen_intensity` (float, CLAMP 0~1) | 锐化强度 |

### 7.16 嵌套 `cloud` 段 → `RClouds` 类

`render` 段内嵌套的 `cloud { ... }` 子段对应 `RClouds` 类（`sdk/include/ig/render/RClouds.h`），通过 `Render::getClouds()` 访问。

| 字段 | 示例值 | 对应成员 | 含义 |
|------|--------|----------|------|
| `fix_size` | 0 | `m_fix_size` (bool) | 固定尺寸开关 |
| `fix_size_w` | 256 | `m_fix_size_w` (float) | 固定宽度 |
| `fix_size_h` | 256 | `m_fix_size_h` (float) | 固定高度 |
| `taa` | 0 | `m_enable_taa` (bool) | 云 TAA 开关 |
| `use_global_wind` | 1 | `m_use_global_wind` (bool) | 使用全局风 |
| `enable_cloud_shadow` | 1 | `m_enable_cloud_shadow` (bool) | 云阴影开关 |
| `screen_size_scale` | 0.5 | `m_screen_size_scale` (float) | 屏幕尺寸缩放 |
| `wind_direction` | 1,0,0 | `m_wind_direction` (vec3) | 风向 |
| `anim_direction` | 0,0,1 | `m_anim_direction` (vec3) | 动画方向 |
| `wind_scale` | 100 | `m_wind_scale` (float) | 风缩放 |
| `anim_scale` | 0.05 | `m_anim_scale` (float) | 动画缩放 |
| `depth_test_threshold` | 200 | `m_depth_test_threshold` (float, MIN 0) | 深度测试阈值 |

`RClouds` 另有 `m_type_config` (Package) / `m_type_config_path` (jString) 用于云类型配置（对应 `data/core/config/cloud_type.cfg`），以及内部 SSBO `m_sb` 用于 GPU 端云层数据。

---

## 8. 结论

引擎的 Light 体系采用 **基类 `Light` + 派生类特化** 的设计：

- 通用属性（颜色、衰减、阴影、掩码）由 `Light` 统一管理；
- `LightWorld` 在此基础上新增 `usage`（身份）与 `scattering`（散射开关），是太阳/月亮/全局光的载体；
- 天空背景渲染由 **`LightWorld::m_scattering == SCATTERING_GLOBAL`** 触发，配合 `render` 段的 `scattering_*` 参数与 `atmosphere.mtl` 预计算 LUT 完成；
- `usage` 仅用于让渲染器识别"哪个 LightWorld 是太阳"，其方向作为散射 shader 的 `sun_direction`；
- 修复代码通过仅切换 `scattering` 而不重置 `usage`/`enabled`，验证了这一职责划分。

因此，当太阳光节点本身在 `.world` 中已正确配置（`usage=1, scattering=1, enabled=1`），应用代码只需在红外/可见光模式间切换 `setScattering()` 即可控制天空背景的渲染，无需重复设置身份与可见性。
