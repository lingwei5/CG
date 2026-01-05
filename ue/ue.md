Unreal Engine 5.x Documentation

# Basics 基础

## Foundation

### Terminology 术语


https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-4-terminology?application_version=4.27
1. object->actor可以放置在场景world中的object->pawn可以进行控制的actor->character人形pawn
2. content browser里的东西应该都是project的asset，包含![alt text](ue内容浏览器可创建的asset.png)
   1. 基本资产material ，paticle-system， level 以及 blueprint class
   2. 高级资产，如特效 动画 物理 声音 ai等
   3. blueprint class是一种特殊的资产，提供了直观 基于node的编程脚本，用来生成不同的actor以及level event 
   4. level是一组actors(mesh light volume)的组合，进行game所在的虚拟scene称为level,多个level可以组成streaming experience,
3. Component是分为actor或者场景的组件 
4. game default map:初始加载的地图，否则是黑屏
5. editor start map
6. game mode
7. 
   1. tools 完成某项工作，如将actor放置在world中
   2. editor是一组tools的集合
   3. system是更复杂的功能，如blueprint system
8. 从内容浏览器选择ASSET，右键，asset actions进行批量编辑或者detail面板里的matrix property
9. Project， ue工程文件.uproject,包含了硬盘上的一系列文件夹,如Blueprints, Materials等
10. Blueprint 蓝图，完整的游戏脚本系统，通过编辑器基于node 的接口实现游戏逻辑,用来定义OO类或对象
11. Object
12. Class
13. Actor Technically speaking, an Actor is a programming class used within the Unreal Engine to define an object that has 3D position, rotation, and scale data. Think of an Actor as any object that can be placed in your levels.
    Actor Type: 
    1. static mesh
    2. brush
    3. skeletal mesh
    4. camera 
    5. playerstart
    6. triggers
    7. pointlight
    8. spotlight
    9. directionallight
    10. particleemitter
14. xx

### Tools and Editors

Tool:
Editor: a collection of tools to achieve some more complex things
System:a large collection of features that work together to produce some aspect of the game or application,如蓝图系统

1. level editor 关卡编辑器
   gameplay level
   有5种模式，默认是select actor模式，地形编辑 植被编辑 画刷 mesh-painter
2. static mesh editor 
   You can use the Static Mesh Editor to preview the look, collision, and UV mapping, as well as set and manipulate the properties of Static Meshes
3. material editor
   ![alt text](材质编辑器UI.png)
	1 菜单栏
	2 工具栏
	3 视口面板
	4 细节面板
	5 材质图面板
	6 统计信息面板
	7 控制板面板 以分类的形式显示所有材质节点
	材质表达式（Material Expressions） 和 材质函数（Material Functions） 是在虚幻引擎中创建功能齐全材质的基本单位。每个表达式或函数都是材质图表中完全独立的节点。 这些节点对其输入运行HLSL代码的小片段，并输出结果。
4. blueprint编辑器
	修改 编辑blueprint的地方，blueprint是一种可以创建游戏元素(如控制actor或创建event script等)、修改材质、实现其他feature而不需要编写c++代码的特殊资产
5.  physics asset editor
	创建Skeletal Meshes的物理属性
6.  Behavior Tree Editor
	行为树编辑器 通过可视化节点为关卡中的Actor编写脚本的地方，可以为敌人 npc 载具等创建各种行为
7. font editor
8. UMG UI
	
9.  sequence editor 通过tracks轨道实现动画
   1.  Tracks can consist of things like Animations (for animating a character), Transformations (moving things around in the scene), Audio (for including music or sound effects), and so on
   2.  过场动画及动态事件编辑
10. Animation editor
11. Control Rig Editor
12. Sound Cue Editor
13. Media Editor
14. nDisplay 3D Config Editor多屏显示编辑器
15. DMX Library Editor


## content browser
对package file的管理，asset的操作
collection：自定义的asset引用的集合，

## 定制化引擎

## 项目与模板
## 项目设置
## 关卡
## 资产与内容包
## actor与geometry
## 游戏与模拟

# work with content
## Alembic File 导入
## Artist Quick Start
## FBX 内容管线
## 毛发渲染与模拟
## Interchange Framework
## Skeleton Meshes 骨骼mesh
## Static Meshes 静态网格
## Mutable Skeletal Mesh Generation 可变骨骼网格生成
## Datasmith
## glTF
## Universal Scene Description
## LiDAR 点云插件
## Modeling and Geometry Scripting
## Work with Scene Variants
## SpeedTree
## Localization本地化


# build virtual world
# Design Visuals, Rendering, and Graphics
# Create Visual Effects
# Gameplay Tutorials
# Blueprint Visual Scripts
# Programming With C++ 
# Gameplay System 游戏系统
# Mobile Development
# Animating Actors and Objects
# Motion Design 运动设计
# Creating User Interfaces
# Work with Audio
# Work with Media
# Setup Your Production Pipeline
# Test and Optimization
# API



# 快捷键
alt切换窗口一类的操作，如alt1-9分别是不同的光照 线框 shader复杂度 光照复杂度的显示
alt p/s进行游戏/上帝视角观察游戏
alt+L：地形显隐
alt+F：雾显隐
alt+c：碰撞开闭

ctrl是控制actor之类的操作以及复制粘贴啥的
ctrl+g：打组 shift+G取消打组
G上帝视角吧？