# ue蓝图到底是什么？本质是个脚本编程语言，可以用来给游戏关卡中的对象添加脚本化的响应逻辑，但是它本身不是通过写代码实现的，而是基于可视化的节点图连线实现，是吗？
你的理解非常准确，概括得很到位。UE蓝图本质上是虚幻引擎内置的**可视化脚本系统**，你可以把它当作一种面向对象的脚本编程语言，只不过语法不是用文本代码，而是通过**节点**和**连线**来组成逻辑。

为了帮你更彻底地厘清“蓝图到底是什么”，可以从以下几个维度来拆解：

**1. 它的本质确实是“脚本逻辑”而非“底层引擎”**
蓝图的核心作用，就是给关卡中的Actor（对象）、组件或者游戏模式添加交互、响应和状态变化。比如“角色按W键前进”、“敌人碰到玩家扣血”、“打开大门触发动画”，这些都属于**脚本化响应逻辑**。它是驱动游戏玩法的“胶水”。

**2. 可视化节点图的底层仍然是代码**
虽然你不直接写代码，但蓝图背后的运行机制依旧遵循编程原理。每一个节点（比如“Print String”、“Branch”、“Event Tick”）本质上都对应着底层C++函数的封装或蓝图自身的字节码。在编译或运行阶段，引擎会将这些节点图**编译成机器可运行的指令**（在较新版本的引擎中，蓝图甚至可以被“固化（Nativization）”成C++代码来提升性能）。所以，它并不是神秘的“无代码”，而是**“无文本化代码”**。

**3. 可视化连线的本质是“数据流”和“执行流”**
你在蓝图里看到的连线分为两种：
- **白色的执行线**：代表逻辑执行的先后顺序（相当于代码里的“先做A，再做B”）。
- **彩色的数据线**：代表数据的传递（比如把“变量A”的值传入“节点B”的输入端）。

这种节点式的连接方式，直观地展示了程序的控制流（Control Flow），这正是它强大的地方——逻辑的先后顺序一目了然。

**4. 它适用场景的边界**
你说“给游戏关卡中的对象添加脚本化的响应逻辑”，这非常精准。蓝图非常适合**搭建游戏玩法原型（Prototype）**、**编写AI行为树**、**创建UI交互**以及**组合复杂的关卡事件**。

不过，虽然蓝图能实现绝大多数C++能做的基础逻辑，但在处理海量数据的复杂算法（如大规模寻路、复杂物理模拟、资源密集型的数学计算）时，**运行效率通常不如纯C++代码**。因此，顶尖的游戏团队通常会采用“**C++写底层核心框架，蓝图写游戏专属逻辑和关卡事件**”的混合开发模式。

**总结你的描述：**
你的理解是完全正确的。蓝图是**一门可视化的、事件驱动的、面向对象的脚本语言**。它的本质是把程序逻辑做成可视化的节点图，让开发者（特别是偏向策划和关卡设计的开发者）能够在不接触文本代码的情况下，为游戏对象注入复杂的响应行为，极大地降低了游戏逻辑开发的门槛，同时兼顾了强大的功能与极高的开发效率。

# UE 蓝图 Gameplay 框架：一张表看懂 8 个核心类

先给一个总览心智模型，再逐个拆。

```
World（当前关卡世界）
└── GameMode       规则裁判（仅服务器）
└── GameState      全局公告板（全员同步）
    └── PlayerArray[]
        ├── PlayerState（玩家A）  ← 分数/击杀/名字
        ├── PlayerState（玩家B）
        └── ...
└── PlayerController（玩家A的"意志"）
    ├── Possessed Pawn / Character（玩家A的"身体"）
    ├── HUD（2D界面）
    └── CameraManager（视角）
└── Actor（场景里一切可放置实体）
    └── ActorComponent（挂在 Actor 上的能力模块）
```

---

## 一、核心对比表

| 类 | 父类 | 存在端 | 是否复制 | 生命周期 | 负责什么 | 不负责什么 |
|---|---|---|---|---|---|---|
| **Actor** | UObject | 服务端+客户端 | 可选 | 关卡内 | 世界里一切可放置实体的基类 | 单一职责，具体能力交给 Component |
| **ActorComponent** | UObject | 跟随宿主 Actor | 跟随 | 随 Actor | 给 Actor 附加可复用能力（移动、网格、音效、自定义系统） | 不参与世界坐标决策（无 Transform，SceneComponent 除外） |
| **Pawn** | Actor | 服务端+客户端 | 是 | 可被销毁/重生 | 可被 Controller 控制的"身体"，物理表现、碰撞、基础移动接口 | 不处理输入来源（谁在控制它） |
| **Character** | Pawn | 服务端+客户端 | 是 | 可被销毁/重生 | 人形 Pawn：自带 Capsule + CharacterMovementComponent + 骨骼网格，走路/跳/爬 | 不负责"为什么跳"（那是 Controller 的事） |
| **PlayerController** | Controller(Actor) | 拥有者客户端+服务器 | 部分 | 跨 Pawn 存活（死亡/换身不销毁） | 玩家意志：输入、相机、HUD、Possess/UnPossess | 不放需要跨玩家同步的数据；不存玩家分数 |
| **AIController** | Controller(Actor) | 服务端 | 是 | 同 Pawn | AI 的"意志"：行为树、导航、决策 | 物理表现 |
| **PlayerState** | Actor | 服务端+所有客户端 | 是 | 跨 Pawn 存活（重生保留） | 玩家档案：名字、分数、击杀、等级、队伍 | 不放全局数据；不放纯本地私有数据 |
| **GameMode** | Actor(Info) | **仅服务器** | 否 | 当前关卡 | 规则裁判：出生点、胜负条件、生成类、匹配流程 | 不放任何需要客户端看到的数据 |
| **GameState** | Actor(Info) | 服务端+所有客户端 | 是 | 当前关卡 | 全局公告板：比赛阶段、总比分、目标进度、PlayerArray | 不放服务器秘密；不放玩家私有数据 |

---

## 二、逐个拆开讲

### 1. Actor —— 世界里的"万物之基"

- 能被放进关卡、能被 Spawn、能挂组件、能网络复制
- **本身几乎不干具体活**，是个容器 + 生命周期管理器
- 典型：道具、门、子弹、触发器、灯光、相机

> 💡 判断标准：东西要在世界里"存在"，就继承 Actor。

### 2. ActorComponent —— 可复用的"能力插件"

Actor 本身很瘦，真正的能力是组件拼出来的：

```
MyActor
├── SceneComponent        （根，有 Transform）
├── StaticMeshComponent    （看得见）
├── BoxComponent           （碰撞体积）
├── AudioComponent         （听得见）
└── MyCustomComponent      （自定义逻辑）
```

- 组件可以**跨不同类型 Actor 复用**（比如"可互动物品"组件挂在宝箱、门、NPC 上）
- 运行时创建的组件要 `RegisterComponent()` 才会 Tick/渲染
- 典型误区：把本可以复用的逻辑写死在某个 Actor 蓝图里，导致复制粘贴遍地

> 💡 判断标准：这段逻辑可能挂在不同 Actor 上 → 做成 Component。

### 3. Pawn —— "可被附身的壳"

- 特殊的 Actor，设计上就是"能被 Controller 控制"
- 不预设人形，可以是飞船、坦克、棋子、摄像头
- 提供 `PossessedBy()` / `UnPossessed()` 接口

### 4. Character —— "穿了衣服会跑的 Pawn"

Character = Pawn + 三件套默认组件：

```
Character
├── CapsuleComponent        （碰撞胶囊，根组件）
├── SkeletalMeshComponent   （骨骼网格）
└── CharacterMovementComponent  （走/跑/跳/游泳/飞行，带网络平滑）
```

- 自带移动复制、动画接口、蹲伏、攀爬
- 90% 的人形角色直接用它就够了
- 自定义载具、飞行器等非人形移动，反而更适合用 Pawn + 自定义移动组件

> ⚠️ 常见误区：把所有玩家逻辑（血量、背包、技能 CD）都塞进 Character。Character 是"身体"，身体会死、会换，数据应该外移。

### 5. PlayerController —— 玩家的"灵魂"

关键特性：

- **没有物理实体**，不出现在世界里
- **跨 Pawn 存活**：你角色死了、换了身体，Controller 还在
- 负责：
  - 接收键鼠/手柄输入
  - 管理相机（PlayerCameraManager）
  - 管理 HUD/UI 输入模式
  - 决定 Possess 哪个 Pawn
  - 处理暂停菜单、观战、重生流程

```
玩家按 W
  → PlayerController 收到输入
  → 翻译成 "MoveForward"
  → 发给当前 Possessed 的 Character
  → Character 的移动组件真正执行
```

> 💡 判断标准：跟"玩家意图"有关 → Controller；跟"身体动作"有关 → Pawn/Character。

### 6. PlayerState —— 玩家的"数据档案"

- 每个玩家一个，服务端修改，自动同步到所有客户端
- **跨 Pawn 保留**：角色死了重生，击杀数还在
- 适合放：名字、分数、KDA、等级、队伍、是否持旗

```cpp
// 正确
PlayerState->Score += 10;
PlayerState->Kills++;

// 错误：放 Character 上，角色一死数据就没了
Character->Kills++;  // ❌ 重生后归零
```

> ⚠️ 纯本地私有数据（如本地设置、未提交的操作缓存）不适合放这里，因为 PlayerState 对所有人是可见的。

### 7. GameMode —— 只活在服务器的"裁判"

- **客户端根本不存在这个类**，客户端 `GetGameMode()` 永远返回 null
- 负责：
  - 指定默认 Pawn 类、PlayerController 类、PlayerState 类、GameState 类
  - 出生点选择（`ChoosePlayerStart`）
  - 加入/离开处理（`PostLogin`）
  - 胜负判定、比赛阶段切换（`StartMatch` / `EndMatch`）
- 不存任何需要同步给客户端的状态

> ❌ 经典错误：在 GameMode 里放"当前比分"变量，然后客户端想读——读不到。

### 8. GameState —— 全局"公告板"

- 服务端有，复制到所有客户端
- 适合放：
  - 比赛阶段（Waiting / Playing / Ended）
  - 双方总比分
  - 剩余时间
  - 已完成的任务列表
  - `PlayerArray`（所有 PlayerState 的引用）
- 服务器改了，所有人自动看到

---

## 三、多人游戏下的同步边界（最重要）

```
               服务器           客户端A          客户端B
GameMode        ✅ 唯一实例      ❌ 不存在        ❌ 不存在
GameState       ✅ 权威          ✅ 复制只读       ✅ 复制只读
PlayerState     ✅ 权威          ✅ 复制           ✅ 复制
Controller      ✅ + 本地        ✅ 仅自己的       ❌ 别人的看不到
Pawn/Character  ✅ 权威          ✅ 复制表现       ✅ 复制表现
```

**铁律**：

1. 所有权威数据修改**必须在服务器执行**，客户端只读取/请求
2. 要同步的变量必须标 `Replicated` 或 `RepNotify`
3. 客户端别直接改 GameState/PlayerState 核心数据

---

## 四、数据该放哪？决策树

```
这个数据……
├─ 要跨关卡保留？（存档/配置/选择）
│   └─► GameInstance / SaveGame
├─ 只服务当前关卡，是"规则"（谁赢、怎么刷怪）
│   └─► GameMode（仅服务器）
├─ 是当前关卡的"全局状态"（比分/阶段/目标）
│   └─► GameState（同步）
├─ 是"某个玩家"的状态（分数/名字/KDA），要跨死亡保留
│   └─► PlayerState（同步）
├─ 是"玩家意志"（输入/相机/UI/当前控制谁）
│   └─► PlayerController（本地+服务器）
├─ 是"身体当前状态"（位置/速度/当前动画/临时Buff）
│   └─► Pawn / Character
├─ 是可复用能力（移动/碰撞/交互/音效）
│   └─► ActorComponent
└─ 是场景里的一个实体
    └─► Actor
```

---

## 五、一个完整流程：玩家加入到击杀得分

```
1. 客户端连接
   → 服务器 GameMode.PostLogin()
   → 创建 PlayerController + PlayerState（Kills=0, Score=0）

2. 选出生点
   → GameMode.ChoosePlayerStart()
   → Spawn 一个 Character
   → PlayerController.Possess(Character)

3. 玩家按 W
   → PlayerController 收输入
   → Character 移动组件执行位移
   → 位置通过网络复制给其他客户端

4. 击杀敌人
   → 服务器在 PlayerState 上 Kills++
   → GameState 里队伍总分更新
   → 所有客户端 HUD 自动刷新

5. 玩家死亡
   → Character 销毁
   → PlayerController 还在，PlayerState 还在（Kills 保留）
   → 延迟后重新 Spawn 新 Character，再次 Possess
```

---

## 六、常见踩坑清单

| 错误做法 | 正确做法 |
|---|---|
| 把比分放 GameMode | 放 GameState |
| 把 KDA 放 Character | 放 PlayerState |
| 客户端调用 `GetGameMode` | 用 GameState 或让服务器 RPC |
| 把输入逻辑写进 Character | 输入在 PlayerController，Character 只执行 |
| 把可复用能力写死在 Actor 里 | 抽成 ActorComponent |
| 把本地设置（画质/按键）放 PlayerState | 放本地存档或 GameInstance |
| 在 Pawn 里存"这局累计伤害" | Pawn 会重生，存 PlayerState |
| 用 Actor 硬写移动物理 | 用 CharacterMovementComponent 或自定义 MovementComponent |

---

## 七、一句话记忆法

- **Actor/Component**：世界与能力（“有什么”）
- **Pawn/Character**：身体（“能动什么”）
- **Controller**：灵魂与意志（“想做什么”）
- **PlayerState**：档案（“我是谁、我攒了什么”）
- **GameMode**：裁判（“这局怎么玩”）
- **GameState**：记分牌（“现在战况如何”）

**接下来想看哪类落地内容：最小可运行蓝图搭建、C++ 子类化示例，还是多人联机变量同步？**

# TODO
blueprint

node 
eventgraph 蓝图应该是还有一些其他的graph及对应的editor
function call
blueprint class
instance of blueprint
blueprint assets

With Blueprint Classes, you can pair physical components with scripted behavior

蓝图里的变量

事件是跟actor或者其他对象如何绑定的？如何触发的？如何接收响应的?

我看有些变量是可以出现多次的，比如在执行流输入了，又作为条件执行分支，这个变量是怎么知道是一个变量的？name？tag？id？
后边有marcs function的创建的教程
In the Blueprint Editor, you can define Components, perform setup operations, respond to events, organize and modularize operations, define properties, and more. Visuals and functionality you add to the Blueprint applies to all instances of that Blueprint that are in your game.

https://dev.epicgames.com/documentation/unreal-engine/overview-of-blueprints-visual-scripting-in-unreal-engine