# Blender Python 脚本编程

本章系统梳理 Blender Python API（`bpy`）的核心模块、数据模型与编程范式。所有内容基于 Blender 4.x，源码参考 `D:\mlw\code\blender`。

参考：
- [Blender Python API](https://docs.blender.org/api/4.5/index.html)
- [Blender Developer Documentation](https://developer.blender.org/docs/)
- [Quickstart: Introduction to Python Scripting](https://docs.blender.org/api/4.5/info_quickstart.html)

---

## 1. Application Module（应用模块）

`bpy` 顶层由若干子模块组成，每个模块承担不同职责。理解模块边界是写脚本的第一步。

### 1.1 模块总览

| 模块 | 作用 | 典型场景 | 是否依赖上下文 |
|------|------|---------|--------------|
| `bpy.app` | Blender 应用本身的只读信息（版本、构建、事件回调） | 版本判断、启动/退出钩子 | 否 |
| `bpy.context` | **当前活动状态**（活动对象、活动场景、选中集、编辑器模式） | 查询"用户当前在做什么" | **是**（强依赖） |
| `bpy.data` | **文档级数据池**（所有 .blend 文件内的数据块） | 按名称/UUID 读写对象、材质、图像 | 否 |
| `bpy.ops` | **操作符调用**（对应菜单/按钮的可执行动作） | 导入导出、烘焙、添加对象、变换 | **是**（需正确的 area/region/active） |
| `bpy.props` | 自定义属性类型（`StringProperty`/`FloatProperty` 等） | 定义 Operator/Panel 的输入参数、自定义 ID 属性 | 否 |
| `bpy.types` | 所有 RNA 类型类（`Object`、`Material`、`NodeTree` 等） | 注册自定义 Operator/Panel/Node、查询类型元信息 | 否 |
| `bpy.utils` | 工具函数（注册/注销类、资源路径、预览图标） | 插件注册、资源定位 | 否 |
| `bpy.path` | 路径处理（相对/绝对路径转换、路径分解） | 文件 I/O | 否 |
| `bpy.msgbus` | 消息总线（订阅属性变更） | 响应式监听某属性变化 | 否 |
| `bpy.app.handlers` | 事件处理器（保存前/后、渲染前/后、帧变更） | 自动化流水线钩子 | 否（但回调内 context 有效） |
| `bpy.app.timers` | 定时器（延迟执行、循环执行） | 后台轮询、异步任务 | 是（回调内 context 有效） |

### 1.2 三大数据入口对比

脚本 99% 的工作围绕三个入口：`bpy.context`、`bpy.data`、`bpy.ops`。

| 维度 | `bpy.context` | `bpy.data` | `bpy.ops` |
|------|---------------|------------|-----------|
| **本质** | 视图层当前状态的快照 | .blend 文件的数据池 | 命令式动作调用 |
| **数据范围** | 当前 scene + 当前选中 + 当前编辑器焦点 | 所有打开的 .blend 数据块（全部 scene、全部对象） | 受 context 限制的操作集合 |
| **修改持久化** | 改的是 `bpy.data` 的引用，保存即持久 | 改即持久（保存 .blend 后） | 受 context 限制 |
| **依赖上下文** | **强依赖**：不同编辑器下 `context` 字段不同 | **不依赖**：无头模式也能完整访问 | **强依赖**：area/region/active 必须匹配 |
| **无头模式可用性** | 受限（部分字段为 None） | **完全可用** | 受限（部分 operator 需 GUI 上下文） |
| **典型代码** | `obj = bpy.context.active_object` | `obj = bpy.data.objects["Cube"]` | `bpy.ops.mesh.primitive_cube_add()` |

### 1.3 模块协作模式

#### 模式 A：查询 → 修改 → 刷新（最常见）

```python
import bpy

# 1. 通过 context 或 data 查询目标
obj = bpy.context.active_object          # 当前激活对象
mat = bpy.data.materials["MyMat"]        # 直接按名取数据块

# 2. 修改属性
obj.location = (1.0, 2.0, 3.0)
mat.use_nodes = True

# 3. 触发依赖图刷新（修改 mesh/材质节点后必需）
obj.update_tag()
bpy.context.view_layer.update()
```

#### 模式 B：调用 Operator（需要正确上下文）

```python
import bpy

# 设置正确的上下文：选中对象、激活对象
bpy.ops.object.select_all(action='DESELECT')
obj = bpy.data.objects["Cube"]
obj.select_set(True)
bpy.context.view_layer.objects.active = obj

# 调用 operator（依赖 active object 上下文）
bpy.ops.object.shade_smooth()
```

#### 模式 C：无头模式批量处理（无 GUI）

```python
import bpy

# 无头模式下 context 字段受限，优先用 bpy.data
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        # 直接通过 data 访问，不需要选中
        for poly in obj.data.polygons:
            poly.use_smooth = True

# 保存修改
bpy.ops.wm.save_as_mainfile(filepath="output.blend")
```

#### 模式 D：事件驱动（handlers + msgbus）

```python
import bpy

# handler: 保存前自动清理
@bpy.app.handlers.persistent
def cleanup_before_save(scene):
    print(f"Saving scene: {scene.name}")

bpy.app.handlers.save_pre.append(cleanup_before_save)

# msgbus: 监听某对象 location 变化
subscribe_to = bpy.types.Object.location
bpy.msgbus.subscribe_rna(
    key=(bpy.data.objects["Cube"], "location", 0),  # 监听 X 坐标
    owner=object(),
    args=("Cube X changed",),
    notify=lambda msg: print(msg),
)
```

### 1.4 关键原则

1. **`bpy.ops` 是最后选择**：尽量用 `bpy.data` 直接修改，operator 慢且依赖上下文。
2. **无头模式优先 `bpy.data`**：`context` 在无头下部分字段为 None。
3. **修改 mesh/节点后必须刷新**：调用 `update_tag()` + `view_layer.update()`，否则依赖图不更新。
4. **`bpy.ops` 需正确的 area/region**：在无头或非 3D Viewport 上下文下调用 `bpy.ops.object.xxx` 可能失败，需用 `bpy.context.temp_override` 切换上下文。

---

## 2. ID Data（ID 数据块）

### 2.1 什么是 ID Data

**ID Data** 是 Blender 中所有**可独立存在的、可被引用的、可被保存到 .blend 文件**的数据块的基类。它们都继承自 `bpy.types.ID`，具有以下共同特征：

| 特征 | 说明 |
|------|------|
| **`name`** | 唯一标识符（在同类数据池内唯一） |
| **`users`** | 引用计数（为 0 时可被清理） |
| **`library`** | 所属链接库（None = 本地，否则为外部 .blend 链接） |
| **`tag`** | 通用标记位（用于批量操作时的临时标记） |
| **`is_embedded_data`** | 是否为附属数据（如节点树属主是 Material，自身不能独立存在） |
| **`asset_data`** | 资产元数据（标记为资产后才有） |

### 2.2 ID 数据类型一览

所有继承自 `bpy.types.ID` 的类型都在 `bpy.data` 下有对应集合：

| ID 类型 | `bpy.data` 集合 | 典型形态 | 是否可独立 |
|---------|---------------|---------|----------|
| `Object` | `bpy.data.objects` | 场景中的物体（含变换、关联 mesh/材质槽） | 是 |
| `Mesh` | `bpy.data.meshes` | 几何数据（顶点、面、UV、属性） | 是（但通常被 Object 引用） |
| `Material` | `bpy.data.materials` | 材质定义（含节点树） | 是 |
| `Image` | `bpy.data.images` | 图像数据（含像素缓冲、文件路径） | 是 |
| `Texture` | `bpy.data.textures` | 旧式纹理（非节点纹理） | 是 |
| `Light` | `bpy.data.lights` | 灯光数据 | 是 |
| `Camera` | `bpy.data.cameras` | 相机参数 | 是 |
| `Curve` | `bpy.data.curves` | 曲线/文本几何 | 是 |
| `NodeTree` | `bpy.data.node_groups` | 节点树（Shader/Geometry/Composite） | 部分（Shader 节点树是 Material 的附属） |
| `Collection` | `bpy.data.collections` | 对象集合 | 是 |
| `Scene` | `bpy.data.scenes` | 场景 | 是 |
| `World` | `bpy.data.worlds` | 世界环境 | 是 |
| `Action` | `bpy.data.actions` | 动画曲线 | 是 |
| `Armature` | `bpy.data.armatures` | 骨骼 | 是 |
| `MeshCache` | `bpy.data.mesh_cache_files` | 网格缓存文件 | 是 |
| `Volume` | `bpy.data.volumes` | 体素数据 | 是 |
| `Screen` | `bpy.data.screens` | 屏幕布局 | 是 |
| `Window` | `bpy.data.windows` | 窗口 | 是（运行时） |
| `Workspace` | `bpy.data.workspaces` | 工作区 | 是 |
| `Brush` | `bpy.data.brushes` | 笔刷 | 是 |
| `Palette` | `bpy.data.palettes` | 调色板 | 是 |
| `Speaker` | `bpy.data.speakers` | 音源 | 是 |
| `Sound` | `bpy.data.sounds` | 音频文件 | 是 |
| `MovieClip` | `bpy.data.movieclips` | 视频跟踪片段 | 是 |
| `Mask` | `bpy.data.masks` | 遮罩 | 是 |
| `Text` | `bpy.data.texts` | 文本数据块（脚本编辑器内容） | 是 |
| `CacheFile` | `bpy.data.cache_files` | Alembic/USD 缓存 | 是 |
| `PaintCurve` | `bpy.data.paint_curves` | 绘制曲线 | 是 |
| `FreestyleLineStyle` | `bpy.data.linestyles` | Freestyle 线条样式 | 是 |

### 2.3 主从关系（Owner vs Embedded）

部分 ID 数据是**附属的**（`is_embedded_data=True`），不能脱离主数据独立存在：

| 主数据 | 附属 ID | 关系 |
|--------|--------|------|
| `Material` | `ShaderNodeTree`（`node_tree`） | 材质删除时节点树跟着删 |
| `Light` | `ShaderNodeTree`（`node_tree`） | 同上 |
| `World` | `ShaderNodeTree`（`node_tree`） | 同上 |
| `Object` | `Mesh` / `Curve` / `Light` / `Camera` | 通过 `data` 字段关联，但**不是附属**（可独立存在） |
| `Object` | `ParticleSettings` | 粒子系统的设置 |

**关键区别**：
- `Material.node_tree` 是**附属**：不能脱离 Material 单独存在，删除 Material 自动删除节点树。
- `Object.data`（指向 Mesh）是**引用**：Mesh 可被多个 Object 共享，删除 Object 不会自动删 Mesh（除非 users 减到 0）。

### 2.4 引用计数与孤儿数据

每个 ID 有 `users` 字段：

```python
mesh = bpy.data.meshes["Cube"]
print(mesh.users)  # 引用数

# 删除 Object 后，Mesh 的 users 减 1
bpy.data.objects.remove(some_obj_using_mesh)
print(mesh.users)  # 如果降到 0，Mesh 成为孤儿

# 清理所有孤儿数据块
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
# 或用 data API
for block in bpy.data.meshes:
    if block.users == 0:
        bpy.data.meshes.remove(block)
```

### 2.5 ID 的 UUID 与重命名

Blender 4.x 引入 `session_uid`（会话内唯一整数 ID，重启后变化）和 `uuid`（持久化 UUID，4.3+ 实验性）：

```python
obj = bpy.data.objects["Cube"]
print(obj.session_uid)   # 会话内唯一 ID
print(obj.uuid)          # 持久化 UUID（4.3+）
print(obj.name)          # 名称（可能被自动重命名加 .001 后缀）
```

重命名时 Blender 自动避免重名：

```python
bpy.data.objects["Cube"].name = "Sphere"
# 如果已存在 "Sphere"，自动改为 "Sphere.001"
```

---

## 3. 数据创建、获取、修改

### 3.1 数据创建

#### 方式 A：`bpy.data` 的 `new()` 方法（推荐）

所有 `bpy.data.xxx` 集合都有 `new()` 方法：

```python
import bpy

# 创建对象
obj = bpy.data.objects.new("MyCube", bpy.data.meshes.new("MyCubeMesh"))
bpy.context.collection.objects.link(obj)  # 必须 link 到 collection 才能在场景中显示

# 创建材质
mat = bpy.data.materials.new("MyMat")

# 创建图像
img = bpy.data.images.new("MyImg", width=1024, height=1024, alpha=False, float_buffer=True)

# 创建集合
col = bpy.data.collections.new("MyCollection")
bpy.context.scene.collection.children.link(col)
```

**特点**：
- 不依赖上下文，无头模式可用
- 创建后必须手动 `link` 到 collection（对象）或赋值给引用者（材质赋给 slot）
- 速度快，无副作用

#### 方式 B：`bpy.ops` 操作符（依赖上下文）

```python
import bpy

# 创建图元
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0))
cube = bpy.context.active_object  # operator 会自动激活新对象

# 创建材质（无直接 operator，通常用 bpy.data.materials.new）
# 导入文件
bpy.ops.wm.obj_import(filepath="model.obj")
bpy.ops.wm.open_image(filepath="texture.png")  # 加载图像到图像编辑器
```

**特点**：
- 自动 link 到当前 collection，自动设为 active
- 依赖上下文：无头模式下部分 operator 需 `temp_override` 切换 area
- 慢，会触发完整的事件链路

#### 方式 C：复制现有数据

```python
import bpy

# 复制对象（含 mesh 引用）
src = bpy.data.objects["Cube"]
dup = src.copy()              # 浅拷贝：共享 mesh 引用
dup.data = src.data.copy()    # 深拷贝：复制 mesh 数据
bpy.context.collection.objects.link(dup)

# 复制材质（含节点树）
src_mat = bpy.data.materials["MyMat"]
dup_mat = src_mat.copy()      # 自动复制节点树
```

### 3.2 数据获取

#### 方式 A：按名称获取

```python
import bpy

# 直接按名取，不存在抛出 KeyError
obj = bpy.data.objects["Cube"]
mat = bpy.data.materials["MyMat"]

# 安全获取（避免异常）
obj = bpy.data.objects.get("Cube")  # 不存在返回 None
if obj is not None:
    print(obj.location)
```

#### 方式 B：遍历集合

```python
import bpy

# 遍历所有对象
for obj in bpy.data.objects:
    print(obj.name, obj.type)

# 过滤
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
selected_objs = [o for o in bpy.context.selected_objects]

# 遍历某对象的所有材质
for slot in obj.material_slots:
    mat = slot.material
    if mat:
        print(mat.name)
```

#### 方式 C：通过 context 获取活动对象

```python
import bpy

obj = bpy.context.active_object     # 当前激活对象（最后选中的）
objs = bpy.context.selected_objects # 所有选中对象
scene = bpy.context.scene           # 当前场景
view_layer = bpy.context.view_layer # 当前视图层
```

#### 方式 D：通过引用链获取

```python
import bpy

# Object → Mesh
mesh = obj.data

# Mesh → 关联的所有 Object（反向查询）
users = [o for o in bpy.data.objects if o.data == mesh]

# Object → Material
for slot in obj.material_slots:
    mat = slot.material
    # Material → NodeTree
    if mat.use_nodes:
        tree = mat.node_tree
        # NodeTree → Nodes
        for node in tree.nodes:
            print(node.name, node.type)
```

### 3.3 数据修改

#### 方式 A：直接属性赋值

```python
import bpy

obj = bpy.data.objects["Cube"]

# 简单属性
obj.location = (1.0, 2.0, 3.0)
obj.rotation_euler = (0.0, 0.0, 1.5708)  # 弧度
obj.scale = (2.0, 2.0, 2.0)
obj.hide_render = True

# 嵌套属性
obj.data.polygons[0].use_smooth = True
obj.material_slots[0].material = bpy.data.materials["MyMat"]
```

#### 方式 B：批量修改（性能优化）

Blender Python 的属性访问很慢，批量操作时建议用 `foreach_set` / `foreach_get`：

```python
import bpy

mesh = bpy.data.objects["Cube"].data
n = len(mesh.vertices)

# 慢：循环赋值
for v in mesh.vertices:
    v.co.x += 1.0

# 快：批量赋值
import numpy as np
coords = np.empty(n * 3, dtype=np.float32)
mesh.vertices.foreach_get("co", coords)
coords[0::3] += 1.0  # 只改 X
mesh.vertices.foreach_set("co", coords)
mesh.update()
```

#### 方式 C：修改后刷新依赖图

Blender 的依赖图（depsgraph）负责跟踪数据变更。**修改 mesh/材质节点/约束等后，必须显式刷新**：

```python
import bpy

# 修改 mesh
mesh.vertices[0].co.x += 1.0

# 刷新依赖图
mesh.update()                                # 更新 mesh 的派生数据
bpy.data.objects["Cube"].update_tag()        # 标记对象脏
bpy.context.view_layer.update()              # 重新计算依赖图
```

**易错点**：不刷新时，渲染结果可能是旧数据。Cycles/Eevee 会读取 depsgraph 评估后的数据，而非 `bpy.data` 的原始数据。

#### 方式 D：删除数据

```python
import bpy

# 删除对象（自动 unlink，mesh.users 减 1）
obj = bpy.data.objects["Cube"]
bpy.data.objects.remove(obj)

# 删除材质数据块
mat = bpy.data.materials["MyMat"]
bpy.data.materials.remove(mat)

# 用 operator 删除（会同时处理选中状态）
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.ops.object.delete()
```

---

## 4. 核心数据类型

### 4.1 类型关系图

```
Scene
 └─ Collection (递归)
     └─ Object (含 transform)
          ├─ Mesh / Curve / Light / Camera (data 字段)
          │    └─ Material (via material_slots)
          │         └─ ShaderNodeTree (node_tree)
          │              ├─ ShaderNode (各种类型)
          │              └─ NodeLink
          ├─ Modifier
          └─ Constraint
```

### 4.2 Object

`bpy.types.Object` 是场景中所有可见对象的容器。

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | str | 对象名 |
| `type` | enum | `'MESH'`/`'CURVE'`/`'LIGHT'`/`'CAMERA'`/`'EMPTY'`/`'ARMATURE'` 等 |
| `data` | ID | 关联的数据块（Mesh/Curve/Light/Camera） |
| `location` | Vector | 局部位置 |
| `rotation_euler` | Euler | 欧拉旋转 |
| `rotation_quaternion` | Quaternion | 四元数旋转 |
| `scale` | Vector | 缩放 |
| `matrix_world` | Matrix | 世界变换矩阵（只读，由 location/rotation/scale 派生） |
| `matrix_local` | Matrix | 局部变换矩阵 |
| `parent` | Object | 父对象 |
| `matrix_parent_inverse` | Matrix | 父变换的逆，用于修正 parenting 时的位置跳变 |
| `material_slots` | list[MaterialSlot] | 材质槽列表（按索引） |
| `modifiers` | list[Modifier] | 修改器列表 |
| `constraints` | list[Constraint] | 约束列表 |
| `hide_viewport` | bool | 视口中隐藏 |
| `hide_render` | bool | 渲染时隐藏 |
| `select_get()` | bool | 是否选中（用函数而非属性，因为依赖视图层） |
| `select_set(state)` | - | 设置选中状态 |
| `bound_box` | tuple[8][3] | 局部包围盒 8 个角点 |
| `empty_display_type` | enum | 空对象的显示类型 |
| `empty_display_size` | float | 空对象的显示大小 |

**关键概念**：

1. **Object 与 Data 分离**：Object 只存变换和引用，Mesh/Light/Camera 才是真正的数据。多个 Object 可共享同一个 Mesh（如 instancing）。
2. **`matrix_world` 是派生属性**：不能直接赋值，改 `location`/`rotation`/`scale` 后由 depsgraph 计算得到。
3. **`material_slots` 与面索引**：Mesh 的每个面有 `material_index`，指向 `material_slots` 的索引。

```python
import bpy

obj = bpy.data.objects["Cube"]

# 查看每个面用哪个材质
mesh = obj.data
for poly in mesh.polygons[:5]:
    slot = obj.material_slots[poly.material_index]
    mat = slot.material
    print(f"Face {poly.index}: slot={poly.material_index}, mat={mat.name if mat else None}")
```

### 4.3 Mesh

`bpy.types.Mesh` 是几何数据，被 Object 引用。包含顶点、边、面、UV、顶点色、属性等。

| 字段 | 类型 | 说明 |
|------|------|------|
| `vertices` | MeshVertices | 顶点集合 |
| `edges` | MeshEdges | 边集合 |
| `polygons` | MeshPolygons | 面集合（多边形） |
| `loops` | MeshLoops | 循环（每个面的每个顶点是一个 loop） |
| `uv_layers` | UVLoopLayers | UV 层集合 |
| `vertex_colors` | LoopColors | 顶点色（4.x 改为 `color_attributes`） |
| `attributes` | Attributes | 通用属性系统（点/面/边/loop 上的自定义属性） |
| `materials` | list[Material] | 材质引用列表（与 `Object.material_slots` 共享） |
| `shape_keys` | ShapeKey | 形态键 |
| `update()` | - | 重新计算法线、包围盒等派生数据 |

**关键概念**：

1. **Vertex/Edge/Polygon/Loop 的关系**：
   - Vertex：3D 空间中的一个点
   - Edge：连接两个 Vertex 的边
   - Polygon：由多个 Vertex 构成的面（三角形、四边形、N 边形）
   - Loop：面的每个顶点是一个 loop（一个四边形有 4 个 loop）
   - 关系：`polygon.vertices → vertex indices`，`polygon.loop_indices → loop indices`

2. **性能优化**：直接访问 `mesh.vertices[i].co` 很慢，用 `foreach_get`/`foreach_set` 批量操作。

3. **BMesh**：需要做拓扑编辑（删面、合并顶点、布尔）时，用 `bmesh` 模块，它提供双向链表结构，比 `bpy.data.meshes` 适合复杂编辑。

```python
import bpy
import bmesh

# BMesh 编辑示例
obj = bpy.data.objects["Cube"]
bm = bmesh.new()
bm.from_mesh(obj.data)

# 删除选中的面（在 edit mode 下）
for f in bm.faces:
    if f.select:
        bm.faces.remove(f)

bm.to_mesh(obj.data)
bm.free()
obj.data.update()
```

### 4.4 Material

`bpy.types.Material` 是材质定义，包含节点树和渲染参数。

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | str | 材质名 |
| `use_nodes` | bool | 是否启用节点系统 |
| `node_tree` | ShaderNodeTree | 关联的着色器节点树（`use_nodes=True` 时才有） |
| `blend_method` | enum | Eevee 透明混合模式 |
| `shadow_method` | enum | Eevee 阴影方法 |
| `use_backface_culling` | bool | 背面剔除 |
| `preview_render_type` | enum | 预览缩略图类型 |
| `diffuse_color` | Color | 漫反射色（旧式，非节点） |
| `metallic` | float | 金属度（旧式） |
| `roughness` | float | 粗糙度（旧式） |

**关键概念**：

1. **`use_nodes` 必须为 True**：现代 Blender 材质默认用节点系统，`use_nodes=False` 时只能用旧式属性（`diffuse_color` 等）。
2. **节点树是附属数据**：`Material.node_tree` 不能脱离 Material 独立存在。
3. **Material Slot**：`Object.material_slots` 是 Object 上的材质挂载点，每个 slot 引用一个 Material。Mesh 的面通过 `material_index` 指向 slot。

```python
import bpy

# 给对象添加材质
obj = bpy.data.objects["Cube"]
mat = bpy.data.materials.new("MyMat")
mat.use_nodes = True

# 添加到 slot
if obj.data.materials:
    obj.data.materials[0] = mat
else:
    obj.data.materials.append(mat)

# 获取 Principled BSDF 节点
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = (0.8, 0.2, 0.2, 1.0)
```

### 4.5 NodeTree

`bpy.types.NodeTree` 是节点系统的容器，包含节点和连接。

| 字段 | 类型 | 说明 |
|------|------|------|
| `nodes` | Nodes | 节点集合 |
| `links` | NodeLinks | 连接集合 |
| `inputs` | NodeInputs | 组输入（仅 Group 节点树） |
| `outputs` | NodeOutputs | 组输出（仅 Group 节点树） |
| `type` | enum | `'SHADER'`/`'COMPOSITING'`/`'GEOMETRY'`/`'TEXTURE'` |
| `name` | str | 节点树名 |
| `interface` | NodeTreeInterface | 节点组接口（4.x 新） |

**三种节点树**：

| 类型 | 容器 | 创建方式 |
|------|------|---------|
| `SHADER` | Material/Light/World（附属） | `mat.use_nodes = True` 自动创建 |
| `COMPOSITING` | Scene（附属） | `scene.use_nodes = True` 自动创建 |
| `GEOMETRY` | 独立 NodeTree（`bpy.data.node_groups`） | `bpy.data.node_groups.new("Geo", 'GEOMETRY')` |

```python
import bpy

# Shader 节点树（Material 的附属）
mat = bpy.data.materials.new("MyMat")
mat.use_nodes = True  # 自动创建 node_tree
tree = mat.node_tree

# Geometry 节点树（独立 ID）
geo_tree = bpy.data.node_groups.new("MyGeo", type='GEOMETRY')
```

### 4.6 Node

`bpy.types.Node` 是节点树中的单个节点。

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | str | 节点名（可重名，自动加 .001 后缀） |
| `label` | str | 显示标签（不影响功能，可任意重命名） |
| `type` | enum | 节点类型枚举（`'BSDF_PRINCIPLED'`/`'TEX_IMAGE'`/`'OUTPUT_MATERIAL'` 等） |
| `location` | Vector | 节点在编辑器中的位置 |
| `width` | float | 节点宽度 |
| `height` | float | 节点高度 |
| `inputs` | NodeInputs | 输入端口集合 |
| `outputs` | NodeOutputs | 输出端口集合 |
| `parent` | Node | 父节点（Frame 节点用于分组） |
| `select` | bool | 是否选中 |
| `mute` | bool | 是否静音（禁用） |
| `hide` | bool | 是否折叠 |

**创建节点**：

```python
import bpy

tree = bpy.data.materials["MyMat"].node_tree

# 创建节点
bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
output = tree.nodes.new('ShaderNodeOutputMaterial')
tex = tree.nodes.new('ShaderNodeTexImage')

# 删除节点
tree.nodes.remove(bsdf)

# 按类型查找节点
for n in tree.nodes:
    if n.type == 'BSDF_PRINCIPLED':
        print("Found Principled BSDF:", n.name)

# 按名称查找
node = tree.nodes.get("Principled BSDF")
```

**节点类型枚举**：`node.type` 是只读的枚举字符串，常见的：

| `node.type` | 类型含义 |
|------------|---------|
| `'BSDF_PRINCIPLED'` | Principled BSDF |
| `'BSDF_DIFFUSE'` | 漫反射 BSDF |
| `'BSDF_GLOSSY'` | 光泽 BSDF |
| `'EMISSION'` | 发光 |
| `'OUTPUT_MATERIAL'` | 材质输出 |
| `'OUTPUT_WORLD'` | 世界输出 |
| `'TEX_IMAGE'` | 图像纹理 |
| `'TEX_COORD'` | 纹理坐标 |
| `'MAPPING'` | 映射 |
| `'MIX_SHADER'` | 混合着色器 |
| `'ADD_SHADER'` | 相加着色器 |
| `'MIX_RGB'` | 混合颜色（4.x 改名） |
| `'SEPARATE_COLOR'` | 分离颜色 |
| `'COMBINE_COLOR'` | 合并颜色 |
| `'VALUE'` | 数值 |
| `'RGB'` | 颜色 |
| `'VECTOR'` | 向量 |
| `'GROUP'` | 节点组实例 |
| `'FRAME'` | 分组框（无功能） |
| `'REROUTE'` | 重路由 |

**注意**：`node.bl_idname` 是节点的内部 ID（如 `'ShaderNodeBsdfPrincipled'`），`node.type` 是简化枚举（如 `'BSDF_PRINCIPLED'`）。创建时用 `bl_idname`，比较时用 `type`。

### 4.7 NodeSocket（输入/输出端口）

`bpy.types.NodeSocket` 是节点的输入/输出端口。

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | str | 端口名 |
| `type` | enum | `'VALUE'`/`'INT'`/`'BOOLEAN'`/`'VECTOR'`/`'RGBA'`/`'STRING'`/`'SHADER'` |
| `default_value` | varies | 默认值（未连接时的值） |
| `links` | NodeLinks | 连接到此端口的连接（输出端口可有多连接，输入端口最多 1 个） |
| `enabled` | bool | 端口是否启用 |
| `hide` | bool | 是否隐藏 |

**关键概念**：

1. **`default_value` 的类型随 `type` 变化**：
   - `VALUE` → float
   - `INT` → int
   - `BOOLEAN` → bool
   - `VECTOR` → Vector（3 个 float）
   - `RGBA` → Color（4 个 float）
   - `SHADER` → 无 default_value（只能连接）
   - `STRING` → str

2. **按名称访问**：`node.inputs["Base Color"]`、`node.outputs["BSDF"]`。名称区分大小写，不同 Blender 版本可能不同（4.x 的 `Emission Color` 在旧版叫 `Emission`）。

3. **安全访问**：用 `get()` 避免异常：

```python
bsdf = tree.nodes.get("Principled BSDF")
if bsdf:
    # 4.x: Emission Color / Emission Strength
    emit_color = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emit_color:
        emit_color.default_value = (1.0, 0.0, 0.0, 1.0)
```

### 4.8 NodeLink

`bpy.types.NodeLink` 是节点间的连接。

| 字段 | 类型 | 说明 |
|------|------|------|
| `from_node` | Node | 源节点 |
| `from_socket` | NodeSocket | 源输出端口 |
| `to_node` | Node | 目标节点 |
| `to_socket` | NodeSocket | 目标输入端口 |
| `is_valid` | bool | 连接是否有效（类型匹配） |
| `is_muted` | bool | 是否静音 |

**创建/删除连接**：

```python
import bpy

tree = bpy.data.materials["MyMat"].node_tree
nodes = tree.nodes
links = tree.links

tex = nodes.new('ShaderNodeTexImage')
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
output = nodes.new('ShaderNodeOutputMaterial')

# 创建连接
links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

# 删除某个输入端口的所有连接
for l in list(bsdf.inputs["Base Color"].links):
    links.remove(l)

# 删除所有连接
for l in list(links):
    links.remove(l)

# 查询连接
for l in links:
    print(f"{l.from_node.name}.{l.from_socket.name} -> {l.to_node.name}.{l.to_socket.name}")
```

**连接规则**：
- 输入端口最多 1 个连接（新连接会覆盖旧连接）
- 输出端口可连接多个输入
- 类型必须兼容（`SHADER` 只能连 `SHADER`，`RGBA` 可连 `VALUE` 取 R 通道）

### 4.9 Shader 与 ShaderNode

#### 4.9.1 Shader 的概念

**Shader（着色器）** 是描述表面如何与光交互的程序。在 Blender 节点系统中：

- **BSDF（Bidirectional Scattering Distribution Function）**：双向散射分布函数，描述光在表面的散射。节点输出的 `SHADER` 类型就是 BSDF。
  - `ShaderNodeBsdfPrincipled` → Principled BSDF
  - `ShaderNodeBsdfDiffuse` → 漫反射 BSDF
  - `ShaderNodeBsdfGlossy` → 光泽 BSDF
  - `ShaderNodeBsdfGlass` → 玻璃 BSDF
- **BSSRDF**：次表面散射（Principled BSDF 内置）
- **Displacement**：位移（连到 `Output.Material` 的 Displacement 输入）

**Shader 节点的输出类型**：

| 输出类型 | 颜色 | 用途 |
|---------|------|------|
| `SHADER`（BSDF） | 绿色 | 表面光照模型 |
| `RGBA`（Color） | 黄色 | 颜色值 |
| `VALUE`（Float） | 灰色 | 数值 |
| `VECTOR` | 蓝色 | 3D 向量 |

**只有 `SHADER` 类型能连到 `Material Output.Surface`**，其他类型需要先经过 BSDF 节点转换。

#### 4.9.2 ShaderNode 类型分类

| 分类 | 代表节点 | bl_idname |
|------|---------|-----------|
| **BSDF** | Principled BSDF, Diffuse, Glossy, Glass, Transparent | `ShaderNodeBsdfXxx` |
| **Emission** | Emission | `ShaderNodeEmission` |
| **Output** | Material Output, World Output, Light Output | `ShaderNodeOutputXxx` |
| **Texture** | Image Texture, Noise, Voronoi, Musgrave | `ShaderNodeTexXxx` |
| **Input** | Texture Coordinate, UV Map, Attribute, Value, RGB | `ShaderNodeTexXxx` / `ShaderNodeValue` / `ShaderNodeRGB` |
| **Color** | Mix Color, Brightness/Contrast, Hue/Saturation | `ShaderNodeMixRGB` 等 |
| **Vector** | Mapping, Vector Math, Bump, Normal Map | `ShaderNodeVectorXxx` |
| **Converter** | Math, Separate Color, Combine Color, Clamp | `ShaderNodeMath` 等 |
| **Shader Mix** | Mix Shader, Add Shader | `ShaderNodeMixShader` / `ShaderNodeAddShader` |
| **Group** | 自定义节点组 | `ShaderNodeGroup` |
| **Layout** | Frame, Reroute | `NodeFrame` / `NodeReroute` |

#### 4.9.3 完整材质创建示例

```python
import bpy

# 1. 创建材质
mat = bpy.data.materials.new("PBR_Material")
mat.use_nodes = True

# 2. 获取节点树，清空默认节点
tree = mat.node_tree
for n in list(tree.nodes):
    tree.nodes.remove(n)

# 3. 创建节点
tex_coord = tree.nodes.new('ShaderNodeTexCoord')
mapping = tree.nodes.new('ShaderNodeMapping')
albedo_tex = tree.nodes.new('ShaderNodeTexImage')
normal_tex = tree.nodes.new('ShaderNodeTexImage')
normal_map = tree.nodes.new('ShaderNodeNormalMap')
bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
output = tree.nodes.new('ShaderNodeOutputMaterial')

# 4. 配置节点
albedo_tex.image = bpy.data.images.load("albedo.png")
albedo_tex.image.colorspace_settings.name = 'sRGB'
normal_tex.image = bpy.data.images.load("normal.png")
normal_tex.image.colorspace_settings.name = 'Non-Color'
normal_map.inputs["Strength"].default_value = 1.0

# Principled BSDF 参数
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.5

# 5. 连接
links = tree.links
links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])
links.new(mapping.outputs["Vector"], albedo_tex.inputs["Vector"])
links.new(mapping.outputs["Vector"], normal_tex.inputs["Vector"])
links.new(albedo_tex.outputs["Color"], bsdf.inputs["Base Color"])
links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

# 6. 赋给对象
obj = bpy.data.objects["Cube"]
obj.data.materials.append(mat)
```

---

## 5. 编程范式总结

### 5.1 查询优先用 `bpy.data`，操作优先用 `bpy.ops`

| 场景 | 推荐 | 原因 |
|------|------|------|
| 查询数据 | `bpy.data` | 不依赖上下文，无头可用 |
| 创建数据 | `bpy.data.xxx.new()` | 速度快，不依赖上下文 |
| 删除数据 | `bpy.data.xxx.remove()` | 直接 |
| 调用工具（烘焙、导入、变换） | `bpy.ops` | 必须用 operator |
| 批量修改 | `bpy.data` + `foreach_set` | 性能 |

### 5.2 修改后必须刷新

```python
# 修改 mesh / 材质节点 / 修改器后
obj.update_tag()
bpy.context.view_layer.update()
```

### 5.3 无头模式注意

- `bpy.context.scene` / `bpy.context.view_layer` 可用
- `bpy.context.active_object` / `selected_objects` 在 `--background` 下需要手动设置
- `bpy.ops` 部分 operator 需要正确的 area/region，用 `temp_override`：

```python
import bpy

# 在无头模式下调用需要 3D Viewport 上下文的 operator
window = bpy.context.window
screen = window.screen
for area in screen.areas:
    if area.type == 'VIEW_3D':
        for region in area.regions:
            if region.type == 'WINDOW':
                with bpy.context.temp_override(
                    window=window,
                    area=area,
                    region=region,
                ):
                    bpy.ops.object.bake()
                break
```

### 5.4 性能优化

1. **批量操作用 `foreach_get`/`foreach_set`**：避免 Python 循环
2. **避免频繁刷新依赖图**：批量修改后统一刷新一次
3. **用 `bmesh` 做复杂拓扑编辑**：比 `bpy.data.meshes` 的 Python API 快 10 倍以上
4. **缓存引用**：`nodes = tree.nodes; links = tree.links` 比每次 `tree.nodes` 快

### 5.5 调试技巧

```python
import bpy

# 打印对象的所有属性
obj = bpy.data.objects["Cube"]
for attr in dir(obj):
    if not attr.startswith('_'):
        try:
            val = getattr(obj, attr)
            print(f"{attr}: {type(val).__name__} = {val}")
        except:
            print(f"{attr}: <error>")

# 打印节点树结构
def dump_tree(tree, indent=0):
    pad = "  " * indent
    print(f"{pad}NodeTree: {tree.name}")
    for node in tree.nodes:
        print(f"{pad}  Node: {node.name} (type={node.type})")
        for inp in node.inputs:
            print(f"{pad}    Input: {inp.name} (type={inp.type})")
        for out in node.outputs:
            print(f"{pad}    Output: {out.name} (type={out.type})")
    for link in tree.links:
        print(f"{pad}  Link: {link.from_node.name}.{link.from_socket.name} -> {link.to_node.name}.{link.to_socket.name}")

dump_tree(bpy.data.materials["MyMat"].node_tree)
```

---

## 6. 参考资源

- [Blender Python API 4.5](https://docs.blender.org/api/4.5/)
- [Info Quickstart](https://docs.blender.org/api/4.5/info_quickstart.html)
- [API Overview](https://docs.blender.org/api/4.5/info_api_reference.html)
- [Best Practices](https://docs.blender.org/api/4.5/info_best_practice.html)
- [Tips & Tricks](https://docs.blender.org/api/4.5/info_tips_and_tricks.html)
