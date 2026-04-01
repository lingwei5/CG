整个文档都应该看看，只不过重点是uv 渲染 材质 光照 动画以及基础的文件系统
blender manual: https://docs.blender.org/manual/en/latest/index.html 学习

4.0开始rendering有重大更新 新的Principled BSDF shader with coat and sheen layers  


图标是个比较好的提示

Photorealistic Materials and Textures in Blender Cycles - Fourth Edition
The Complete Guide to Blender Graphics
Blender script with python

dream-textures是stable diffusion的blender插件https://github.com/carson-katri/dream-textures

# User Interface
## window系统
![蓝色的TopBar 绿色的workspace 红色的Status Bar](<blender UI 3大部分.png>)  

![TopBar](TopBar.png)  

![workspace](workspace.png)  

![status](status.png) 有一些资源 log 鼠标 键盘状态等的信息

### workspace
1. window系统中最主要的部分就是workspace部分:  
   Workspaces are essentially predefined window layouts. Each Workspace consists of a set of Areas containing Editors, and is geared towards a specific task such as modeling, animating, or scripting.  


2. ![Areas](window中不同的Areas.png)可以认为是editor在窗口的占位符或容器  
   The Blender window is divided into a number of rectangles called Areas. Areas reserve screen space for Editors, such as the 3D Viewport or the Outliner. Each editor offers a specific piece of functionality.

3. ![Regions](editor下的不同Regions.png)

workspace下有多个areas，每个area下有多个editor可切换，每个editor下有多个region，每个region可以有tab/panel等完成特定功能    
每个editor的region主要包括:  
Toolbar Sidebar Headerbar 及 中央的main region

## keymap

## UI Elements
button widget menus input-field

## Tools & Operators
undo redo

## Nodes
blender有很多基于node的编辑器  
包括geometry nodes, shader nodes, texture nodes, composite nodes等

# Editors
![alt text](各种editors.png)
支持整个 3D 创作流程：建模、雕刻、骨骼装配、动画、模拟、实时渲染、合成和运动跟踪，甚至可用作视频编辑及游戏创建, 包括property editor   

每种editor都是针对特定资源的编辑器
workspace是针对某种工作流组合多种编辑器的预定义布局

每个editor的介绍至少都包括:  
1. Toolbar 
2. sidebar
3. headerbar
4. overlay
5. navigation

每个editor下有多种mode，如3d view的select edit等mode, tab可以切换前两种mode ctrl+tab弹出mode选择窗口

overlay:
	模型下的overlay有文字 注解 grid 骨骼 动画等等
	不同的editor有不同的overlay

**Gizmo**:  
Gizmos are graphical representations of tools that allow you to manipulate objects, lights, cameras, and other elements in the 3D Viewport. They are interactive and provide a visual representation of the tool's current state and allow you to manipulate it using the mouse or keyboard.  
嵌入3d场景中的可视化交互工具,主要功能包括变换(旋转 缩放 平移)、调试辅助(显示碰撞体、光源位置、相机位置、视景体等)  

在场景视图（Scene View）中显示为临时的、非游戏运行时的图形，帮助开发者在设计和调试阶段更好地理解对象的位置、方向和交互。这些Gizmos可以是线、点、框、球或其他几何形状，用于表示各种功能，如变换轴、碰撞体、关节、导航网格等。  

the Pivot Point determines the location of the Object Gizmo.

pivot types:
![alt text](<pivot types.png>)

snapping target

## 3D Viewport

### navigation
导航有很多模式
1. 标准模式
2. 还有walk/fly navigation，是第一人称视角，这些模式是暂时的，点击鼠标确认后会退出选中的模式，可以使用键盘操作

小键盘快捷键:
- 2 4 6 8 旋转, ctrl+2 4 6 8平移
- 5切换投影方式
- 0切换相机/上帝视角
- 1 3 5 7切换三视图方向

**标准模式下有很多交互样式**:  
1. orbit:MMB,小键盘2468旋转预定角度
   alt键在orbit下
   - alt键+MMB点击一个点,此点成为pivot点，旋转时围绕此点旋转
   - 按住alt键,拖动MMB，画一条线，旋转时围绕此轴旋转
   - 先拖动MMB，再按住alt键，旋转时围绕此轴旋转并吸附到世界轴
2. pan:shift+MMB拖动，平移
3. zoom:滚轮缩放
4. dolly:shift+ctrl+MMB
5. 句点.:跳到选中物体的视角

### walk/fly navigation
view->navigation->walk/fly navigation:
移动鼠标，或者qwer等键盘移动视角,左键点击确认视角，右键/esc取消视角


### 3d cursor
是空间中一个点,具有位置和旋转,可以用来指定新添加的物体的位置或者手动指定gizmo的位置

shift+RMB点击3d cursor,可以设置3d cursor的位置,或者选中toolbar下的cursor，然后左键

## image editor


## UV editor
UV Editing比layout下的editor功能更丰富

navigation:  
Sync Selection:同步uv和3d view的选中状态  
vertex  
edge  
face  
uv island selection

与object有类似的selection功能

# Scenes & Objects

## Scenes
## Objects
一个或多个Object构成一个Scene，  
object type包括mesh, light, curve, camera, etc，由两部分组成
1. object:Holds information about the position, rotation and size of a particular element
2. objectData
   Holds everything else. For example:
	Meshes:
	Store geometry, material list, vertex groups, etc.

	Cameras:
	Store focal length, depth of field, sensor size, etc.

	Each object has a link to its associated object-data, and a single object-data may be shared by many objects.

object type包括mesh curve surface text volume armature camera lamp speaker

object的origin在平移旋转中很重要 选中物体时会显示原点 

选中对象(橙色) 激活对象(最近一次选中的对象，黄色) ![alt text](Active&SelectedObject.png)  
Object的selection state包括:
1. active
2. selected but not active
3. not linked and not selected
4. linked
5. selected,linked, but not active

a:全选所有object  
alt-a:全不选  
ctrl-i:反选  
b:box selection  
还有从菜单栏打开的选择菜单功能  

### Editing
这是物体编辑的重点内容https://docs.blender.org/manual/en/latest/scene_layout/object/editing/index.html

## Collections
把objects组织起来，方便管理

## View Layers
方便渲染，可以设置哪些object被渲染，哪些被忽略

# Modeling
blender里有四种模型表示方式
1. mesh:explicit defined by vertices
2. curve:explicit defined by control points 1d u坐标，nurbs 或者bezier
3. surface:explicit defined by control points 2d u,v坐标，nurbs 或者bezier
4. metaball:implicit defined by formulas

## Meshes
### Tools
### Selecting
### Editing
### UVs
展uv的流程如下
1. Mark Seams if necessary. See more about marking seams.

2. Select mesh faces in the 3D Viewport.

3. Select a UV mapping method from the UV ‣ Unwrap menu or the UV menu in the 3D Viewport.

4. Adjust the unwrap settings in the Adjust Last Operation panel.

5. Add a test image to see if there will be any distortion. See Applying Images to UVs.

6. Adjust UVs in the UV editor. See Editing UVs.


uv editing:选择seam，进行unwrap(此时必须a或l，选中要展开的物体，才能看见mesh展开的情况) 
Texture Painting:
Shading: 在shader编辑器里添加texture，需要选中的object本身有material，material里添加texture
要在3d viewport里直接显示预览效果，需要选中header中的viewport shading为Material Preview

## Curves
## Surfaces
## Metaballs
## Texts
## Point Clouds
## Volume
## Empties
## Modifiers
## Geometry Nodes



# Sculpting & Painting

## Texture Painting
就是绘制纹理，可以绘制在模型上，也可以绘制在uv上，可以同步预览
分左右窗口，左边是image editor,右边是3d view
image editor有view paint mask等mode
3d view有texture paint sculpt edit等mode，默认是texture paint模式

具体绘制时，颜色得选好，有时有bug，没选择颜色(黑色，啥也看不见，颜色&second color)


# Grease Pencil
油画笔

# Animation & Rigging
动画是使物体随着时间移动或者改变形状
动画有多种形式
1. 物体作为一个整体进行移动(改变位置，旋转，缩放等)
2. 变形:顶点或控制点动画
3. 继承动画

骨骼编辑模式 E键进入骨骼挤出模式 移动鼠标后点击退出挤出模式
1. 创建骨架 armature,可以修改骨架的属性 形状 父子关系 挤出方向
2. 多个骨架可以连接起来


rigging插件有预设骨架 humuan basic animal

# Physics

# Rendering

纹理烘焙：离线提前制作好一些asset，在引擎里使用以提高效果效率，如高模法线烘焙贴到低模
blender里烘焙的流程如下:
选中需要进行烘焙的object，选中烘焙结果的导出目标(image texture node，不需要连接到任何节点，但需要有一张link的bitmap或生成的image,模型已经展uv到这张bitmap上)，选中烘焙类型(漫反射，法线，粗糙度，金属度等)点击bake
Property Editor里的render属性下有bake功能，需要选择引擎 烘焙类型 观察位置等
PBR贴图是实现真实感材质的关键，通常包括以下几种贴图：

1.** 反照率（Albedo）贴图 **：记录物体的基础颜色，不包含光照和阴影信息。在Blender中，可通过烘焙"漫反射"类型并去除光照影响得到。

2.** 法线（Normal）贴图 **：模拟物体表面的凹凸细节，使低模呈现高模的立体感。烘焙"法线"类型时，注意选择正确的空间（通常为" tangent "空间）。

3.** 粗糙度（Roughness）贴图 **：控制物体表面的光滑程度，影响高光的大小和模糊程度。可通过烘焙高模的细节或手动绘制得到。

4.** 金属度（Metallic）贴图 **：区分物体表面的金属和非金属区域，金属区域反射环境，非金属区域反射高光。

5.** 环境光遮蔽（AO）贴图 **：模拟物体表面因自身遮挡产生的阴影，增强细节的层次感。

这些贴图可以通过Blender的节点编辑器进行组合，创建PBR材质。例如，将法线贴图连接到Principled BSDF节点的"法线"输入，粗糙度和金属度贴图分别连接到对应的输入，即可实现基于物理的真实渲染效果。

Blender的PBR材质节点设置可参考 scripts/addons_core/io_scene_gltf2/blender/imp/pbrMetallicRoughness.py 中的PBR材质导入代码。

Open Shading Language

烘焙单个物体 多个物体 场景的具体操作都不太一样

## 3个引擎
3个引擎Cycles, Eevee, Workbench

EEVEE is a physically based realtime renderer. based on rasterization

Cycles is a physically based path tracer. based on path tracer

Workbench is designed for layout, modeling and previews.

每个引擎有自己的渲染设置，有时间了可以看看了解内部实现以及一些概念

## Cameras
## Light
## Material

## Shader Nodes
Materials, lights and backgrounds are all defined using a network of shading nodes. These nodes output values, vectors, colors and shaders

color model:
	RGB:红绿蓝
	HSV:色相饱和度明度
	HSL:色相亮度饱和度



### Input
### Output
AOV Output Node:any output variables
Material Output Node:材质表面输出
Light Output Node:光源
World Output Node:世界
### Shader
各种常见BSDF shader![alt text](BSDFs.png)
### Texture
各种常见纹理![alt text](常见纹理.png)
### Color
![alt text](颜色转换的一些shader.png)
### Vector
![alt text](法线贴图等非颜色vector的shader.png)
### Converter
![alt text](mix-math等一些node之间的转换shader.png) 多通道非颜色属性的分离、合并的转换等channel package
### Scripte Node

## Color Management
OpenColorIO用于管理颜色，包括颜色空间转换，颜色校正等
![alt text](颜色管理配置.png)

1. 显示设备
   1. sRGB: Used by most displays.
   2. Display P3: Used by most Apple devices.
   3. Rec. 1886: Used by many older TVs.
   4. Rec. 2020: Used for newer wide gamut HDR displays.
2. view transform
3. exposure 曝光，控制亮度 ![alt text](曝光作为指数控制亮度.png)
4. gamma校正
5. sequencer

## Freestyle
## Layers & Passes
## Render Output


~~# Compositing~~

# Motion Tracking & Masking
~~# Video Editing~~
# Assets, Filse & Data System
.blend文件包含一个database，这个database包含所有的scenes，objects，meshes，textures等等
一个.blend文件可以包含多个scenes，每个scene可以包含多个objects，每个object可以包含多个materials，每个material可以包含多个textures

## Data-Blocks
主要是在outline编辑器里使用
blend项目的基础单位是data-block,data-block可以是meshes, objects, materials, textures, node trees, scenes, texts, brushes, and even Workspaces.  
data-block是各种不同数据的通用抽象:  
1. 是.blender文件的主要内容
2. 可以相互引用，用于复用、实例化
3. 指定类型的数据，名字唯一
4. 可以增删改查
5. 不同文件之间可以链接
6. 可以有自己的动画数据
7. 可以有自定义属性


![alt text](<data-blocks types and icon.png>)

删除data-block: 
unlink:当前数据不再被某个用户使用，引用计数-1  
材质右侧的x进行unlink
shift+LMB+x:所有用户都不在使用此data-block,引用计数置零，删除data-block

~~# Add-ons~~  
~~# Advanced~~  
~~# Troubleshooting~~  
# Glossary
https://docs.blender.org/manual/en/latest/glossary/index.html# blender及图形学术语


view layer

~~先把各种编辑器看完 走马灯看完了~~

shading nodes
geometry nodes


texture paint
材质/shading:所有三维软件的材质系统大致可以概括为两类，图层堆栈型和节点编辑型
animation
vfx特效
rendering

blender 3渲2 用3d模型渲染2d手绘般的效果 npr非真实感渲染的一种风格，又叫伪3d 2.5d


# shortcut
在 Edit->Preferences->Keymap里有各种快捷键
1. 视角控制：
   1. 鼠标中键按住旋转
   2. shift+M 平移
   3. 滚轮缩放
2. 视图切换
   1. 小键盘1正视图 3右视图 7俯视图，ctrl+是对面视图
   2. 9翻转当前视图
   3. 0切换摄像机视角
   4. 5切换正交 透视
   5. 2 4 6 8前后左右微调角度
   6. + - 缩放微调

3. 物体控制
先选中物体,小键盘的.切换物体
	G:按住G，移动物体，GXYZ分别代表x,y,z轴移动，G+中键坐标轴平移
	R:代表旋转，
	S:代表缩放 

新建物体 shift A:add model,在cursor当前所在位置添加模型
复制物体 shift D:复制+移动
删除物体 x 或delete

H:隐藏 alt+H shift+H

n:切换侧边栏显示

tab:切换模式 在最前面的两种模式间切换 编辑模式，物体模式，编辑模式，雕刻模式，顶点模式，权重模式，粒子模式，曲线模式，曲面模式，metaball模式，文本模式，点云模式，体积模式，空物体模式，修改器模式，几何节点模式

ctrl+tab:切换模式 调出模式列表进行选中切换

alt+某快捷键，撤销某种

select选择工具:框选 套索 a全选 c刷选，shift加选或减选

模型编辑模式下，可以添加法线显示的overlay


# blender的插件
各个小版本之间的插件安装方式都不一样  
4.5.3主要的安装方式有:  
1. edit->preferences->addons,可以选择内置插件,勾选激活
2. edit->preferences->addons->install from file,从硬盘选择插件安装,插件主要是压缩包或.py文件
3. 拖拽压缩包安装

安装失败的原因:  
1. 当您打算下载它时，插件 .py 文件会在浏览器中显示为代码。
2. 插件以 .zip 文件形式下载，但本应以 .py 文件形式安装
3. 一个压缩得很深的插件 .zip。
4. 一个压缩在 .zip 内的插件。

插件安装的位置:
第三方插件，打开插件能看见文件位置 内置的没有提示应该是在blender安装目录下4.5\scripts\addons_core
https://github.com/matyalatte/Blender-DDS-Addon

# uv展开
https://www.bilibili.com/video/BV114hgzYETE?vd_source=ffd47f490f976be9dd70c839d34b8fdc&spm_id_from=333.788.videopod.sections


# TODO
- [x] 导航时鼠标操作及小键盘快捷键
- [x] 3d视图快捷键
- [x] . gizmo center, pivot, origin, active object, select object
- [] asset datablock
- [] uv editor
- [] texture node
- [] shader node