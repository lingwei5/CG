# Blender 实现细节总结

本章深入 Blender 4.x 的内部实现架构，涵盖代码组织、核心数据结构、依赖图、渲染管线、Python 集成和关键子系统。所有源码引用路径基于 `D:\mlw\code\blender`。

参考：
- [Blender Developer Documentation](https://developer.blender.org/docs/)
- [Blender Source Code Structure](https://wiki.blender.org/wiki/Source/File_Structure)
- [Blender Architecture (Code Structure)](https://wiki.blender.org/wiki/Source/Architecture)

## 1. 整体架构概览

### 1.1 代码组织顶层结构

| 目录 | 作用 |
|------|------|
| `source/blender/` | Blender 主程序代码（核心、编辑器、渲染、UI） |
| `intern/` | 第三方/自研的内部库（cycles、ghost、eigen、guardedalloc 等） |
| `lib/` | 第三方库（Linux/Windows 平台抽象层） |
| `scripts/` | Python 脚本（启动、扩展、操作符定义） |
| `release/` | 发布数据（图标、字体、主题） |
| `tests/` | 单元测试和集成测试 |
| `doc/` | 官方文档源（API 参考、手册） |
| `build_files/` | CMake 构建配置 |

### 1.2 源码目录详细结构（`source/blender/`）

| 子目录 | 核心职责 |
|--------|----------|
| `blenkernel/` | **BKE**（Blender KErnel）— 核心数据结构与无 UI 业务逻辑（~1500 个 .hh/.cc） |
| `blenlib/` | **BLI**（Blender LIbrary）— 通用工具库（容器、字符串、数学、文件） |
| `blenloader/` | **读写 .blend 文件**（序列化/反序列化） |
| `blenloader_core/` | 文件 I/O 的核心层 |
| `makesdna/` | **SDNA**（Structure DNA）— 序列化数据结构定义（DNA_*_types.h） |
| `makesrna/` | **RNA**（Ranged Necessary API）— 运行时 API/属性系统 |
| `blentranslation/` | 多语言/翻译支持 |
| `bmesh/` | **BMesh** — 网格数据结构（边、面、顶点的双向链表） |
| `depsgraph/` | **依赖图系统** — 自动计算脏标记和更新顺序 |
| `draw/` | **视口渲染**（OpenGL/Vulkan/Metal 抽象层） |
| `render/` | 渲染器主入口（hydra、RenderEngine 抽象） |
| `compositor/` | 合成器节点实现 |
| `sequencer/` | 视频序列编辑器 |
| `modifiers/` | 修改器系统（吸积、阵列、布尔等） |
| `nodes/` | 节点系统（着色、合成、几何节点的基类） |
| `windowmanager/` | 窗口管理、事件循环、UI 状态机 |
| `editors/` | 所有 UI 编辑器（按空间划分：3D 视图、节点、UV 等） |
| `python/` | Python 绑定（`bpy` 模块） |
| `gpu/` | GPU 抽象层 |
| `animrig/` | 动画/绑定系统（Action、Pose、FCurve） |
| `asset_system/` | 资产系统（Asset Library、标记、目录） |
| `geometry/` | 几何处理工具（重网格化、布尔等） |
| `io/` | 导入导出器（OBJ、FBX、USD、glTF、EXR、PNG 等） |
| `simulation/` | 物理模拟（布料、粒子、流体） |
| `imbuf/` | 图像缓冲区（图像读写、颜色管理） |
| `shader_fx/` | 着色器特效（视频编辑用） |
| `freestyle/` | NPR 线描渲染 |

### 1.3 内部库结构（`intern/`）

| 子目录 | 作用 |
|--------|------|
| `cycles/` | **Cycles 渲染器**（GPU/CPU 路径追踪，独立可嵌入） |
| `ghost/` | 跨平台窗口/输入抽象（OpenGL/Vulkan/Metal 后端） |
| `guardedalloc/` | 内存分配追踪（debug 用） |
| `eigen/` | Eigen 线性代数库的副本（不依赖系统） |
| `mikktspace/` | Mikkelsen 切线空间算法（法线贴图必需） |
| `opensubdiv/` | OpenSubdiv 细分曲面 |
| `mantaflow/` | Mantaflow 流体模拟 |
| `openvdb/` | OpenVDB 体素库 |
| `quadriflow/` | Quadriflow 重网格化 |
| `audaspace/` | 音频抽象库 |
| `atomic/` | 原子操作 |
| `memutil/` | 内存工具 |
| `sky/` | 天空/大气散射（Preetham 模型） |
| `clog/` | C 日志库 |
| `slim/` | 几何简化 |

## 2. 核心数据模型：DNA + ID + Main

### 2.1 SDNA（Structure DNA）— 数据序列化层

`source/blender/makesdna/` 是 Blender 的"元数据层"——所有持久化数据结构用 C 结构体定义，且必须**与字段名/类型一一对应**（通过 SDNA 字符串表实现自描述序列化）。

**关键文件**：
- `DNA_ID.h` — ID 基类定义
- `DNA_object_types.h` — Object 数据
- `DNA_mesh_types.h` — Mesh 数据
- `DNA_material_types.h` — Material 数据
- `DNA_scene_types.h` — Scene 数据
- `DNA_listBase.h` — 双向链表（ListBase）
- `DNA_sdna_types.h` — SDNA 自身结构

**SDNA 序列化原理**：
```
.blend 文件 = 文件头 + SDNA 字符串表 + 数据块

数据块 = {
  code: "OB" (Object),  // 4 字符 ID
  struct_name: "Object",  // SDNA 查找
  field_count: N,
  data: N 个字段值
}
```

**为什么这样设计**：
- 跨版本兼容性（旧版读 .blend 时，缺失字段用默认值填充）
- 内存映射效率（结构体直接序列化到磁盘）
- 自描述（不依赖外部 schema）

### 2.2 ID 类层次 — 数据块的基类

所有可被引用、链接、复制的"资产"都继承自 `ID`：

```c
// DNA_ID.h
typedef struct ID {
  void *data;             // 旧系统残留
  ID_Runtime *runtime;    // 运行时数据（C++ 对象）
  struct Library *lib;    // 所属库（链接用）
  struct ID *newid;       // 复制时的新 ID
  struct AssetMetaData *asset_data;  // 资产元数据
  char name[64];          // 数据块名
  int flag;               // 标志位（选中/隐藏/资产）
  int tag;                // 临时标记（处理中/已处理）
  int us;                 // 引用计数
  int icon_id;            // 显示图标
  struct IDProperty *properties;  // 自定义属性
  SessionUID session_uid; // 唯一会话 ID
  // ...预览图、资产引用等
} ID;
```

**ID 子类（按 ID 类别，Blender 4.x 约 50+ 种）**：

| ID 类别 | 数据结构 | 说明 |
|---------|----------|------|
| `OB_OB` | `Object` | 场景对象 |
| `ME_MESH` | `Mesh` | 网格数据 |
| `MA_MATERIAL` | `Material` | 材质 |
| `WO_WORLD` | `World` | 世界环境 |
| `TE_TEXTURE` | `Texture` | 旧版纹理 |
| `IM_IMAGE` | `Image` | 图像数据 |
| `SC_SCENE` | `Scene` | 场景 |
| `OB_LAMP` | `Light` | 灯光 |
| `CA_CAMERA` | `Camera` | 相机 |
| `AR_ARMATURE` | `Armature` | 骨架 |
| `AC_ACTION` | `Action` | 动画动作 |
| `MB_METABALL` | `MetaBall` | 融球 |
| `LT_LATTICE` | `Lattice` | 晶格 |
| `CU_CURVE` | `Curve` | 曲线 |
| `KE_KEY` | `Key` | 形状键 |
| `NT_NODE` | `NodeTree` | 节点树 |
| `LIB_LIBRARY` | `Library` | 库引用 |
| ... | ... | （还有近 30 种） |

**类图（ID 体系）**：
```
            ┌──────────────────┐
            │  ID (基类)       │
            │  ────────────    │
            │  name, flag, us  │
            │  lib, properties │
            └────────┬─────────┘
                     │ (内嵌)
   ┌────────────┬────┴─────┬────────────┐
   ▼            ▼          ▼            ▼
Object      Material      Mesh         Scene
(lib)       (lib)         (lib)        (lib)
   │            │          │            │
   ├ data ──────┼──────────┼────────────┤
   │ (Mesh)     │ (NodeTree)            │
```

### 2.3 Main — 全局数据库

`Main`（`BKE_main.hh`）是整个 .blend 文件的"根容器"——所有 ID 都按类别存储在 `ListBase` 链表中。

**结构定义**（简化）：

```cpp
// BKE_main.hh
struct Main : blender::NonCopyable, blender::NonMovable {
  char filepath[1024];                    // .blend 文件路径
  short versionfile, subversionfile;     // 文件版本
  
  // 50+ 个 ListBase，每个对应一种 ID 类别
  ListBase scenes;
  ListBase objects;
  ListBase meshes;
  ListBase materials;
  ListBase textures;
  ListBase images;
  ListBase collections;
  ListBase node_trees;
  ListBase libraries;        // 链接的外部 .blend
  ListBase actions;
  // ... 约 50+ 个
  
  MainColorspace colorspace;
  MainIDRelations *relations;  // ID 关系图（谁引用谁）
  UniqueName_Map *name_map;    // 全局唯一名管理
};
```

**关键设计**：
- `Main` 自身**不**被序列化（注释："This list of lists is not serialized itself"）
- 反序列化时按字段名+类型从 SDNA 字符串表重建
- 拆分 Main（`split_mains`）：链接库时为每个库文件创建独立 Main

**Main 与关系图**：

```cpp
// 关系图：跟踪 ID 之间的引用（用于依赖图、撤销/重做）
struct MainIDRelations {
  GHash *relations_from_pointers;  // 键: ID 指针 → 值: 引用方+被引用方
  // 标签：DOIT / PROCESSED_TO / PROCESSED_FROM / INPROGRESS_TO / INPROGRESS_FROM
  // 用于循环依赖检测
};
```

## 3. 关键子系统详解

### 3.1 BLI（Blender Library）— 基础工具库

`source/blender/blenlib/` 提供：
- **容器**：`BLI_listbase`, `BLI_vector`, `BLI_set`, `BLI_map`, `BLI_mempool`
- **数学**：`BLI_math_*`（矩阵、向量、四元数）
- **字符串**：`BLI_string_*`（UTF-8 安全）
- **文件**：`BLI_path_*`（跨平台路径）
- **线程**：`BLI_task.*`（任务并行，OpenMP 风格）
- **内存**：`MEM_*`（带调试追踪的分配器）

**示例 — 任务并行**（`blenlib/BLI_task.hh`）：
```cpp
BLI_task_parallel_range(0, n, nullptr, 
  [](void *userdata, int iter) { /* 工作 */ },
  use_threading, grain_size);
```

### 3.2 BKE（Blender Kernel）— 核心业务逻辑

`source/blender/blenkernel/` 是 Blender 的"无头核心"——所有 ID 的创建/销毁/操作函数都在这里。
- 每个 ID 类别有对应的 `BKE_<name>_*` 函数集
- 不依赖 UI，可单独测试
- 包含 **depsgraph**、**scene**、**object**、**mesh** 等子系统

**约定**：
- 文件名以 `BKE_<topic>.hh` / `BKE_<topic>.cc` 组织
- 函数命名 `BKE_<topic>_<action>()`
- 不调用 `WM_` 或 `ED_`（避免反向依赖 UI）

### 3.3 RNA（运行时 API）— 反射/属性系统

`source/blender/makesrna/` 自动生成 Python/C 双语言 API。

**核心思想**：从 C 结构体定义生成 `PropertyGroup` / `Property` 树，使：
- Python 端：`bpy.context.scene.frame_start = 100`
- C 端：`RNA_int_set(&ptr, "frame_start", 100)`
- UI 端：自动生成控件、tooltip、范围限制

**生成流程**：
```
C 结构体（DNA）
   │
   ▼
makesrna 工具（Python 脚本）
   │
   ▼
rna_*.c / rna_*.h（自动生成的反射代码）
   │
   ▼
Python `bpy` 绑定
```

**类图（RNA 简化）**：
```
StructRNA
  ├── PropertyRNA (字段)
  │     ├── IntPropertyRNA
  │     ├── FloatPropertyRNA
  │     ├── StringPropertyRNA
  │     ├── EnumPropertyRNA
  │     ├── PointerPropertyRNA
  │     ├── CollectionPropertyRNA
  │     └── ...
  ├── FunctionRNA (方法)
  └── ... 
```

### 3.4 Python 集成

`source/blender/python/` 实现 `bpy` 模块：

| 子模块 | Python 路径 | 用途 |
|--------|-------------|------|
| `bpy.types` | C/RNA 自动生成 | 所有 Blender 数据类型 |
| `bpy.ops` | 操作符（按钮/菜单/快捷键） | 用户可调用的操作 |
| `bpy.context` | 全局上下文 | 当前场景/对象/模式 |
| `bpy.data` | 全部数据块 | 访问所有 Main 中的 ID |
| `bpy.utils` | 工具 | 注册类等 |
| `bpy.app` | 应用信息 | 版本/构建哈希 |

**Python 调用 C 函数的机制**：
```cpp
// PyTypeObject 注册
PyTypeObject bpy_prop_collection_Type = {
  PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "bpy_prop_collection",
  .tp_methods = bpy_prop_collection_methods,
  .tp_iter = bpy_prop_collection_iter,
};
```

**示例 — 用户脚本如何修改场景**：
```python
import bpy
bpy.context.scene.frame_start = 100  # RNA 调用 → C 函数
```

### 3.5 资产系统（Asset System）

`source/blender/asset_system/` 是 Blender 3.0+ 引入的资产管理系统。

**核心组件**：
- `AssetHandle` — 资产的轻量级句柄（指针+库路径）
- `AssetLibrary` — 资产库（目录 + 索引）
- `AssetMetaData` — 元数据（catalog、tags、author、description、preview）
- `AssetCatalog` / `AssetCatalogTree` — 树形目录结构
- `AssetIndex` — 启动时扫描库生成的索引

**API 关系**：
```cpp
class AssetLibrary {
  AssetIndex *catalog_index;  // 来自 .blend 内部
  AssetIndex *index;          // 来自文件系统库
  Library *linked_library;    // 链接库时使用
};

class AssetRepresentation {
  ID *id;                     // 指向 Main 中的 ID
  AssetMetaData *metadata;    // 资产的元数据
  AssetLibrary *owner_library; // 所属库
};
```

**Main 中 ID 的资产标志位**：
```c
// DNA_ID.h 中的标志
#define ID_FLAG_FAKEUSER  1   // 防止删除
#define ID_FLAG_ASSET     2   // 标记为资产
```

### 3.6 依赖图（Depsgraph）— 增量更新核心

`source/blender/depsgraph/intern/` 是 Blender 性能关键系统：自动跟踪"谁依赖谁"，只重算脏数据。

**核心概念**：
- **ID 节点**：每个 ID 是一个节点
- **操作节点**（Operation）：细粒度依赖（"Mesh 位置需要重算"）
- **关系**：读写关系（"材质修改 → Mesh 重算"）

**类图**：
```
Depsgraph
  └── Node (ID Node / Operation Node)
        ├── ID Node
        │     ├── MeshEvalNode
        │     ├── ObjectEvalNode
        │     ├── MaterialEvalNode
        │     └── ...
        └── Operation Node
              ├── GeometryEvalOp
              ├── ShaderCompileOp
              └── ...
  └── Relation
        ├── OpToOpRelation
        └── IdToIdRelation
```

**关键算法**：
1. **构建**：扫描所有 ID，收集 ID 间引用，构建有向图
2. **脏标记传播**：修改某个 ID 时，沿反向边传播到所有依赖
3. **拓扑排序**：按依赖顺序遍历，更新每个操作节点的结果
4. **循环检测**：使用 `MAINIDRELATIONS_ENTRY_TAGS_INPROGRESS` 标签

**使用场景**：
- 视口渲染（按需更新）
- 烘焙
- 撤销/重做（保存脏状态）
- 物理模拟（时间相关更新）

### 3.7 窗口管理 + UI 系统

`source/blender/windowmanager/intern/`：
- `WM_main()` — 事件循环入口
- `GHOST`（`intern/ghost/`）— 跨平台窗口抽象（OpenGL/Vulkan/Metal）

`source/blender/editors/` 下约 50 个编辑器，每个对应一个 `ED_<editor>_*.cc`。

**空间（Space）类型**：
- `SpaceView3D` — 3D 视口
- `SpaceNode` — 节点编辑器
- `SpaceImage` — UV/图像编辑器
- `SpaceOutliner` — 大纲
- `SpaceFile` — 文件浏览器
- `SpaceConsole` — Python 控制台
- ... 约 20+ 种

**类图（UI 抽象）**：
```
ScrVert / ScrEdge
       │
       ▼
   ARegion
       │ (包含)
       ▼
   Space<EditorType>    (包含 ARegion 列表)
       │
       ▼
     bScreen            (完整的编辑器布局)
       │
       ▼
     WorkSpace          (工作区，主题+布局)
       │
       ▼
     WorkSpaceLayout    (具体布局)
```

### 3.8 渲染管线

**两层架构**：

| 层 | 路径 | 作用 |
|----|------|------|
| **抽象层** | `source/blender/render/intern/` | 渲染器接口（`RenderEngine` 基类） |
| **视口层** | `source/blender/draw/intern/` | 实时视口（GPU） |
| **具体渲染器** | `intern/cycles/` | Cycles（路径追踪） |
| **外部集成** | `source/blender/render/hydra/` | USD Hydra delegate |

**RenderEngine 类图**：
```cpp
class RenderEngine {
  // 抽象接口
  virtual void render(RenderData *rd, RenderLayer *rl) = 0;
  virtual void update(RenderData *rd) = 0;
  virtual bool support_material(Material *mat) = 0;
};

// 派生
class CyclesRenderEngine : public RenderEngine { ... };
class EEVEEEngine : public RenderEngine { ... };
class WorkbenchEngine : public RenderEngine { ... };
class HydraRenderEngine : public RenderEngine { ... };  // USD 委托
```

**视口渲染流程**（Eevee/Workbench）：
```
3D 视口 (DrawManager)
  → Mesh Extractor (draw/intern/mesh_extractors/)
  → GPU Shader (draw/intern/shaders/)
  → GPU Backend (gpu/)
  → GHOST Window
```

**离线渲染流程**（Cycles）：
```
Render Engine
  → Cycles Session (intern/cycles/session/)
    → Scene (intern/cycles/scene/)
      → Integrator (intern/cycles/integrator/)
        → Kernel (intern/cycles/kernel/)  [CPU/GPU]
          → Device (intern/cycles/device/)  [CUDA/OptiX/HIP/Metal/OneAPI]
```

### 3.9 Cycles 渲染器

`intern/cycles/` 是独立可嵌入的路径追踪引擎。

**目录**：

| 子目录 | 作用 |
|--------|------|
| `kernel/` | 着色/路径追踪核心（CUDA/HIP/OptiX/Metal 设备代码） |
| `device/` | 设备抽象（CPU/GPU 后端） |
| `scene/` | 场景图（Blender 数据 → Cycles 内部数据） |
| `integrator/` | 积分器（路径追踪、PT、Volumetric） |
| `bvh/` | 加速结构（BVH 树构建/遍历） |
| `subd/` | 细分曲面 |
| `graph/` | 节点图（着色器编译） |
| `session/` | 渲染会话（任务调度） |
| `app/` | 应用程序集成（Blender 适配层） |
| `hydra/` | USD Hydra 集成 |
| `util/` | 工具（图像、类型、函数） |

**类图**：
```
Session → Scene → Mesh/Object/Light/Material/Shader
                  → Integrator → Film → Device → BVH
```

### 3.10 节点系统

`source/blender/nodes/` 提供跨编辑器共享的节点基础架构。

**类图**：
```
bNodeTree (节点树)
  ├── bNode (节点)
  │     ├── bNodeSocket (输入)
  │     ├── bNodeSocket (输出)
  │     └── IDProperty* (自定义属性)
  └── Links (连接)
```

**编辑器后端**：
- `editor/space_node/` — 着色/合成/几何节点编辑器 UI
- `nodes/shader_nodes/` — 着色器节点（Principled BSDF 等）
- `nodes/composite_nodes/` — 合成器节点
- `nodes/geometry_nodes/` — 几何节点（最新最复杂）
- `nodes/function_nodes/` — 函数节点

**关键设计**：
- 节点是数据（`bNode`）和执行（运行时编译）的分离
- 几何节点通过 Geometry Nodes Virtual Machine 解释执行
- 着色器节点编译为 GLSL/Metal/HLSL/OSL

## 4. 编辑流程典型数据流

### 4.1 用户拖动 3D 视口中的物体

```
1. GHOST 接收鼠标事件
   ↓
2. WM_event_process()  (windowmanager/intern/wm_event_system.cc)
   - 路由到 SpaceView3D 处理
   ↓
3. ED_view3d_*() (editors/space_view3d/view3d_ops.cc)
   - 识别为 Transform Modal 操作
   ↓
4. ED_transform_*() (editors/transform/)
   - 计算新变换矩阵
   - 更新 Object->obmat
   ↓
5. DAG_id_tag_update() (depsgraph/intern/depsgraph.cc)
   - 标记 Object + 依赖它的操作为脏
   ↓
6. 触发视口重绘
   ↓
7. draw_engine_render() (draw/intern/draw_manager.cc)
   - Eevee/Workbench 渲染视口
```

### 4.2 烘焙流程

```
1. 用户点击"烘焙"
   ↓
2. RNA 调用 bpy.ops.object.bake()
   ↓
3. ED_bake_*() (editors/render/bake.cc)
   ↓
4. Cycles Session::bake() (intern/cycles/session/bake.cpp)
   - 设置渲染目标为烘焙目标
   - 调用 render()
   ↓
5. 写入图像文件 (imbuf/)
   - IMB_exr_write() / IMB_png_write()
```

## 5. 关键设计模式与约定

### 5.1 命名约定
- **C 函数**：`BKE_xxx_yyy()` / `ED_xxx_yyy()` / `WM_xxx_yyy()` / `RE_xxx_yyy()`
- **数据结构**：`Main` / `Scene` / `Object` / `bNode`（b 前缀表示 Blender 私有）
- **枚举**：`OB_MESH`, `MA_MATERIAL`, `ID_FLAG_FOO`
- **文件**：`BKE_xxx.hh` / `BKE_xxx.cc`（Blender 4.x 改用 .hh 后缀）

### 5.2 设计模式

| 模式 | 用法 | 位置 |
|------|------|------|
| **Template Method** | `RenderEngine::render()` 调用子类 | `render/intern/render_engine.cc` |
| **Visitor** | `IDWALK_` 遍历 ID 关系 | `blenkernel/BKE_lib_query.hh` |
| **Observer** | RNA property update 通知 | `makesrna/` |
| **Factory** | `BKE_id_new()` / `BKE_id_free()` | `blenkernel/BKE_idtype.hh` |
| **Strategy** | 不同 RenderEngine 切换 | `render/intern/` |
| **MVC** | RNA 反射 + UI 自动生成 | `makesrna/` + `editors/` |
| **State** | bContext 状态机 | `windowmanager/intern/wm_context.cc` |

### 5.3 跨平台抽象
- **窗口**：`intern/ghost/` (GHOST — Generic Handy OpenGL Stub Toolkit)
- **GPU**：`source/blender/gpu/` (OpenGL/Vulkan/Metal 后端)
- **文件路径**：`BLI_path_*`
- **线程**：`BLI_task_*` (跨平台任务并行)

## 6. 性能关键路径

### 6.1 视口性能
- **Mesh 提取器**（`draw/intern/mesh_extractors/`）— 缓存静态几何数据
- **GPU 着色器缓存**（`draw/intern/shaders/`）— 着色器只编译一次
- **依赖图脏标记**（`depsgraph/`）— 增量更新而非全量重算
- **EEVEE**（基于光栅化的实时渲染）— 60 FPS 目标

### 6.2 烘焙性能
- **Cycles GPU**（CUDA/OptiX/HIP/Metal）— 离线/烘焙首选
- **BHV 加速**（`intern/cycles/bvh/`）— O(log n) 射线求交
- **Tile-based 渲染**（`intern/cycles/integrator/`）— 大图分块并行

### 6.3 大场景性能
- **集合**（Collections）— 隔离场景数据
- **LOD**（Level of Detail）— 远处用低模
- **Bounded BBH**（`intern/cycles/bvh/`）— 视锥剔除

## 7. 常见任务的代码定位

| 任务 | 入口文件 |
|------|----------|
| 添加新 ID 类型 | `makesdna/`（DNA）+ `blenkernel/BKE_idtype.hh` + `makesrna/` |
| 添加新操作符 | `editors/<space>/<space>_ops.cc`（Python 也可） |
| 添加新修改器 | `modifiers/` + `modifiers_modifier.c` |
| 添加新节点 | `nodes/<type>_nodes.cc` + `editors/space_node/` |
| 添加新文件 I/O | `io/`（导入器/导出器） |
| 添加新 GPU 后端 | `gpu/`（shader/opengl/、shader/vulkan/、shader/metal/） |
| 修改 UI | `editors/<space>/<space>*.cc` |
| 修改渲染管线 | `intern/cycles/`（核心）或 `render/intern/`（接口） |
| 添加新资产类型 | `asset_system/` + `asset/asset_types.c` |

## 8. 编译与构建

### 8.1 构建系统
- **CMake**（`build_files/`）
- 平台预设：`build_files/build_environment/`
- 第三方库通过 `extern/` 管理

### 8.2 关键编译开关
| 宏 | 作用 |
|----|------|
| `WITH_CYCLES` | 启用 Cycles 渲染器 |
| `WITH_OPENEXR` | 启用 OpenEXR 支持 |
| `WITH_USD` | 启用 USD 集成 |
| `WITH_PYTHON` | 启用 Python 脚本 |
| `WITH_GHOST_X11/WAYLAND/WIN32/COCOA` | 平台窗口 |
| `WITH_GPU_OPENGL/VULKAN/METAL` | GPU 后端 |

### 8.3 模块依赖
```
BKE (核心) ← BLI (工具库)
  ↑
  ├── 编辑器层（依赖 BKE + WM + RNA）
  ├── 渲染层（依赖 BKE + Cycles）
  └── Python 绑定（依赖 BKE + RNA + 全部）
```

## 9. 开发调试技巧

### 9.1 关键调试宏
```cpp
BLI_assert(condition);          // 断言（debug 模式）
BLI_log("info: %d", value);     // 日志
CLOG_INFO(LOG_TAG, "msg %d", v);  // 分类日志
```

### 9.2 常用环境变量
| 变量 | 作用 |
|------|------|
| `BLENDER_USER_SCRIPTS` | 用户脚本路径 |
| `BLENDER_PATH` | Blender 资源路径 |
| `GHOST_DEBUG` | GHOST 调试输出 |
| `CYCLES_DEBUG` | Cycles 调试（设备、内存等） |
| `BLENDER_DEBUG` | 通用调试 |

### 9.3 内存调试
- `MEM_guardedalloc_*`（`intern/guardedalloc/`）— 跟踪分配/泄漏
- `WITH_ASSERT_ABORT` — 断言失败时 abort
- 编译 `WITH_GUARDEDALLOC=ON` — 启用内存追踪

## 10. 与外部系统集成

### 10.1 USD/Hydra 集成
- `source/blender/render/hydra/` — 渲染委托
- `intern/cycles/hydra/` — Cycles 的 USD 集成
- 允许 Blender 作为 USD 场景的查看器

### 10.2 MaterialX
- 通过 Python `bpy` 导出/导入
- 实验性支持（在 `nodes/shader_nodes/` 中）

### 10.3 OpenPBR
- 计划中（Blender 5.x 可能原生支持）
- 目前通过 Principled BSDF 模拟

## 11. Blender 4.x 重大变化

| 变化 | 详情 |
|------|------|
| **C++ 深度整合** | 从 C 转向 C++ 越来越多（`BKE_main.hh` 用 C++ 类继承） |
| **`.hh` 后缀** | 新代码用 `.hh`（C++ 头文件） |
| **deferred shader compilation** | 着色器延迟编译 |
| **Geometry Nodes 增强** | 大量新增节点 |
| **EEVEE Next** | 重写 Eevee（基于光栅化 → 延迟渲染） |
| **资产系统成熟** | 全 UI 集成、Cloud 库支持 |
| **Substance 集成改进** | .sbsar 文件原生加载 |

## 12. 推荐学习资源

### 12.1 必读
- [Blender Wiki - Source/Architecture](https://wiki.blender.org/wiki/Source/Architecture)
- [Blender Wiki - Source/File Structure](https://wiki.blender.org/wiki/Source/File_Structure)
- `source/blender/blenkernel/BKE_main.hh` 注释（"section aboutmain"）

### 12.2 进阶
- [developer.blender.org](https://developer.blender.org/docs/) 开发者文档
- [devtalk.blender.org](https://devtalk.blender.org/) 开发者论坛
- [Blender Source Code Review](https://wiki.blender.org/wiki/Style_Guide/C_Cpp) — 代码风格

### 12.3 实践
- 读 `BKE_idtype.hh` 学习 ID 注册机制
- 读 `BKE_anim_data.hh` 学习属性动画机制
- 读 `nodes/geometry_nodes/` 学习现代节点系统
- 读 `intern/cycles/session/` 学习 Cycles 入口

## 13. 总结

Blender 的代码架构可以概括为：

```
数据层
  ↓ SDNA 序列化
文件层（.blend 二进制 + 字符串表）
  ↓ 加载到
运行时层（Main + ID + RNA）
  ↓ BKE 提供操作
核心服务层（depsgraph、blenkernel、bmesh）
  ↓ ED_ 包装
UI 层（editors/、windowmanager/）
  ↓ bpy 暴露
Python 脚本层
```

**核心优势**：
- 单一代码库支持全流程（建模、动画、渲染、合成）
- 数据驱动（任何改动都通过 RNA 暴露）
- 模块化（Cycles 可独立，材质系统可替换）
- 高性能（depsgraph + GPU 抽象）

**挑战**：
- 50+ ID 类型 + 50+ 编辑器，代码量大
- C/C++ 混合，向 C++ 迁移中
- 跨平台兼容（Win/Mac/Linux + OpenGL/Vulkan/Metal）

理解 Blender 内部架构的**最短路径**：
1. 看 `BKE_main.hh` 了解 Main 是什么
2. 看 `DNA_ID.h` 了解 ID 基类
3. 看 `makesrna/` 一个具体文件了解 RNA 如何生成
4. 看 `depsgraph/intern/depsgraph.cc` 了解脏标记机制
5. 看 `intern/cycles/session/session.cpp` 了解 Cycles 入口
