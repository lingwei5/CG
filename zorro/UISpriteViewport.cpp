#include "Engine.h"
#include "render/Render.h"
#include "texture/Texture.h"
#include "texture/TextureRender.h"
#include "render/RState.h"
#include "ui/UISpriteViewport.h"
#include "render/RenderManager.h"
#include "interface/IGame.h"
#include "render/RExec.h"
#include "world/World.h" 
#include "camera/Camera.h"
#include "Engine.h"
#include "ui/UIPainter.h"
#include "gui/IGMainWindow.h"
#include "ui/UIRoot.h"
UISpriteViewport::UISpriteViewport(UIRoot* gui, int width, int height) 
	: UISpriteLayer(gui)
	, m_world(0)
	, m_cam(0)
	, m_enable_world_update(true)
	, m_vision_mode(IG_VISION_NONE)
	, m_first_frame(true)
	, m_run_game(true)
	, m_clear_color(vec4(0,0,0,1))
{
	m_old_modelview = m_old_projection = dmat4_identity;
	m_auto_adjust_viewport_size = false;
	m_texture_width = width;
	m_texture_height = height;
	//setMinWidth(width);
	//setMinHeight(height);
	setViewportMask(~0);
	setReflectionMask(~0);
	setIFps(0.0f);

	m_viewport_time = 0.0f;

	setBlendFunc(UI_BLEND_ONE, UI_BLEND_ZERO);

	m_texture = NULL;
	m_texture_render = NULL;
}

UISpriteViewport::~UISpriteViewport()
{
	clear_textures();
}

void UISpriteViewport::clear_textures()
{
	if (m_texture != NULL)
	{
		m_texture->release();
		jDestroy0(m_texture);
	}

	if (m_texture_render != NULL)
	{
		m_texture_render->release();
		jDestroy0(m_texture_render);
	}
	setRender(NULL);
}

void UISpriteViewport::setTextureWidth(int width)
{
	m_texture_width = width;
	clear_textures();
}

int UISpriteViewport::getTextureWidth() const
{
	return m_texture_width;
}

void UISpriteViewport::setTextureHeight(int height)
{
	m_texture_height = height;
	clear_textures();
}

int UISpriteViewport::getTextureHeight() const
{
	return m_texture_height;
}

void UISpriteViewport::setIFps(float ifps)
{
	m_viewport_ifps = J_MAX(ifps, EPSILON);
}

float UISpriteViewport::getIFps() const
{
	return m_viewport_ifps;
}


Texture* UISpriteViewport::getLastScreenTexture()
{
	RenderCaller* rc = GET_RENDER->getRenderCaller(this);
	if (rc)
	{
		return rc->last_screen_color;
	}
	return 0;
}

void UISpriteViewport::setProjection(const dmat4& mat)
{
	m_cam->setProjection(mat);
}


void UISpriteViewport::setModelview(const dmat4& mat)
{
	m_cam->setModelview(mat);
}


const dmat4& UISpriteViewport::getProjection()
{
	return m_cam->getProjection();
}


const dmat4& UISpriteViewport::getModelview()
{
	return m_cam->getModelview();
}

void UISpriteViewport::init_textures()
{
	if (m_texture_render == NULL)
	{
		m_texture_render = GET_RENDERMNGR->createTextureRender2D(m_texture_width, m_texture_height, 0, LINE_INFO);
	}

	if (m_texture == NULL)
	{
		RState* state = GET_RENDER->getState();
		int flags = TEXTURE_FLAG::FILTER_LINEAR | GET_RENDER->getTextureRenderFlags();
		m_texture = GET_RENDERMNGR->createTexture2D(m_texture_width, m_texture_height, TEXTURE_FORMAT_RGBA8_UNORM, flags, LINE_INFO);
		m_texture_render->setColorTexture(0, m_texture);
		m_texture_render->enable();
		m_texture_render->clearBuffer(BUFFER_COLOR);
		m_texture_render->resolve();
		//m_texture->copy2D();
		m_texture_render->disable();
	}
}

void UISpriteViewport::renderImage(jImage& image)
{
	JCHECK_RET(m_cam && m_world);
	// clear image
	image.release();

	// create textures
	init_textures();

	m_texture_render->enable();

	// render viewport
	World* world = m_world;
	GET_RENDER->renderViewport(world, m_cam->getProjection(), m_cam->getModelview(), this, true);

	m_texture_render->resolve();
	//m_texture->copy2D();
	// get texture image
	m_texture->getImage(&image);
	// flip image
	if (GET_RENDER->isFlipped()) image.flipY();
	m_texture_render->disable();
}


bool UISpriteViewport::onMouseDClick(const UIEventMouse* e)
{
	JCHECK_RET_0(e);

	UIElement* cur_focus = m_root->getFocusElement();
	do
	{
		JCHECK_BREAK(e->getType() == UI_EVENT_MOUSE);
		bool bHit = isHit(e->getX(), e->getY());
		if (bHit == false && isFocused() == false)
		{
			break;
		}
		if (e->isLeftButtion() || e->isRightButtion())
		{
			if (!isFocused())
			{
				setFocus();
			}
			signalDClick.exec(e, this);
			set_checker();
			return true;
		}
		return false;

	} while (0);
	return false;
}

bool UISpriteViewport::onMouseDown(const UIEventMouse* e)
{
	JCHECK_RET_0(e);

	UIElement* cur_focus = m_root->getFocusElement();
	do
	{
		JCHECK_BREAK(e->getType() == UI_EVENT_MOUSE);
		bool bHit = isHit(e->getX(), e->getY());
		if (bHit == false && isFocused() == false)
		{
			break;
		}
		if (e->isLeftButtion() || e->isRightButtion())
		{
			if (!isFocused())
			{
				setFocus();
				signalPress.exec(e, this);
			}
			else
			{
				signalHover.exec(e, this);
			}
			set_checker();
			return true;
		}
		return false;

	} while (0);
	return false;
}

bool UISpriteViewport::onMouseMove(const UIEventMouse* e)
{
	JCHECK_RET_0(e);

	UIElement* cur_focus = m_root->getFocusElement();
	do
	{
		JCHECK_BREAK(e->getType() == UI_EVENT_MOUSE);
		bool bHit = isHit(e->getX(), e->getY());
		if (bHit == false && isFocused() == false)
		{
			break;
		}
		if (bHit)
		{
			signalHover.exec(e, this);
			set_checker();
			return true;
		}
		return false;
	} while (0);
	return false;
}


bool UISpriteViewport::onMouseUp(const UIEventMouse* e)
{
	JCHECK_RET_0(e);

	UIElement* cur_focus = m_root->getFocusElement();
	do
	{
		JCHECK_BREAK(e->getType() == UI_EVENT_MOUSE);
		bool bHit = isHit(e->getX(), e->getY());
		if (bHit == false && isFocused() == false)
		{
			break;
		}
		signalUp.exec(e, this);
		bool bClick = false;
		if (cur_focus == this)
		{
			removeFocus();
			signalClick.exec(e, this);
			bClick = true;
		}
		set_checker();
		return true;
	} while (0);
	return false;
}


bool UISpriteViewport::checkShortcut(const UIEventKey* e)
{
	CHK_SHORTCUT(signalClick, e);
	CHK_SHORTCUT(signalDClick, e);
	CHK_SHORTCUT(signalPress, e);
	CHK_SHORTCUT(signalHover, e);
	CHK_SHORTCUT(signalUp, e);
	return UIElement::checkShortcut(e);
}

void UISpriteViewport::update(float dt)
{
	JCHECK_RET(m_cam);
	signalUpdateBegin(this);
	RExec* rr = GET_RENDER->getRenderer();
	if (m_auto_adjust_viewport_size)
	{
		if (getWidth() != m_texture_width ||
			getHeight() != m_texture_height)
		{
			clear_textures();
			m_texture_width = getWidth();
			m_texture_height = getHeight();
		}
	}
	// create textures
	init_textures();

	// update time
	m_viewport_time += m_root->getWidget()->getDeltaTime();

	Render* r = GET_RENDER;
	if (m_viewport_time > m_viewport_ifps)
	{
		vec4 old_clear_color = r->getBackgroundColor();
		r->setBackgroundColor(m_clear_color);
		m_viewport_time = jMath::mod(m_viewport_time, m_viewport_ifps);
		m_texture_render->setColorTexture(0, m_texture);
		m_texture_render->enable();
		m_texture_render->clearBuffer(BUFFER_ALL);
		World* world = m_world;
		bool enable_visualizer = m_cam->isEnableVisualizer();
		m_cam->setEnableVisualizer(false);
		rr->signalRenderWithDepth.connect(this, &UISpriteViewport::onRenderWithDepth);
		rr->signalRenderWithoutDepth.connect(this, &UISpriteViewport::onRenderWithoutDepth);
		IG_VISION_MODE mode = r->getVisionMode();
		jString post_mats = r->getRenderMaterials();
		r->setVisionMode(m_vision_mode);
		r->setRenderMaterials(m_post_materials);
		rr->saveState();
		rr->saveCamera();
		{
			if (m_first_frame)
			{
				m_first_frame = false;
				m_old_modelview = m_cam->getModelview();
				m_old_projection = m_cam->getProjection();
			}
			rr->setProjection(m_cam->getProjection());
			rr->setModelview(m_cam->getModelview());
			rr->setOldProjection(m_old_projection);
			rr->setOldModelview(m_old_modelview);
			GET_RENDER->update(0);
			if (world && m_enable_world_update)world->update(dt);
		}
		r->renderViewport(world, m_cam->getProjection(), m_cam->getModelview(), this, m_run_game);
		m_old_modelview = m_cam->getModelview();
		m_old_projection = m_cam->getProjection();
		rr->restoreCamera();
		rr->restoreState();
		//
		r->setBackgroundColor(old_clear_color);
		r->setRenderMaterials(post_mats);
		r->setVisionMode(mode);
		rr->signalRenderWithDepth.release();
		rr->signalRenderWithoutDepth.release();
		m_cam->setEnableVisualizer(enable_visualizer);
		m_texture_render->resolve();
		m_texture_render->disable();
	}
	// update texture
	setRender(m_texture, !GET_RENDER->isFlipped());
	signalUpdateEnd(this);
	UIElement::update(dt);
}


void UISpriteViewport::release()
{
	if (m_texture != NULL)
	{
		m_texture->release();
		jDestroy0(m_texture);
	}

	if (m_texture_render != NULL)
	{
		m_texture_render->release();
		jDestroy0(m_texture_render);
	}
	setRender(NULL);
	m_cam = 0;

	// force update
	m_viewport_time = m_viewport_ifps * 2.0f;
}
