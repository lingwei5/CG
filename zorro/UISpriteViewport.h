/** @file
 * @brief UISpriteViewport 类声明。
 * 提供在 UI 中嵌入渲染视口的能力，可将场景渲染到纹理并在 UI 中显示。
 */
#pragma once
#include "ui/UISpriteLayer.h"
class Texture;
class TextureRender;
class Camera;
class World;
/**
 * @brief 可在 UI 中显示渲染视口的 UI 元素。
 * 支持设置相机、投影/模型视图矩阵、渲染到纹理以及帧率控制。
 * 所有权：Camera、World、Texture 等对象的生命周期需由调用方管理，确保在本对象使用期间有效。
 * 线程安全性：渲染相关方法应在渲染线程或主线程中调用，且需要与引擎的渲染循环同步。
 */
struct RenderCaller;
class J_API UISpriteViewport : public UISpriteLayer
{
protected:
	J_PROPERTY(int, m_viewport_mask, ViewportMask);
	J_PROPERTY(int, m_reflection_mask, ReflectionMask);
	J_PROPERTY_BOOL(m_auto_adjust_viewport_size, AutoAdjustViewportSize);
	//是否触发GameScene相关函数调用
	J_PROPERTY_BOOL(m_run_game, RunGame);
	Camera* m_cam;
	int m_texture_width;		// texture width
	int m_texture_height;		// texture height

	float m_viewport_ifps;	// viewport ifps
	float m_viewport_time;	// viewport time

	Texture* m_texture;
	TextureRender* m_texture_render;
	J_PROPERTY_REF(jString, m_post_materials, PostMaterials);
	J_PROPERTY(IG_VISION_MODE, m_vision_mode, VisionMode);
	J_PROPERTY_BOOL(m_enable_world_update, EnableWorldUpdate);
	J_PROPERTY_BOOL(m_first_frame, FirstFrame);
	J_PROPERTY(World*, m_world, World);
	J_PROPERTY_REF(vec4, m_clear_color, ClearColor);
	J_PROPERTY_REF(dmat4, m_old_projection, OldProjection);
	J_PROPERTY_REF(dmat4, m_old_modelview, OldModelview);
public:
	 /**
	  * @brief 构造函数。
	  * @param r UI 根节点指针。
	  * @param width 纹理初始宽度（像素）。
	  * @param height 纹理初始高度（像素）。
	  */
	UISpriteViewport(UIRoot* r, int width, int height);
	 /**
	  * @brief 析构函数，释放内部纹理与渲染资源（如属于本对象）。
	  */
	virtual ~UISpriteViewport();
public:
	 /**
	  * @brief 设置渲染目标纹理宽度。
	  * @param width 宽度（像素）。
	  */
	void setTextureWidth(int width);
	 /**
	  * @brief 获取渲染目标纹理宽度。
	  * @return 宽度（像素）。
	  */
	int getTextureWidth() const;

	 /**
	  * @brief 设置渲染目标纹理高度。
	  * @param height 高度（像素）。
	  */
	void setTextureHeight(int height);
	 /**
	  * @brief 获取渲染目标纹理高度。
	  * @return 高度（像素）。
	  */
	int getTextureHeight() const;
	 /**
	  * @brief 获取当前用于渲染的纹理指针。
	  * @return 纹理指针。
	  */
	Texture* getTexture() { return m_texture; }
	 /**
	  * @brief 设置视口的目标更新帧率（IFps）。
	  * @param ifps 目标帧率或步长参数。
	  */
	void setIFps(float ifps);
	 /**
	  * @brief 获取视口的 IFps。
	  * @return IFps 值。
	  */
	float getIFps() const;
public:
	 /**
	  * @brief 设置用于视口渲染的相机。
	  * @param c 相机指针。
	  * @note 相机指针生命周期需由调用方管理。
	  */
	void setCamera(Camera* c) { m_cam = c; }
	 /**
	  * @brief 获取当前绑定的相机指针。
	  * @return 相机指针。
	  */
	Camera* getCamera() { return m_cam; }
	 /**
	  * @brief 设置投影矩阵，用于渲染时替换相机投影。
	  * @param mat 投影矩阵引用。
	  */
	void setProjection(const dmat4& mat);
	 /**
	  * @brief 设置模型视图矩阵，用于渲染时替换相机模型视图。
	  * @param mat 模型视图矩阵引用。
	  */
	void setModelview(const dmat4& mat);
	 /**
	  * @brief 获取当前投影矩阵引用。
	  * @return 投影矩阵引用。
	  */
	const dmat4& getProjection();
	 /**
	  * @brief 获取当前模型视图矩阵引用。
	  * @return 模型视图矩阵引用。
	  */
	const dmat4& getModelview();
	 /**
	  * @brief 获取上一帧渲染到屏幕的纹理（若可用）。
	  * @return 纹理指针或 nullptr。
	  */
	// 获取上一帧屏幕纹理
	Texture* getLastScreenTexture();
public:
	 /**
	  * @brief 将传入的图像渲染到视口的目标纹理上。
	  * @param image 可变引用，包含要复制到纹理的数据。
	  */
	void renderImage(jImage& image);
public:
	UISignal<UIEventMouse> signalClick;
	UISignal<UIEventMouse> signalDClick;
	UISignal<UIEventMouse> signalPress;
	UISignal<UIEventMouse> signalHover;
	UISignal<UIEventMouse> signalUp;
	Signal<UISpriteViewport*> signalUpdateBegin;
	Signal<UISpriteViewport*> signalUpdateEnd;
public:
	 /**
	  * @brief 带深度的自定义渲染回调。
	  * @param world 渲染时使用的 World 指针。
	  * @note 默认空实现，派生类可重载以自定义渲染流程。
	  */
	virtual void onRenderWithDepth(RenderCaller*, World* world){}
	 /**
	  * @brief 无深度的自定义渲染回调。
	  * @param world 渲染时使用的 World 指针。
	  * @note 默认空实现，派生类可重载以自定义无深度渲染流程。
	  */
	virtual void onRenderWithoutDepth(RenderCaller*, World* world) {}
public:
	 /**
	  * @brief 鼠标双击事件处理。
	  * @param e 事件数据指针。
	  * @return 若事件被处理则返回 true。
	  */
	virtual bool onMouseDClick(const UIEventMouse* e)override;
	 /**
	  * @brief 鼠标按下事件处理。
	  * @param e 事件数据指针。
	  * @return 若事件被处理则返回 true。
	  */
	virtual bool onMouseDown(const UIEventMouse* e)override;
	 /**
	  * @brief 鼠标移动事件处理。
	  * @param e 事件数据指针。
	  * @return 若事件被处理则返回 true。
	  */
	virtual bool onMouseMove(const UIEventMouse* e)override;
	 /**
	  * @brief 鼠标抬起事件处理。
	  * @param e 事件数据指针。
	  * @return 若事件被处理则返回 true。
	  */
	virtual bool onMouseUp(const UIEventMouse* e)override;
	 /**
	  * @brief 键盘快捷键检测。
	  * @param e 键盘事件数据指针。
	  * @return 若快捷键被处理则返回 true。
	  */
	virtual bool checkShortcut(const UIEventKey* e)override;
	 /**
	  * @brief 更新视口（推进时间、触发渲染等）。
	  * @param dt 时间增量（秒）。
	  */
	// 更新视口
	virtual void update(float dt) override;
	 /**
	  * @brief 释放视口使用的资源。
	  */
	virtual void release();
protected:
	void clear_textures();
	void init_textures();
};

