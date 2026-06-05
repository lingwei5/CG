# Shadertoy 使用指南：常用函数与变量详解

## 一、Shadertoy 基础介绍

Shadertoy 是一个基于 WebGL 的在线实时着色器编辑和分享平台，主要用于编写片段着色器（Fragment Shader）。所有代码都在 GPU 上执行，实现各种视觉效果。

### 基本代码结构
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 标准化坐标：将像素坐标映射到 [0,1] 范围
    vec2 uv = fragCoord / iResolution.xy;
    
    // 主颜色计算
    vec3 color = vec3(uv, 0.5);
    
    // 输出颜色
    fragColor = vec4(color, 1.0);
}
```

## 二、内置变量（Uniforms）

### 1. 分辨率与坐标
```glsl
// 窗口分辨率（像素）
uniform vec3 iResolution;  // x:宽度, y:高度, z:像素宽高比

// 当前像素坐标（像素单位）
in vec2 fragCoord;  // 范围：[0, iResolution.xy]

// 标准化坐标转换函数
vec2 getUV(vec2 coord) {
    return coord / iResolution.xy;  // [0,1]
}

vec2 getCenteredUV(vec2 coord) {
    vec2 uv = coord / iResolution.xy;
    return uv * 2.0 - 1.0;  // [-1,1]
}

vec2 getAspectCorrectUV(vec2 coord) {
    vec2 uv = coord / iResolution.xy;
    uv -= 0.5;
    uv.x *= iResolution.x / iResolution.y;
    return uv;
}
```

### 2. 时间相关
```glsl
// 时间（秒）
uniform float iTime;           // 着色器运行时间
uniform float iTimeDelta;      // 帧间时间差
uniform int iFrame;           // 帧数
uniform float iFrameRate;     // 帧率

// 时间循环函数
float timeLoop(float period) {
    return mod(iTime, period);
}

float smoothTimeLoop(float period) {
    return sin(iTime * 6.2831853 / period) * 0.5 + 0.5;
}
```

### 3. 输入设备
```glsl
// 鼠标输入
uniform vec4 iMouse;  // xy:当前位置, zw:点击位置
// iMouse.xy: 鼠标当前位置（像素）
// iMouse.zw: 鼠标点击位置（像素）
// iMouse.z > 0: 鼠标按下

// 键盘输入
uniform bool iKeyShift;   // Shift键状态
uniform bool iKeyControl; // Ctrl键状态
uniform bool iKeyAlt;     // Alt键状态
uniform bool iKeySpace;   // 空格键状态
```

### 4. 日期时间
```glsl
uniform vec4 iDate;  // 年,月,日,秒
// iDate.x: 年（如2025.0）
// iDate.y: 月（1-12）
// iDate.z: 日（1-31）
// iDate.w: 秒（0-59.999）

// 获取当前时间（小时:分钟:秒）
vec3 getCurrentTime() {
    float totalSeconds = iDate.w;
    float hours = floor(totalSeconds / 3600.0);
    float minutes = floor(mod(totalSeconds, 3600.0) / 60.0);
    float seconds = mod(totalSeconds, 60.0);
    return vec3(hours, minutes, seconds);
}
```

### 5. 纹理通道
```glsl
// 纹理输入（最多4个）
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;

// 纹理类型
uniform vec3 iChannelResolution[4];  // 各通道纹理分辨率

// 纹理采样函数
vec4 textureSample(sampler2D channel, vec2 uv) {
    return texture(channel, uv);
}

// 带重复的纹理采样
vec4 textureRepeat(sampler2D channel, vec2 uv) {
    return texture(channel, fract(uv));
}
```

## 三、常用数学函数

### 1. 坐标变换
```glsl
// 极坐标转换
vec2 toPolar(vec2 uv) {
    float r = length(uv);
    float theta = atan(uv.y, uv.x);
    return vec2(r, theta);
}

vec2 fromPolar(float r, float theta) {
    return vec2(r * cos(theta), r * sin(theta));
}

// 旋转
vec2 rotate(vec2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// 缩放和平移
vec2 scale(vec2 p, vec2 s) {
    return p * s;
}

vec2 translate(vec2 p, vec2 t) {
    return p - t;
}
```

### 2. 距离函数（SDF）
```glsl
// 圆形
float circleSDF(vec2 p, vec2 center, float radius) {
    return length(p - center) - radius;
}

// 矩形
float boxSDF(vec2 p, vec2 center, vec2 size) {
    vec2 d = abs(p - center) - size * 0.5;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 线段
float segmentSDF(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// 距离场操作
float unionSDF(float d1, float d2) {
    return min(d1, d2);
}

float intersectSDF(float d1, float d2) {
    return max(d1, d2);
}

float subtractSDF(float d1, float d2) {
    return max(d1, -d2);
}
```

### 3. 插值函数
```glsl
// 平滑插值
float smoothstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// 改进的平滑插值
float smootherstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 线性插值
float mix(float a, float b, float t) {
    return a + (b - a) * t;
}

vec3 mix(vec3 a, vec3 b, float t) {
    return a + (b - a) * t;
}
```

### 4. 噪声函数
```glsl
// 随机数
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 值噪声
float valueNoise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + 
           (c - a) * u.y * (1.0 - u.x) + 
           (d - b) * u.x * u.y;
}

// 分形布朗运动（FBM）
float fbm(vec2 st, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * valueNoise(st * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}
```

## 四、颜色处理函数

### 1. 颜色空间转换
```glsl
// RGB 转 HSV
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV 转 RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// 线性转sRGB
vec3 linear2srgb(vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

// sRGB转线性
vec3 srgb2linear(vec3 color) {
    return pow(color, vec3(2.2));
}
```

### 2. 颜色混合
```glsl
// 叠加混合
vec3 blendOverlay(vec3 base, vec3 blend) {
    return mix(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 
               2.0 * base * blend, 
               step(base, vec3(0.5)));
}

// 屏幕混合
vec3 blendScreen(vec3 base, vec3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

// 正片叠底
vec3 blendMultiply(vec3 base, vec3 blend) {
    return base * blend;
}

// 柔光
vec3 blendSoftLight(vec3 base, vec3 blend) {
    return (1.0 - 2.0 * blend) * base * base + 2.0 * base * blend;
}
```

### 3. 调色板
```glsl
// 三色渐变
vec3 triColorGradient(float t, vec3 a, vec3 b, vec3 c) {
    if (t < 0.5) {
        return mix(a, b, t * 2.0);
    } else {
        return mix(b, c, (t - 0.5) * 2.0);
    }
}

// 彩虹色
vec3 rainbow(float t) {
    return 0.5 + 0.5 * cos(6.2831853 * (t + vec3(0.0, 0.33, 0.67)));
}

// 热力图颜色
vec3 heatmap(float t) {
    const vec3 c1 = vec3(0.0, 0.0, 1.0);  // 蓝
    const vec3 c2 = vec3(0.0, 1.0, 1.0);  // 青
    const vec3 c3 = vec3(0.0, 1.0, 0.0);  // 绿
    const vec3 c4 = vec3(1.0, 1.0, 0.0);  // 黄
    const vec3 c5 = vec3(1.0, 0.0, 0.0);  // 红
    
    if (t < 0.25) return mix(c1, c2, t * 4.0);
    else if (t < 0.5) return mix(c2, c3, (t - 0.25) * 4.0);
    else if (t < 0.75) return mix(c3, c4, (t - 0.5) * 4.0);
    else return mix(c4, c5, (t - 0.75) * 4.0);
}
```

## 五、实用工具函数

### 1. 屏幕效果
```glsl
// 扫描线效果
float scanlines(vec2 uv, float count) {
    return 0.5 + 0.5 * sin(uv.y * count * 6.2831853);
}

// 色差效果
vec3 chromaticAberration(sampler2D tex, vec2 uv, float amount) {
    float r = texture(tex, uv + vec2(amount, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - vec2(amount, 0.0)).b;
    return vec3(r, g, b);
}

// 晕影效果
float vignette(vec2 uv, float intensity) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    return 1.0 - smoothstep(0.0, intensity, dist);
}
```

### 2. 数学工具
```glsl
// 映射函数
float map(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

// 限制函数
float clamp01(float x) {
    return clamp(x, 0.0, 1.0);
}

// 符号函数
float signZero(float x) {
    return x >= 0.0 ? 1.0 : -1.0;
}

// 阶乘近似
float factorial(int n) {
    if (n <= 1) return 1.0;
    float result = 1.0;
    for (int i = 2; i <= n; i++) {
        result *= float(i);
    }
    return result;
}
```

### 3. 几何函数
```glsl
// 反射
vec3 reflect(vec3 incident, vec3 normal) {
    return incident - 2.0 * dot(incident, normal) * normal;
}

// 折射
vec3 refract(vec3 incident, vec3 normal, float eta) {
    float k = 1.0 - eta * eta * (1.0 - dot(normal, incident) * dot(normal, incident));
    if (k < 0.0) {
        return vec3(0.0);
    } else {
        return eta * incident - (eta * dot(normal, incident) + sqrt(k)) * normal;
    }
}

// 球面坐标
vec3 sphericalToCartesian(float r, float theta, float phi) {
    return vec3(
        r * sin(phi) * cos(theta),
        r * sin(phi) * sin(theta),
        r * cos(phi)
    );
}
```

## 六、完整示例

### 示例1：动态渐变背景
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 标准化坐标
    vec2 uv = fragCoord / iResolution.xy;
    
    // 创建动态渐变
    float time = iTime * 0.5;
    vec3 color1 = vec3(0.1, 0.2, 0.8);
    vec3 color2 = vec3(0.8, 0.1, 0.3);
    
    // 添加噪声
    float noise = fbm(uv * 3.0 + time, 4);
    
    // 混合颜色
    vec3 color = mix(color1, color2, uv.x + noise * 0.2);
    
    // 添加扫描线
    color *= 0.9 + 0.1 * sin(uv.y * iResolution.y * 0.5 + time * 5.0);
    
    // 添加晕影
    color *= vignette(uv, 0.8);
    
    fragColor = vec4(color, 1.0);
}
```

### 示例2：交互式粒子系统
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    
    // 鼠标位置
    vec2 mouse = iMouse.xy / iResolution.xy;
    mouse = mouse * 2.0 - 1.0;
    mouse.x *= iResolution.x / iResolution.y;
    
    // 粒子参数
    float time = iTime;
    vec3 color = vec3(0.0);
    
    // 生成多个粒子
    for (int i = 0; i < 20; i++) {
        float fi = float(i);
        
        // 粒子位置
        vec2 pos = vec2(
            sin(time * 0.5 + fi * 0.7) * 0.5,
            cos(time * 0.3 + fi * 0.5) * 0.5
        );
        
        // 鼠标影响
        if (iMouse.z > 0.0) {
            pos += mouse * 0.5;
        }
        
        // 粒子大小和颜色
        float size = 0.02 + 0.01 * sin(time + fi);
        vec3 particleColor = hsv2rgb(vec3(fi * 0.1 + time * 0.1, 0.8, 1.0));
        
        // 计算距离
        float dist = length(uv - pos);
        float intensity = smoothstep(size, 0.0, dist);
        
        // 累加颜色
        color += particleColor * intensity;
    }
    
    // 添加辉光
    color = pow(color, vec3(0.4545));  // Gamma校正
    
    fragColor = vec4(color, 1.0);
}
```

### 示例3：3D光线步进场景
```glsl
// 场景距离函数
float sceneSDF(vec3 p) {
    // 地面
    float ground = p.y + 1.0;
    
    // 球体
    vec3 spherePos = vec3(sin(iTime) * 2.0, 0.0, 0.0);
    float sphere = length(p - spherePos) - 1.0;
    
    // 合并
    return min(ground, sphere);
}

// 法线计算
vec3 calcNormal(vec3 p) {
    const float eps = 0.001;
    return normalize(vec3(
        sceneSDF(vec3(p.x + eps, p.y, p.z)) - sceneSDF(vec3(p.x - eps, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + eps, p.z)) - sceneSDF(vec3(p.x, p.y - eps, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z + eps)) - sceneSDF(vec3(p.x, p.y, p.z - eps))
    ));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    
    // 相机设置
    vec3 ro = vec3(0.0, 0.0, 5.0);  // 相机位置
    vec3 rd = normalize(vec3(uv, -1.0));  // 射线方向
    
    // 光线步进
    float t = 0.0;
    vec3 p = ro;
    
    for (int i = 0; i < 100; i++) {
        p = ro + rd * t;
        float d = sceneSDF(p);
        
        if (d < 0.001) break;
        if (t > 100.0) break;
        
        t += d;
    }
    
    // 计算颜色
    vec3 color = vec3(0.0);
    
    if (t < 100.0) {
        // 命中物体
        vec3 normal = calcNormal(p);
        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
        
        // 漫反射
        float diff = max(dot(normal, lightDir), 0.0);
        color = vec3(diff) * vec3(0.8, 0.5, 0.2);
        
        // 环境光
        color += vec3(0.1, 0.1, 0.2);
    } else {
        // 背景
        color = vec3(0.1, 0.1, 0.2);
    }
    
    fragColor = vec4(color, 1.0);
}
```

## 七、性能优化技巧

### 1. 减少纹理采样
```glsl
// 不好：多次采样同一纹理
float value1 = texture(iChannel0, uv).r;
float value2 = texture(iChannel0, uv + offset).r;

// 好：一次采样多个通道
vec4 tex = texture(iChannel0, uv);
float value1 = tex.r;
float value2 = texture(iChannel0, uv + offset).r;
```

### 2. 使用近似函数
```glsl
// 快速平方根倒数（Quake III算法）
float fastInverseSqrt(float x) {
    float xhalf = 0.5 * x;
    int i = floatBitsToInt(x);
    i = 0x5f3759df - (i >> 1);
    x = intBitsToFloat(i);
    x = x * (1.5 - xhalf * x * x);
    return x;
}

// 快速正弦近似
float fastSin(float x) {
    x = mod(x, 6.2831853);
    if (x > 3.14159265) x -= 6.2831853;
    return (4.0 * x * (3.14159265 - abs(x))) / (9.8696044);
}
```

### 3. 循环优化
```glsl
// 不好：动态循环次数
for (int i = 0; i < int(sin(iTime) * 10.0); i++) {
    // ...
}

// 好：固定循环次数
const int MAX_ITERATIONS = 10;
for (int i = 0; i < MAX_ITERATIONS; i++) {
    // ...
}
```

## 八、调试技巧

### 1. 可视化调试
```glsl
// 显示UV坐标
vec3 debugUV(vec2 uv) {
    return vec3(uv, 0.0);
}

// 显示法线
vec3 debugNormal(vec3 normal) {
    return normal * 0.5 + 0.5;
}

// 显示深度
vec3 debugDepth(float depth) {
    return vec3(depth);
}

// 显示网格
float debugGrid(vec2 uv, float scale) {
    vec2 grid = fract(uv * scale);
    float line = min(grid.x, grid.y);
    return step(line, 0.01);
}
```

### 2. 性能分析
```glsl
// 帧时间显示
void showFrameTime() {
    float frameTime = iTimeDelta * 1000.0;  // 毫秒
    float fps = 1.0 / iTimeDelta;
    
    // 在左上角显示
    if (fragCoord.x < 200.0 && fragCoord.y < 50.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.8);
        // 这里可以添加文字渲染逻辑
    }
}
```

## 九、常用资源与参考

### 1. 内置纹理
- `iChannel0`: 默认纹理（噪声）
- `iChannel1`: 立方体贴图
- `iChannel2`: 视频纹理
- `iChannel3`: 音频纹理

### 2. 快捷键
- `Ctrl+Enter`: 运行/停止
- `Ctrl+S`: 保存
- `Ctrl+Shift+S`: 另存为
- `Ctrl+Z`: 撤销
- `Ctrl+Y`: 重做
- `F11`: 全屏

### 3. 常用网站
- https://www.shadertoy.com/
- https://thebookofshaders.com/
- https://iquilezles.org/articles/

## 十、最佳实践总结

1. **坐标处理**：始终将像素坐标标准化到[0,1]或[-1,1]范围
2. **时间使用**：使用`iTime`创建动画，`iTimeDelta`控制速度
3. **性能优先**：减少纹理采样，使用近似函数，避免动态循环
4. **模块化设计**：将复杂功能拆分为独立函数
5. **交互设计**：利用`iMouse`和`iKeyboard`增加交互性
6. **视觉效果**：结合多种技术（噪声、SDF、后处理）创造丰富效果
7. **调试技巧**：使用颜色编码可视化中间结果
8. **学习资源**：多研究社区优秀作品，理解实现原理

通过掌握这些常用函数和变量，你可以在Shadertoy上创造出各种令人惊叹的实时图形效果。