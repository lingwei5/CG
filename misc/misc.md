工作中遇到的各种知识 不限于图形学，当前主要是开源库的一些关键知识点记录

# 图形相关的各种库

## 几何处理库
### igl
https://github.com/libigl/libigl 几何处理库

### assimp

### tinyobjloader
```c++
struct tinyobj::attrib_t
{
	std::vector<real_t> vertices;  // 'v'(xyz)

  // For backward compatibility, we store vertex weight in separate array.
  std::vector<real_t> vertex_weights;  // 'v'(w)
  std::vector<real_t> normals;         // 'vn'
  std::vector<real_t> texcoords;       // 'vt'(uv)

  // For backward compatibility, we store texture coordinate 'w' in separate
  // array.
  std::vector<real_t> texcoord_ws;  // 'vt'(w)
  std::vector<real_t> colors; 
};

struct shape_t {
  std::string name;
  mesh_t mesh;
  lines_t lines;
  points_t points;
};

struct material_t {
  std::string name;

  real_t ambient[3];
  real_t diffuse[3];
  real_t specular[3];
  real_t transmittance[3];
  real_t emission[3];
  real_t shininess;
  real_t ior;       // index of refraction
  real_t dissolve;  // 1 == opaque; 0 == fully transparent
  // illumination model (see http://www.fileformat.info/format/material/)
  int illum;

  int dummy;  // Suppress padding warning.

  std::string ambient_texname;   // map_Ka. For ambient or ambient occlusion.
  std::string diffuse_texname;   // map_Kd
  std::string specular_texname;  // map_Ks
  std::string specular_highlight_texname;  // map_Ns
  std::string bump_texname;                // map_bump, map_Bump, bump
  std::string displacement_texname;        // disp
  std::string alpha_texname;               // map_d
  std::string reflection_texname;          // refl

  texture_option_t ambient_texopt;
  texture_option_t diffuse_texopt;
  texture_option_t specular_texopt;
  texture_option_t specular_highlight_texopt;
  texture_option_t bump_texopt;
  texture_option_t displacement_texopt;
  texture_option_t alpha_texopt;
  texture_option_t reflection_texopt;

  // PBR extension
  // http://exocortex.com/blog/extending_wavefront_mtl_to_support_pbr
  real_t roughness;            // [0, 1] default 0
  real_t metallic;             // [0, 1] default 0
  real_t sheen;                // [0, 1] default 0
  real_t clearcoat_thickness;  // [0, 1] default 0
  real_t clearcoat_roughness;  // [0, 1] default 0
  real_t anisotropy;           // aniso. [0, 1] default 0
  real_t anisotropy_rotation;  // anisor. [0, 1] default 0
  real_t pad0;
  std::string roughness_texname;  // map_Pr
  std::string metallic_texname;   // map_Pm
  std::string sheen_texname;      // map_Ps
  std::string emissive_texname;   // map_Ke
  std::string normal_texname;     // norm. For normal mapping.

  texture_option_t roughness_texopt;
  texture_option_t metallic_texopt;
  texture_option_t sheen_texopt;
  texture_option_t emissive_texopt;
  texture_option_t normal_texopt;

  int pad2;

  std::map<std::string, std::string> unknown_parameter;
  /**and on */
};
```



## 通用图像处理库
1. stb_image
stb_truetype

- https://ermig1979.github.io/Simd/ simd库

## 纹理图像处理
1. dds ktx io https://github.com/g-truc/gli
2. https://github.com/AcademySoftwareFoundation/OpenImageIO 读写多种图像格式的库
3. openexr
4. DirectXTex Texcov Texassemble https://github.com/Microsoft/DirectXTex/wiki/Texassemble
5. https://github.com/matyalatte/Texconv-Custom-DLL 微软的纹理转换工具的跨平台版本


## 纹理查看器

### tev
大量使用17 20

``` c++ 可视化面板
/*Represents a display surface (i.e. a full-screen or windowed GLFW window)
and forms the root element of a hierarchy of nanogui widgets.
*/
class NANOGUI_EXPORT Screen;

//top-level window
class ImageViewer:public nanogui::Screen: public Widget : public Object
{
	updateTitle();
};
//表示一个显示表面（即全屏或窗口化的GLFW窗口） ,所有的内容包括UI都是绘制出来的，UI使用了nanoVG库

```

```c++ imagecanvas
//imageviewer的绘制区
class ImageCanvas : public nanogui::Canvas
{
	void getValuesAtNanoPos();
};

class Image;//图像路径，图像数据，图像信息
class ImageData//图像数据
{
    size;
    displaySize;
    dataWindow;
    displayWindow;
};
rec709 color space:HDR UHDR
```

```c++
ImageInfoWindow:应该是鼠标放到ImageButton上时，显示图像信息的控件
9
ImageButton:图像列表
```

### ImageViewer
https://github.com/kopaka1822/ImageViewer.git 可以看hdr dds png等,可以参照实现一个查看器

## 数学库
glm

### imath
半精度浮点数 Industrail Light&Magic
``` c++
/// @file half.h
/// The half type is a 16-bit floating number, compatible with the
/// IEEE 754-2008 binary16 type.
///
/// **Representation of a 32-bit float:**
///
/// We assume that a float, f, is an IEEE 754 single-precision
/// floating point number, whose bits are arranged as follows:
///
///     31 (msb)
///     |
///     | 30     23
///     | |      |
///     | |      | 22                    0 (lsb)
///     | |      | |                     |
///     X XXXXXXXX XXXXXXXXXXXXXXXXXXXXXXX
///
///     s e        m
///
/// S is the sign-bit, e is the exponent and m is the significand.
///
/// If e is between 1 and 254, f is a normalized number:
///
///             s    e-127
///     f = (-1)  * 2      * 1.m
///
/// If e is 0, and m is not zero, f is a denormalized number:
///
///             s    -126
///     f = (-1)  * 2      * 0.m
///
/// If e and m are both zero, f is zero:
///
///     f = 0.0
///
/// If e is 255, f is an "infinity" or "not a number" (NAN),
/// depending on whether m is zero or not.
///
/// Examples:
///
///     0 00000000 00000000000000000000000 = 0.0
///     0 01111110 00000000000000000000000 = 0.5
///     0 01111111 00000000000000000000000 = 1.0
///     0 10000000 00000000000000000000000 = 2.0
///     0 10000000 10000000000000000000000 = 3.0
///     1 10000101 11110000010000000000000 = -124.0625
///     0 11111111 00000000000000000000000 = +infinity
///     1 11111111 00000000000000000000000 = -infinity
///     0 11111111 10000000000000000000000 = NAN
///     1 11111111 11111111111111111111111 = NAN
///
/// **Representation of a 16-bit half:**
///
/// Here is the bit-layout for a half number, h:
///
///     15 (msb)
///     |
///     | 14  10
///     | |   |
///     | |   | 9        0 (lsb)
///     | |   | |        |
///     X XXXXX XXXXXXXXXX
///
///     s e     m
///
/// S is the sign-bit, e is the exponent and m is the significand.
///
/// If e is between 1 and 30, h is a normalized number:
///
///             s    e-15
///     h = (-1)  * 2     * 1.m
///
/// If e is 0, and m is not zero, h is a denormalized number:
///
///             S    -14
///     h = (-1)  * 2     * 0.m
///
/// If e and m are both zero, h is zero:
///
///     h = 0.0
///
/// If e is 31, h is an "infinity" or "not a number" (NAN),
/// depending on whether m is zero or not.
///
/// Examples:
///
///     0 00000 0000000000 = 0.0
///     0 01110 0000000000 = 0.5
///     0 01111 0000000000 = 1.0
///     0 10000 0000000000 = 2.0
///     0 10000 1000000000 = 3.0
///     1 10101 1111000001 = -124.0625
///     0 11111 0000000000 = +infinity
///     1 11111 0000000000 = -infinity
///     0 11111 1000000000 = NAN
///     1 11111 1111111111 = NAN
///
/// **Conversion via Lookup Table:**
///
/// Converting from half to float is performed by default using a
/// lookup table. There are only 65,536 different half numbers; each
/// of these numbers has been converted and stored in a table pointed
/// to by the ``imath_half_to_float_table`` pointer.
///
/// Prior to Imath v3.1, conversion from float to half was
/// accomplished with the help of an exponent look table, but this is
/// now replaced with explicit bit shifting.
///
/// **Conversion via Hardware:**
///
/// For Imath v3.1, the conversion routines have been extended to use
/// F16C SSE instructions whenever present and enabled by compiler
/// flags.
///
/// **Conversion via Bit-Shifting**
///
/// If F16C SSE instructions are not available, conversion can be
/// accomplished by a bit-shifting algorithm. For half-to-float
/// conversion, this is generally slower than the lookup table, but it
/// may be preferable when memory limits preclude storing of the
/// 65,536-entry lookup table.
///
/// The lookup table symbol is included in the compilation even if
/// ``IMATH_HALF_USE_LOOKUP_TABLE`` is false, because application code
/// using the exported ``half.h`` may choose to enable the use of the table.
///
/// An implementation can eliminate the table from compilation by
/// defining the ``IMATH_HALF_NO_LOOKUP_TABLE`` preprocessor symbol.
/// Simply add:
///
///     #define IMATH_HALF_NO_LOOKUP_TABLE
///
/// before including ``half.h``, or define the symbol on the compile
/// command line.
///
/// Furthermore, an implementation wishing to receive ``FE_OVERFLOW``
/// and ``FE_UNDERFLOW`` floating point exceptions when converting
/// float to half by the bit-shift algorithm can define the
/// preprocessor symbol ``IMATH_HALF_ENABLE_FP_EXCEPTIONS`` prior to
/// including ``half.h``:
///
///     #define IMATH_HALF_ENABLE_FP_EXCEPTIONS
///
/// **Conversion Performance Comparison:**
///
/// Testing on a Core i9, the timings are approximately:
///
/// half to float
/// - table: 0.71 ns / call
/// - no table: 1.06 ns / call
/// - f16c: 0.45 ns / call
///
/// float-to-half:
/// - original: 5.2 ns / call
/// - no exp table + opt: 1.27 ns / call
/// - f16c: 0.45 ns / call
///
/// **Note:** the timing above depends on the distribution of the
/// floats in question.
///
```




# UI库 底层也是shader渲染
前端各种UI库
mfc c# wpf WinUi WinForms
eletron
qt
lvgl
nanovg:2d vector drawing based on opengl

ImGUI:轻量 无状态 高性能 跨平台，适合游戏编辑器、调试界面以及CAD软件界面

**nanogui vs imgui**
🔍 核心工作机制剖析
这个表格揭示了根本差异，下面我们深入看看这些差异是如何体现在具体工作机制上的。

NanoGUI的保留模式：其架构类似于许多传统的GUI框架（如Qt）。你需要在初始化时创建控件对象（例如按钮、滑块），这些对象会一直存在于内存中，形成一个持久的控件树。NanoGUI的布局引擎会帮你计算和管理这些控件的位置与大小。当有用户输入（如点击、拖拽）时，系统会通过事件回调机制（例如一个onClick函数）来通知你的程序。

ImGui的即时模式：它没有持久的控件对象。相反，在应用的每一帧，你的代码都需要通过直接调用函数（如ImGui::Button("Click Me")）来“描述”当前帧的UI应该长什么样。这个函数调用不仅完成了绘制，其返回值（一个布尔值）就直接告诉你在这一帧中按钮是否被按下。所有的UI状态（例如输入框的文字、窗口是否打开）都必须由你的应用程序在ImGui之外进行存储和管理，并在每一帧传递给ImGui。

🎨 渲染与实现细节
两者在渲染和底层实现上的考量也各有侧重。

NanoGUI的集成化渲染：它被设计为与OpenGL（包括OpenGL ES）紧密集成，直接利用这些底层API进行硬件加速渲染，以实现高性能的2D图形界面。其代码结构包含了从控件到渲染的完整实现。

ImGui的解耦设计：ImGui采用了核心库与渲染后端分离的架构。它的核心只负责生成绘制命令列表（包含顶点、索引、纹理等），而具体的渲染工作则交给独立的、可插拔的后端（如OpenGL、DirectX、Vulkan）来完成。这种设计使其能轻松嵌入到不同的图形项目中。在内存管理上，ImGui为应对每帧重建带来的压力，广泛采用了对象池（如窗口对象池）和帧内临时内存分配等策略来优化性能、避免内存碎片


NanoVG:借鉴HTML5 canvas的api，专注于2d矢量图形渲染,解决如何画的问题，不管画的是按钮还是啥，也不关心是否被点击，类似于Qt的渲染引擎
Nanogui:基于NanoVG，解决如何布局的问题，解决画什么的问题，解决如何点击的问题，也就是一套GUI框架，类似于Qt

```c++ NanoVG 渲染管线的重要组成部分，它负责收集和预处理所有的绘图命令，为后续的渲染做好准备
static void nvg__appendCommands(NVGcontext* ctx, float* vals, int nvals)
{
	NVGstate* state = nvg__getState(ctx);
	int i;

	if (ctx->ncommands+nvals > ctx->ccommands) {
		float* commands;
		int ccommands = ctx->ncommands+nvals + ctx->ccommands/2;
		commands = (float*)realloc(ctx->commands, sizeof(float)*ccommands);
		if (commands == NULL) return;
		ctx->commands = commands;
		ctx->ccommands = ccommands;
	}

	if ((int)vals[0] != NVG_CLOSE && (int)vals[0] != NVG_WINDING) {
		ctx->commandx = vals[nvals-2];
		ctx->commandy = vals[nvals-1];
	}

	// transform commands
  /**
  根据不同的命令类型对坐标进行变换
  使用当前状态的变换矩阵（state->xform）来变换坐标点
  支持的命令类型：
  NVG_MOVETO：移动到指定点（3个float：命令+X+Y）
  NVG_LINETO：画线到指定点（3个float：命令+X+Y）
  NVG_BEZIERTO：画贝塞尔曲线（7个float：命令+三个控制点的X和Y）
  NVG_CLOSE：闭合路径（1个float：命令）
  NVG_WINDING：设置绕行方向（2个float：命令+方向） */
	i = 0;
	while (i < nvals) {
		int cmd = (int)vals[i];
		switch (cmd) {
		case NVG_MOVETO:
			nvgTransformPoint(&vals[i+1],&vals[i+2], state->xform, vals[i+1],vals[i+2]);
			i += 3;
			break;
		case NVG_LINETO:
			nvgTransformPoint(&vals[i+1],&vals[i+2], state->xform, vals[i+1],vals[i+2]);
			i += 3;
			break;
		case NVG_BEZIERTO:
			nvgTransformPoint(&vals[i+1],&vals[i+2], state->xform, vals[i+1],vals[i+2]);
			nvgTransformPoint(&vals[i+3],&vals[i+4], state->xform, vals[i+3],vals[i+4]);
			nvgTransformPoint(&vals[i+5],&vals[i+6], state->xform, vals[i+5],vals[i+6]);
			i += 7;
			break;
		case NVG_CLOSE:
			i++;
			break;
		case NVG_WINDING:
			i += 2;
			break;
		default:
			i++;
		}
	}

	memcpy(&ctx->commands[ctx->ncommands], vals, nvals*sizeof(float));

	ctx->ncommands += nvals;
}

```
```c++ nanoVG具体的渲染工作由后端负责，包括填充(fill)、描边(stroke)、绘制三角形(triangles)等操作
  NVGparams params;
	NVGcontext* ctx = NULL;
	GLNVGcontext* gl = (GLNVGcontext*)malloc(sizeof(GLNVGcontext));
	if (gl == NULL) goto error;
	memset(gl, 0, sizeof(GLNVGcontext));

	memset(&params, 0, sizeof(params));
	params.renderCreate = glnvg__renderCreate;
	params.renderCreateTexture = glnvg__renderCreateTexture;
	params.renderDeleteTexture = glnvg__renderDeleteTexture;
	params.renderUpdateTexture = glnvg__renderUpdateTexture;
	params.renderGetTextureSize = glnvg__renderGetTextureSize;
	params.renderViewport = glnvg__renderViewport;
	params.renderCancel = glnvg__renderCancel;
	params.renderFlush = glnvg__renderFlush;
	params.renderFill = glnvg__renderFill;
	params.renderStroke = glnvg__renderStroke;
	params.renderTriangles = glnvg__renderTriangles;
	params.renderDelete = glnvg__renderDelete;
	params.userPtr = gl;
	params.edgeAntiAlias = flags & NVG_ANTIALIAS ? 1 : 0;
```


# 通用库
## 测试框架
1. gtest
2. Catch2
3. doctest

## 日志库


## 命令行参数库
clara:https://github.com/philsquared/Clara 单头文件命令行解析库