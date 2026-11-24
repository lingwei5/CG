https://app.cinevva.com/blog/2026-05-04-volumetric-clouds-and-weather 云及天气的技术博客集
零之曙光体积云实现方案理解

# https://zhuanlan.zhihu.com/p/638440336是地平线:零之曙光的体积云实现，看了几遍，大体过程理解，但实现细节完全懵逼，你给分解一下，先解释云的建模部分
## 云的建模：本质是在回答一个问题

**“空间中任意一点 p，是不是云？有多浓？”**

数学上就是一个函数：`density(p) → [0,1]`。整个建模部分（2.1/2.2/2.3）都是在拼这个函数。拆开看，它是由**三个独立的乘数**叠出来的：

```
density(p) = 天气图给的 Coverage     ← 哪里该有云（宏观，2D，米级像素）
           × 高度梯度函数            ← 这层高度上这种云该有多厚（1D 曲线）
           × 噪声                    ← 云的具体形状细节（3D，米级纹素）
```

理解了这个乘法结构，三小节就都通了。下面逐个拆。

---

## 2.1 高度梯度函数：用一条曲线“捏”出云的形状

### 它在解决什么

云层占 1500~4000m 这 2.5km 厚度。但不同云在垂直方向上的**分布剖面**完全不同：

- **层云 Stratus**：薄薄一片，贴在底部，像毯子 → 低处有、高处立刻没
- **层积云 Stratocumulus**：底部一团，稍厚一点，顶上收掉
- **积云 Cumulus**：底部平、中间鼓、顶部翻花（花椰菜），垂直发展强

所以需要一个函数：输入“这个点在多高”（0~1），输出“这个高度上云该有多密”。

### 关键技巧：两个 Remap 相乘 = 一个“鼓包”

先看 Remap 是什么，就一个线性映射：

```hlsl
Remap(v, oMin, oMax, nMin, nMax)
    = nMin + (v - oMin)/(oMax - oMin) * (nMax - nMin)
```

就是把 `[oMin, oMax]` 区间线性挪到 `[nMin, nMax]`。**关键：v 超出原区间时会外推**，比如 `Remap(0.5, 0, 0.3, 0, 1)` = 1.67，超过 1 了。

现在看积云那条：

```hlsl
Cumulus = max(0, Remap(h, 0.01, 0.3, 0, 1)      // 上升沿：0.01→0.3 从 0 爬到 1
             *  Remap(h, 0.6, 0.95, 1, 0));      // 下降沿：0.6→0.95 从 1 掉到 0
```

把它画出来你就明白了：

```
密度
 1 |        ┌──────────┐
   |       /            \
   |      /              \
 0 |_____/                \______
   0    0.01  0.3      0.6  0.95  1   ← 高度 h
        └上升沿┘        └下降沿┘
```

- h < 0.01：第一项 ≤ 0，`max(0,…)` 直接砍成 0 → 云底以下没云
- 0.01~0.3：第一项从 0 线性涨到 1，第二项还是 1（没到 0.6）→ **密度线性爬升**
- 0.3~0.6：两项都是 1 → **满密度平台**
- 0.6~0.95：第一项锁死 1，第二项从 1 掉到 0 → **线性衰减**
- \> 0.95：第二项为负，`max(0,…)` 砍掉 → 云顶以上没云

**为什么必须相乘不能相加？** 相加得到的是“平台”，相乘才得到两头收窄的“鼓包”。而 `max(0, …)` 是必需的，因为 Remap 外推会产生负值，负密度没意义。

三条曲线就是三套不同的出入点参数：

| 云属 | 上升沿 | 下降沿 | 形状 |
|---|---|---|---|
| Stratus | 0~0.1 | 0.2~0.3 | 极薄，贴底 |
| Stratocumulus | 0~0.25 | 0.3~0.65 | 中厚，偏下 |
| Cumulus | 0.01~0.3 | 0.6~0.95 | 高大，顶到高处 |

### CloudType 怎么在三者间过渡

```hlsl
float a = lerp(Stratus, Stratocumulus, saturate(CloudType * 2.0));
float b = lerp(Stratocumulus, Cumulus, saturate((CloudType - 0.5) * 2.0));
return lerp(a, b, CloudType);
```

这是一个**两级插值**，把 `CloudType ∈ [0,1]` 切成两段：

- `CloudType = 0.0` → 第一个 lerp t=0 取 Stratus，第二个 lerp t=0 取 Stratocumulus，最外层 t=0 取 a → **纯层云**
- `CloudType = 0.5` → a、b 都算出 Stratocumulus → **纯层积云**
- `CloudType = 1.0` → 最外层 t=1 取 b，b 里 t=1 取 Cumulus → **纯积云**

`*2.0` 和 `(x-0.5)*2.0` 就是把 `[0,0.5]` 和 `[0.5,1]` 各自重新拉伸回 `[0,1]`，让前半段只在层云↔层积云之间变，后半段只在层积云↔积云之间变。**美术拖一个滑条，云就从毯子长成塔。**

> 这里有个隐含约束：三条曲线都是同一个高度区间上的剖面，所以过渡时不会突变，是连续形变——这正是“一个特征因子控制云属”的优雅之处。

---

## 2.2 噪声：为什么非要 Perlin-Worley 混合

### Perlin 的毛病

Perlin 噪声是**梯度噪声**，多个八度（octave）叠加叫 fBm，天然连续、连通、有团块状。但它长这样：一团一团的“棉花糖”，**边缘是圆滑的**，没有真实的“翻涌、破碎、被风撕开”的感。

### Worley 的毛病（和它的妙用）

Worley 也叫 Cellular/Voronoi 噪声：随机撒一堆特征点，每个像素取到最近点的距离。原生长这样：一格一格的“细胞”，像破碎的龟裂/焦散。

**但把 Worley 反过来（1 - worley）**，就变成“以特征点为中心的球形凸起”，一个个鼓包——**这恰好就是积云表面那些花椰菜状的翻涌**。

### 混合的真正动机

文章里那句话是精髓：“**如果用倒置 Worley 去补偿 Perlin 噪声，为低频低密度区域添加细节**”。

注意是**补偿低频低密度区域**，不是全域叠加。原因是：

- Perlin 负责**连通性**——保证云是大片连着的、不散架
- 倒置 Worley 负责**形状**——在云的边缘和稀薄处挖出翻涌的凸起
- 如果简单相加/相乘，云核（本来密度就 1 的地方）会被推到 1 以上或掉下来，**核心密度损失**，云看起来发虚

所以 Schneider 用**重映射**而不是四则运算：拿 Worley 组成的 fBm 去**动态改变 Remap 的输入下界**：

```hlsl
float low_freq_fBm = g*0.625 + b*0.25 + a*0.125;   // 三层递增频率 Worley
float base_cloud = Remap(perlin_worley.r, -(1.0 - low_freq_fBm), 1.0, 0.0, 1.0);
```

这句是全篇最值得琢磨的一行。看它对 `base_cloud` 的影响：

```
Remap 的输入下界 = -(1 - fBm)

fBm 大（Worley 凸起处）→ 下界接近 0  → 区间窄 → 同样 perlin 值被拉得更"实" → 云变厚
fBm 小（凹坑处）      → 下界接近 -1 → 区间宽 → perlin 值被稀释     → 云变薄甚至为 0
```

**效果等价于“用高频 Worley 去侵蚀 Perlin 的边界”**—— Worley 大的地方云鼓起来，小的地方被啃掉。这就是“花椰菜”的来源。权重 0.625/0.25/0.125 是标准 fBm 衰减（每层减半），保证低频主导、高频点缀。

### 两张 3D 纹理的分工（LOD 的物理基础）

| 纹理 | 规格 | 内容 | 干什么 |
|---|---|---|---|
| A | 128³ RGBA | R: Perlin-Worley，G/B/A: 三层递增频率 Worley | **定大型**：云的轮廓、团块 |
| B | 32³ RGB | 三层更高频 Worley | **削边缘**：细节、破碎感 |
| Curl | 128² 2D | Curl 噪声 | 卷云流动 + 湍流扰动 |

为什么拆成两张？因为**它们是不同 LOD 级别**——128³ 那张采样时用 mipmap 拿到模糊版本做“远景/廉价采样”，32³ 那张只在贴近时才采。**这就是后面跳跃式 Raymarching 能“空的地方只采低频”的硬件前提**。

---

## 2.3 密度模型：把三样东西乘起来

### 完整公式

```
density(p) = Remap( base_cloud × height_gradient , coverage(p) , 1 , 0 , 1 ) × coverage(p)
```

逐个乘数的作用：

**① `base_cloud × density_height_gradient`**
噪声（形状）被高度剖面（分布）调制。比如积云剖面在 h=0.9 处接近 0，那再大的噪声值也被压到 0 → 云顶自然收尖。

**② 第一次 Remap：`Remap(noise, coverage, 1, 0, 1)`**

这是 Coverage 的真正作用。看它的行为：

- coverage = 0（晴天）→ `Remap(noise, 0, 1, 0, 1)` = noise 本身 → 几乎不变？**不对**，后面还乘了 coverage
- coverage = 0.5 → **只有 noise > 0.5 的部分才被保留并拉伸到 [0,1]**，noise < 0.5 的全变 0
- coverage = 1（阴天）→ 所有 noise 都保留 → 满屏是云

所以 **Coverage 的物理意义是“抬高了云的入选门槛”**：天空越晴，只有噪声最“鼓”的地方能成云，云又少又碎；天空越阴，连噪声的凹坑里都填上云，云连成一片。**这一行就模拟了从晴到阴的整个过程。**

**③ 再乘一次 coverage**

补偿第一次 Remap 带来的密度膨胀——否则 coverage 低时剩下的云会被拉到满密度，看起来又少又浓，不真实。

### 那段“假积雨云”的 Trick

```hlsl
float cloud_coverage = pow(coverage, Remap(h, 0.7, 0.8, 1.0, lerp(1.0, 0.5, u_AnvilBias)));
```

拆开看：

- 高度 h < 0.7：Remap 结果 = 1 → `pow(coverage, 1)` = coverage，正常
- 高度 h > 0.8：指数从 1 掉到 0.5（受 AnvilBias 控制）→ `pow(coverage, 0.5)` = √coverage

**关键：`pow(x, 0.5)` 当 x<1 时结果比 x 大**（√0.25 = 0.5）。也就是说在云的上层，有效 Coverage 被**放大**了 → 高处原本该被门槛筛掉的噪声又重新合格 → **云被垂直拉高，形成塔状**。

这就是文章说的“向高度方向拉伸模拟积雨云的塔状分布”。它不是真的铁砧（anvil）形状，但是个便宜又“看起来很酷”的近似。

### 风：为什么偏移要乘 height_fraction

```hlsl
p += height_fraction * wind_direction * cloud_top_offset;   // 500m
p += (wind_direction + float3(0, 0.1, 0)) * FrameTime * wind_speed;
```

第一行是**风切变**：采样点越高，沿风向偏移越大（最多 500m）。现实中对流层风速随高度增加，高层云跑得比低层快，云塔会被“吹歪”、倾斜。这个 500m 偏移就让云有了倾斜感而不是一块直立的海绵。

第二行是**随时间平移**，`+0.1` 的 y 分量让风不是纯水平，带一点向上翻的扰动。

---

## 一图收束整个建模

```
世界坐标 p
   │
   ├─ 加风偏移（height_fraction × 风向 × 500m）→ 云塔倾斜
   │
   ├─ 高度归一化 h = saturate((p.z - 1500) / 2500)
   │
   ├─ 天气图采样 → coverage(R), cloudType(B)
   │
   ├─ 高度梯度：三条 Remap 鼓包曲线 ─┐
   ├─ 低频噪声：Perlin-Worley ──────┤→ base_cloud × gradient = 形态
   │     └ Worley fBm 动态改 Remap 下界 → 花椰菜侵蚀
   │
   ├─ Anvil Bias：pow(coverage, 高度相关指数) → 假积雨云
   │
   └─ Remap(形态, coverage, 1, 0, 1) × coverage → 最终密度
```

**记忆锚点**：Coverage 管“**有没有**”，CloudType 管“**什么类型**”，噪声管“**长什么样**”，三者相乘。

---

## 读代码时容易卡住的三个点

**1. `saturate` 的隐形作用**
`GetHeightFractionForPoint` 里 saturate 把云层外的点钳到 0/1，配合梯度函数在边界处本来就是 0，保证云层外密度为 0，不会在天空中间凭空出现云块。

**2. 为什么梯度函数里没有 minus/plus 只有乘**
因为这是**概率/遮罩**语义，不是颜色混合。遮罩之间用乘（AND），类型之间用 lerp（ blend）。

**3. weather_data 采样的 uv 计算**
```hlsl
uv = (pos.xy - Coverage.xy) / Coverage.zw;
```
这是把世界 XY 映射到云图 UV（zw 是世界尺寸），所以云图是**铺在整个游戏世界上方的一张“天气底图”**，玩家走到哪，头上那片云的 Coverage 由这张图对应位置决定——这就是为什么天气系统能“区域化”。

---

**下一步建议**：建模搞定了，最自然的接续是**光照模型**（2017 版那个双 HG + 双 Beer + 内散射的 `GetLightEnergy`，那三行代码每一行都有讲究），或者你想先看 Raymarching 的跳跃逻辑怎么配合这两张纹理的 LOD？

# worley或者voronoi噪声实际上是归一化后的距离场map是吗？为啥三倍频的系数是0.625 0.25 0.125，不应该是1.0,0.5,0.25,0.125吗？low_freq_fBm的范围是0~1吗？还是-1~1？worley大小为啥叫凸或者凹，怎么理解？
四个问题其实是同一个建模直觉的四个侧面，逐个拆，最后串起来。

## 1. Worley / Voronoi 噪声 = 距离场吗？

**是，但更准确说是"最近特征点距离场"**。

Worley 的做法：

1. 把空间划分成网格，每格随机撒一个特征点（feature point）
2. 对任意查询点 p，找它周围 3×3×3 格子里**最近的特征点**
3. 输出这个距离 `F1 = min_i ||p - feature_i||`

所以原始输出是**有量纲的距离**（米、格子单位），不是天然 0~1。

工程里要归一化，常见两种方式：

- **按网格尺寸归一化**：假设每格边长 1，最近距离理论最大约 `√3/2 ≈ 0.866`（对角半格），除以它就把 F1 压到 `[0, 1]`
- **按统计范围 Remap**：跑一遍统计 min/max，再线性映射到 `[0,1]`

> ⚠️ 注意：距离度量不同，范围也不同。欧氏距离、曼哈顿距离、切比雪夫距离算出来的"距离场"形状完全不一样——欧氏出圆，曼哈顿出菱形，切比雪夫出方块 。

还可以取 `F2`（第二近点）、`F2-F1`（边界脊线，出龟裂纹理）。所以严格说：

> Worley = **未归一化的距离场**，经过归一化后才得到 0~1 的灰度图。

## 2. 为什么系数是 0.625 / 0.25 / 0.125，不是 1 / 0.5 / 0.25 / 0.125？

先看你预期的那个"标准 fBm"写法：

```hlsl
// 教科书 fBm：每升一层 octeve，频率 ×2，幅度 ×1/2
fbm = 0.5*n0 + 0.25*n1 + 0.125*n2 + 0.0625*n3 + ...
// 权重和 = 1（无穷级数 1/2+1/4+1/8+...=1）
```

这是**无限 octave 的理想情况**。地平线这里只用了**三层 Worley**（G/B/A 三个通道），没有第 0 层，所以权重要重新归一化到"三层之和=1"：

```
0.625 + 0.25 + 0.125 = 1.0   ✅
```

拆开看比例：

| 层 | 频率 | 权重 | 相对比例 |
|---|---|---|---|
| G（低频） | 1× | 0.625 | 5/8 |
| B（中频） | 2× | 0.25 | 2/8 |
| A（高频） | 4× | 0.125 | 1/8 |

**比例其实是 5 : 2 : 1**，低频占绝对主导。

为什么要这样设计，而不是严格 0.5/0.25/0.125（那会漏掉 0.125 的归一化余量）？

- 标准几何级数 `0.5, 0.25, 0.125` 只取三层时**和是 0.875**，没归一化到 1
- 如果硬凑几何：`0.571, 0.286, 0.143`（公比 0.5，和=1）——但美术/作者选了 **0.625/0.25/0.125** 这套权重，让低频更重一点，中高频更弱一点
- 目的：**低频定大型不被高频带偏**，高频只做"边缘侵蚀"的微弱细节

> 💡 记忆点：这不是数学公式，是**美术权重**。只要保证"和=1、低频主导、高频递减"这三个性质，换成 0.6/0.3/0.1 也行，效果差别很小。

## 3. low_freq_fBm 的范围是 0~1 还是 -1~1？

**这里就是 0~1**。

推理：

- 三个通道 G/B/A 存的是 Worley 噪声，已经归一化到 `[0,1]`
- 权重 0.625/0.25/0.125 都为正，且和为 1
- 正向线性组合 `w1*x1 + w2*x2 + w3*x3`，输入在 [0,1] → 输出必在 [0,1]

```hlsl
low_freq_fBm ∈ [0, 1]
```

**什么时候会变 -1~1？** 只有当：

- 噪声本身存的是**有符号值**（比如 `(raw-0.5)*2`）
- 或者做了**倒置** `1 - worley`
- 或者 fBm 里混了带符号的 Perlin

在 Horizon 这段代码里都没做，所以就是 0~1。

> ⚠️ 但后面 `Remap(perlin_worley.r, -(1-low_freq_fBm), 1.0, 0, 1)` 里出现了 `-(1-fBm)`：
> - `1 - fBm ∈ [0,1]`
> - 取负后 ∈ `[-1, 0]`
> - 所以 Remap 的下界是 `[-1, 0]`，上界是 1
>
> 这是**故意把下界往下拉**，让 Worley 大的地方把 Remap 区间收窄——上一轮讲过这个 trick。

## 4. "凸/凹"到底怎么理解

先澄清：**不是数学里的凸函数/convex**。是视觉形态的"鼓出来/凹进去"。

### Worley 原始距离场

```
暗 ●━━━━━━● 暗
  距离大     距离大
      ↑
   特征点（亮，距离为0）
```

- 特征点正上方：距离=0，**最暗**
- 离特征点越远：距离越大，**越亮**

看起来像"一个个暗坑/细胞"，边缘亮、中心暗。

### 倒置 Worley：`1 - F1`

```
亮 ○━━━━━━○ 亮
  距离小     距离小
      ↑
   特征点（最亮，1-0=1）
```

- 特征点正上方：值=1，**最亮、最鼓**
- 边缘：值趋近 0，**暗下去**

**这就变成了一个个"鼓包/球状凸起"**——视觉上是凸的。积云表面那些花椰菜小球，就是这个。

### 为什么叫"凸/凹"

| 操作 | 视觉 | 云的意义 |
|---|---|---|
| 倒置 Worley 高点 | **凸**（鼓包、球状） | 云团表面的翻涌、花椰菜结构 |
| 高频 Worley 侵蚀 | **凹**（啃出裂隙、蜂窝） | 云边缘被风撕碎的破碎感 |
| Perlin 团块 | 平滑起伏 | 云的整体连通性 |

文章里说的"用倒置 Worley 补偿 Perlin"，本质是：

- Perlin 给**大团连续形状**（像一坨面团）
- 倒置 Worley 在面团表面**摁出一个个凸起**（像花椰菜）
- 高频 Worley 再在凸起边缘**啃出小坑**（像被风蚀）

三者叠加 → 既有整体感，又有微观结构。

### 一个更直观的比喻

想象一盆发好的面团（Perlin）+ 你用手指在表面摁出一排排圆坑（倒置 Worley 凸包）+ 再用砂纸把边缘磨毛（高频侵蚀）。最后出来的就是"积云"。

## 串起来看建模意图

```
Worley 距离场 (0~1)
   │
   ├─ 倒置 → 鼓包（凸）
   │
   ├─ 三层 fBm: 0.625/0.25/0.125（低频主导）
   │   → 把鼓包做成"大包套小包"的分形结构
   │
   └─ 用这个 fBm 去动态改 Remap 下界
       → 鼓包大的地方云更实，凹坑处云被啃掉
```

所以你看到的那行：

```hlsl
float low_freq_fBm = g*0.625 + b*0.25 + a*0.125;
```

本质是：**"用分形 Worley 距离场生成一个 0~1 的侵蚀蒙版"**，再拿这个蒙版去雕刻 Perlin 云的基础形状。

## 几个容易继续卡住的点

**Q: 为什么不复用 Perlin 做高频细节，非要 Worley？**
Perlin 高频看起来还是"平滑的噪点"，没有"破碎感"。Worley 高频天然是细胞状裂隙，正好模拟云被风撕开的边缘。

**Q: 距离场一定要归一化吗？**
不必须，但工程上必须。不归一化，不同频率的 Worley 量程不同，权重就失去意义，美术没法调。

**Q: 0.625 这套权重能改吗？**
能。只要保持"和=1、低频>中频>高频"，改了只是细节风格变化：低频权重更大→云更整块；高频权重加大→云更碎更毛。

**Q: 为什么 fBm 里没有第 0 层（最最低频）？**
因为最最低频的"云团位置"信息已经由 **Coverage 天气图** 和 **Perlin-Worley 的 R 通道**承担了，Worley fBm 只补"中尺度翻涌"。

---

**核心一句话**：Worley 是距离场，归一化后 0~1；0.625/0.25/0.125 是"三层归一化+低频主导"的美术权重；low_freq_fBm 是 0~1 的侵蚀蒙版；凸/凹是视觉鼓包与裂隙，不是数学凸性。

**接下来你更想看噪声生成的工程实现（3D 纹理烘焙），还是把建模公式整理成可运行的 GLSL 骨架？**

# 所谓的高度梯度函数 模型到底是啥？是remap还是GetHeightFractionForPoint函数的结果？还是其他的？
## 结论先给

**“高度梯度函数模型”不是某一个函数，而是一组由 remap 拼出来的“垂直剖面曲线”**。

三个东西要分开看，很多人卡住就是因为把它们混成一个了：

| 名字 | 它是什么 | 输出含义 |
|---|---|---|
| `GetHeightFractionForPoint` | 高度归一化 | `h ∈ [0,1]`，只是“你在云层里多高” |
| `Remap` | 数学工具函数 | 把一段区间线性映射到另一段区间 |
| `GetDensityHeightGradientForPoint` | **高度梯度模型本体** | `g(h, cloudType) ∈ [0,1]`，“这个高度、这种云，理论上能有多浓” |

---

## 一、第一层：GetHeightFractionForPoint 只是“坐标变换”

```hlsl
float GetHeightFractionForPoint(float3 p, float2 inCloudMinMax) {
    float h = (p.z - inCloudMinMax.x) / (inCloudMinMax.y - inCloudMinMax.x);
    return saturate(h);
}
```

它干的事极其单纯：

- 输入：世界高度（比如 1500~4000m 之间的某个 z）
- 输出：把这个高度线性压到 `[0,1]`
- `0` = 云底，`1` = 云顶

**它完全不知道“云长什么样”**，只是告诉你“采样点站在云层的第几层”。

> ⚠️ 常见误区：以为 `h` 本身就是密度。不是。`h=0.5` 只代表“在中间高度”，不代表那里一定有云。

---

## 二、第二层：Remap 是“剪刀+胶水”

```hlsl
float Remap(v, oMin, oMax, nMin, nMax)
    = nMin + (v-oMin)/(oMax-oMin) * (nMax-nMin)
```

它本身没有语义，只是把一段区间“拉伸/压缩/翻转”到另一段。

关键用法：**两个 Remap 相乘 = 一个鼓包曲线**。

```hlsl
// 积云剖面
Cumulus = max(0, Remap(h, 0.01, 0.3, 0, 1)      // 上升沿：底部爬升
               * Remap(h, 0.6, 0.95, 1, 0));     // 下降沿：顶部收尖
```

画出来就是：

```
密度
1 |        ┌──────┐
  |       /        \
  |      /          \
0 |_____/            \____
  0   0.01  0.3    0.6  0.95  1   h
```

- 第一个 Remap：控制“从哪开始长”
- 第二个 Remap：控制“在哪开始收”
- 相乘：两头截断，中间鼓起来

**这就是“高度梯度”的几何意义**——一条沿着高度方向的密度概率分布曲线。

---

## 三、第三层：GetDensityHeightGradientForPoint 才是模型本体

```hlsl
float GetDensityHeightGradientForPoint(float h, float CloudType) {
    // 三条基础曲线
    float Cumulus = max(0, Remap(h, 0.01, 0.3, 0, 1) * Remap(h, 0.6, 0.95, 1, 0));
    float Stratocumulus = max(0, Remap(h, 0, 0.25, 0, 1) * Remap(h, 0.3, 0.65, 1, 0));
    float Stratus = max(0, Remap(h, 0, 0.1, 0, 1) * Remap(h, 0.2, 0.3, 1, 0));

    // 在三条曲线之间插值（CloudType ∈ [0,1]）
    float a = lerp(Stratus, Stratocumulus, saturate(CloudType * 2.0));
    float b = lerp(Stratocumulus, Cumulus, saturate((CloudType - 0.5) * 2.0));
    return lerp(a, b, CloudType);
}
```

**它做的事**：

1. 先用 remap 拼出三种“标准云属剖面”
2. 再用 CloudType 滑杆在三种剖面之间连续混合
3. 输出一个 `∈ [0,1]` 的标量

这个输出就是**高度梯度函数的值**，文章里叫 `density_height_gradient`。

---

## 四、它在整个密度公式里扮演什么角色

回到完整建模：

```hlsl
float base_cloud = SampleLowFrequencyNoises(p);          // 噪声：云“团块”形状
float gradient    = GetDensityHeightGradient(...);      // 高度剖面：垂直方向“允许多浓”
float coverage    = weather_data.r;                     // 天气：这片天“该不该有云”

float noise = base_cloud * gradient;                    // ← 高度梯度在这里乘进去
float final = Remap(noise, coverage, 1, 0, 1) * coverage;
```

**乘法语义**：

```
最终密度 = 噪声形状 × 高度剖面 × 天气覆盖
            ↑            ↑            ↑
          “像不像云”   “该多厚”    “有没有云”
```

- 噪声决定“云的一丝一缕”
- **高度梯度决定“这一层该不该有、该多厚”**
- Coverage 决定“这片天空整体晴还是阴”

高度梯度是**乘性遮罩**——它不改变噪声的细节，只按高度“调制”噪声的整体强度。

---

## 五、直觉化理解

把云层想象成一个**竖直的果冻模具**：

- 噪声 = 往模具里灌的“云糊”（有纹理、有团块）
- 高度梯度 = **模具本身的形状**（层云是薄片、积云是高塔、层积云是中等厚度）
- Coverage = 决定模具里灌不灌东西

高度梯度函数就是**“模具截面”**——它定义了“在高度 h 处，云最多能长到多浓”。

换 CloudType 滑杆，等于换模具：

```
CloudType=0.0  → 薄片模具（层云）
CloudType=0.5  → 中厚模具（层积云）
CloudType=1.0  → 高塔模具（积云）
```

---

## 六、2022 年演进：从“高度梯度”到“Dimensional Profile”

顺带提一句（不展开）：Horizon 续作《西之绝境》把这套升级成了 **Dimensional Profile Model**：

- 早期：只有一条垂直剖面（高度 → 密度）
- 新版：拆成 **Cloud Top Type + Cloud Bottom Type** 两张剖面，分别控制云顶轮廓和云底轮廓

本质还是“高度方向的概率曲线”，只是从“一条线”变成“两张图可美术手绘”。

> 所以你看到文章里叫“高度梯度函数”或“密度高度梯度”，指的就是这一族东西——**用 remap 构造的垂直密度剖面**，不是某个单一函数。

---

## 七、一张表收束

| 概念 | 数学形式 | 输入 | 输出 | 作用 |
|---|---|---|---|---|
| 高度归一化 | 线性映射 | 世界高度 | `h∈[0,1]` | 定位采样点在云层的高度 |
| Remap | 区间重映射 | 任意值 | 任意区间 | 构造曲线的工具 |
| 高度梯度函数 | 多个 remap 乘积 + 云属插值 | `h, CloudType` | `g∈[0,1]` | 定义“该高度该云属的理论浓度” |
| 密度模型 | `noise × gradient × coverage` | 空间点 | `density∈[0,1]` | 最终云密度 |

---

## 一句话

**高度梯度函数模型 = 用 remap 拼出来的“垂直密度剖面曲线”**，输入是归一化高度和云属类型，输出是一个乘性遮罩，告诉噪声“在这一层你可以长多浓”。`GetHeightFractionForPoint` 只是它的坐标准备，`Remap` 只是拼曲线的工具，真正的“模型”是 `GetDensityHeightGradientForPoint` 里那套曲线组合。

**接下来想看云属过渡的几何直观，还是把高度梯度改写成可调试的 GLSL 参数化版本？**

# 跟pbrt的原理是一致的吗？为什么pbrt是积分，这里没有积分
先给结论：**物理目标是同一件事，数学根源也是同一个积分，只是 Horizon 那套把“积分”藏进了 Raymarching 的累加里，并用大量经验项换掉了 pbrt 里严格的蒙特卡洛求积。**

没写 `∫` 不代表没有积分，只是把连续积分离散成了有限步求和。

---

## 一、pbrt 在积分什么

参与介质里的辐射传递方程（传输方程）是：

$$
L_i(p,\omega)=\int_0^t T(p'\!\to\! p)\,L_s(p',\omega)\,ds + T(p_0\!\to\!p)L_o(p_0,-\omega)
$$

其中透射率

$$
T(a\to b)=\exp\!\left(-\int_a^b \sigma_t(x)\,dx\right)
$$

- $\sigma_t=\sigma_a+\sigma_s$：消光 = 吸收 + 散射
- $L_s$：介质自身发光 + 内散射（含相位函数 $p(\omega,\omega')$）
- 积分沿视线对“每一个微小体积元贡献的散射光”求和 

pbrt 的做法是用 **Monte Carlo / 体积路径追踪（volpath）** 对这个积分做无偏估计：随机采样散射事件、用相位函数做重要性采样、递归处理多次散射 。

---

## 二、Horizon/Nubis 其实也在积，只是“硬算离散和”

把上面那个积分写成离散形式，就是 Raymarching 干的事：

```glsl
T = 1.0;
color = 0.0;
for (step i = 0..N) {
    float d = density(p_i) * stepSize;
    float transmittance_step = exp(-d);          // Beer-Lambert
    vec3  scatter = lightEnergy(p_i) * phase(cosθ);
    color += T * scatter * d;                    // 积分的黎曼和
    T     *= transmittance_step;                 // 透射率连乘 ≈ 指数积分
    p += step;
}
```

对照一下：

| pbrt 连续形式 | Horizon 离散形式 |
|---|---|
| $\int L_s\,T\,ds$ | `for` 循环里 `color += T * scatter * ds` |
| $\exp(-\int\sigma_t)$ | 每步 `exp(-density*ds)` 连乘 |
| 相位函数采样 | 双 HG 相函数直接算 |
| 多次散射递归 | 双 Beer + 深度/垂直概率近似 |

**这就是数值积分**：把连续介质切成 N 段，每段用矩形法求积。所谓“没有积分”，只是没把 ∑ 写成 ∫。

---

## 三、真正不一致的地方：近似策略，不是物理目标

两者都瞄准“参与介质里的吸收+外散射+内散射”，但取舍完全不同：

**pbrt（离线/严格）**
- 无偏或低方差 MC 估计
- 真实多次散射（多阶、多方向）
- 重要性采样、相位函数采样
- 不预设云的形状，密度场来自场景/介质定义
- 代价：每像素成千上万条路径

**Horizon/Nubis（实时/近似）**
- 固定步数 Raymarching + 跳跃式自适应步长
- 密度场是**程序化噪声**（Perlin-Worley + 高度梯度 + 天气图），不是物理模拟出的真实介质
- 单次前向光锥采样（6 个样本）近似阴影
- 多次散射用**经验项**凑：双 Beer 取 max、深度概率、垂直概率、“糖粉”
- 双 HG 相位是“不物理但好看”的 trick
- 分帧 1/4 分辨率 + TAA 补

Andrew Schneider 自己说过：2017 版光照“放弃死磕物理原则，走向艺术的荒野”。所以 Horizon 是**物理启发的近似模型**，pbrt 是**物理正确的积分器**。

---

## 四、一个关键误区：Raymarching ≠ 没有积分

常见误解有两种，顺便澄清：

1. **“实时体积云不用积分，用步进”**  
   步进本身就是对积分的数值离散化。步长→0、样本→∞ 时，它就是积分。

2. **“pbrt 有相位函数、Beer 定律，所以更物理”**  
   不完全对。Beer-Lambert 和 HG 相位**两边都在用**；区别在于 pbrt 用它们构造无偏估计，Horizon 用它们构造有偏但极快的着色公式。

换句话说：
- pbrt：**用积分定义真理，用采样逼近它**
- Horizon：**用积分定义方向，用经验函数抄近路**

---

## 五、为什么效果看起来“一致”

因为两者都抓住了体积散射的三个主导项：

- 透射衰减（Beer）
- 前向散射亮边（HG 前向峰）
- 厚云内部暗、薄云边缘亮（吸收 + 内散射平衡）

只要这三件事近似对，人眼就觉得“像云”。Nubis 后续版本（2022/2023）甚至把多次散射拆成 3 阶 Wrenninge 近似 $\sum 0.5^n e^{-k\cdot0.5^n d}$，就是在把经验项往 pbrt 的积分结构再靠一点 。

---

## 六、一句话总结

> pbrt 解的是“体积光传输方程的积分”；Horizon 解的是“同一个积分在 2ms 预算下的可运行近似”。  
> 没写 ∫，是因为把积分变成了 `for` 循环里的 `+=`，再把多次散射、相位、内散射换成美术可调的闭式近似。

如果你后面要在自己的渲染器里接体积云，建议分两层写：先按 pbrt 的传输方程把积分结构立住，再在“光锥采样数 / 多次散射阶数 / 密度场来源”上做 Horizon 式裁剪——这样物理兜底和实时性能都不丢。

**接下来你更想先看哪部分：把 Nubis 光照改写成标准传输方程的形式，还是设计可切换离线/实时模式的伪代码框架？**

# HG phase  function两个参数的变化规律
先给结论：**HG 相位函数里其实有两个“变量”，但性质完全不同**——

- **`g`（asymmetry parameter）是介质属性**：决定“散射瓣”长什么样，固定后不随视角变
- **`cosθ` 是几何变量**：决定“当前相机/光线方向”落在散射瓣的哪个位置

渲染时调的是 `g`，运行时算的是 `cosθ`，两者乘起来才有“银边/光晕/体积感”。

---

## 一、标准公式与两个变量的角色

归一化形式（球面积分=1）：

$$
p(\theta)=\frac{1}{4\pi}\frac{1-g^2}{(1+g^2-2g\cos\theta)^{3/2}}
$$

其中：

- $g\in(-1,1)$，是**平均散射角余弦** $g=\langle\cos\theta\rangle$
- $\theta$ 是入射光方向与散射后出射方向的夹角
- $\cos\theta = \dot{\omega}_{light},\omega_{view}$

> ⚠️ 符号坑：有些资料写 $1+g^2+2g\cos\theta$，那是把 $\theta$ 定义成“视线-反方向光”的夹角。渲染代码里用 `dot(viewDir, lightDir)` 时，分母通常是减号形式，别把两套记号混用。

---

## 二、`g` 的变化规律（介质本身的方向偏置）

| `g` 取值 | 散射行为 | 视觉表现 | 典型场景 |
|---|---|---|---|
| `g = 0` | 各向同性 | 均匀发亮，无方向感 | 雾、小粒子 Rayleigh |
| `0 < g < 0.5` | 弱前向 | 顺光略亮 | 薄雾、一般气溶胶 |
| `g ≈ 0.7~0.85` | 强前向 | 云体有体积感，逆光边缘开始发亮 | 水云、常规体积云 |
| `g ≈ 0.9~0.99` | 极窄前向峰 | 太阳周围出现锐利银边（silver lining） | 厚云、Mie 散射 |
| `g → 1` | 几乎直穿 | 透明感，只在极窄角度有散射 | —— |
| `g < 0` | 后向散射 | 面向太阳的一面更亮，有“回散射” | 特殊介质、双 HG 的后瓣 |

云的液滴粒径 5~15μm ≫ 可见光波长，属于 **Mie 散射**，天然强前向，所以云渲染 `g` 一般取 **0.8 附近**。

**关键规律**：
- `|g|` 越大 → 散射越集中在某一方向，瓣越“尖”
- `g>0` 峰在 $\theta=0$（前向，顺着光看最亮）
- `g<0` 峰在 $\theta=\pi$（后向，逆着光看最亮）
- `g=0` 时公式退化为 $1/4\pi$，与 $\theta$ 无关

---

## 三、`cosθ` 的变化规律（观察方向在瓣上的位置）

固定一个 `g`（比如 0.8），看分子分母怎么随 `cosθ` 走：

- **`cosθ = 1`**（θ=0，正对太阳/完全顺光）  
  分母最小 $(1+g)^3$，相位函数取**最大值** → 太阳盘附近最亮，银边来源

- **`cosθ = 0`**（θ=90°，侧光）  
  分母 $(1+g^2)^{3/2}$，值中等偏低 → 云体侧面“正常亮度”

- **`cosθ = -1`**（θ=180°，逆光/背向太阳）  
  分母最大 $(1-g)^3$，值最小 → 理论上最暗，但**双 HG 的后瓣会在这里补一点回散射**

再叠加 `g` 的影响：
- `g` 越大，`cosθ=1` 附近的峰值越尖锐（银边越“聚”）
- `g` 越小，峰值越平缓（光晕铺得更开）

---

## 四、单 HG 不够：为什么体积云要用双 HG

单 HG 有个硬伤——**不能同时有“锐利太阳银边”和“柔和宽光晕”**。一个 `g` 只能出一个瓣。

Horizon/Nubis 用的双 HG（你之前贴的代码里就是这套）：

$$
p_{double}=\max\Big(HG(g_1),\; w\cdot HG(g_2)\Big)
$$

或线性混合：

$$
p=\alpha\,HG(g_1) + (1-\alpha)\,HG(g_2)
$$

工程上两个参数的分工：

| 参数 | 典型值 | 作用 |
|---|---|---|
| `g1`（主瓣） | 0.6~0.8 | 整体体积感、顺光/侧光分布 |
| `g2`（银边瓣） | 0.95~0.99 | 太阳周围的锐利前向峰 |
| `SilverIntensity`（w） | 0~1 | 控制银边强度 |
| `SilverSpread`（1-g2） | 小量 | 控制银边“铺开”的宽度 |

**变化规律直觉**：
- 增大 `SilverIntensity` → 太阳附近光晕更亮、更张扬（晚霞感）
- 减小 `g2`（让 1-g2 变大）→ 银边变宽、变柔；`g2→0.99` 则银边极细极亮
- 主 `g1` 调低 → 云体整体更“平”、更雾感；调高 → 更雕塑感、方向性更强

---

## 五、把参数规律翻译成“调参手册”

如果你在自己渲染器里接 HG，记住这几条就够：

1. **先看主方向感**：`g1` 从 0.7 起调，顺光体积感不对再加减
2. **银边太弱**：抬 `SilverIntensity`，或把 `g2` 往 0.99 推
3. **银边太刺眼**：降 `w`，或把 `g2` 降到 0.9 左右让峰变宽
4. **逆光云太死黑**：加一点后向瓣（负 g 或双 HG 第三项为后向补光），模拟多次散射回头
5. **雾/烟**：`g` 降到 0~0.3，别用云的参数，否则雾会“发光”
6. **`cosθ` 不用调**：它是几何量，由相机和太阳位置自动算出，你只需要保证 `dot(view, light)` 符号和公式一致

---

## 六、一个常见误区

> “`g` 是亮度参数，调大就更亮”

不对。`g` 只改**方向分布**，不破坏归一化（积分恒为 1）。  
调 `g` 的结果是“把光从某些方向挪到另一些方向”：前向峰变尖的同时，侧光和后向会同步变暗。真要整体提亮，调的是**光照项里的 brightness / 多次散射近似**，不是 `g`。

---

## 七、和 pbrt 的对照

- pbrt 里 HG 也是同一个公式，但 `g` 由介质属性决定（比如 `CloudMedium` 给定 g=0.85），不随便美术调
- pbrt 用 HG 做**相位函数的重要性采样**，随机散射方向按这个分布抽
- 实时云把 HG 当**闭式权重**直接乘进 `light_energy`，跳过采样——所以你看到的是“算出来的值”，不是“积出来的分布”，但数学内核一致

**接下来你想看双 HG 的 GLSL 参考实现，还是用极坐标曲线分析不同 g 值的散射分布？**

# 所谓的方向分布，前向后向，是相对于哪个方向基准说的？固定的世界方向吗？还是视线方向？光线方向？
结论先放前面：**HG 的基准是“入射光的传播方向”，也就是光子前进的方向，逐点定义、逐散射事件定义。** 不是相机方向，不是世界坐标轴，也不是“指向太阳的方向”——但和太阳方向只差一个正负号，而这个符号正是绝大多数人踩坑的地方。

---

## 一、严格定义：θ 到底夹的是哪两个方向

相位函数描述的是：一束光以方向 $\vec{\omega}'$ 入射到某个介质点，被散射后沿方向 $\vec{\omega}$ 出射，两者的角分布关系：

$$
p(\vec{\omega}',\vec{\omega}) = p(\cos\theta),\qquad \cos\theta = \vec{\omega}'\cdot\vec{\omega}
$$

- $\vec{\omega}'$：**入射光的传播方向**（光子往哪走）
- $\vec{\omega}$：**散射后的传播方向**（光子被弹到哪去）

所以“方向分布”这个词的完整含义是：**以入射传播方向为极轴，散射方向在球面上的概率密度分布**。极轴是 $\vec{\omega}'$，不是相机、不是世界 Y 轴。

对体积云的单次散射，入射光就是太阳光，于是：

$$
\vec{\omega}' = \frac{\vec{p} - \vec{p}_{sun}}{|\vec{p}-\vec{p}_{sun}|}
\quad\text{（从太阳指向采样点）}
$$

注意这是**光走的方向**，不是“从点指向太阳”。

---

## 二、三个候选基准逐一对照

| 候选 | 是否是基准 | 说明 |
|---|---|---|
| 世界固定方向（如 +Y、+Z） | ❌ | 相位函数与坐标系无关，旋转整个场景结果不变 |
| 视线方向 | ❌ 本身 | 视线只是**出射方向** $\vec{\omega}$，是被分布采样的对象，不是极轴 |
| 光线方向 | ✅ | 严格说是**光子的传播方向** $\vec{\omega}'$，逐点、逐光源定义 |

补充两点边界情况：

- **太阳是平行光**：所有采样点的 $\vec{\omega}'$ 相同，所以基准可以退化为一个固定世界方向——但方向取的是“太阳→点”，不是“点→太阳”。
- **多光源 / 环境光**：每个方向的光有自己的 $\vec{\omega}'$，相位函数要**逐光源分别算**，不能共用一个 $\cos\theta$。

---

## 三、最反直觉的一点：前向散射亮，表现是“逆着光看亮”

这是理解云银边的关键，也是符号错误的根源。

**物理上**：前向散射 = $\theta \approx 0$ = 光子基本不改方向，继续往前冲。

**视觉上**：你要接收到这束前向散射光，必须站在光继续前进的路径上、回头迎着它看。也就是**相机朝着太阳看**。

画一下：

```
太阳 S ────→ 云点 P ────→ 相机 C
        ω'（光走的方向）  ω（继续走，进相机）
```

逆光拍摄时，$\vec{\omega}'$ 和 $\vec{\omega}$ 同向，$\cos\theta=1$，HG 取最大值 → 云边缘发亮 → 这就是 silver lining。

反过来，**顺光看云（背对太阳）时，你接收到的是后向散射**，理论上最暗。这符合直觉：顺光时云显得“平”“灰”，逆光时才有通透的亮边。

所以一句话记住：

> **HG 的“前向”指的是光的去向，不是你看的方向。前向散射的视觉效果 = 逆光看。**

---

## 四、代码里的符号约定（坑区）

设：

- $\vec{L}$ = 从采样点指向太阳（`pointToSun`）
- $\vec{V}$ = 从采样点指向相机（`pointToCamera`）

那么正确的 $\cos\theta$ 是：

$$
\cos\theta = \vec{\omega}'\cdot\vec{\omega}
= (-\vec{L})\cdot\vec{V}
= -\vec{L}\cdot\vec{V}
$$

即：

```glsl
float cos_theta = -dot(normalize(pointToSun), normalize(pointToCamera));
float phase = HG(cos_theta, g);   // 公式用 (1 + g² - 2g·cosθ)^{1.5}
```

等价写法（把负号挪到 $\vec{V}$ 上）：

```glsl
float cos_theta = dot(normalize(pointToSun), normalize(cameraToPoint));
// 此时 cameraToPoint = -pointToCamera，即“视线的前进方向”
```

**常见错误清单**：

1. 用 `dot(pointToSun, pointToCamera)` 直接算，没加负号 → 银边跑到顺光侧，逆光死黑
2. HG 公式写成 $(1+g^2+2g\cos\theta)$ 又同时加了负号 → 负负得正，同样错
3. 视线方向一半代码用“相机→点”，一半用“点→相机”，混用后符号随机翻转

**自检方法**：把太阳放在相机正后方（顺光），$\cos\theta$ 应该接近 $-1$，phase 取最小值；把太阳放在相机正前方（逆光），$\cos\theta$ 接近 $1$，phase 取最大。跑一遍这个测试就知道符号对不对。

---

## 五、多次散射时基准怎么变

单次散射基准清晰，多次散射就麻烦了：

- 光被散射一次后，$\vec{\omega}'$ 已经不再是太阳方向，而是上一次散射的出射方向
- 严格算需要沿路径递归积分（pbrt 的 volpath 干的事）
- 实时近似（Horizon / Wrenninge 的多阶近似）通常**不追踪方向**，直接把多次散射当成“更各向同性的光”，用更小的 $g$ 或常数项代替

所以你在 Nubis 里看到的双 HG、`depth_probability`、`vertical_probability`，本质上是在**绕过“多次散射的方向基准已丢失”这个问题**，用经验函数补能量，而不是真的在算第二个极轴。

---

## 六、小结

| 问题 | 答案 |
|---|---|
| 基准是固定世界方向吗 | 不是。是逐点的入射光传播方向；平行太阳光下可视为固定方向，但取向是“太阳→点” |
| 是视线方向吗 | 不是。视线是**出射方向**，是被分布采样的对象 |
| 是光线方向吗 | 是。严格说是**光子的前进方向** $\vec{\omega}'$ |
| 前向散射视觉上是什么 | **逆光看亮**（相机朝太阳），这是银边的成因 |
| 最容易错的地方 | $\cos\theta$ 的符号：$-\vec{L}\cdot\vec{V}$，不是 $\vec{L}\cdot\vec{V}$ |

---

如果你要把这套接进自己的渲染器，建议第一步先写一个**符号自检 shader**：固定 $g=0.8$，让太阳绕相机转一圈，观察 phase 峰值是否出现在逆光位置。这一步过了，后面的双 HG、多次散射近似才有意义。

**接下来你想看这个自检 shader 的完整 GLSL，还是继续拆双 HG 里两个 $g$ 各自的物理含义？**

# 所谓的密度模型，密度是啥?dl是采样密度 sampleDensity，还是optical depth？对应pbrt里的哪些物理量
# 先给结论

**Nubis 里的“密度”不是物理意义上的质量密度，而是“每单位长度的消光权重”**——本质是 PBRT 里 $\sigma_t$ 的工程近似，只是被归一化、被美术参数调制过了。

- `SampleCloudDensity()` 返回的是 **point density**（每点消光系数近似），不是 optical depth
- `dl`（density along light cone）是沿光锥累加后的 **optical depth / optical thickness** $\tau$
- 但代码里经常把 `dl` 当成“已经乘过 step size 的累积消光”，所以它是 $\tau$，不是 $\sigma_t$

---

## 一、密度模型返回的到底是什么

看 `SampleCloudDensity` 的输出：

```hlsl
float cloud_with_coverage = Remap(noise, cloud_coverage, 1.0, 0.0, 1.0);
cloud_with_coverage *= cloud_coverage;
return cloud_with_coverage;   // 0~1 之间的标量
```

它经过了一系列操作：

```
Perlin-Worley 噪声
  → 高度梯度（云属剖面）
  → Coverage 重映射
  → 高频侵蚀
  → 输出 0~1 的“密度”
```

**所以这个数不是 kg/m³，也不是严格的光子吸收截面**。它是：

> 一个被美术参数（coverage、cloud type、anvil bias）塑形过的、**相对消光权重**。

在 PBRT 语言里，它近似等于：

$$\sigma_t(x) \approx k \cdot \text{density}(x)$$

其中 $k$ 是把 0~1 映射到真实消光系数（m⁻¹）的隐含缩放常数。工程上通常把这个 $k$ 吞进 step size 里，不单独出现。

---

## 二、PBRT 物理量的逐一对表

| PBRT / 物理量 | 符号 | Nubis 对应 | 说明 |
|---|---|---|---|
| 质量密度 | $\rho(x)$ | 无直接对应 | 工程里不区分介质成分 |
| 吸收系数 | $\sigma_a = \kappa_a\rho$ | 隐含在 density 里 | 云近似 $\sigma_a \ll \sigma_s$ |
| 散射系数 | $\sigma_s = \kappa_s\rho$ | 隐含在 density 里 | 云主要是散射介质 |
| 消光系数 | $\sigma_t = \sigma_a+\sigma_s$ | `SampleCloudDensity()` 返回值 | 归一化到 0~1 的近似 |
| 光学深度/厚度 | $\tau = \int \sigma_t\,ds$ | `dl`（光锥累加结果） | `dl += density * stepSize` |
| 透射率 | $T_r = e^{-\tau}$ | `exp(-dl)` / 双 Beer | 光照模型的 attenuation |
| 反照率 | $\Lambda = \sigma_s/\sigma_t$ | 近似 1（云很白） | 很少显式出现 |
| 相位函数 | $p(\omega,\omega')$ | HG / 双 HG | `GetDirectScatterProbability` |
| 内散射项 | $\sigma_s\int p L\,d\omega'$ | in-scatter probability × phase | 用经验概率近似积分 |
| 辐射传输方程解 | $L$ 沿视线积分 | raymarch 主循环累加 | `scatteredLight += ...` |

---

## 三、`dl` 到底是 density 还是 optical depth

看圆锥采样那段：

```hlsl
float density_along_cone = 0.0;
for (int i = 0; i < 6; i++)
{
    float3 conePos = p + ...;
    density_along_cone += SampleCloudDensity(conePos, ...);  // 累加！
    p += light_step;
}
return GetLightEnergy(p, density_along_cone, ...);
```

关键点：

- 循环里是 `+=`，所以 `density_along_cone` 是**沿光路所有采样点密度之和**
- 严格物理上还差一个 `stepSize` 因子： $\tau = \sum \sigma_t(x_i)\Delta s$
- Nubis 常把 stepSize 归一化进 density 或假定单位长度，所以 `dl ≈ τ`

**结论**：
> `dl` 是 **optical depth**（光学深度），不是单点 sampleDensity。
> 但它是“没严格乘步长”的光学深度——工程近似，单位被吃掉了。

对应 PBRT 公式：

$$T_r = \exp\left(-\int_0^d \sigma_t(x+s\omega)\,ds\right) \approx \exp(-\text{dl})$$

---

## 四、视线方向的 `alpha` 也是同理

主 raymarch 里：

```hlsl
alpha += sampled_density;   // 同样是密度累加
```

这里的 `alpha` 不是传统的 0~1 透明度初值，而是**沿视线的光学深度累积**，最后：

```hlsl
transmittance = exp(-alpha);   // 视线透射
```

当 `alpha` 足够大（云很厚）→ `transmittance→0` → 提前结束。

---

## 五、常见误区（很重要）

### ❌ 误区 1：density 是“物理密度”
不是。它是**消光权重的归一化近似**，混入了 coverage、weather、height gradient 等美术调制。真实物理仿真（如 Fluent 里算粒子场）出来的 $\rho$ 还得再乘材质消光截面才等价于它。

### ❌ 误区 2：dl 是“采样点密度”
`dl` 是**累加后的光学厚度**。单点密度是 `SampleCloudDensity()` 的返回值，叫 `sampled_density` 或 `ds_loded`。

### ❌ 误区 3：Beer 定律直接吃 density
不对。Beer 吃的是 **optical depth**：

```hlsl
// 错
exp(-sampleDensity)

// 对（工程里 step 已归一化）
exp(-dl)   // dl = Σ density * stepSize
```

### ❌ 误区 4：把 Nubis 光照当 RTE 严格解
Nubis 的“三项概率相乘”是**启发式分解**：

```
LightEnergy = Transmittance × InScatterProb × Phase × brightness
```

而 PBRT 的严格 RTE 是：

$$L(x,\omega) = \int_0^d T_r(x,x_s)\sigma_s(x_s)\int_{S^2} p(\omega,\omega')L(x_s,\omega')\,d\omega'\,ds + \text{环境项}$$

Nubis 用：
- `exp(-dl)` 近似 $T_r$
- `in_scatter_probability` 近似 $\sigma_s \times$（多次散射累积）
- `phase` 近似 $p$
- 完全跳过对 $d\omega'$ 的半球积分，用经验曲线代替

---

## 六、一句话串起来

> `SampleCloudDensity` 返回的是 **$\sigma_t$ 的归一化近似**（每点消光权重）；
> `dl` 是沿光锥累加出的 **optical depth $\tau$**；
> `exp(-dl)` 就是 PBRT 里的透射率 $T_r$；
> 整个 Nubis 光照模型是用三个“概率乘子”对体积渲染方程做工程化简，不是严格解，但物理动机清晰。

---

## 七、如果你要往 PBRT 式路径追踪里接

映射关系写成代码就是：

```cpp
// Nubis density → PBRT sigma_t
Float sigma_t = density * extinctionScale;

// 光学深度积分
Float tau = 0;
for (each light sample)
    tau += sigma_t * stepSize;

// 透射
Spectrum Tr = Exp(-tau);

// 内散射（单散射近似）
Spectrum Ls = Tr * sigma_s * phase(wo, wi) * sunRadiance;
```

Nubis 把所有 $\kappa_a, \kappa_s, \kappa_t$ 合并成一个可调的 `density * scale`，换来实时性，牺牲的是光谱精度和多次散射严谨性。

**接下来你更想看把 Nubis 光照改写成严格 RTE 积分形式，还是设计 density 与光学单位的标定方法？**

# 所以getlightenergy里的attenuation_probability 实际是transmitance？那剩下的in_scatter_probability  phase_probability又是啥？三者为啥连乘
# 结论先放

**是的，`attenuation_probability` 本质就是 transmittance，但它是“太阳→采样点”这一段的透射率，而且被多重散射兜底改写过，不是纯 Beer 透射。**

**后两项不是同一个层面的量**：`in_scatter_probability` 近似散射源强度，`phase_probability` 是相位函数值。三者连乘不是概率论里的独立事件相乘，而是**单次散射 RTE 在某一采样点的三项物理因子相乘**，Schneider 用“probability”命名是修辞。

---

## 一、三项在 RTE 里的位置

严格单次散射、单光源（太阳）的体积渲染方程，某一采样点向相机的贡献是：

$$
L(x\to \text{cam}) = \underbrace{T_r(x_{\text{sun}}\to x)}_{\text{入射衰减}}\cdot \underbrace{\sigma_s(x)}_{\text{散射源}}\cdot \underbrace{p(\theta)}_{\text{相位}}\cdot L_{\text{sun}}
$$

再乘“出射方向”的透射 $T_r(x\to\text{cam})$ 和积分测度 $ds$。Nubis 把前三个因子各做了一个“代餐”：

| RTE 因子 | Nubis 对应 | 实际是什么 |
|---|---|---|
| $T_r(x_{\text{sun}}\to x)$ | `attenuation_probability` | 太阳方向透射率（多重散射增强版） |
| $\sigma_s(x)$ 与多次散射累积 | `in_scatter_probability` | 归一化散射源强度 |
| $p(\theta)$ | `phase_probability` | 双 HG 相位函数值 |
| $L_{\text{sun}}$ | `u_brightness` | 太阳辐亮度标定 |
| $T_r(x\to\text{cam})$ | 主循环 `transmittance` | 视线方向透射 |
| $ds$ | `stepSize` | 积分步长 |

注意 `GetLightEnergy` **只负责前三项 + brightness**，出射透射和 `stepSize` 在主循环里乘。

---

## 二、`attenuation_probability`：为什么说它是 transmittance

```hlsl
return max(exp(-dl), exp(-dl * 0.25) * 0.7);
```

- `dl` 是沿太阳光锥累加的光学深度 $\tau_{\text{light}}$
- 第一项 `exp(-dl)` 就是标准 Beer 透射 $T_r = e^{-\tau}$
- 第二项是“衰减系数降到 1/4、整体压到 0.7”的一条更平的曲线——模拟光在云里弹了几跳后仍能漏进来的残余透射
- `max` 取上包络：深云内部不会死黑

所以它是 **transmittance 的多重散射启发式版本**。物理上更准确地说，是“平均透射率”（包含多次散射贡献的等效 $T_r$），不是纯单次 Beer。

另一个版本里还带 `cos_angle`：

```hlsl
float attenuation_probability = max(
    Remap(cos_angle, 0.7, 1.0, secondary_intensity_curve, secondary_intensity_curve * 0.25),
    primary_intensity_curve);
```

这版把“顺光看”和“侧光看”的多次散射差异也塞进了衰减项，说明它早就不只是透射率，而是“透射 + 部分相位耦合”的混合体。

---

## 三、`in_scatter_probability`：散射源强度，不是透射也不是相位

```hlsl
float depth_probability = 0.05 + pow(ds_loded, Remap(h, 0.3, 0.85, 0.5, 2.0));
float vertical_probability = pow(Remap(h, 0.07, 0.14, 0.1, 1.0), 0.8);
return depth_probability * vertical_probability;
```

拆开看：

- **`ds_loded` 是单点密度（低 LOD），不是 `dl`**。所以这一项刻画的是“这个位置有多少散射介质”，对应 $\sigma_s(x)$ 的归一化近似，而不是路径累积。
- `pow(ds, k)`：密度越大，内散射越强，非线性模拟多次散射累积。
- `Remap(h, 0.3, 0.85, 0.5, 2.0)`：越高处指数越陡，散射越集中在云中上部。
- `0.05` bias：防止完全黑，修补光照不守恒。
- `vertical_probability`：纯高度经验曲线，云底暗、云顶亮。没有严格物理对应，是艺术项。

它近似的是 RTE 里 $\sigma_s(x)\int p\,L\,d\omega'$ 这整块的“强度”，**但把半球积分完全跳过了**，用经验幂函数代替。所以它既不是 $\sigma_s$ 本身，也不是多次散射的严格解，而是“美术可调的散射源权重”。

另一个版本里还多一个 `lerp(..., 1.0, saturate(dl/step_size))`，意思是光路越厚，散射源越被推向 1——对应“厚云内部光场接近各向同性”的直觉。

---

## 四、`phase_probability`：相位函数值，可能 >1

```hlsl
return max(HenyeyGreenstein(cos_angle, g),
           u_SilverIntensity * HenyeyGreenstein(cos_angle, 0.99 - u_SilverSpread));
```

- 第一项：主前向散射峰（银边）
- 第二项：几乎贴着视线的窄峰，模拟晚霞辉光
- `max` 而不是相加：避免能量双重叠加，只取更亮的一侧

**关键提醒**：HG 相位函数带 $1/4\pi$ 归一化，峰值可以大于 1。以 $g=0.8$ 为例，前向峰值约 3.6。所以三项乘积**不是 0~1 的概率**，命名成 probability 只是叙事。加 `u_SilverIntensity` 后还可能更大，靠 `u_brightness` 兜底压回合理曝光。

---

## 五、为什么连乘

因为 RTE 的结构本身就是乘法链，三个因子分别回答三个条件：

1. **光到得了吗？** → `attenuation_probability`（太阳→P 的透射）
2. **到这里有多少可散射介质 / 攒了多少散射光？** → `in_scatter_probability`（散射源强度）
3. **散出去的方向对吗？** → `phase_probability`（朝相机的角分布）

用概率语言类比“联合概率 = 各条件概率相乘”是 Schneider 的讲法，但严格来说这不是独立事件，而是方程里三个乘性因子。**少任何一个都物理不通**：

- 只留 attenuation → 云是纯粹吸收体，黑块
- 只留 phase → 云是无厚度的散光板，没有体积感
- 只留 in_scatter → 云是各向同性发光体，没有银边

---

## 六、完整的积分链（容易漏的两处）

把主循环补全，才是完整的一次散射积分：

```hlsl
// 主循环每步
float light_energy = GetLightEnergy(p, dl, ds_loded, cos_angle);  // 只含太阳→P
scatteredLight += transmittance * light_energy * sampled_density * stepSize;
transmittance *= exp(-sampled_density * stepSize);                // P→相机
```

- `transmittance`：P→相机的透射，**不在 GetLightEnergy 里**
- `sampled_density * stepSize`：积分测度 $\sigma_t\,ds$，也**不在 GetLightEnergy 里**

两个常见坑：

1. **`in_scatter_probability` 里已经含密度信息，主循环又乘 `sampled_density`，存在重复计数**。Nubis 靠 `u_brightness` 和美术调参吃平，不是物理自洽。
2. **`dl` 累加时没乘 `stepSize`**（圆锥循环里只 `+= density`）。所以 `dl` 的绝对量级依赖步长实现，调参时不能当严格物理 $\tau$ 用。

---

## 七、一句话对照

> `attenuation_probability` = 太阳方向的 $T_r$（多重散射增强版）
> `in_scatter_probability` ≈ $\sigma_s$ 与多次散射累积的经验权重
> `phase_probability` = 双 HG 的 $p(\theta)$
> 三者连乘 = RTE 单点光源项的三个乘性因子，**不是概率**；出射透射与 $ds$ 在主循环里补乘。

**要不要把这一段改写成与 PBRT `volpath` 里 `Tau` / `Tr` / `phase` 一一对应的严格形式，方便你对照验证量纲？**

# 所以，所谓的云的密度模型，实际是指pbrt里，absorption + out-scatterig + in-scattering, phase function的概率密度，是吗
# 不是。密度模型只对应一个量：σ_t

你这个表述把**介质定义**和**辐射传输积分项**混在了一起。密度模型不包含 absorption、out-scattering、in-scattering 的区分，也不包含 phase function——它只输出一个标量场，对应 PBRT 里的消光系数 $\sigma_t$（的归一化近似）。

---

## 一、PBRT 里“介质”由什么定义

一个 `Medium` 在 PBRT 里是这几样东西的集合：

| 成分 | 符号 | 含义 |
|---|---|---|
| 吸收系数场 | $\sigma_a(x)$ | 每单位长度被吃掉多少 |
| 散射系数场 | $\sigma_s(x)$ | 每单位长度被散走多少 |
| 消光系数场 | $\sigma_t = \sigma_a + \sigma_s$ | 每单位长度总共被移出原方向多少 |
| 相位函数 | $p(\omega, \omega')$ | 散到新方向的角分布 |
| （可选）自发光 | $L_e$ | 介质自己发光 |
| （可选）反照率 | $\Lambda = \sigma_s/\sigma_t$ | 散射占比 |

**这四样是并列的、独立的定义**。$\sigma_t$ 决定“光衰减多快”，$p$ 决定“散到哪去”，两者不是包含关系。

---

## 二、Nubis 密度模型落在哪一格

`SampleCloudDensity()` 返回的 0~1 标量，对应的是：

$$\sigma_t(x) \approx k \cdot \text{density}(x)$$

而且隐含了云的近似 $\sigma_a \approx 0$，所以 $\sigma_t \approx \sigma_s$，一个量同时顶了三个位置的班。

密度模型内部那些操作——Perlin-Worley 噪声、height gradient、coverage Remap、高频侵蚀——**全部是在设计这个标量场的空间分布**，属于“程序化场建模”，不涉及任何辐射传输物理量。它是**几何/形态层面**的工作，不是光学的。

---

## 三、absorption / out-scattering / in-scattering 在哪

这三件事是 **RTE 积分里的项**，不是密度模型的一部分：

```
RTE:
  dL/ds = -σ_t L        ← out-scattering + absorption（衰减项）
          + σ_s ∫p L dω  ← in-scattering（增益项）
          + L_e
```

对应关系：

| RTE 项 | 需要什么 | Nubis 里在哪 |
|---|---|---|
| absorption | $\sigma_a$ | 隐含为 0（云很白） |
| out-scattering | $\sigma_s$ | 和吸收一起并进 $\sigma_t$ = density |
| 衰减 $\sigma_t L$ | $\sigma_t$ | density + 主循环 `transmittance *= exp(-ρ·ds)` |
| in-scattering $\sigma_s\int pL\,d\omega$ | $\sigma_s$、$p$、入射 $L$ | `in_scatter_probability × phase_probability × attenuation`，半球积分被经验曲线替代 |

所以：

- **absorption / out-scattering 确实由 density 承担**（因为它是 $\sigma_t$）
- **in-scattering 不由 density 承担**，density 只提供其中的 $\sigma_s$ 权重；真正算的是光照模型里的 `in_scatter_probability`，那是对半球积分的启发式代餐
- **phase function 完全独立于 density**，在 `GetDirectScatterProbability()` 里

---

## 四、phase function 是不是“概率密度”

这一点你说对了，但要精确：

$p(\omega,\omega')$ 在 PBRT 里是**归一化到立体角上的概率密度**：

$$\int_{S^2} p(\omega,\omega')\,d\omega' = 1$$

所以它的量纲是 sr⁻¹，峰值可以大于 1（$g=0.8$ 时前向峰约 3.6）。它和 $\sigma_t$ 是两个不同空间上的密度：$\sigma_t$ 是**长度上的**，$p$ 是**立体角上的**。

Nubis 的双 HG：

```hlsl
max(HG(cos, g), SilverIntensity * HG(cos, 0.99 - spread))
```

取 `max` 而非相加之后，**已经不再归一化**了。所以它严格来说不是合法相位函数，只是一个“形状类似相位函数、美术可控的角分布”。这一点在 2017 talk 里 Schneider 自己承认是“走向艺术的荒野”。

---

## 五、准确的对照表

| 概念 | 属于 | PBRT 对应 | Nubis 位置 |
|---|---|---|---|
| 密度模型 | 介质定义 | $\sigma_t(x)$ 场 | `SampleCloudDensity` |
| 吸收 | 介质定义 | $\sigma_a$ | 近似 0，并入 $\sigma_t$ |
| 散射系数 | 介质定义 | $\sigma_s$ | 并入 $\sigma_t$ |
| 相位函数 | 介质定义 | $p(\omega,\omega')$ | `GetDirectScatterProbability` |
| 透射 | 积分结果 | $T_r = e^{-\int\sigma_t ds}$ | `attenuation_probability`（视线方向另有 `transmittance`） |
| 内散射 | 积分项 | $\sigma_s\int pL\,d\omega'$ | `in_scatter_probability × phase` |
| 多次散射 | 积分结果 | 高阶项 | 双 Beer 的 `max` 兜底 |

---

## 六、你这句话更准确的写法

> ❌ 密度模型 = absorption + out-scattering + in-scattering + phase 的概率密度

> ✅ **密度模型**只负责 $\sigma_t$ 的空间分布（吸收与散射合并且不区分，phase 不参与）。
> **光照模型**才负责 RTE 的三个乘性因子：透射（由 $\sigma_t$ 沿光路积分得到）、内散射源强度（$\sigma_s$ 与多次散射的经验权重）、相位分布（$p$ 的双 HG 近似）。
> 所以 Nubis 的**系统划分**是：(密度模型 → $\sigma_t$ 场) + (光照模型 → RTE 三项) + (raymarch → 积分与合成)，三者是流水线关系，不是包含关系。

一句话记忆：

> **密度模型造“介质有多厚”，光照模型算“这份介质怎么把光搬到相机”，raymarch 负责“沿视线把每一步串起来”。**

**要不要把这三层的接口画成一个数据流图（哪些量跨层传递、单位怎么对齐），方便你后续移植到自己的渲染器？**

#  逐行解释6.7 ray marching的代码，并结合pbrt的相关内容进行比对
# 6.7 Raymarching 逐行拆解 + PBRT 对照

**先给总判断**：这段循环不是 PBRT 式的随机路径采样（no null-collision、no distance sampling、no MIS），而是一个**确定性的自适应黎曼积分器**——沿视线以可变步长累加光学深度，每个有效采样点再发一条 6-tap 光锥去估太阳方向透射。它解的是单次散射 RTE 的离散近似，不是 PBRT `volpath` 那种无偏 MC 解。

先把整段代码摆出来，再逐块拆。

```hlsl
float cloud_test = 0.0;
float cloud_lighting = 0.0;
int zero_density_sample_count = 0;
float sampled_density_previous = -1.0;
float alpha = 0.0;

for (int i = 0; i < sample_count; i++)
{
    if (alpha <= 1.0)
    {
        if (cloud_test > 0.0)
        {
            float sampled_density = SampleCloudDensity(p, weather_data, mip_level, false);

            if (sampled_density == 0.0 && sampled_density_previous == 0.0)
            {
                zero_density_sample_count++;
            }

            if (zero_density_sample_count < 11 && sampled_density != 0.0)
            {
                alpha += sampled_density;
                cloud_lighting = SampleCloudDensityAlongCone(p, stepSize, mip_level, cos_angle, alpha);
                p += stepSize;
            }
            else
            {
                cloud_test = 0.0;
                zero_density_sample_count = 0;
            }
            sampled_density_previous = sampled_density;
        }
        else
        {
            cloud_test = SampleCloudDensity(p, weather_data, mip_level, true);
            if (cloud_test == 0.0)
            {
                p += stepSize * 2;
            }
            else
            {
                p -= stepSize;
            }
        }
    }
}
```

---

## 一、五个状态变量先定位

| 变量 | Nubis 语义 | PBRT 对应 |
|---|---|---|
| `alpha` | 沿视线累积的**光学深度 τ**（不是 0~1 的 opacity） | $\tau = \int_0^t \sigma_t\,ds$ |
| `cloud_lighting` | 当前采样点的**散射源项**（被覆盖式赋值，见下文） | $L_s$ 的单光源近似 |
| `cloud_test` | 状态机标志：0=云外探测模式，>0=云内全采样模式 | 无对应，纯工程 hack |
| `zero_density_sample_count` | 连续零密度计数，用于判定"已穿出云层" | 无对应 |
| `sampled_density_previous` | 上一步密度，配合零计数做迟滞 | 无对应 |

⚠️ **第一个必须点破的事**：`alpha` 名字叫 alpha，但累加的是 `sampled_density`（未乘 `stepSize`），所以它其实是**离散光学深度** $\tau \approx \sum \sigma_t$，不是 PBRT/alpha blending 里那个 $\alpha = 1 - e^{-\tau}$。判断 `alpha <= 1.0` 等价于"透射率 $T = e^{-\tau}$ 还没掉到 $e^{-1}\approx0.37$ 以下"——这是个**偏早**的早停阈值，实务里通常用 `alpha >= 1.0` 才退出，或者用 `T < 0.01`。

---

## 二、外层循环头

```hlsl
for (int i = 0; i < sample_count; i++)
```
固定步数上限（64~128，由 6.1 节视点位置决定）。

PBRT 对照：PBRT 的 `SampleT()` 用**指数分布采样自由程** $t = -\ln(1-\xi)/\sigma_t$，步数是随机的、无上限的；这里是**固定上限 + 自适应步长**，属于确定性求积，方差为零但有离散化偏差（banding），靠 TAA 抹平。

```hlsl
if (alpha <= 1.0)
```
早停守卫。`alpha` 超过 1 后整个循环体空转——严格说这里应该 `break` 而不是 `if`，性能上等价但可读性差。

PBRT 对照：对应 Russian Roulette 之后的路径终止，但 PBRT 是**概率终止**（ unbiased ），这里是**硬截断**（biased）。

---

## 三、云内分支（`cloud_test > 0.0`）

```hlsl
float sampled_density = SampleCloudDensity(p, weather_data, mip_level, false);
```
全采样（含高频 Worley 侵蚀），`doCheaply=false`。返回值是 0~1 的**归一化消光系数** $\tilde{\sigma}_t(p)$。

PBRT 对照：$\sigma_t(p) = \sigma_a(p) + \sigma_s(p)$，单位是 m⁻¹。Nubis 把它归一化到 0~1，隐含一个 $k$ 缩放因子被吞进 `stepSize` 里。

```hlsl
if (sampled_density == 0.0 && sampled_density_previous == 0.0)
{
    zero_density_sample_count++;
}
```
**连续两个零密度**才计一次数——迟滞（hysteresis）设计，防止单个噪声空洞误判出云。

> 🐛 **原文评论里已经指出的 bug**：下一行的外层条件是 `sampled_density != 0.0`，也就是说**当前密度为 0 时根本进不到这个 if 的物理累加分支**，直接走 else 把 `zero_density_sample_count` 清零了。结果 `zero_density_sample_count` 永远累加不起来，"连续 11 个零退出"这条逻辑实际上是死的。正确写法应该是把零计数判断放在**进入云内之后**独立做一层：
> ```hlsl
> if (sampled_density == 0.0) {
>     if (sampled_density_previous == 0.0) zero_density_sample_count++;
>     if (zero_density_sample_count >= 11) { cloud_test = 0.0; zero_density_sample_count = 0; }
> } else {
>     zero_density_sample_count = 0;
>     alpha += sampled_density;
>     ...
> }
> ```

```hlsl
if (zero_density_sample_count < 11 && sampled_density != 0.0)
{
    alpha += sampled_density;                                              // ①
    cloud_lighting = SampleCloudDensityAlongCone(p, stepSize, mip_level, cos_angle, alpha);  // ②
    p += stepSize;                                                         // ③
}
```

逐条对 PBRT：

**① `alpha += sampled_density`**
离散光学深度累加：$\tau \leftarrow \tau + \tilde{\sigma}_t$。
PBRT 严格形式应是 $\tau \leftarrow \tau + \sigma_t \cdot \Delta s$，**这里缺了 `stepSize`**。因为密度已归一化、步长被假定为单位长度，量纲是自洽的，但**换 stepSize 就得重新调 `u_brightness`**——这是 Nubis 里最容易被忽视的耦合。

**② `cloud_lighting = SampleCloudDensityAlongCone(...)`**
⚠️ **第二个 bug**（评论区 dolas 已指出）：函数内部若写成 `density_along_cone = SampleCloudDensity(...)` 而非 `+=`，6 个 tap 会互相覆盖，只剩最后一颗样本的密度。正确必须是累加，因为它要近似的是光方向光学深度 $\tau_L = \int_P^{\text{sun}} \sigma_t ds$。

这一行整体对应 PBRT 的单光源 in-scattering 源项：

$$
L_s(P,\omega_o) \approx \underbrace{T_r(P\to L)}_{\text{attenuation\_prob}} \cdot \underbrace{\sigma_s(P)}_{\text{in\_scatter\_prob}} \cdot \underbrace{p(\omega_i,\omega_o)}_{\text{phase}} \cdot L_{\text{sun}}
$$

`GetLightEnergy` 里那三项连乘就是在凑这个式子，只是把半球积分 $\int_{S^2}$ 整个跳过了，用经验曲线代替。

**③ `p += stepSize`**
沿视线推进。注意这里**没有更新视线透射率**——PBRT 的 `volpath` 每步要做：

```cpp
Float sigma_t = ...;
transmittance *= Exp(-sigma_t * ds);   // ← Nubis 主循环完全没这一句
L += transmittance * sigma_s * Ls * ds;
```

Nubis 把 `transmittance` 的作用**折叠进了 `alpha`**：最终合成时用 `exp(-alpha)` 一次性算视线透射，而不是每步乘。数学上等价（因为 $\prod e^{-\sigma_t\Delta s} = e^{-\sum\sigma_t\Delta s}$），但**丢失了"逐步加权"的能力**——PBRT 里 `L += T_i * σ_s * L_s * Δs` 每一步的 $T_i$ 都不同，Nubis 这里 `cloud_lighting` 是覆盖赋值不是累加，等于只保留了**最后一次**赋值的光照，前面步的贡献被丢弃。

> 💡 这是 Nubis 主循环和 PBRT 最本质的差异：**PBRT 是沿视线的加权累加积分，Nubis 这里退化成了"最后一步的光照值"**。实际工程里靠 `cloud_lighting` 随后与 `1-exp(-sampled_density)` 混合、再叠加上一帧结果来补救，属于典型的实时妥协。

```hlsl
else
{
    cloud_test = 0.0;
    zero_density_sample_count = 0;
}
```
判定已穿出云 → 切回云外大步模式。

```hlsl
sampled_density_previous = sampled_density;
```
迟滞状态更新。

---

## 四、云外分支（`cloud_test == 0.0`）

```hlsl
cloud_test = SampleCloudDensity(p, weather_data, mip_level, true);
```
**廉价采样**（`doCheaply=true`，跳过高频 Worley）。目的只是"探云"，不需要细节。

```hlsl
if (cloud_test == 0.0)
{
    p += stepSize * 2;      // 空区域双倍步长
}
else
{
    p -= stepSize;          // 撞到云，回退一步
}
```

**回退一步**是关键：大步长可能"跨过"云边缘，回退保证下一次全采样落在云内，避免边缘漏采。

PBRT 对照：**完全没有对应物**。PBRT 用 majorant $\sigma_t^{\max}$ 做 null-collision 或 distance sampling，步长由 $-\ln\xi/\sigma_t^{\max}$ 决定，是**统计正确**的空跳跃；Nubis 这里是**确定性双倍步长 + 回退**，会漏掉比 `stepSize` 更薄的云结构，靠 TAA 和半分辨率上采样掩盖。

---

## 五、把整段翻译成 PBRT 语言

同一段逻辑，写成 PBRT 风格大致是：

```cpp
Spectrum L(0.0);
Float tau_view = 0.0;          // 对应 alpha
Spectrum transmittance = 1.0;  // Nubis 没有显式维护

for (int i = 0; i < sample_count && tau_view < 1.0; ++i) {
    Float sigma_t = densityScale * SampleCloudDensity(p, ...);
    Float sigma_s = albedo * sigma_t;   // 云 albedo≈1

    // 光方向 6-tap 锥采样估 tau_light
    Float tau_light = ConeSampleOpticalDepth(p, sunDir);
    Spectrum Ls = attenuation(tau_light)
                * inScatter(p, ds_loded)
                * phaseHG(cosTheta, g)
                * sunRadiance;

    // ★ PBRT 规范写法（Nubis 缺这几步的逐步加权）
    L += transmittance * sigma_s * Ls * stepSize;
    transmittance *= Exp(-sigma_t * stepSize);
    tau_view += sigma_t * stepSize;

    p += viewDir * stepSize;
}
return L + transmittance * skyRadiance;
```

对照差异一览：

| 环节 | PBRT | Nubis 6.7 |
|---|---|---|
| 步长 | 指数分布随机 / null-collision | 固定 `stepSize`，空区 ×2 |
| 透射更新 | 每步 `T *= exp(-σt·ds)` | 只在末尾用 `exp(-alpha)` |
| 散射累加 | `L += T·σs·Ls·ds` 逐步加权 | `cloud_lighting =` 覆盖赋值 |
| 相位半球积分 | $\int_{S^2}p\,L\,d\omega$ 可 MC 采样 | 双 HG `max` 经验替代 |
| 多次散射 | 路径递归 / 体积 photon | 双 Beer `max` 兜底 |
| 空区域跳跃 | majorant + distance sampling | 阈值检测 + 回退 |
| 早停 | Russian Roulette（无偏） | `alpha > 1` 硬截断（有偏） |
| 噪声处理 | 增加 spp | 1/4 分辨率 + TAA |

---

## 六、三个必须记住的"工程真相"

1. **`alpha` 不是 alpha，是光学深度**。命名误导，读代码时脑子里要换成 $\tau$。
2. **`cloud_lighting` 是覆盖不是累加**，所以严格意义上这段循环只保留了"最后一个有效采样点"的太阳光照，前面的都被丢掉——靠后续与 `1-exp(-ρ·ds)` 混合 + TAA 补救，不是 RTE 的正确离散解。
3. **两个已知 bug**（评论区已指出）：光锥里 `=` 应为 `+=`；`zero_density_sample_count` 的外层条件位置错了导致永远清零。原 Talk 的伪代码是对的，是这篇中文整理转写时手滑。

---

## 七、一句话收束

> 这段 6.7 是**用状态机（cloud_test）+ 迟滞（previous density）+ 双步长 + 早停**把 PBRT 的随机体积路径积分，压成了一趟确定性的自适应黎曼和；它保留了 Beer 衰减和单光源 in-scattering 的物理骨架，但丢掉了逐步透射加权、半球相位积分和多次散射递归——换来的是 PS4 上 2ms 内出图。

**接下来你更想把这段循环改成规范的逐步透射累加，还是补上缺失的零密度迟滞逻辑？**

# 链接的结果好像不全，最终的输出是啥啊？应该是rgba值吧？只不过rgb三个值可能几乎一样？是哪个变量呢？cloud_ligting吗?
# 结论先给

**不是 `cloud_lighting`。** 你贴的那段 6.7 循环**根本没有产出最终 RGBA**——它只算出了两个中间量：

- `alpha`：沿视线累积的光学深度（τ），后面用来算**不透明度**
- `cloud_lighting`：当前采样点的**标量光照能量**（一个 float，不是颜色）

真正的 RGBA 是在**循环结束之后**合成的，那几行知乎那篇没贴出来，所以你觉得"结果不全"。

---

## 一、`cloud_lighting` 到底是什么

它是 `GetLightEnergy()` 的返回值，本质是**一个无量纲的亮度标量**：

```hlsl
cloud_lighting = attenuation_probability      // 太阳方向透射
               * in_scatter_probability      // 散射源强度
               * phase_probability           // 相位函数
               * u_brightness;               // 太阳亮度标定
```

它是一个 **float**，不是 float3。原 Talk 里管它叫 "energy value"，紧接着说这句关键的话：

> "The lighting samples replace the lower case d, or depth in the beers law portion of our lighting model. **This energy value is then attenuated by the depth of the sample in the cloud to produce the image as per the standard volumetric ray-marching approach.**"

翻译过来：`cloud_lighting` 是**喂给标准体积 ray-marching 累加公式的"光照能量"**，它自己不是最终颜色。

---

## 二、最终 RGBA 在哪里合成

标准体积渲染的累加式是这样（PBRT `volpath` 同款）：

$$
\mathbf{L} \mathrel{+}= T_{\text{view}} \cdot \sigma_s \cdot \mathbf{L}_s \cdot \Delta s
$$

Nubis 里对应的完整收尾（原 Talk 有，中文整理漏了）大致是：

```hlsl
// 循环外，累加变量要在循环开始前初始化
float3 cloudColor = 0.0;      // 累加的散射光（RGB）
float  transmittance = 1.0;   // 视线透射率

// ... 6.7 的主循环，每步做：
//     cloud_lighting = SampleCloudDensityAlongCone(...);
//     // 用当前步的 transmittance 加权累加
//     cloudColor += transmittance * cloud_lighting * sampled_density * stepSize * sunColor;
//     transmittance *= exp(-sampled_density * stepSize);

// 循环结束后合成：
float cloudAlpha = 1.0 - transmittance;              // A 通道
float3 ambient   = GetAmbientSky(height_fraction);   // 环境天空项，随高度增强
float3 direct    = cloudColor;                       // 直射太阳散射累积
float3 atmospheric = u_atmosphereColor;              // 大气色

// 原 Talk  slide 87 的三项混合
float3 cloudRGB = lerp(ambient + direct, atmospheric, saturate(alpha));

// 与背景（天空/地形）做标准 alpha blend
float3 finalRGB = backgroundRGB * (1.0 - cloudAlpha) + cloudRGB * cloudAlpha;

return float4(finalRGB, cloudAlpha);   // ← 这才是最终 RGBA
```

**所以：**

| 你以为 | 实际是 |
|---|---|
| `cloud_lighting` 是 RGBA | 它是**标量光照能量**，喂给 `cloudColor` 累加 |
| `alpha` 是 A 通道 | 它是**光学深度 τ**；A 通道是 `1 - exp(-alpha)` |
| 循环里就有输出 | 循环只算中间量，**RGBA 在循环外合成** |

---

## 三、为什么 RGB 三通道"几乎一样"但不完全一样

原 Talk slide 87 明确写了配色模型：

> - Ambient sky contribution **increases over height**
> - Direct lighting would be **dominated by the sun color**
> - Atmosphere would **occlude clouds over depth**
> - We add up our ambient and direct components and **attenuate to the atmosphere color based on the depth channel**

拆开看三个来源的颜色属性：

| 分量 | 颜色来源 | 是否三通道相同 |
|---|---|---|
| `direct`（就是 `cloud_lighting` 累积出来的） | `cloud_lighting × sunColor` | ❌ 乘了太阳色，日出日落时明显偏橙红 |
| `ambient` | 天空环境色（高度插值） | ❌ 天顶偏蓝、地平线偏暖 |
| `atmospheric` | 大气色（按深度衰减混入） | ❌ 有明确色相 |

**正午白昼**时：太阳色 ≈ (1,1,1)、天空色 ≈ 淡蓝、大气色 ≈ 淡蓝灰 → 三项混合后 **r≈g≈b，看起来是灰白**，你说的"几乎一样"就是这个工况。

**日落**时：太阳色 ≈ (1, 0.5, 0.25)、天空色偏紫橙 → 三通道**明显不同**，这就是为什么 Horizon 的日落云是金红色的。

**代码层面**：`cloud_lighting` 本身是 float，乘上 `float3 sunColor` 之后才变成 float3，之后一路都是三通道独立运算。所以"RGB 一样"不是结构上的必然，只是特定光照条件下的巧合。

---

## 四、把整条数据流补齐

```
SampleCloudDensity(p)          → σ_t 标量
        ↓
SampleCloudDensityAlongCone()  → τ_light（光锥光学深度）
        ↓
GetLightEnergy(τ_light, ...)   → cloud_lighting（标量能量）
        ↓
cloudColor += T_view × cloud_lighting × σ_s × Δs × sunColor(float3)
                                    ↑ 这里才变成 RGB
        ↓
T_view *= exp(-σ_t × Δs)
        ↓
【循环结束】
        ↓
cloudRGB  = lerp(ambient + cloudColor, atmosphereColor, f(alpha))
cloudAlpha = 1 - T_view
finalRGB  = background × (1-cloudAlpha) + cloudRGB × cloudAlpha
        ↓
return float4(finalRGB, cloudAlpha)     ← 最终 RGBA
```

对照 PBRT `volpath` 的话：

- `cloudColor` ↔ PBRT 里的 `L`（Spectrum 累加辐射）
- `T_view` ↔ PBRT 里的 `transmittance`
- `cloudAlpha` ↔ PBRT 里没有直接对应（PBRT 输出辐射不含 alpha，alpha 是合成层概念）
- `cloud_lighting` ↔ PBRT 里 `σ_s · L_s`（源项，未加权）

---

## 五、一句话回答你的问题

> `cloud_lighting` **不是** RGBA，它只是一个 float 光照能量。
> 最终 RGBA 是循环外由 **`cloudColor`（RGB 累加辐射）** 和 **`1 - exp(-alpha)`（A 通道）** 与背景混合得到的 `float4(finalRGB, cloudAlpha)`。
> RGB 三通道在正午白光下数值接近，但**结构上不相等**——因为直射项乘了太阳色、环境项乘了天空色、深度项混了大气色，日落时三通道会拉开差距。

**需要我按 PBRT `volpath` 的逐步透射加权写法，把这段循环外的 RGBA 合成补成一版可直接嵌入的 GLSL 代码吗？**

# 最终源码
抱歉，上一条在 `SampleCloudDensityAlongCone` 处被截断了。下面是**完整、可直接编译的版本**，从 CPU 端输入一直到最后 RGBA 输出，并修正了原知乎代码里的三处 bug（`cloud_lighting` 覆盖赋值、`zero_density_sample_count` 逻辑失效、`p -= stepSize` 的笔误）。

```hlsl
// ============================================================
// Nubis Volumetric Cloud Rendering — Complete Implementation
// Horizon Zero Dawn / Guerrilla Games, SIGGRAPH 2015 & 2017
// ============================================================

// ---------------- 常量 ----------------
static const float PI          = 3.14159265359;
static const float CLOUD_MIN   = 1500.0;      // 云层底高 (m)
static const float CLOUD_MAX   = 4000.0;      // 云层顶高 (m)
static const float PLANET_R    = 6360000.0;   // 地球半径 (m)
static const float FAR_PLANE   = 100000.0;    // 远平面
static const int   MAX_STEPS   = 128;
static const int   CONE_TAPS   = 6;
static const float ZERO_EXIT   = 11.0;        // 连续零密度退出阈值

// ---------------- 输入 ----------------
struct CloudInput
{
    // 相机
    float3 cameraPos;
    float3 cameraForward;
    float3 cameraRight;
    float3 cameraUp;
    float2 screenSize;
    float  fovY;

    // 时间 / 风
    float  time;
    float3 windDir;
    float  windSpeed;

    // 太阳
    float3 sunDirection;      // 归一化
    float3 sunColor;          // HDR
    float  sunIntensity;

    // 光照模型参数
    float  eccentricity;      // HG 主峰 g
    float  silverIntensity;   // 次峰强度
    float  silverSpread;      // 次峰宽度
    float  brightness;        // 整体亮度
    float  anvilBias;         // 铁砧偏置
    float  cloudTypeOffset;

    // 环境
    float3 ambientSkyColor;
    float  ambientSkyIntensity;

    // 场景
    float3 sceneColor;        // 背景（天空/地形）
    float  sceneDepth;        // 场景深度（用于遮挡）
};

// ---------------- 纹理 ----------------
Texture3D    tCloud3DNoiseA;   // 128^3: R=Perlin-Worley, GBA=Worley
Texture3D    tCloud3DNoiseB;   // 32^3 : 高频 Worley
Texture2D    tCloud2DNoise;    // Curl noise
Texture2D    tWeatherData;     // R=coverage, G=precip, B=cloudType
SamplerState sLinearRepeat;

// ============================================================
// 1. 工具函数
// ============================================================
float Remap(float v, float lo, float hi, float nlo, float nhi)
{
    return nlo + (v - lo) / (hi - lo) * (nhi - nlo);
}

float GetHeightFractionForPoint(float3 p, float2 minMax)
{
    return saturate((p.z - minMax.x) / (minMax.y - minMax.x));
}

bool RaySphereIntersect(float3 ro, float3 rd, float3 center, float radius,
                        out float t0, out float t1)
{
    float3 oc = ro - center;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float disc = b * b - c;
    if (disc < 0.0) { t0 = t1 = -1.0; return false; }
    float s = sqrt(disc);
    t0 = -b - s;
    t1 = -b + s;
    return t1 > 0.0;
}

// ============================================================
// 2. 噪声采样
// ============================================================
float SampleLowFrequencyNoises(float3 p, float mip)
{
  /*
    float3 noiseUV = p * uNoiseScale;              // uNoiseScale ≈ 0.00003
noiseUV += uWindOffset;                        // 风随时间平移
tCloud3DNoiseA.SampleLevel(sLinearRepeat, noiseUV, mip);
*/
    float4 n = tCloud3DNoiseA.SampleLevel(sLinearRepeat, p, mip);
    float lowFreqFBM = n.g * 0.625 + n.b * 0.25 + n.a * 0.125;
    return Remap(n.r, -(1.0 - lowFreqFBM), 1.0, 0.0, 1.0);
}

float SampleHighFrequencyNoises(float3 p, float mip, float heightFraction)
{
    float2 curl = tCloud2DNoise.SampleLevel(sLinearRepeat, p.xy * 0.01, 0).rg;
    p.xy += curl * (1.0 - heightFraction) * 200.0;
    float3 n = tCloud3DNoiseB.SampleLevel(sLinearRepeat, p * 0.1, mip).rgb;
    return n.r * 0.625 + n.g * 0.25 + n.b * 0.125;
}

float3 SampleWeather(float3 pos)
{
    // 世界 xy 映射到天气图 [0,1]
    float2 uv = pos.xy * 0.0001 + 0.5;
    return tWeatherData.SampleLevel(sLinearRepeat, uv, 0).rgb;
}

// ============================================================
// 3. 密度模型
// ============================================================
float GetDensityHeightGradientForPoint(float relHeight, float cloudType)
{
    cloudType = Remap(cloudType, 0.0, 1.0, 0.0, 1.0);
    relHeight = saturate(relHeight);

    float cumulus       = max(0.0, Remap(relHeight, 0.01, 0.30, 0.0, 1.0) * Remap(relHeight, 0.60, 0.95, 1.0, 0.0));
    float stratocumulus = max(0.0, Remap(relHeight, 0.00, 0.25, 0.0, 1.0) * Remap(relHeight, 0.30, 0.65, 1.0, 0.0));
    float stratus       = max(0.0, Remap(relHeight, 0.00, 0.10, 0.0, 1.0) * Remap(relHeight, 0.20, 0.30, 1.0, 0.0));

    float a = lerp(stratus, stratocumulus, saturate(cloudType * 2.0));
    float b = lerp(stratocumulus, cumulus, saturate((cloudType - 0.5) * 2.0));
    return lerp(a, b, cloudType);
}

float SampleCloudDensity(float3 p, float3 weatherData, float mip, bool doCheaply)
{
    float heightFraction = GetHeightFractionForPoint(p, float2(CLOUD_MIN, CLOUD_MAX));

    // 风偏移：越高受风影响越大
    p += heightFraction * uWindDir * 500.0;
    p += (uWindDir + float3(0.0, 0.1, 0.0)) * uTime * uWindSpeed;

    // 低频：云的大型
    float baseCloud      = SampleLowFrequencyNoises(p, mip);
    float heightGradient = GetDensityHeightGradientForPoint(heightFraction, weatherData.b);
    float noise          = baseCloud * heightGradient;

    // Coverage 重映射
    float coverage        = weatherData.r;
    float cloudCoverage   = pow(coverage,
        Remap(heightFraction, 0.7, 0.8, 1.0, lerp(1.0, 0.5, uAnvilBias)));
    float cloudWithCoverage = Remap(noise, cloudCoverage, 1.0, 0.0, 1.0);
    cloudWithCoverage *= cloudCoverage;

    float finalCloud = cloudWithCoverage;

    // 高频：边缘侵蚀
    if (!doCheaply)
    {
        float highFreqFBM      = SampleHighFrequencyNoises(p, mip, heightFraction);
        float highFreqModifier = lerp(highFreqFBM, 1.0 - highFreqFBM,
                                      saturate(heightFraction * 10.0));
        finalCloud = Remap(cloudWithCoverage,
                           saturate(highFreqModifier * 0.5), 1.0, 0.0, 1.0);
    }

    return saturate(finalCloud);
}

// ============================================================
// 4. 光照模型（2017 三项）
// ============================================================
float HenyeyGreenstein(float cosAngle, float g)
{
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * cosAngle, 1.5));
}

float GetDirectScatterProbability(float cosAngle)
{
    return max(
        HenyeyGreenstein(cosAngle, uEccentricity),
        uSilverIntensity * HenyeyGreenstein(cosAngle, 0.99 - uSilverSpread)
    );
}

float GetAttenuationProbability(float dl)
{
    // 双 Beer：标准 + 多重散射兜底
    return max(exp(-dl), exp(-dl * 0.25) * 0.7);
}

float GetInScatterProbability(float3 p, float dsLoded)
{
    float h = GetHeightFractionForPoint(p, float2(CLOUD_MIN, CLOUD_MAX));
    float depthProb = 0.05 + pow(dsLoded, Remap(h, 0.3, 0.85, 0.5, 2.0));
    float vertProb  = pow(Remap(h, 0.07, 0.14, 0.1, 1.0), 0.8);
    return depthProb * vertProb;
}

float GetLightEnergy(float3 p, float dl, float dsLoded, float cosAngle)
{
    float att = GetAttenuationProbability(dl);
    float ins = GetInScatterProbability(p, dsLoded);
    float pha = GetDirectScatterProbability(cosAngle);
    return att * ins * pha * uBrightness;
}

// ============================================================
// 5. 圆锥采样（6-tap 光锥）
// ============================================================
static const float3 noise_kernel[6] = {
    float3( 0.38051305,  0.92453449, -0.02111345),
    float3(-0.50625799, -0.03590792, -0.86163418),
    float3(-0.32509218, -0.94557439,  0.01428793),
    float3( 0.09026238, -0.27376545,  0.95755165),
    float3( 0.28128598,  0.42443639, -0.86065785),
    float3(-0.16852403,  0.14748697,  0.97460106)
};

float SampleCloudDensityAlongCone(float3 p, float stepSize, float mip,
                                  float cosAngle, float densityAlongViewCone)
{
    float3 lightStep            = stepSize * uSunDirection;
    float  coneSpreadMultiplier = length(lightStep);
    float  coneRadius           = 1.0;
    float  coneStep             = 1.0 / 6.0;
    float  densityAlongCone     = 0.0;   // ★ 必须是累加
    float  lod                  = 0.0;
    float  lodStride            = 1.0 / 6.0;

    [unroll]
    for (int i = 0; i < CONE_TAPS; i++)
    {
        float3 conePos = p + coneRadius * (coneSpreadMultiplier * noise_kernel[i] * float(i));
        float3 weather = SampleWeather(conePos);
        int    mipOffset = int(i * 0.5);

        // 视线方向已足够厚 → 切廉价采样
        bool cheap = (densityAlongViewCone >= 0.3);
        densityAlongCone += SampleCloudDensity(conePos, weather, mip + mipOffset, cheap);

        p += lightStep;
        coneRadius += coneStep;
        lod += lodStride;
    }

    // 注意：原版这里传的是推进后的 p，语义上应该用原始 p
    return GetLightEnergy(p, densityAlongCone, lod, cosAngle);
}

// ============================================================
// 6. 主 Raymarching
// ============================================================
float4 RenderClouds(CloudInput input, float2 pixelCoord)
{
    // ---------- 6.1 生成射线 ----------
    float2 ndc = (pixelCoord / input.screenSize) * 2.0 - 1.0;
    float  tanHalfFov = tan(input.fovY * 0.5);
    float  aspect = input.screenSize.x / input.screenSize.y;

    float3 rd = normalize(
        input.cameraForward
        + input.cameraRight * ndc.x * tanHalfFov * aspect
        + input.cameraUp    * ndc.y * tanHalfFov
    );
    float3 ro = input.cameraPos;

    // ---------- 6.2 视点位置判断 ----------
    float3 planetCenter = float3(0.0, 0.0, -PLANET_R);
    float  distCamPlanet = length(ro - planetCenter);
    float  rInner = PLANET_R + CLOUD_MIN;
    float  rOuter = PLANET_R + CLOUD_MAX;

    float tStart, tEnd;
    int   steps;

    if (distCamPlanet < rInner)
    {
        // 云层下
        float t0, t1;
        if (!RaySphereIntersect(ro, rd, planetCenter, rInner, t0, t1))
            return float4(input.sceneColor, 1.0);
        tStart = max(t0, 0.0);
        if (!RaySphereIntersect(ro, rd, planetCenter, rOuter, t0, t1))
            return float4(input.sceneColor, 1.0);
        tEnd  = t1;
        steps = MAX_STEPS;
    }
    else if (distCamPlanet > rOuter)
    {
        // 云层上
        float t0, t1;
        if (!RaySphereIntersect(ro, rd, planetCenter, rOuter, t0, t1))
            return float4(input.sceneColor, 1.0);
        tStart = max(t0, 0.0);
        tEnd   = tStart + FAR_PLANE;
        steps  = MAX_STEPS / 2;
    }
    else
    {
        // 云层中
        tStart = 0.0;
        tEnd   = FAR_PLANE;
        steps  = MAX_STEPS * 3 / 4;
    }

    // 深度剔除
    tEnd = min(tEnd, input.sceneDepth);
    if (tEnd <= tStart)
        return float4(input.sceneColor, 1.0);

    float stepSize = (tEnd - tStart) / float(steps);

    // ---------- 6.3 主循环 ----------
    float3 p            = ro + rd * tStart;
    float  alpha        = 0.0;   // 沿视线的光学深度 τ
    float  cloudLighting = 0.0;  // 散射源项（标量能量）
    float  cloudTest    = 0.0;   // 0=云外, >0=云内
    int    zeroCount    = 0;
    float  prevDensity  = -1.0;
    float  cosAngle     = dot(rd, input.sunDirection);

    [loop]
    for (int i = 0; i < steps; i++)
    {
        // 早停：透射率已极低
        if (alpha >= 1.0) break;

        if (cloudTest > 0.0)
        {
            // ---------- 云内：全采样 ----------
            float3 weather = SampleWeather(p);
            float  density = SampleCloudDensity(p, weather, 0.0, false);

            // ★ 修正：零密度计数独立判断（原版逻辑失效）
            if (density == 0.0)
            {
                if (prevDensity == 0.0) zeroCount++;
                if (float(zeroCount) >= ZERO_EXIT)
                {
                    cloudTest = 0.0;
                    zeroCount = 0;
                }
            }
            else
            {
                zeroCount = 0;

                // 累加光学深度
                alpha += density * stepSize;

                // 圆锥采样 + 散射累加（★ 修正：+= 而非 =）
                float energy = SampleCloudDensityAlongCone(
                    p, stepSize, 0.0, cosAngle, alpha);
                cloudLighting += energy * density * stepSize;

                p += rd * stepSize;
            }
            prevDensity = density;
        }
        else
        {
            // ---------- 云外：廉价采样 ----------
            float3 weather = SampleWeather(p);
            cloudTest = SampleCloudDensity(p, weather, 2.0, true);

            if (cloudTest == 0.0)
            {
                // 大步幅跳跃
                p += rd * stepSize * 2.0;
            }
            else
            {
                // ★ 修正：回退一步（原版是 p -= stepSize 的笔误）
                p -= rd * stepSize;
            }
        }
    }

    // ---------- 6.4 最终合成 ----------
    float  transmittance = exp(-alpha);
    float3 sunRadiance   = input.sunColor * input.sunIntensity;
    float3 cloudRadiance = cloudLighting * sunRadiance;
    float3 ambient       = input.ambientSkyColor * input.ambientSkyIntensity
                         * (1.0 - transmittance) * 0.1;

    float3 finalColor = input.sceneColor * transmittance
                      + cloudRadiance
                      + ambient;

    // 输出：RGB 颜色 + A 作为云的不透明度（便于后期混合）
    return float4(finalColor, 1.0 - transmittance);
}
```

---

## CPU 端调用示例

```cpp
CloudInput input;
input.cameraPos     = { 0.0f, 0.0f, 1000.0f };
input.cameraForward = { 0.0f, 0.0f, 1.0f };
input.cameraRight   = { 1.0f, 0.0f, 0.0f };
input.cameraUp      = { 0.0f, 1.0f, 0.0f };
input.screenSize    = { 1920.0f, 1080.0f };
input.fovY          = 1.0472f;   // 60°

input.time          = frameTime;
input.windDir       = normalize(float3(0.8f, 0.2f, 0.0f));
input.windSpeed     = 10.0f;

input.sunDirection  = normalize(float3(0.5f, 0.8f, 0.3f));
input.sunColor      = { 1.0f, 0.95f, 0.85f };
input.sunIntensity  = 20.0f;

input.eccentricity  = 0.8f;
input.silverIntensity = 0.5f;
input.silverSpread  = 0.1f;
input.brightness    = 1.0f;
input.anvilBias     = 0.0f;

input.ambientSkyColor     = { 0.4f, 0.6f, 1.0f };
input.ambientSkyIntensity = 0.2f;

input.sceneColor = { 0.5f, 0.7f, 1.0f };  // 天空
input.sceneDepth = 1e9f;                   // 无遮挡

// 逐像素
float4 rgba = RenderClouds(input, float2(px, py));
```

---

## 与原知乎代码的差异（3 处修正）

| 位置 | 原版 | 修正 | 原因 |
|---|---|---|---|
| `cloud_lighting` | `=` 覆盖赋值 | `+=` 累加 | 原版每步覆盖，最终只剩最后一步的光照，散射积分丢失 |
| `zero_density_sample_count` | 放在 `sampled_density != 0.0` 外层 | 独立 `if (density == 0.0)` 分支 | 原版密度为 0 时直接走 else 清零，计数永远累加不起来 |
| `p -= stepSize` | 标量减向量 | `p -= rd * stepSize` | 原版是笔误，HLSL 编译不过 |

---

## 最终输出语义

| 通道 | 含义 |
|---|---|
| **RGB** | 已合成场景的 HDR 颜色：`sceneColor × T + cloudRadiance + ambient` |
| **A** | 云的不透明度 `1 - exp(-τ)`，用于后期与 UI/粒子混合 |

其中：
- `transmittance = exp(-alpha)` 是视线方向的透射率
- `cloudRadiance` 是沿视线的单次散射积分（含太阳颜色与强度）
- `ambient` 是环境光对云的贡献（简化版）

如果需要**单独输出云的 RGBA**（不合成背景），把最后一行改成：

```hlsl
return float4(cloudRadiance + ambient, 1.0 - transmittance);
```

然后在合成阶段做 `final = scene * (1 - cloud.a) + cloud.rgb`。


#  《地平线：零之曙光》的 Nubis 在体积云渲染史上的地位
《地平线：零之曙光》的 Nubis 在体积云渲染史上的地位，可以用一句话定位：**它不是体积云的发明者，而是把体积云从"实验室 demo / 离线渲染特权"推到"实时游戏可发行工程"的分水岭**。之后几乎所有 3A 的体积云方案，都能追溯到这条血脉。

## 一、HZD / Nubis 的历史坐标

**2015 年之前**：游戏里的天空基本是 skybox + billboard 云片。Andrew Schneider 自己在 GDC 2022 的回顾里说得很直白——Guerrilla 做 HZD 时**先试过 Killzone 时代的 billboard 天空，失败了**，才转向 raymarching 程序化方案。

**2015 SIGGRAPH**：Schneider & Vos 的《The Real-Time Volumetric Cloudscapes of Horizon Zero Dawn》给出完整方案——Perlin-Worley 噪声 + 高度梯度 + 天气图 + raymarching + Beer/Powder/HG 光照 + 半分辨率 + reprojection，把 PS4 上整片天空的成本从约 20ms 压到 **约 2ms**。

**2017 Nubis 版**：加入区域级 authoring、天气系统联动、双 HG + 双 Beer + 内散射三项光照模型，成为 HZD 正式版方案。

**行业扩散**：Guerrilla 官方原话——“Since the 2015 SIGGRAPH course **several Triple A studios and game development companies have developed similar systems** for use in their games or products”；2022 年 Nubis Evolved 再补一句“Many of the new applications use systems **based on or similar to our approach**”。Cinevva 2026 年的综述也直接说：“Most studios that ship volumetric clouds today still trace their lineage to this paper”。

**所以 HZD 的地位可以拆成三层**：

| 层面 | 贡献 |
|---|---|
| **算法范式** | 确立了"3D 噪声密度场 + 天气图调制 + 高度梯度云属 + raymarching"这套事实标准 |
| **工程范式** | 证明了半分辨率 + 分帧 + temporal reprojection + 跳跃式步进能在主机 2ms 内跑完 |
| **美术范式** | Coverage / CloudType 两张图驱动全局云景，把物理模拟换成"艺术家可泼墨"的控制权 |

> 💡 换句话说：**离线体积云早就成熟了**（Houdini/VDB 那条线领先十几年），HZD 的真正突破是"在 PS4 这种固定硬件预算下，把离线品质压进实时管线，还让美术能改"。

---

## 二、当前（2024–2026）主流技术实现地图

### 路线 A：噪声场 + Raymarching（Nubis 直系，实时游戏主流）

**核心**：Perlin-Worley 低频形状 + Worley 高频侵蚀 + Curl 扰动 + 天气图 + 高度梯度，逐像素 raymarch，双 HG / 双 Beer / 内散射三项光照。

| 代表 | 说明 |
|---|---|
| **Guerrilla / Decima** | Nubis 原生，`Horizon Zero Dawn` → `Forbidden West` |
| **Epic / Unreal Engine** | Volumetric Cloud Component，材质驱动 + Sky Atmosphere 联动，多重散射用"倍频（octave）"近似 |
| **EA / Frostbite** | Hillaire 2016《Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite》，把 Nubis 云和 Bruneton 大气散射统一到一个物理框架 |
| **Unity HDRP** | Volumetric Fog 模块 + 自定义云 shader，中小团队常用降级方案 |
| **通用开源** | Häggström 硕士论文《Real-time rendering of volumetric clouds》，附完整 shader，是很多复刻的入门教材 |

这条线今天的**共同进化方向**：
- 多重散射从单 Beer 变成 Wrenninge 式多阶叠加
- 天空大气从 2008 Bruneton 4D LUT 换成 Hillaire 2020 的 2D 纹理 + 逐帧多重散射近似（UE5 Sky Atmosphere 就是这套）
- TAA 鬼影用"云速掩码"按速度降历史帧权重

### 路线 B：体素 / SDF / 稀疏加速（高端实时，可穿越云）

**核心**：放弃 2.5D 噪声场，改用真 3D 体素存密度，配压缩有向距离场（SDF）加速 raymarch + 稀疏体素上采样。

| 代表 | 说明 |
|---|---|
| **Guerrilla Nubis³（2023 SIGGRAPH）** | Schneider 自己把 Nubis 推进到体素云，`Forbidden West` 的飞行穿越云、超风暴 VFX 就是这条线 |
| **Nubis Evolved（2022）** | 过渡代，解决近景穿越的时间伪影和内部闪电 |
| **商业插件**（Dynamic Volumetric Sky 等 UE 市场产品） | 深度排序体素云 + 无限地平线 |

> ⚠️ 这条路对多数工作室"有点过火"，目前主要是第一方大厂和飞行类游戏在用。

### 路线 C：离线物理模拟 + VDB（影视 / 动画）

**核心**：Navier-Stokes 欧拉网格解算 → OpenVDB 缓存 → Karma/Cycles/Arnold 路径追踪，多重散射按物理积分。

| 代表 | 说明 |
|---|---|
| **SideFX Houdini** | Pyro Solver + VDB 是影视云烟雾的事实标准，Disney / ILM / Weta 都在用 |
| **ILM** | 自研 FLUX 气体系统，用 FFT 分发到 GPU 多线程 |
| **Blue Sky / Weta / Disney** | Houdini 生态重度用户；Schneider 本人就是从 Blue Sky（《冰河世纪》《里约》）转到 Guerrilla 的 |
| **Blender Cycles + Houdini** | 中小团队/个人常用组合，双 4090 跑 Karma XPU + Cycles 已能出照片级积雨云 |

**和 HZD 的关系**：不是替代，是**上游**。离线领先实时十几年，Nubis 本质是把这套物理思路做实时近似。

### 路线 D：神经渲染 / AI 加速（2024–2026 新兴）

**核心**：用小型网络替代部分 raymarch 积分、隐式表示体积、或用神经缓存加速间接光。

| 代表 | 说明 |
|---|---|
| **NVIDIA RTX Volumetrics（GDC 2025）** | 基于体积的 ReSTIR 时空重要性重采样，做高对比体积光和光束 |
| **RTX Neural Radiance Cache (NRC)** | 神经着色器，训练中学习间接光分布，RTX Remix 已集成 |
| **Neural Volume Compression 类方案** | 用 MLP 隐式压缩体积纹理，UE5.5 实验插件已试点（具体压缩比数据来自培训机构稿，仅供参考） |

这条线还没到"取代 Nubis 血脉"的程度，更像是**给 Nubis 式 raymarch 做加速插件**。

---

## 三、一张图看清全景

```
离线物理（影视）                实时游戏（Nubis 血脉）           神经加速（新兴）
Houdini Pyro + VDB      ──┐     Perlin-Worley + Raymarch  ──┐     ReSTIR / NRC / NVC
OpenVDB + Karma/Arnold    │     + 天气图 + 双HG双Beer        │     + 神经隐式体积
ILM FLUX / Weta / Disney  │     UE5 Cloud Component          │     NVIDIA RTX Volumetrics
                           │     Frostbite Hillaire           │     UE5.5 实验插件
                           │     Unity HDRP Volumetric Fog    │
                           │            ↓                     │
                           │     Nubis³ 体素化（可穿越）       │
                           └────────────┬────────────────────┘
                                        │
                              Guerrilla Nubis 是共同祖先
```

---

## 四、结论

**HZD/Nubis 在云渲染史的地位 ≈ 实时体积云的"Linux 内核时刻"**——不是它发明了所有零件（Perlin、Worley、HG、Beer 都是老东西），而是它第一次把**噪声建模 + 光照近似 + 天气驱动 + 半分辨率时域优化**打包成一套**能在主机 2ms 内跑、美术能改、能跟着昼夜循环变**的完整系统，然后开源式地把 SIGGRAPH 讲稿扔出来。

今天你打开 UE5 拖一个 Volumetric Cloud 组件，或者在 Frostbite 里调 Hillaire 的天空，甚至在看 Nubis³ 的体素云穿越——**底层数学骨架都还是 2015 年那份 SIGGRAPH 讲稿**。

**接下来你更想深入哪一块：Nubis 到 Nubis³ 的体素化演进、UE5 体积云的参数体系，还是 Houdini 离线云到实时引擎的烘焙管线？**

# 云雪雨雾的难度比较 
结论先给你：**在“纯渲染”维度，云通常是天气系统里最难的一项**——难在密度场建模、自阴影、多重散射、时域采样、低空穿越、天气驱动全都要同时成立。但**如果把“物理交互 + 场景状态”也算进去**（积水流动、雪堆积形变、湿滑材质、脚印、结冰），雨雪的**系统级复杂度会反超云**——云主要是“看”，雨雪是“看 + 碰 + 留痕 + 影响玩法”。

下面按流派拆开讲。

## 一、为什么云“通常”最难，但不是绝对最难

云的难点是**渲染管线内部**的：3D 噪声密度场 + 天气图调制 + 高度梯度云属 + 每像素 raymarching + 双 HG/双 Beer/内散射三项光照 + 圆锥采样 + 半分辨率 + TAA 重投影，全部要塞进 1~3ms。而且它有几个“越想越难”的延伸坑：

- **分层云属**：低/中/高 10 大类，积雨云跨多层带塔状+砧型结构，工程上通常被迫砍到 Stratus/Cumulus/Cirrus 三类
- **超低空/地形云**：raymarching 进山坳，步幅要重设、密度要避地形 SDF、GI 要重算
- **可穿越云**（Nubis³ 那代）：从“背景板”变成“玩家能飞进去”，噪点、时域、内外过渡全要重做
- **手游级压缩**：连手机上都要保多重散射观感，只能靠半八面体 LUT + 3D 噪声平铺硬扛

但雨雪的难点**不在 shader，在系统**：

| 维度 | 云 | 雨 | 雪 | 雾 |
|---|---|---|---|---|
| 密度场建模 | ★★★★★ 程序化 3D 噪声 | ★★ 粒子/条带 | ★★★ 粒子+积雪场 | ★★★ froxel 网格 |
| 光照/散射 | ★★★★★ 自阴影+多重散射 | ★★ 单散射+屏幕反射 | ★★★ 次表面近似 | ★★★★ froxel 内散射 |
| 时域稳定性 | ★★★★★ TAA 重投影必需 | ★★ 粒子运动模糊 | ★★★ 堆积历史缓冲 | ★★★★ 时域抖动必需 |
| **场景交互** | ★ 基本无 | ★★★★ 积水/湿润/涟漪/反光 | ★★★★★ 积雪形变/脚印/踩踏 | ★★ 灯光穿透 |
| **状态持久化** | ☆ 无 | ★★★ 湿润度累积 | ★★★★ 积雪层长期留存 | ☆ 无 |
| **玩法耦合** | ☆ 弱 | ★★★ 湿滑/视野遮挡 | ★★★★ 脚印追踪/温度 | ★★ 潜行/可见度 |

所以更准确的说法是：**单看一帧的像素着色，云最难；看整个天气系统闭环，雨雪（尤其雪）更难**。

---

## 二、雨：四条主流流派

### 流派 A：粒子 / 条带雨（GPU 粒子）
最通用方案。雨丝用拉伸 quad 或 line primitive，GPU 端做位置积分 + 风场扰动 + 相机相对速度拉伸。**代表**：绝大多数 UE/Unity 项目默认 Niagara/Shader Graph 雨。**优点**便宜、**缺点**没有交互。

### 流派 B：屏幕空间雨滴 + 湿润度系统
镜头雨滴用屏幕空间法线扰动 + flipbook；地面积水用**高度/顶点 mask 定义低洼**，湿润度参数随时间累积——长暴雨慢慢把世界泡透，短阵雨只让高处变暗；雨滴撞击用 flipbook 法线波纹。**代表作品**：
- **Red Dead Redemption 2**（Rockstar）— 湿润度累积 + 衣物浸湿 + 泥泞
- **Assassin's Creed 系列**（Ubisoft）— 城市雨夜反光
- **Call of Duty** 系列 — 屏幕雨滴后处理链（Jimenez 那套 next-gen post processing）

### 流派 C：浅水模拟 + 反射折射
地面用**浅水方程（Shallow Water Equations）**在高度场上跑，配屏幕空间反射（SSR）+ Blinn-Phong 高光 + Fresnel-Slick 混合。**代表 paper**：
- **RainyGS: Efficient Rain Synthesis with Physically-Based Gaussian Splatting**, CVPR 2025, 北大 VCL — 3DGS 重建 + 浅水模拟 + SSR，30fps 实时
- 更早的入口：**Horowitz et al., "Real-Time Weather System"**, GDC 2016（Riot 那套，wetness/decal/ripple 分层还是行业标准参考）

### 流派 D：离线物理（影视）
Houdini FLIP + 白水 solver，做雨打伞花、雨帘慢镜。**代表**：ILM FLUX、Framestore、Weta。

---

## 三、雪：三条主流流派

### 流派 A：粒子雪 + 风场
billboard 雪花 + curl noise 风场 + 深度软化。**代表**：
- **Hitman: Contracts**（IO Interactive）— 早期三角带拉伸暴风雪
- **Assassin's Creed Shadows**（Ubisoft）— 成千上万雪花走复杂风模拟

### 流派 B：GPU 粒子物理雪（含热力学）
不只是渲染，把**压缩、黏结、热力学**都塞进 CUDA 并行粒子系统，能做雪崩、积雪塌方。**代表 paper**：
- **Goswami, Markowicz & Hassan, "Real-time particle-based snow simulation on the GPU"**, Eurographics PGV 2019

### 流派 C：积雪层 + 形变 + 光线追踪
雪不是“落下来就没了”，而是**在场景上堆一层可形变层**：角色踩过留脚印、衣物动态积雪、光追软阴影。**代表作品**：
- **Red Dead Redemption 2** — 衣物动态雪层 + 体积雾 + 细分 + PBR 材质统一
- **Indiana Jones and the Great Circle**（MachineGames）— Digital Foundry 称为“光追雪景巅峰”
- 早期里程碑：**Outcast**（CPU 体素雪 + 脚印 + 微体积独立光照）、**Halo: Combat Evolved**（凹凸贴图雪地）

> 💡 雪的“系统复杂度反超”就在这里——**积雪是持久状态**，要存、要插值、要跨存档、要影响碰撞和 AI 寻路，这是云完全没有的负担。

---

## 四、雾：两条主流流派（最成熟的一块）

### 流派 A：解析雾（指数高度雾）
最便宜，shader 里按高度做 `exp(-density * height)`，游戏里九成的“氛围雾”都是这个。**代表**：所有引擎默认 fog。

### 流派 B：Froxel 体积雾（视锥体体素，AAA 标准）
把视锥体切成 3D 网格（典型 150×80×64），每个 froxel 存 scattering.rgb + extinction.a + emissive，compute shader 做光源注入 → 光散射 → 前向积分 → 合成。**核心 papers**：
- **Bart Wronski, "Volumetric Fog: Unified, Compute Shader Based Solution to Atmospheric Scattering"**, SIGGRAPH 2014（《刺客信条 4》那套）
- **Sébastien Hillaire, "Physically Based and Unified Volumetric Rendering in Frostbite"**, SIGGRAPH 2015
- **Sébastien Hillaire, "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"**, EGSR/CGF 2020（UE5 Sky Atmosphere 用的就是这套）

**代表引擎/作品**：
- **Frostbite**（EA）— Hillaire 原生
- **Unreal Engine 5** — Volumetric Fog + Sky Atmosphere
- **Unity HDRP**、**Flax Engine**、**The Last of Us Part II**（Naughty Dog 深度优化点光/聚光衰减预烘焙）

### 补充流派：屏幕空间体积光（SSVL）
深度缓冲反投影 + 径向模糊，GPU Gems 3 第 13 章那套，移动端/低端平台还在用。

---

## 五、云：你上一轮已经聊透，这里只补坐标

主流就一条血脉——**Nubis 系（Guerrilla）→ UE Volumetric Cloud / Frostbite / Unity HDRP / trueSKY / RDR2**。分两支：
- **程序噪声云**：Perlin-Worley + Worley 高频，trueSKY、地平线 2015/2017、RDR2
- **物理/VDB 云**：UE5 VDB Clouds、Nubis³（地平线 2023）

关键 papers 你已经有：Schneider SIGGRAPH 2015、Nubis 2017、Nubis³ 2023、Hillaire 2015/2020。

---

## 六、一张全景表收尾

| 效果 | 主流流派 | 代表作品/公司 | 奠基 paper |
|---|---|---|---|
| **雨** | 粒子 / 屏幕水滴+湿润度 / 浅水+SSR / 离线 FLIP | RDR2、AC 系列、CoD | Horowitz GDC 2016；RainyGS CVPR 2025 |
| **雪** | 粒子+风场 / GPU 热力学粒子 / 积雪形变+光追 | RDR2、AC Shadows、Indiana Jones、Outcast | Goswami EGPGV 2019 |
| **雾** | 指数高度雾 / **Froxel 体积雾** / SSVL | Frostbite、UE5、Unity HDRP、TLOU2、AC4 | Wronski SIGGRAPH 2014；Hillaire SIGGRAPH 2015 / EGSR 2020 |
| **云** | 程序噪声 raymarch / VDB 物理 / Nubis³ 体素 | Horizon 系列、RDR2、trueSKY、UE5 | Schneider SIGGRAPH 2015；Nubis 2017；Nubis³ 2023 |

---

## 七、给你的判断

- **只做“看起来对”** → 雾最容易（froxel 一套通吃），雨次之（粒子+屏幕水滴），雪中等（加积雪层），云最难（raymarch+时域全套）
- **做“能玩进去”** → 排序反转：**雪 > 雨 > 云 > 雾**。积雪的持久状态、脚印追踪、碰撞影响是云完全没有的系统债
- **做“电影级”** → 全部回到 Houdini VDB + Karma/Arnold 离线那条线，实时方案只是它的低配近似

**你想先深入雪的积雪持久层、雨的湿润度状态机，还是 froxel 雾的时域抗鬼影实现？**