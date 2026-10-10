# 模型矩阵 视图/相机矩阵 投影矩阵作用及其逆矩阵 正交性 可逆性 点跟向量(尤其是法线)的矩阵乘法 

## 模型矩阵 视图/相机矩阵 投影矩阵作用及其逆矩阵 点跟向量的矩阵乘法
这是一个非常经典的图形学问题。我们来系统梳理一下这三个核心矩阵的逆矩阵用途，以及法线向量和方向向量的变换规则。

---

### 1. 模型矩阵 (Model Matrix) `M`
- **作用**: 将顶点从**局部空间** (Local/Object Space) 变换到**世界空间** (World Space)。
- **逆矩阵**: `M⁻¹`
- **用途**:
  - 将世界空间中的点或方向转换回模型的局部空间（例如，用于拾取检测、局部坐标系计算）。
  - 构建法线变换矩阵（见下文）。

---

### 2. 相机矩阵 (View Matrix) `V`
- **作用**: 将顶点从**世界空间**变换到**观察空间** (View/Camera Space)。
- **逆矩阵**: `V⁻¹`
- **用途**:
  - 将观察空间中的点或方向转换回世界空间（例如，从深度缓冲重建世界坐标）。
  - 获取相机在世界空间中的位置（通常 `V⁻¹` 的最后一列就是相机位置）。

---

### 3. 投影矩阵 (Projection Matrix) `P`
- **作用**: 将顶点从**观察空间**变换到**裁剪空间** (Clip Space)。
- **逆矩阵**: `P⁻¹`
- **用途**:
  - 将裁剪空间或NDC坐标反推回观察空间（例如，延迟渲染中重建位置）。
  - 注意：投影矩阵本身不可逆（行列式为0）的情况极少，但透视投影的逆矩阵存在且常用。

---

### 4. 法线与方向向量的变换

这是最容易出错的地方，需要特别注意。

#### 情况A：普通方向向量 (如光线方向、视线方向)
- **定义**: 表示方向，不受平移影响。
- **变换矩阵**: 直接用原矩阵的左上角 3x3 部分即可。
  ```
  世界空间方向 = M_3x3 * 局部空间方向
  观察空间方向 = V_3x3 * 世界空间方向
  ```
- **原因**: 方向向量是齐次坐标中的 `(x, y, z, 0)`，平移分量被忽略。

#### 情况B：法线向量 (Normal)
- **问题**: 如果模型矩阵包含**非均匀缩放**（如沿X轴拉伸2倍），直接用 `M_3x3` 变换法线会导致法线不再垂直于表面。
- **正确做法**: 使用**逆转置矩阵** (Inverse Transpose)。
  ```
  法线变换矩阵 N = (M_3x3⁻¹)ᵀ
  ```
- **推导逻辑**:
  - 假设切向量 `T` 经过 `M_3x3` 变换后仍是切向量：`T' = M_3x3 * T`。
  - 法线 `N` 必须满足：`N' · T' = 0`。
  - 代入得：`(N')ᵀ · (M_3x3 * T) = 0` → `((M_3x3)ᵀ · N')ᵀ · T = 0`。
  - 因为 `N · T = 0`，所以 `N' = (M_3x3⁻¹)ᵀ * N`。

- **特殊情况**:
  - 如果模型矩阵只有**刚体变换**（旋转+平移，**无缩放**），则 `(M⁻¹)ᵀ = M` **严格成立**，可以直接用 `M_3x3`。
  - 如果是**均匀缩放**（`M_3x3 = sR`），则 $(M^{-1})^\top = \tfrac{1}{s}R = \tfrac{1}{s^2}\,M_{3\times3} \neq M$——**不是严格相等，只是方向相同**（差一个正标量倍）。变换后 `normalize()` 即可得到正确法线。这是**图形学的工程优化**，不是数学上的等价替换（详见下文"正交性"一章的补充辨析）。
  - 一旦包含**非均匀缩放或剪切**，`(M⁻¹)ᵀ` 与 `M_3x3` 连**方向**都不同，必须用逆转置，否则法线不再垂直于表面。
  - 对于**视图矩阵** `V`（刚体变换，3×3 就是相机旋转矩阵），法线可以直接用 `V_3x3` 变换。
  - 对于**投影矩阵**，一般不直接对法线应用投影，而是在观察空间完成光照计算。

---

### 5. 总结表

| 向量类型 | 变换方式 | 说明 |
|---|---|---|
| **位置点** (Position) | 完整 4x4 矩阵 (M, V, P) | 齐次坐标 w=1 |
| **方向向量** (Direction) | 左上角 3x3 矩阵 | 齐次坐标 w=0，忽略平移 |
| **法线向量** (Normal) | 逆转置矩阵 `(M_3x3⁻¹)ᵀ` | 保证垂直性，不受非均匀缩放破坏 |

如果你正在实现一个渲染管线，建议：
- 在 CPU 端预计算好法线变换矩阵并传入 shader。
- 或者在 shader 中通过 `inverse(transpose(mat3(modelMatrix)))` 计算（性能稍差但通用）。
- 

## 各矩阵正交性

### 视图变换矩阵  投影矩阵通常不是正交矩阵
这个问题很关键，容易混淆。简单直接的答案是：

**视图变换矩阵和投影矩阵通常都不是正交矩阵。**

只有特定情况下才可能是正交矩阵。我们分别来看：

---

#### 1. 视图变换矩阵 (View Matrix)

**结论：一般不是正交矩阵，但可以是。**

- **为什么通常不是？**
  视图变换矩阵 = 旋转矩阵 × 平移矩阵。
  其中旋转部分是正交矩阵（因为旋转保持长度和角度），但平移部分不是——平移矩阵是仿射变换矩阵，不是正交矩阵。
  两个矩阵相乘，结果一般不再是正交矩阵。

- **什么时候是正交矩阵？**
  只有当视图矩阵只包含旋转（没有平移，即相机位于原点）时，它才是正交矩阵。但实际渲染中几乎不会出现这种情况。

- **验证方法**：检查 `Vᵀ = V⁻¹` 是否成立。由于平移分量的存在，这个等式不成立。

---

#### 2. 投影矩阵 (Projection Matrix)

**结论：绝大多数情况下不是正交矩阵。**

- **透视投影矩阵**：绝对不是正交矩阵。
  透视投影会引入非均匀缩放（近大远小），导致不同方向的缩放比例不同。它的行向量之间既不单位长度也不相互正交。

- **正交投影矩阵**：也不是正交矩阵。
  虽然正交投影没有透视畸变，但它包含**缩放和平移**操作（将视景体映射到[-1,1]³的立方体）。缩放因子通常是 `2/(right-left)` 这样的值，不是1，因此不满足正交矩阵的条件。

- **唯一可能的情况**：如果正交投影的左右、上下、远近范围恰好对称且缩放因子为1（即视景体已经是[-1,1]³），那么投影矩阵退化为单位矩阵——但这在实际中毫无意义。

---

#### 3. 直观理解为什么它们不是正交矩阵

正交矩阵的核心性质是：**保持向量长度和夹角不变**（即纯旋转或反射）。

- **视图矩阵**：除了旋转，还包含平移。平移虽然不改变向量长度，但正交矩阵的定义要求矩阵的列向量是标准正交基，平移破坏了这一点。
- **投影矩阵**：无论是透视还是正交，都会改变向量的长度（把场景压缩到NDC范围内），甚至改变向量之间的夹角（透视投影下平行线不再平行）。这明显违背了正交矩阵的性质。

---

#### 4. 常见误区澄清

很多人以为"视图矩阵是正交矩阵"，是因为：
- 视图矩阵的**旋转子矩阵**（左上角3x3）确实是正交矩阵。
- 但完整的4x4视图矩阵**不是**正交矩阵。

同理，有些人误以为"正交投影矩阵是正交矩阵"，只是因为名字里带"正交"二字——这里的"正交"指的是投影方向与投影平面垂直，而不是数学上的正交矩阵概念。

---

#### 5. 总结

| 矩阵类型 | 是否是正交矩阵 | 原因 |
|---|---|---|
| 视图矩阵 | ❌ 一般不是 | 包含平移分量，破坏了正交性 |
| 透视投影矩阵 | ❌ 绝不是 | 非均匀缩放，改变向量长度和夹角 |
| 正交投影矩阵 | ❌ 不是 | 包含缩放和平移，不满足正交条件 |

**一句话记忆**：图形学中常用的变换矩阵，除了纯旋转矩阵外，几乎没有一个是正交矩阵。不要被"正交投影"的名字误导。

### 视图变换矩阵  投影矩阵的3*3左上角一定是正交矩阵吗
这个问题问得很细，答案也很有区分度。我们分开看：

---

#### 视图变换矩阵的左上角 3×3

**是的，一定是正交矩阵。**

- 视图变换矩阵 = 旋转矩阵 × 平移矩阵
- 平移矩阵的左上角 3×3 是单位矩阵 I
- 旋转矩阵的左上角 3×3 是正交矩阵（旋转矩阵本身就是正交矩阵）
- 两者相乘：`R × I = R`，仍然是正交矩阵

所以视图矩阵的左上角 3×3 就是相机的旋转矩阵，必然满足：
- 列向量互相正交
- 每个列向量长度为 1
- `Rᵀ = R⁻¹`

**结论：视图矩阵的 3×3 左上角一定是正交矩阵。**

---

#### 投影矩阵的左上角 3×3

**不是正交矩阵，两种情况都不是。**

##### 透视投影矩阵
对称视锥下，左上角 3×3 的实际形式（f = 1/tan(fov/2)）：
```
[ f/aspect   0         0           ]
[   0        f         0           ]
[   0        0      (f+n)/(n-f)    ]
```

这是一个**对角矩阵**，三个列向量**两两垂直**——但正交矩阵要求列向量构成**标准正交基**（垂直 **且** 单位长度），这里三个对角元一般互不相等且都不等于 ±1：

- 对称视锥（常见情形）：列间**垂直**但**长度 ≠ 1** → 不正交（败在长度，不是败在垂直性）
- 非对称视锥（off-center）：第一/二行第三列出现 (r+l)/(r-l)、(t+b)/(t-b) 等耦合项，列间**连垂直都不满足** → 更不正交

**结论：透视投影的 3×3 左上角不是正交矩阵。**

> **⚠️ 两个独立问题的辨析（重要）**
> 1. **数学上是否正交**：只看这 9 个数组成的矩阵 Q 是否满足 QᵀQ = I。上面已回答（不满足）。
> 2. **这个 3×3 块作为变换是否有意义**：对仿射变换（模型/视图矩阵），左上角 3×3 就是线性部分，可直接作用于方向向量 (x,y,z,0)（它们的最后一行是 (0,0,0,1)，w' 恒为 0）。但透视投影是**射影变换**而非仿射变换，核心机制（第四行的 w' = -z 与透视除法）不在 3×3 里，左上角 3×3 无法独立描述投影——用它变换方向向量会得到错误结果（方向 (x,y,z,0) 经完整投影后 w' = -z ≠ 0）。
>
> 第 2 点是**语义层面的"无意义"，不能作为第 1 点"数学上不正交"的论据**。一个矩阵完全可能"不正交但可逆"（透视投影的 3×3 正是如此），也可能"正交但在此语境无意义"——两个属性互相独立，判断正交性时只看这 9 个数本身。

> **📌 术语学注记："正交"一词的分层含义**
>
> "正交矩阵"这个名字有历史遗留的别扭——它要求的其实不是"列向量正交"，而是"列向量**标准正交**"。分层如下：
>
> | 层级 | 术语 | 定义 | 要求长度吗 |
> |---|---|---|---|
> | 向量层面 | 两向量**正交** | 点积为 0 | 否，只管方向垂直 |
> | 向量组 | **正交向量组** | 两两点积为 0 | 否 |
> | 向量组 | **标准正交向量组**（规范正交） | 两两点积为 0 **且** 每个长度为 1 | 是 |
> | 矩阵 | **正交矩阵**（技术术语） | QᵀQ = I，即列向量构成**标准正交基** | **是** |
>
> 从定义 QᵀQ = I 看最不易歧义：QᵀQ 的 (i,j) 元正是第 i 列与第 j 列的点积——对角线（自点积）= 1 要求**单位长度**，非对角线（互点积）= 0 要求**垂直**，缺一不可。
>
> 照此分层，"列两两正交但列长不为 1"的矩阵**存在且常见**——典型就是对角元不全为 ±1 的对角矩阵：
>
> | 矩阵 | 列两两正交？ | 列单位长？ | 是正交矩阵？ |
> |---|:---:|:---:|:---:|
> | diag(2, 3, 4) | ✓ | ✗ | ✗ |
> | diag(1, 1, 1) = I | ✓ | ✓ | ✓ |
> | diag(1, -1, 1)（反射） | ✓ | ✓ | ✓ |
> | 置换矩阵（行列交换） | ✓ | ✓ | ✓ |
> | 旋转矩阵 | ✓ | ✓ | ✓ |
> | 投影矩阵的 3×3（对称视锥，diag(f/aspect, f, …)） | ✓ | ✗ | ✗ |
>
> 注意**正交矩阵 ≠ 单位矩阵**：反射、置换、旋转（及它们的组合，行列式 = ±1）都是正交矩阵。投影 3×3（对称视锥）正属于"**列正交但非正交矩阵**"这一类——本文说它"不是正交矩阵"用的是技术术语定义（QᵀQ ≠ I），与"列向量互相垂直"并不矛盾，差别就在"正交"用在哪一层。

##### 正交投影矩阵
正交投影矩阵的左上角 3×3 形式为：
```
[ 2/(r-l)    0         0    ]
[    0     2/(t-b)     0    ]
[    0       0      2/(f-n) ]
```

- 同样是**对角矩阵**：列向量两两垂直，但长度 2/(r-l)、2/(t-b)、2/(f-n) 一般 ≠ 1 且互不相等，不满足标准正交基条件
- 严格地说，对角矩阵是正交矩阵当且仅当对角元 ∈ {±1}（如 diag(1,-1,1) 是反射，也算正交矩阵）。由于 r>l、t>b、f>n 保证 2/(r-l) 等恒为正，实践中唯一可能是全部等于 1（视景体恰为 [-1,1]³），此时退化为单位矩阵

**结论：正交投影的 3×3 左上角一般不是正交矩阵，仅当缩放因子全为 ±1（实践中即全为 1）时才是。**

---

#### 总结对比

| 矩阵 | 左上角 3×3 是否为正交矩阵 |
|---|---|
| 视图变换矩阵 | ✅ **一定是**（就是相机的旋转矩阵） |
| 透视投影矩阵 | ❌ **不是**（对称视锥下列间垂直但列长不为1；非对称视锥列间也不垂直） |
| 正交投影矩阵 | ❌ **一般不是**（仅当缩放因子全为±1时才是） |

**记忆要点**：视图矩阵的 3×3 本质上是旋转，而投影矩阵的 3×3 本质上是（非均匀）缩放，所以只有前者是正交矩阵。另注：投影矩阵 3×3 的"不正交"是纯数学结论（列长不为 1）；它"无法独立描述投影"是语义层面的局限——两个问题独立，不要互相作为论据。

### 模型矩阵 视图变换矩阵  投影矩阵的3*3左上角一定是正交矩阵吗
这个问题非常好，我们来逐一分析，答案并不统一：

---

#### 模型矩阵 (Model Matrix) 的左上角 3×3

**不一定，取决于模型矩阵的内容。**

模型矩阵可以包含三种基本变换的组合：**缩放、旋转、平移**。

- 左上角 3×3 由**旋转矩阵 × 缩放矩阵**构成（常见 TRS 约定，平移不影响左上角）。
- **如果是刚体变换**（只有旋转+平移，无缩放）：左上角 3×3 就是旋转矩阵，**是正交矩阵**。
- **如果包含缩放——无论均匀还是非均匀——都不是正交矩阵**：
  - 均匀缩放（`sR`，s≠±1）：列向量两两垂直但长度都是 `s ≠ 1`，满足 $(sR)^\top(sR) = s^2I \neq I$，是"**标量倍正交**"而非正交矩阵；
  - 非均匀缩放（`R·S`）：列向量**仍两两垂直**（第 i 列 = $s_i \times$ 旋转矩阵的第 i 列），但长度互不相等；
  - 真正破坏列间**垂直性**的是**剪切**（shear）或缩放/旋转交错复合的变换。
  - 也就是说：**缩放破坏的是"单位长度"，剪切破坏的才是"两两垂直"**——两者只要出现其一，就不满足标准正交基条件 $Q^\top Q = I$。

> **📌 补充辨析：均匀缩放不是正交矩阵，为什么图形学还敢直接用它变换法线？（严格数学 vs 工程优化）**
>
> "模型矩阵是正交矩阵"这个前提**只在刚体变换（纯旋转+平移）下成立**。均匀缩放常被误认为"还是正交的"，需要分两个层面澄清：
>
> **层面一：严格的数学结论**
>
> 正交矩阵要求 $Q^\top Q = I$，即列向量构成**标准正交基**（两两垂直**且**单位长度，缺一不可）。据此：
>
> | 模型矩阵 3×3 的内容 | 形式 | $Q^\top Q$ | 是否正交矩阵 | 法线变换 $(M^{-1})^\top$ 与 $M$ 的关系 |
> |---|---|---|---|---|
> | 纯旋转（刚体） | $R$ | $I$ | ✅ 是 | **严格相等**：$(M^{-1})^\top = M$ |
> | 旋转+均匀缩放 | $sR$（s≠±1） | $s^2 I$ | ❌ 不是（标量倍正交） | **同向不等值**：$(M^{-1})^\top = \tfrac{1}{s^2} M$ |
> | 非均匀缩放/剪切 | $R \cdot S$ 等 | 对角元≠1（剪切连非对角元也≠0） | ❌ 不是 | **连方向都不同**，必须用逆转置 |
>
> 所以"含均匀缩放的模型矩阵是正交矩阵"在数学上**不成立**——连 $sI$（s≠±1）都不满足 $Q^\top Q = I$。
>
> **层面二：图形学的工程优化**
>
> 工程上真正关心的不是"矩阵是否正交"，而是"**用 $M$ 直接变换法线，方向会不会错**"。均匀缩放恰好是安全的退化情形：
>
> $$(M^{-1})^\top = \tfrac{1}{s}R \;\parallel\; sR = M \quad (\text{只差正标量倍，方向相同})$$
>
> 因此"旋转+均匀缩放"的模型可以跳过昂贵的 `inverse()`，直接 `normalize(M_3x3 * aNormal)`，结果与严格逆转置**方向完全一致**——这是有前提的**工程优化**，不是数学等价。一旦出现非均匀缩放或剪切，该优化立即失效。
>
> **数值反例（非均匀缩放下用 $M$ 变换法线会错）**：取切线 $\mathbf{t} = \tfrac{1}{\sqrt{2}}(1,1,0)$、法线 $\mathbf{n} = \tfrac{1}{\sqrt{2}}(1,-1,0)$，施加 x 方向 2 倍拉伸 $S = \mathrm{diag}(2,1,1)$：
> - 变换后切线：$S\mathbf{t} \propto (2,1,0)$；
> - **错误做法**（直接用 $S$ 变换法线）：$S\mathbf{n} \propto (2,-1,0)$，验证 $(2,1,0)\cdot(2,-1,0) = 3 \neq 0$ ❌ 法线不再垂直于表面；
> - **正确做法**（用 $(S^{-1})^\top = \mathrm{diag}(\tfrac{1}{2},1,1)$）：得 $(1,-2,0)$ 方向，验证 $(2,1,0)\cdot(1,-2,0) = 0$ ✅。
>
> **一句话总结**：严格的数学标准正交（$Q^\top Q=I$）只有刚体变换满足；均匀缩放是"标量倍正交"，数学上不正交但**方向变换等价**，图形学借此做工程优化（省掉求逆、归一化兜底）；非均匀缩放/剪切两者皆不满足，必须用 `transpose(inverse(mat3(model)))`。

**结论：模型矩阵的 3×3 左上角，只有在刚体变换（无缩放，或缩放因子全为 ±1——实践中即无缩放）时才是正交矩阵；均匀缩放是"标量倍正交"（不是正交矩阵，但法线方向变换等价，工程上可用）；非均匀缩放/剪切时一定不是，且法线必须走逆转置。**

---

#### 视图变换矩阵 (View Matrix) 的左上角 3×3

**一定是正交矩阵。**

- 视图矩阵 = 旋转矩阵 × 平移矩阵
- 平移不影响左上角，左上角就是相机的旋转矩阵
- 旋转矩阵天然是正交矩阵

**结论：视图矩阵的 3×3 左上角一定是正交矩阵。**

---

#### 投影矩阵 (Projection Matrix) 的左上角 3×3

**一定不是正交矩阵。**

##### 透视投影
- 左上角 3×3（对称视锥）= diag(f/aspect, f, (f+n)/(n-f))：列向量**两两垂直但长度不为 1**，不是正交矩阵（非对称视锥下连垂直都不满足）
- 透视投影依赖齐次坐标的 w 分量、左上角 3×3 无法独立描述变换——这是**语义上的局限**，与数学上是否正交是两个独立问题（详见上一节的辨析框），不能作为"不正交"的论据

##### 正交投影
- 左上角 3×3 是对角矩阵，对角元为 `2/(r-l)`, `2/(t-b)`, `2/(f-n)`
- 一般情况下这三个值互不相同，列向量长度不为 1
- 仅当视景体恰好是 `[-1,1]³` 时退化为单位矩阵，此时是正交矩阵——但这种情况在实际中几乎不会出现

**结论：投影矩阵的 3×3 左上角不是正交矩阵（极特殊情况除外）。**

---

#### 最终总结表

| 矩阵类型 | 左上角 3×3 是否为正交矩阵 |
|---|---|
| **模型矩阵** | ❌ **不一定**（仅刚体变换（无缩放）时才是；均匀缩放是"标量倍正交"——不正交但方向变换等价） |
| **视图变换矩阵** | ✅ **一定是**（就是相机的旋转矩阵） |
| **投影矩阵** | ❌ **一定不是**（透视和正交投影都不满足） |

**一句话记忆**：只有纯旋转相关的矩阵（视图矩阵的左上角）才是正交矩阵；模型矩阵只要有缩放（哪怕均匀）就不是正交矩阵，但均匀缩放下法线方向变换等价、可作工程优化；投影矩阵永远不是。

这个问题很严谨，我们逐一来分析。

---

## 各矩阵可逆性
### 一、模型矩阵、视图矩阵、投影矩阵一定可逆吗？

#### 模型矩阵 (Model Matrix)
**一定可逆。**

- 模型矩阵 = 平移 × 旋转 × 缩放（顺序可能有变化，但都是仿射变换）
- 平移、旋转、缩放各自都是可逆的（缩放因子不为0）
- 只要没有将某个维度缩放到0，组合后的矩阵就一定可逆
- 实际应用中，缩放因子不可能为0（否则模型消失），所以模型矩阵总是可逆的

#### 视图矩阵 (View Matrix)
**一定可逆。**

- 视图矩阵 = 旋转 × 平移
- 旋转矩阵可逆，平移矩阵可逆
- 两者乘积仍然可逆
- 物理意义上，相机的位置和朝向总是确定的，所以视图矩阵总是可逆的

#### 投影矩阵 (Projection Matrix)
**一定可逆，但有前提。**

- **透视投影矩阵**：可逆。虽然它把视锥体压扁到NDC，但这个映射是双射（一一对应），所以逆矩阵存在。
- **正交投影矩阵**：可逆。同样是一一映射。
- **唯一例外**：如果投影矩阵将某个维度压缩到0（比如将z范围设为 [n, n]，即近远平面重合），则不可逆。但实际渲染中不会这样设置。

**结论：三者在实际应用中都是可逆的。**

---

### 二、左上角 3×3 一定可逆吗？

这个问题的答案更有意思，我们逐个看。

#### 模型矩阵的左上角 3×3
**一定可逆。**

- 模型矩阵的左上角 3×3 = 旋转矩阵 × 缩放矩阵
- 旋转矩阵的行列式 = ±1 ≠ 0
- 缩放矩阵的行列式 = 三个缩放因子的乘积
- 只要所有缩放因子都不为0（实际中确实如此），行列式就不为0
- 所以一定可逆

#### 视图矩阵的左上角 3×3
**一定可逆。**

- 就是相机的旋转矩阵
- 旋转矩阵的行列式 = 1（或 -1，如果包含反射）
- 行列式不为0，一定可逆

#### 投影矩阵的左上角 3×3
**数学上可逆，但语义上要小心使用。**

典型的透视投影矩阵（OpenGL 约定）：
```
[f/aspect   0       0       0]
[   0       f       0       0]
[   0       0    (f+n)/(n-f)  2fn/(n-f)]
[   0       0      -1        0]
```
左上角 3×3（去掉第4行和第4列）得到：
```
[f/aspect   0       0    ]
[   0       f       0    ]
[   0       0    (f+n)/(n-f)]
```
对角元全不为 0，行列式不为 0，**数学上一定可逆**。

这里同样要区分两个层面（与正交性一节的辨析一致）：

- **数学上**：这个 3×3 可逆、非正交（列长不为 1）——结论只由这 9 个数决定，与它来自哪个 4×4 无关
- **语义上**：透视投影不是仿射变换，"线性部分"的概念对它不成立。z 与 w 的耦合发生在第四行/列——第 4 行第 3 列的 -1 使 w' = -z，第 3 行第 4 列的 2fn/(n-f) 使 z' 含 w 项——这才是投影的核心机制。左上角 3×3 单独拿出来既不能正确变换点，也不能变换方向（方向 (x,y,z,0) 经完整投影后 w' = -z ≠ 0，透视除法后结果完全错误）

**正交投影矩阵的左上角 3×3**：
```
[2/(r-l)    0         0    ]
[   0     2/(t-b)     0    ]
[   0       0      2/(f-n) ]
```
只要 r≠l, t≠b, f≠n，对角元都不为0，行列式不为0，**一定可逆**。

---

### 三、总结表

| 矩阵 | 整体是否可逆 | 左上角 3×3 是否可逆 |
|---|---|---|
| **模型矩阵** | ✅ 是 | ✅ 是（缩放因子不为0） |
| **视图矩阵** | ✅ 是 | ✅ 是（就是旋转矩阵） |
| **透视投影矩阵** | ✅ 是 | ✅ 是（对角元不为0，但单独拿出来无实际意义） |
| **正交投影矩阵** | ✅ 是 | ✅ 是（对角元不为0） |

**关键提醒**：虽然透视投影的左上角 3×3 在数学上可逆，但在图形学实践中**不要单独对它求逆**用来变换法线或方向向量。正确的做法是用完整的 4×4 矩阵或专门的法线变换矩阵。

# 从屏幕空间重建世界/视图空间方向：原理与实现

---

## 1. 基本原理

### 1.1 问题的本质

渲染天空盒时，我们需要知道每个像素对应的**视线方向**，用它来采样环境cubemap。

传统方法是渲染一个大立方体，利用顶点插值得到方向。但现代渲染器更常用**全屏三角形**（Full-screen Triangle/Pass）：

```
屏幕坐标 (x, y)  →  视图空间射线方向  →  世界空间射线方向  →  采样cubemap
```

### 1.2 关键思路：逆投影（Unprojection）

顶点着色器执行的是**投影变换**：
$$\mathbf{v}_{clip} = P \cdot V \cdot M \cdot \mathbf{v}_{local}$$

我们需要做**逆变换**：
$$\mathbf{v}_{view} = P^{-1} \cdot \mathbf{v}_{ndc}$$
$$\mathbf{v}_{world} = V^{-1} \cdot \mathbf{v}_{view}$$

对于天空盒，深度可以设为最远（$z=1$ in NDC），这样得到的点就在远裁剪面上，从相机位置指向该点就是视线方向。

---

## 2. 坐标空间回顾

以OpenGL坐标系为例：

| 空间 | 坐标范围 | 说明 |
|-----|---------|------|
| NDC（标准化设备坐标） | $x,y \in [-1,1], z \in [-1,1]$（OpenGL）或 $[0,1]$（D3D/Vulkan） | 裁剪空间透视除法后 |
| 屏幕空间 | $x \in [0, W], y \in [0, H]$ | 像素坐标 |
| 视图空间 | 相机在原点，-Z指向前方 | 视图矩阵变换后 |
| 世界空间 | 全局坐标系 | 模型矩阵变换后 |

---

## 3. 方法一：从NDC坐标重建（最通用）

### 3.1 顶点着色器：全屏三角形

```glsl
// 全屏三角形顶点（不需要顶点缓冲，直接生成）
vec2 positions[3] = vec2[](
    vec2(-1.0, -1.0),  // 左下
    vec2( 3.0, -1.0),  // 右下（超出屏幕，覆盖整个视口）
    vec2(-1.0,  3.0)   // 左上
);

void main() {
    gl_Position = vec4(positions[gl_VertexID], 1.0, 1.0);
}
```

### 3.2 片元着色器：逆投影到视图空间

```glsl
uniform mat4 invProjection;  // 投影矩阵的逆矩阵
uniform vec2 screenSize;     // 屏幕宽高

out vec4 FragColor;

void main() {
    // 1. 从gl_FragCoord得到屏幕像素坐标
    vec2 screenPos = gl_FragCoord.xy;
    
    // 2. 转换到NDC坐标 [-1, 1]
    vec2 ndcXY = screenPos / screenSize * 2.0 - 1.0;
    
    // 3. 天空盒用最远深度 z=1 (NDC)
    //    构造NDC空间中的点，w=1
    vec4 ndcPos = vec4(ndcXY, 1.0, 1.0);
    
    // 4. 逆投影到视图空间
    vec4 viewPos = invProjection * ndcPos;
    
    // 5. 透视除法（虽然逆投影后通常需要除以w）
    vec3 viewDir = viewPos.xyz / viewPos.w;
    
    // 6. 归一化得到方向向量（视图空间）
    viewDir = normalize(viewDir);
    
    // 现在可以用viewDir做视图空间的cubemap采样
    // ...
}
```

### 3.3 从视图空间转换到世界空间

```glsl
uniform mat4 invView;  // 视图矩阵的逆矩阵（即相机的世界变换矩阵）

void main() {
    // ... 上面得到viewDir ...
    
    // 方法A：用逆视图矩阵变换方向（注意是方向不是点，w=0）
    vec4 worldDir4 = invView * vec4(viewDir, 0.0);
    vec3 worldDir = normalize(worldDir4.xyz);
    
    // 方法B：直接用相机右/上/前向量重建（性能更好）
    // cameraRight, cameraUp, cameraForward 是相机的世界空间基向量
    // vec3 worldDir = normalize(
    //     cameraRight * viewDir.x +
    //     cameraUp    * viewDir.y +
    //     cameraForward * (-viewDir.z)  // 注意视图空间-Z是前方
    // );
    
    // 采样cubemap
    vec3 color = texture(environmentMap, worldDir).rgb;
}
```

---

## 4. 方法二：预计算视锥角（更高效）

对于静态相机（如天空盒，FOV和宽高比不变），可以预计算每个屏幕角落的视图空间方向，然后在片元着色器中双线性插值。

### 4.1 顶点着色器

```glsl
out vec3 viewDir;

// 预计算的三个顶点位置处的视图空间方向
// ⚠️ 全屏三角形有两个顶点在屏幕外（NDC (3,-1) 和 (-1,3)），
// 线性插值要求"顶点属性 = 函数在顶点自身位置的值"，
// 所以方向必须按这三个 NDC 坐标（含屏幕外的）计算：
// dir(ndcX, ndcY) ∝ (ndcX*aspect*tanHalfFov, ndcY*tanHalfFov, -1)
uniform vec3 vertexDirs[3];

void main() {
    vec2 pos[3] = vec2[](
        vec2(-1.0, -1.0),
        vec2( 3.0, -1.0),
        vec2(-1.0,  3.0)
    );
    
    int idx = gl_VertexID;
    gl_Position = vec4(pos[idx], 1.0, 1.0);
    viewDir = vertexDirs[idx];
}
```

### 4.2 片元着色器

```glsl
in vec3 viewDir;  // 由硬件插值，每个像素自动得到正确方向

uniform samplerCube environmentMap;
uniform mat4 invView;

void main() {
    vec3 dir = normalize(viewDir);
    
    // 转世界空间
    vec3 worldDir = normalize((invView * vec4(dir, 0.0)).xyz);
    
    vec3 color = texture(environmentMap, worldDir).rgb;
    FragColor = vec4(color, 1.0);
}
```

### 4.3 预计算视锥角（CPU端，OpenGL）

```cpp
// 传入相机参数（或用投影矩阵反算）
float fovY = glm::radians(camera.fov);
float aspect = (float)width / (float)height;
float near = camera.nearPlane;
float far = camera.farPlane;

// 视锥半高和半宽（在近平面上，也可以用远平面）
float tanHalfFovY = tan(fovY / 2.0f);
float halfHeight = tanHalfFovY * near;
float halfWidth = halfHeight * aspect;

// 视图空间：相机在原点，看向-Z
// 四个角（近平面）
glm::vec3 frustumCorners[4] = {
    // 左下
    glm::vec3(-halfWidth, -halfHeight, -near),
    // 右下
    glm::vec3( halfWidth, -halfHeight, -near),
    // 左上
    glm::vec3(-halfWidth,  halfHeight, -near),
    // 右上
    glm::vec3( halfWidth,  halfHeight, -near)
};

// ⚠️ 全屏三角形的三个顶点在 NDC (-1,-1), (3,-1), (-1,3)，
// 后两个在屏幕外——线性插值要求属性取顶点自身位置的值，
// 所以要按这三个坐标（含屏幕外）算方向，不能直接用上面四角的值
glm::vec3 vertexDirs[3] = {
    glm::normalize(glm::vec3(-halfWidth, -halfHeight, -near)),                    // (-1,-1)
    glm::normalize(glm::vec3( 3.0f * halfWidth, -halfHeight, -near)),             // ( 3,-1)
    glm::normalize(glm::vec3(-halfWidth,  3.0f * halfHeight, -near))              // (-1, 3)
};
```

> **注意**：天空盒用近平面还是远平面的方向无所谓，因为方向是一样的（都从原点出发）。

---

## 5. 方法三：从深度纹理重建（延迟渲染/后处理常用）

如果你有场景深度纹理，也可以重建世界位置和方向：

```glsl
uniform sampler2D depthMap;
uniform mat4 invViewProj;
uniform vec2 screenSize;

vec3 ReconstructWorldPos(vec2 screenUV, float depth) {
    // 屏幕UV [0,1] -> NDC [-1,1]
    vec4 ndcPos;
    ndcPos.xy = screenUV * 2.0 - 1.0;
    ndcPos.z = depth * 2.0 - 1.0;  // OpenGL深度范围 [0,1] -> [-1,1]
    ndcPos.w = 1.0;
    
    // 逆变换到世界空间
    vec4 worldPos = invViewProj * ndcPos;
    worldPos /= worldPos.w;
    
    return worldPos.xyz;
}

void main() {
    vec2 screenUV = gl_FragCoord.xy / screenSize;
    float depth = texture(depthMap, screenUV).r;
    
    if (depth >= 1.0) {
        // 天空像素：深度为1（远平面），重建的方向就是视线方向
        vec3 worldPos = ReconstructWorldPos(screenUV, depth);
        vec3 worldDir = normalize(worldPos - cameraWorldPos);
        // 采样天空...
    } else {
        // 场景物体...
    }
}
```

---

## 6. 天空盒渲染的深度技巧

全屏三角形方式渲染天空盒时，有个关键的深度处理：

### 方法A：渲染天空时关闭深度测试
```cpp
glDisable(GL_DEPTH_TEST);
glDepthMask(GL_FALSE);  // 不写入深度
// 画全屏三角形/天空盒
glDepthMask(GL_TRUE);
glEnable(GL_DEPTH_TEST);
// 画场景
```

### 方法B：天空盒Z值设为最远（等于1）
```glsl
// 顶点着色器中
gl_Position = vec4(pos.xy, 1.0, 1.0);  // z=w=1，深度永远为1
```
这样天空盒在最远处，场景物体自动遮挡它，可以一起开深度测试绘制。

### 方法C：Pre-Z（提前写深度）
1. 先不写颜色，只渲染场景深度
2. 然后渲染天空盒，深度测试设为 `GL_EQUAL`（只画深度=1的像素）
3. 最后渲染场景，深度测试 `GL_LESS`

---

## 7. 完整示例：天空盒全屏三角形

### 7.1 顶点着色器

```glsl
#version 450 core

out vec3 vWorldDir;

uniform mat4 invView;
uniform mat4 invProj;

void main() {
    // 全屏三角形
    vec2 pos[3] = vec2[](
        vec2(-1.0, -1.0),
        vec2( 3.0, -1.0),
        vec2(-1.0,  3.0)
    );
    
    vec2 p = pos[gl_VertexID];
    gl_Position = vec4(p, 1.0, 1.0);
    
    // 逆投影到视图空间
    vec4 viewPos = invProj * vec4(p, 1.0, 1.0);
    vec3 viewDir = viewPos.xyz / viewPos.w;
    
    // 转到世界空间（方向用w=0）
    vWorldDir = normalize((invView * vec4(viewDir, 0.0)).xyz);
}
```

### 7.2 片元着色器

```glsl
#version 450 core

in vec3 vWorldDir;
out vec4 FragColor;

uniform samplerCube environmentMap;
uniform float exposure = 1.0;

void main() {
    vec3 color = texture(environmentMap, normalize(vWorldDir)).rgb;
    
    // 色调映射（HDR环境图）
    color = vec3(1.0) - exp(-color * exposure);
    
    // Gamma校正
    color = pow(color, vec3(1.0/2.2));
    
    FragColor = vec4(color, 1.0);
}
```

### 7.3 CPU端准备矩阵

```cpp
// 渲染天空盒前，移除视图矩阵的平移部分（天空不随相机移动）
glm::mat4 viewNoTranslation = glm::mat4(glm::mat3(camera.GetViewMatrix()));
glm::mat4 proj = camera.GetProjectionMatrix();

glm::mat4 invView = glm::inverse(viewNoTranslation);
glm::mat4 invProj = glm::inverse(proj);

// 设置uniform
shader.setMat4("invView", invView);
shader.setMat4("invProj", invProj);
```

---

## 8. 各图形API的坐标系差异

| API | NDC Z范围 | 视图空间前方 | 深度范围 |
|-----|----------|------------|---------|
| OpenGL | $[-1, 1]$ | $-Z$ | $[0, 1]$ |
| Direct3D/Vulkan | $[0, 1]$ | $+Z$ | $[0, 1]$ |
| Metal | $[0, 1]$ | $+Z$ | $[0, 1]$ |

**D3D/Vulkan注意事项**：
- NDC的Z范围是0~1，天空盒z设为1
- 视图空间相机看向+Z方向，方向向量z分量为正
- 逆投影公式需要相应调整

---

## 9. 方法对比总结

| 方法 | 优点 | 缺点 | 适用场景 |
|-----|------|------|---------|
| **大立方体网格** | 简单直观，无需逆矩阵 | 需要顶点缓冲，Overdraw高 | 教学演示、简单场景 |
| **全屏三角形+逆矩阵** | 无顶点缓冲，效率高 | 需要传invView/invProj矩阵 | 现代引擎通用做法 |
| **预计算视锥角** | 片元着色器最简单 | 需要CPU端预计算，FOV改变时更新 | FOV固定的天空渲染 |
| **从深度纹理重建** | 统一处理天空和场景 | 需要深度缓冲 | 延迟渲染、后处理 |

---

## 10. 常见误区和注意事项

1. **方向向量归一化**：逆投影得到的向量长度可能不是1，采样cubemap前必须归一化
2. **w分量除法**：逆投影后别忘了除以 `w`
3. **点 vs 方向**：用矩阵变换方向时使用 `w=0`，避免平移影响
4. **视图矩阵平移**：渲染天空盒时要移除视图矩阵的平移，否则相机会"走出"天空
5. **坐标系手性**：OpenGL右手系 vs D3D左手系，方向符号容易搞错
6. **Vulkan的Y翻转**：Vulkan屏幕坐标Y向下，NDC转换需要额外翻转

实际引擎（UE、Unity、Blender等）的天空渲染路径基本都采用全屏三角形+逆投影的方式，这已经成为现代图形API的标准做法。立方体网格方式更多是教学简化。

# 从屏幕空间重建世界坐标与视图空间坐标

## 1. 核心原理

给定一个像素的屏幕坐标和深度值，我们可以通过**逆变换**把它从屏幕空间还原回三维空间：

```
屏幕坐标 (x, y) + 深度 depth
    ↓ 逆视口变换
NDC坐标 (ndcX, ndcY, ndcZ, 1)
    ↓ 逆投影矩阵 P⁻¹
视图空间坐标 (viewX, viewY, viewZ, w)
    ↓ 透视除法 (÷w)
视图空间位置 (viewX/w, viewY/w, viewZ/w)
    ↓ 逆视图矩阵 V⁻¹
世界空间位置
```

---

## 2. 方法一：逆矩阵法（最通用）

### 2.1 数学推导

正向变换链：
$$\mathbf{v}_{clip} = P \cdot V \cdot \mathbf{v}_{world}$$
$$\mathbf{v}_{ndc} = \mathbf{v}_{clip} / v_{clip.w}$$

逆变换：
$$\mathbf{v}_{view} = P^{-1} \cdot \mathbf{v}_{ndc}$$
$$\mathbf{v}_{world} = V^{-1} \cdot (\mathbf{v}_{view} / v_{view.w})$$

注意：**透视除法要在逆投影之后做**，而不是之前。

### 2.2 GLSL完整实现

```glsl
uniform sampler2D depthMap;      // 深度纹理
uniform mat4 invViewProj;        // (投影×视图)的逆矩阵
uniform mat4 invProjection;      // 投影矩阵的逆（ReconstructViewPos 用）
uniform vec2 screenSize;
uniform float nearPlane;
uniform float farPlane;

// 从深度缓冲读取非线性深度，线性化（可选）
float LinearizeDepth(float depth) {
    // OpenGL: depth ∈ [0,1], NDC z ∈ [-1,1]
    float z = depth * 2.0 - 1.0;
    return (2.0 * nearPlane * farPlane) / 
           (farPlane + nearPlane - z * (farPlane - nearPlane));
}

// 重建视图空间位置
vec3 ReconstructViewPos(vec2 screenUV, float depth) {
    // 1. UV -> NDC xy ∈ [-1,1]
    vec4 ndcPos;
    ndcPos.xy = screenUV * 2.0 - 1.0;
    ndcPos.z = depth * 2.0 - 1.0;  // OpenGL深度范围[0,1]→NDC[-1,1]
    ndcPos.w = 1.0;
    
    // 2. 逆投影到视图空间
    vec4 viewPos = invProjection * ndcPos;
    
    // 3. 透视除法
    return viewPos.xyz / viewPos.w;
}

// 重建世界空间位置
vec3 ReconstructWorldPos(vec2 screenUV, float depth) {
    vec4 ndcPos;
    ndcPos.xy = screenUV * 2.0 - 1.0;
    ndcPos.z = depth * 2.0 - 1.0;
    ndcPos.w = 1.0;
    
    // 直接用逆ViewProj一次变换到世界空间
    vec4 worldPos = invViewProj * ndcPos;
    return worldPos.xyz / worldPos.w;
}

void main() {
    vec2 screenUV = gl_FragCoord.xy / screenSize;
    float depth = texture(depthMap, screenUV).r;
    
    // 重建坐标
    vec3 viewPos = ReconstructViewPos(screenUV, depth);
    vec3 worldPos = ReconstructWorldPos(screenUV, depth);
    
    // 使用重建的坐标...
}
```

### 2.3 D3D/Vulkan版本（NDC z∈[0,1]）

```glsl
vec3 ReconstructWorldPos_D3D(vec2 screenUV, float depth) {
    vec4 ndcPos;
    ndcPos.xy = screenUV * 2.0 - 1.0;
    ndcPos.z = depth;        // D3D/Vulkan NDC z就是[0,1]，不需要×2-1
    ndcPos.w = 1.0;
    
    vec4 worldPos = invViewProj * ndcPos;
    return worldPos.xyz / worldPos.w;
}
```

---

## 3. 方法二：射线插值法（性能更好）

在顶点着色器中计算视锥四个角的位置，硬件自动插值到每个像素，然后乘以线性深度。

### 3.1 顶点着色器

```glsl
out vec3 vViewRay;  // 插值的视图空间射线

// 全屏三角形
void main() {
    vec2 positions[3] = vec2[](
        vec2(-1.0, -1.0),
        vec2( 3.0, -1.0),
        vec2(-1.0,  3.0)
    );
    
    // 三个顶点位置处的近平面射线（由CPU预计算传入）
    // ⚠️ 全屏三角形有两个顶点在屏幕外（NDC (3,-1) 和 (-1,3)），
    // 线性插值要求"顶点属性 = 函数在顶点自身位置的值"，
    // 所以射线必须按这三个 NDC 坐标（含屏幕外的）计算，不能直接搬屏幕四角的值
    // vertexRays[i] = (ndcX*aspect*tanHalfFov*near, ndcY*tanHalfFov*near, -near)
    vec3 cornerRays[3] = vec3[](
        vertexRays[0],  // NDC (-1,-1) 左下
        vertexRays[1],  // NDC ( 3,-1) 屏幕外右下
        vertexRays[2]   // NDC (-1, 3) 屏幕外左上
    );
    
    vec2 p = positions[gl_VertexID];
    gl_Position = vec4(p, 0.0, 1.0);
    vViewRay = cornerRays[gl_VertexID];
}
```

### 3.2 片元着色器

```glsl
in vec3 vViewRay;

void main() {
    vec2 screenUV = gl_FragCoord.xy / screenSize;
    float depth = texture(depthMap, screenUV).r;
    float linearDepth = LinearizeDepth(depth);
    
    // 射线方向 × 线性深度 = 视图空间位置
    // 注意：vViewRay是近平面上的点，需要缩放
    vec3 viewPos = vViewRay * (linearDepth / nearPlane);
    
    // 世界空间位置
    vec3 worldPos = (invView * vec4(viewPos, 1.0)).xyz;
}
```

### 3.3 CPU端预计算视锥角

```cpp
// 已知FOV、宽高比、近平面
float fovRad = glm::radians(fovDeg);
float tanHalfFov = tan(fovRad / 2.0f);
float aspect = (float)width / height;

// 近平面上的四个角（视图空间，相机在原点看向-Z）
glm::vec3 frustumCorners[4] = {
    // 左下
    glm::vec3(-tanHalfFov * aspect * nearPlane, 
              -tanHalfFov * nearPlane, 
              -nearPlane),
    // 右下
    glm::vec3( tanHalfFov * aspect * nearPlane, 
              -tanHalfFov * nearPlane, 
              -nearPlane),
    // 左上
    glm::vec3(-tanHalfFov * aspect * nearPlane, 
               tanHalfFov * nearPlane, 
               -nearPlane),
    // 右上
    glm::vec3( tanHalfFov * aspect * nearPlane, 
               tanHalfFov * nearPlane, 
               -nearPlane)
};

// ⚠️ 全屏三角形的三个顶点在 NDC (-1,-1), (3,-1), (-1,3)，
// 后两个在屏幕外——线性插值要求属性取顶点自身位置的值，
// 所以要按这三个坐标（含屏幕外）算近平面射线，传给顶点着色器的 vertexRays
glm::vec3 vertexRays[3] = {
    glm::vec3(-tanHalfFov * aspect * nearPlane,
              -tanHalfFov * nearPlane,
              -nearPlane),                                              // (-1,-1)
    glm::vec3( 3.0f * tanHalfFov * aspect * nearPlane,
              -tanHalfFov * nearPlane,
              -nearPlane),                                              // ( 3,-1)
    glm::vec3(-tanHalfFov * aspect * nearPlane,
               3.0f * tanHalfFov * nearPlane,
              -nearPlane)                                               // (-1, 3)
};
```

---

## 4. 方法三：从深度缓冲直接重建（无需求逆矩阵）

利用投影矩阵的参数，在shader里直接计算，不需要传矩阵。

### 4.1 已知投影矩阵参数

投影矩阵的关键元素：
$$P = \begin{bmatrix}
\frac{1}{a\tan(fov/2)} & 0 & 0 & 0 \\
0 & \frac{1}{\tan(fov/2)} & 0 & 0 \\
0 & 0 & -\frac{f+n}{f-n} & -\frac{2fn}{f-n} \\
0 & 0 & -1 & 0
\end{bmatrix}$$

其中 $a$ 是宽高比，$n$ 是近平面，$f$ 是远平面。

### 4.2 视图空间重建

```glsl
uniform float proj00;  // P[0][0] = 1/(aspect*tanHalfFov)
uniform float proj11;  // P[1][1] = 1/tanHalfFov
uniform float nearPlane;
uniform float farPlane;

vec3 ReconstructViewPos_NoMat(vec2 screenUV, float depth) {
    // NDC xy
    vec2 ndcXY = screenUV * 2.0 - 1.0;
    
    // 线性化深度，得到视图空间z（负的，看向-Z）
    float ndcZ = depth * 2.0 - 1.0;
    float viewZ = -2.0 * nearPlane * farPlane / 
                  (farPlane + nearPlane - ndcZ * (farPlane - nearPlane));
    
    // 利用投影参数反算x,y
    // clip.x / clip.w = ndcX, 而 clip.w = -viewZ
    // P[0][0] * viewX = ndcX * (-viewZ)
    float viewX = ndcXY.x * (-viewZ) / proj00;
    float viewY = ndcXY.y * (-viewZ) / proj11;
    
    return vec3(viewX, viewY, viewZ);
}
```

---

## 5. 世界空间方向重建（天空盒专用）

天空盒的深度是1（最远），只需要方向不需要位置，这也是最简单的情况：

```glsl
void main() {
    vec2 screenUV = gl_FragCoord.xy / screenSize;
    
    // 天空盒深度=1，等价于在远平面上
    vec4 ndcPos;
    ndcPos.xy = screenUV * 2.0 - 1.0;
    ndcPos.z = 1.0;
    ndcPos.w = 1.0;
    
    // 视图空间方向
    vec4 viewPos = invProjection * ndcPos;
    vec3 viewDir = normalize(viewPos.xyz / viewPos.w);
    
    // 世界空间方向
    vec3 worldDir = normalize((invView * vec4(viewDir, 0.0)).xyz);
    
    vec3 skyColor = texture(environmentMap, worldDir).rgb;
}
```

---

## 6. 三种方法对比

| 方法 | 计算量 | Uniform数量 | 精度 | 适用场景 |
|-----|-------|------------|------|---------|
| **逆矩阵法** | 2次矩阵乘法 | `invViewProj` | 高 | 通用、延迟渲染 |
| **射线插值法** | 1次乘法+线性化深度 | 4个角点向量 | 高 | 前向渲染、后处理 |
| **投影参数法** | 仅ALU运算 | 4个参数 | 中 | 极简实现、无矩阵 |

---

## 7. 关键注意事项

### 7.1 深度的线性化问题

深度缓冲中的值是**非线性**的（用于提升近处精度），不能直接拿来当距离用：

```glsl
// OpenGL非线性深度 -> 线性视图空间深度
float LinearizeDepth(float depth) {
    float z = depth * 2.0 - 1.0;  // 到NDC
    return (2.0 * near * far) / (far + near - z * (far - near));
}
```

### 7.2 点 vs 方向的矩阵变换

```glsl
// 位置（有平移）：w = 1
vec4 worldPos = invView * vec4(viewPos, 1.0);

// 方向（无平移）：w = 0
vec4 worldDir = invView * vec4(viewDir, 0.0);
```

### 7.3 坐标系差异

| API | NDC Z | 视图空间前方 | 深度范围 |
|-----|-------|------------|---------|
| OpenGL | [-1, 1] | -Z | [0, 1] |
| D3D/Vulkan/Metal | [0, 1] | +Z | [0, 1] |

### 7.4 无限远平面（Reverse-Z）

使用反向深度（Reverse-Z，近平面=1，远平面=0）时需要注意深度判断方向改变，但重建公式不变，只是深度值映射相应调整。

---

## 8. 实际引擎中的应用

- **Unreal Engine**：`SceneTextures` 中的 `ScreenToWorld` 函数通过逆矩阵重建，`GetDefaultSceneView()` 提供预计算的视锥射线
- **Unity**：`ComputeWorldSpacePosition` 函数（Shader Library）内置了重建逻辑，URP/HDRP在 `CommonMaterial.hlsl` 中实现
- **Blender Cycles**：通过相机射线直接传递，不需要从深度重建；Eevee的后处理使用逆矩阵法
- **pbrt-v3**：光线追踪器直接从相机生成射线，完全不需要屏幕空间重建——这是光栅化才有的问题

重建世界/视图坐标是光栅化管线中连接屏幕空间和三维空间的桥梁，掌握了它就能实现很多高级后处理效果。

# 从NDC坐标重建view空间坐标时，为什么是先执行逆投影变换再透视除法？不应该先透视乘法再逆投影吗？
这个问题问得很好，确实容易混淆。关键在于理解**NDC坐标已经做过透视除法**了，而我们要做的是逆向回到视图空间。

## 核心原因：NDC已经是透视除法后的结果

完整的正向管线是：

```
视图坐标 (x_view, y_view, z_view, w_view=1)
    ↓ 乘以投影矩阵 P
裁剪坐标 (x_clip, y_clip, z_clip, w_clip)   ← w_clip = -z_view（透视投影下）
    ↓ 透视除法（除以 w_clip）
NDC坐标 (x_ndc, y_ndc, z_ndc, 1.0)
```

当你拿到 NDC 坐标时，它已经**丢失了原始的 w_clip 信息**（因为被归一化了）。

## 正确顺序：先乘逆投影，再做透视乘法

### 第一步：从 NDC 回到裁剪坐标
你需要补回 w 分量。但 NDC 里的 w 已经是 1.0 了，怎么补？

实际上，对于**任意一个 NDC 点**，它对应的裁剪坐标是：
```
(x_clip, y_clip, z_clip, w_clip) = (x_ndc * w_clip, y_ndc * w_clip, z_ndc * w_clip, w_clip)
```
但你不知道 w_clip 是多少。

### 第二步：用逆投影矩阵
关键技巧：**先假设 w_clip = 1.0**，然后乘以逆投影矩阵，得到的是一个**齐次坐标**，最后再除以 w 还原。

完整步骤：
```
1. 取 NDC 坐标 (x_ndc, y_ndc, z_ndc, 1.0)
2. 乘以逆投影矩阵 P⁻¹ → 得到 (x_temp, y_temp, z_temp, w_temp)
   注意：此时 w_temp 恰好等于 1/z_view 的一个倍数（取决于投影矩阵）
3. 除以 w_temp → 得到真正的视图坐标 (x_view, y_view, z_view, 1.0)
```

## 为什么不能先做透视乘法再逆投影？

你说的"透视乘法"是指乘以 w_clip 吧？问题是：
- 你不知道 w_clip 是多少
- w_clip = -z_view，而 z_view 正是你要恢复的目标之一

这就是个**循环依赖**：要恢复 z_view 需要 w_clip，要知道 w_clip 又需要 z_view。

## 数学验证（透视投影为例）

透视投影矩阵 P 的形式：
```
P = [ fx  0   0    0 ]
    [ 0   fy  0    0 ]
    [ 0   0  A    B ]
    [ 0   0  -1   0 ]
```
其中 A = -(far+near)/(far-near)，B = -2*far*near/(far-near)

正向：
```
x_clip = fx * x_view
y_clip = fy * y_view
z_clip = A * z_view + B
w_clip = -z_view
```

NDC：
```
x_ndc = fx * x_view / (-z_view)
y_ndc = fy * y_view / (-z_view)
z_ndc = (A*z_view + B) / (-z_view)
```

逆向（正确做法）：
```
令 (x', y', z', w') = P⁻¹ * (x_ndc, y_ndc, z_ndc, 1)
则 x_view = x' / w'
   y_view = y' / w'
   z_view = z' / w'
```

这里 w' 恰好等于 -1/z_view（经过计算可证），所以除法就恢复了正确的深度。

## 一句话总结

**先逆投影再透视除法**是因为 NDC 已经做了透视除法，你无法单独恢复 w_clip。逆投影矩阵会把 NDC 转成一个齐次坐标，其中的 w 分量隐含了深度信息，最后一次除法同时解除了 w 的歧义并恢复了视图坐标。