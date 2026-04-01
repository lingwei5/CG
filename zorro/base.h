//中文
#ifndef __BASE_H__
#define __BASE_H__
#define NUM_DEFERRED_CONSTANTS 1024
#define NUM_SAMPLER_TEXTURES 16
#define NUM_TEXTURES 24

#ifdef OPENGL
#include <data/core/shaders/common/platform/gl.h>
#elif DIRECT3D11
#include <data/core/shaders/common/platform/dx11.h>
#elif VULKAN
#include <data/core/shaders/common/platform/vk.h>
#endif
/* Constants
 */
#define STREAM_DEPTH 0
#define STREAM_UV 1
#define STREAM_TANGENT 2
#define STREAM_BINORMAL 3
#define STREAM_NORMAL 4
#define STREAM_VERTEX_IN_VIEW 5
#define STREAM_VERTEX_IN_WORLD 6
#define STREAM_TESSELLATE 7
#define STREAM_LIGHT_DIRECTION 8
#define STREAM_CAMERA_DIRCETION 9
#define STREAM_SHADOW 10
#define STREAM_VERTEX_IN_LIGHT_PROJ 11
#define STREAM_ANY_1 12
#define STREAM_ANY_2 13
#define STREAM_ANY_3 14
#define STREAM_ANY_4 15
#define STREAM_ANY_5 16
#define STREAM_ANY_6 17

#define IG_VISION_NONE	0
#define IG_VISION_IR	1
#define IG_VISION_LLNV	2

#define Z_NEAR 0
#define Z_FAR 1

#define ALPHA_TEST_THRESHOLD 0.5f
#define VOLUMETRIC_SAMPLE_NUM 32

#ifdef USE_TAA
	#define WIREFRAME_DEPTH_BIAS -0.001f
#else
	#define WIREFRAME_DEPTH_BIAS -0.005f
#endif

#define SSAO_BIT					1<<31
#define SSR_BIT						1<<30
#define SSS_BIT						1<<29
#define REFRACTION_BIT				1<<28
#define ENVIRONMENT_BIT				1<<27
#define SUN_SHAFTS_BIT				1<<26
#define WGS_LIGHTWORLD_BIT			1<<25
#define SHORELINE_WETNESS_BIT		1<<24

#define FREE_MATERIAL_MASK			0x00FFFFFF
#define RESERVED_MATERIAL_MASK		0xFF000000
#define PI				3.14159265358979323846
#define PI2				9.86960440108935861881
#define PI05			1.57079632679489661923
#define PI_INV			0.31830988618379067153803535746773
#define LOG2			0.693147181f
#define LOG10			2.302585093f
#define SQRT2			1.414213562f
#define EPSILON			1e-6f
#define INT_MAX			4294967294
#define INFINITY		1e+9f
#define DEG2RAD			0.01745329251994329577
#define RAD2DEG			57.29577951308232087685
#define BYTE_UNORM_STEP	1.0f / 255.0f

#define TYPE_R float
#define TYPE_RG float2
#define TYPE_RGB float3
#define TYPE_RGBA float4
#define TYPE_INT int
#define TYPE_UINT uint

#ifdef FRAGMENT
	#define GET_DATA(V) IN_DATA(V)
	#define INIT_DATA(TYPE,NUM,NAME) \
	INIT_IN(TYPE,NUM) \
	#define NAME GET_DATA(NUM)

#else
	#define GET_DATA(V) OUT_DATA(V)
	#define INIT_DATA(TYPE,NUM,NAME) \
	INIT_OUT(TYPE,NUM) \
	#define NAME GET_DATA(NUM)
	
	
	#ifdef VERTEX_ATTRIBUTE_GEOMETRY
		
		ATTRI_BEGIN(VS_IN)
			INIT_ATTRIBUTE(float4, 0, POSITION)
			INIT_ATTRIBUTE(float4,1,TEXCOORD0)
			INIT_ATTRIBUTE(float4,2,TEXCOORD1)
			INIT_ATTRIBUTE(float4,3,TEXCOORD2)
			#ifdef SKINNED
				INIT_ATTRIBUTE(float3,4,TEXCOORD3)
			#endif
			INIT_INSTANCE
		ATTRI_END
		
		#define ATTRIBUTE_POSITION		IN_ATTRIBUTE(0)
		#define ATTRIBUTE_UV			IN_ATTRIBUTE(1)
		#define ATTRIBUTE_BASIS			IN_ATTRIBUTE(2)
		#define ATTRIBUTE_COLOR			IN_ATTRIBUTE(3)
		#ifdef SKINNED
			#define ATTRIBUTE_OLD_POSITION	IN_ATTRIBUTE(4)
		#else
			
			#define ATTRIBUTE_OLD_POSITION	ATTRIBUTE_POSITION.xyz
		#endif
		
	#endif
	
	#ifdef VERTEX_ATTRIBUTE_POST
		ATTRI_BEGIN(VS_IN)
			INIT_ATTRIBUTE(float4, 0, POSITION)
			INIT_ATTRIBUTE(float4,1,TEXCOORD0)
			INIT_ATTRIBUTE(float4,2,TEXCOORD1)
			INIT_INSTANCE
		ATTRI_END
		
		#define ATTRIBUTE_POSITION		IN_ATTRIBUTE(0)
		#define ATTRIBUTE_UV			IN_ATTRIBUTE(1)
		#define ATTRIBUTE_COLOR			IN_ATTRIBUTE(2)
	#endif
	
#endif

#define IF_DATA(NAME) #ifdef NAME
#define ENDIF #endif

#define MAIN_BEGIN_VERTEX(VS_OUT) MAIN_BEGIN(VS_OUT,VS_IN)
#define MAIN_END_VERTEX MAIN_END
#ifdef PASS_SHADOW
#define MAIN_BEGIN_FRAGMENT(PS_OUT) MAIN_VOID_BEGIN(PS_IN)
#define MAIN_END_FRAGMENT MAIN_VOID_END
#else
#define MAIN_BEGIN_FRAGMENT(PS_OUT) MAIN_BEGIN(PS_OUT,PS_IN)
#define MAIN_END_FRAGMENT MAIN_END
#endif
/* Vector aliases
*/
#define float_isrgb		2.2f

#define float4_zero		float4(0.0f,0.0f,0.0f,0.0f)
#define float4_one		float4(1.0f,1.0f,1.0f,1.0f)
#define float4_half		float4(0.5f,0.5f,0.5f,0.5f)
#define float4_neg_one	float4(-1.0f,-1.0f,-1.0f,-1.0f)
#define float4_isrgb	float4(float_isrgb,float_isrgb,float_isrgb,float_isrgb)

#define float3_zero		float3(0.0f,0.0f,0.0f)
#define float3_one		float3(1.0f,1.0f,1.0f)
#define float3_half		float3(0.5f,0.5f,0.5f)
#define float3_neg_one	float3(-1.0f,-1.0f,-1.0f)
#define float3_up		float3(0.0f,0.0f,1.0f)
#define float3_isrgb	float3(float_isrgb,float_isrgb,float_isrgb)
#define float3_epsilon	float3(EPSILON,EPSILON,EPSILON)

#define float2_zero		float2(0.0f,0.0f)
#define float2_one		float2(1.0f,1.0f)
#define float2_half		float2(0.5f,0.5f)
#define float2_neg_one	float2(-1.0f,-1.0f)
#define float2_isrgb	float2(float_isrgb,float_isrgb)

#define float_zero		0.0f

#define float3_luma float3(0.299f,0.587f,0.114f)

#define int4_zero		int4(0,0,0,0)
#define int4_one		int4(1,1,1,1)
#define int4_neg_one	int4(-1,-1,-1,-1)

#define int3_zero		int3(0,0,0)
#define int3_one		int3(1,1,1)
#define int3_neg_one	int3(-1,-1,-1)

#define int2_zero		int2(0,0)
#define int2_one		int2(1,1)
#define int2_neg_one	int2(-1,-1)

#define int_zero		0


#define double3_zero	double3(DF(0.0),DF(0.0),DF(0.0))
#define double3_one		double3(DF(1.0),DF(1.0),DF(1.0))

/* Matrix aliases
*/
#define float4x4_identity float4x4(1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f)


#ifdef DOUBLE_PRECISION
	#define real		double
	#define real1		double
	#define real2		double2
	#define real3		double3
	#define real4		double4
	#define real3_zero	double3_zero
	#define real3_one	double3_one
	#define real3x3		double3x3
	#define real4x4		double4x4
#else
	#define real		float
	#define real1		float
	#define real2		float2
	#define real3		float3
	#define real4		float4
	#define real3_zero	float3_zero
	#define real3_one	float3_one
	#define real3x3		float3x3
	#define real4x4		float4x4
#endif

#ifdef DIRECT3D11 || OPENGL || VULKAN
CBUFFER_BEGIN(textures_parameters)
	UNIFORM float4 s_textures_size[NUM_TEXTURES];
CBUFFER_END

CBUFFER_BEGIN(global_parameters)
	UNIFORM int s_frame;
	UNIFORM int s_vision_mode;
	UNIFORM float s_time;//animation time
	UNIFORM float s_polygon_front;
	UNIFORM float s_atmosphere_thickness;
	UNIFORM float s_ambient_scale;
	UNIFORM float s_light_world_scale;
	UNIFORM float4 s_ambient_color;
	//w,h,1/w,1/h
	UNIFORM real4 s_viewport;
	UNIFORM float4 s_environment[9];
CBUFFER_END

CBUFFER_BEGIN(camera_parameters)
	//相机的世界位置
	UNIFORM real3 s_camera_position;
	//相机的经纬高，弧度
	UNIFORM real3 s_camera_lon_lat_alt;
	//near,far ,1/near, 1/far
	UNIFORM real4 s_depth_range;
	UNIFORM real4x4 s_camera_projection;
	UNIFORM real4x4 s_camera_iprojection;
	UNIFORM real4x4 s_projection;
	UNIFORM real4x4 s_iprojection;
	UNIFORM real4x4 s_modelview;
	UNIFORM real4x4 s_imodelview;
	UNIFORM float4x4 s_iview_delta;
	UNIFORM float4 s_view_delta_z;
	UNIFORM float2 s_taa_offset;
	UNIFORM real4x4 s_camera_wgs_transform;
	UNIFORM real4x4 s_camera_inv_wgs_transform;
	//基于相机的位于海拔0处的局部坐标系
	UNIFORM real4x4 s_wgs_local_transform;
	UNIFORM real4x4 s_inv_wgs_local_transform;
CBUFFER_END
CBUFFER_BEGIN(shader_water_parameters)
	UNIFORM float4 s_water_waves[4];
CBUFFER_END

CBUFFER_BEGIN(node_parameters)
	UNIFORM real4x4 s_world_transform;
	UNIFORM real4x4 s_iworld_transform;
	UNIFORM real4x4 s_wgs_transform;
	UNIFORM real4x4 s_inv_wgs_transform;
CBUFFER_END
CBUFFER_BEGIN(cube_render_parameters)
	UNIFORM float4x4 s_iface_rotation[6];
CBUFFER_END
CBUFFER_BEGIN(material_parameters)
	UNIFORM float4 s_material_anisotropy;
CBUFFER_END
CBUFFER_BEGIN(object_parameters)
	//参考坐标系
	UNIFORM real4x4 s_reference_transform;
CBUFFER_END
/* shader light parameters
 */
//already in modelview coordinates
CBUFFER_BEGIN(light_parameters)
	UNIFORM float3 s_light_position;
	UNIFORM float3 s_light_direction;
	UNIFORM float3 s_light_direction_world;
	UNIFORM float s_light_shadow_distance;
	UNIFORM float s_light_shadow_scale;
	//light,normal
	UNIFORM float2 s_light_shadow_depth_bias;
	UNIFORM float4 s_light_positions[4];
	UNIFORM float4 s_light_color;
	UNIFORM float4 s_light_colors[4];
	UNIFORM float4 s_light_iradius;
	UNIFORM float4 s_light_attenuations;
	UNIFORM float4x4 s_light_transform;
	UNIFORM float4x4 s_light_projection;
	UNIFORM float4x4 s_light_shadow_projection;
	//
	UNIFORM int s_has_shadow;
	UNIFORM int s_has_lightworld;
	UNIFORM int s_has_sun_moon_wgs_fade;
	CBUFFER_END
//already in modelview coordinates
CBUFFER_BEGIN(sun_moon_parameters)
	UNIFORM float3 s_sun_direction;
	UNIFORM float3 s_sun_direction_world;
	UNIFORM float4 s_sun_color;
	UNIFORM float4 s_sun_color_modulation;
	UNIFORM float3 s_moon_direction;
	UNIFORM float3 s_moon_direction_world;
	UNIFORM float4 s_moon_color;
	UNIFORM float4 s_moon_color_modulation;
CBUFFER_END


CBUFFER_BEGIN(light_omni_parameters)
		UNIFORM float2 s_light_shadow_depth_range;
CBUFFER_END

CBUFFER_BEGIN(light_world_parameters)
	UNIFORM int s_light_num_shadow_splits;
	UNIFORM float2 s_light_shadow_projection_z;
	UNIFORM float4 s_light_shadow_projections_xy[4];
	UNIFORM float4x4 s_light_shadow_render_transforms[4];
	UNIFORM float4x4 s_light_shadow_projections[4];
CBUFFER_END

CBUFFER_BEGIN(base_surface_parameters)
	UNIFORM float4 s_surface_bound_sphere;
	//min_visible_distance，max_visible_distance，imin_fade_distance,imax_fade_distance
	UNIFORM float4 s_surface_distances;
	UNIFORM float s_surface_fade;
	UNIFORM int s_material_mask;
	UNIFORM int s_material_backface_mask;
CBUFFER_END

CBUFFER_BEGIN(base_animation_parameters)
	//time, stem, leaf
	UNIFORM float3 s_animation_param;
	UNIFORM float3 s_animation_wind;
	UNIFORM float4 s_material_animation_stem;
	UNIFORM float3 s_material_animation_leaf;
CBUFFER_END

/* shader light prob parameters
*/
CBUFFER_BEGIN(volume_parameters)
	UNIFORM float3 s_volume_size;
	UNIFORM float s_volume_fade;
	UNIFORM float4 s_volume_local_camera_position;
	UNIFORM float4 s_volume_plane;
CBUFFER_END

CBUFFER_BEGIN(shader_particles_parameters)
	UNIFORM real4 s_particles_transform[3];
	UNIFORM float s_particles_radius;
	UNIFORM float s_particles_fade;
	UNIFORM real3 s_particles_center;
CBUFFER_END

CBUFFER_BEGIN(planet_parameters)
	//lod,x,y,uv scale
	UNIFORM float4 s_tile_lod_x_y;
CBUFFER_END

CBUFFER_BEGIN(haze_parameters)
	UNIFORM float s_haze_max_distance;
	UNIFORM float s_haze_density;
CBUFFER_END
//gl dx的对齐方式不同
//dx:float float3合并为1个float4
//gl:float float3合并为2个float4

#ifdef USE_FIELD_ANIMATION
	/*
	0:vec3(2.0f) / size, attenuation;
	1:animation_stem, animation_leaf, animation_angle
	2:animation_wind,spread;
	*/
CBUFFER_BEGIN(field_animation_parameters)
	UNIFORM float2 s_field_animation_num_animations;//x:num_box;y:num_total
	UNIFORM float4 s_field_animation_parameters[24];//8个
	UNIFORM float4 s_field_animation_transforms[24];//8个,0,1,2:xyz为旋转的逆，w为位置
CBUFFER_END
#endif
//////////////////////////////////////////////////////////////////////////
#define dotFixed(X,Y) saturate(dot(X,Y))
#define lerpFixed(X,Y,FACTOR) lerp(X,Y,saturate(FACTOR))

float3 srgb(in float3 color)
{
	return pow(color, FLOAT3(1.0f / 2.2f));
}

float srgbInv(in float value)
{
	return pow(value, float_isrgb);
}

float2 srgbInv(in float2 value)
{
	return pow(value, float2_isrgb);
}

float3 srgbInv(in float3 value)
{
	return pow(value, float3_isrgb);
}

float4 srgbInv(in float4 value)
{
	return pow(value, float4_isrgb);
}
bool checkMask(in int mask, in int bits)
{
	return (mask & bits) != 0;
}

bool checkMask(in uint mask, in uint bits)
{
	return (mask & bits) != 0;
}
float pow2(in float value)
{
	return value * value;
}

float2 pow2(in float2 value)
{
	return value * value;
}

float3 pow2(in float3 value)
{
	return value * value;
}

float4 pow2(in float4 value)
{
	return value * value;
}
float powMirror(in float value, in float power)
{
	return 1.0f - pow(1.0f - value, power);
}

float2 powMirror(in float2 value, in float2 power)
{
	return float2_one - pow(float2_one - value, power);
}

float3 powMirror(in float3 value, in float3 power)
{
	return float3_one - pow(float3_one - value, power);
}

float4 powMirror(in float4 value, in float4 power)
{
	return float4_one - pow(float4_one - value, power);
}

double4x4 perspective(double fovV, double aspect, double n, double f)
{
	double h = 1.0;
	double w = aspect;
	h = tan(float(fovV * DEG2RAD * 0.5));
	w = h * aspect;
	double nf = n - f;
	double4x4 ret;
	ret[0][0] = 1.0 / w;
	ret[0][1] = 0.0;
	ret[0][2] = 0.0;
	ret[0][3] = 0.0;

	ret[1][0] = 0.0;
	ret[1][1] = 1.0 / h;
	ret[1][2] = 0.0;
	ret[1][3] = 0.0;

	ret[2][0] = 0.0;
	ret[2][1] = 0.0;
	ret[2][2] = (f + n) / nf;
	ret[2][3] = 2.0 * f * n / nf;

	ret[3][0] = 0.0;
	ret[3][1] = 0.0;
	ret[3][2] = -1;
	ret[3][3] = 0;
	return ret;
}
float3 floatPack1212To888(in float2 x)
{
	// Pack 12:12 to 8:8:8
	float2 x1212 = floor(x * 4095);
	float2 high = floor(x1212 / 256);	// x1212 >> 8
	float2 low = x1212 - high * 256;	// x1212 & 255
	float3 x888 = float3(low, high.x + high.y * 16);
	return saturate(x888 / 255);
}

float2 floatPack888To1212(in float3 x)
{
	// Pack 8:8:8 to 12:12
	float3 x888 = floor(x * 255);
	float high = floor(x888.z / 16);	// x888.z >> 4
	float low = x888.z - high * 16;		// x888.z & 15
	float2 x1212 = x888.xy + float2(low, high) * 256;
	return saturate(x1212 / 4095);
}

// todo: pack!
float floatPack88To16(in float2 value)
{
	float temp_x = floor(saturate(value.x) * 255.0f);
	float temp_y = floor(saturate(value.y) * 255.0f);

	float result = temp_x + temp_y * 256.0f;
	return saturate(result / 65535.0f);
	// uint2 bytes = uint2(floor(saturate(value) * 255.0f));
	// return (bytes.x | (bytes.y << 8)) / 65535.0f;
}

float2 floatPack16To88(in float value)
{
	float temp = floor(saturate(value) * 65535.0f);
	float high = floor(temp / 256.0f);
	float low = temp - high * 256.0f;
	return saturate(float2(low, high) / 255.0f);

	// uint byte = uint(floor(value * 65535.0f));
	// return float2(byte & 0x00ff,(byte >> 8) & 0x00ff) / 255.0f;
}

float floatPack44To8(in float x, in float y)
{
	float temp_x = floor(saturate(x) * 15.0f);
	float temp_y = floor(saturate(y) * 15.0f);

	float result = temp_x + temp_y * 16.0f;
	return saturate(result / 255.0f);
}

float2 floatPack8To44(in float value)
{
	float temp = floor(saturate(value) * 255.0f);
	float high = floor(temp / 16.0f);
	float low = temp - high * 16.0f;
	return saturate(float2(low, high) / 15.0f);
}

float2 floatPack8888To1616(in float4 value)
{
	return float2(floatPack88To16(value.xy), floatPack88To16(value.zw));
}

float4 floatPack1616To8888(in float2 value)
{
	float4 unpacked = float4_zero;
	unpacked.xy = floatPack16To88(value.x);
	unpacked.zw = floatPack16To88(value.y);
	return unpacked;
}

float2 floatPack32To1616(in float value)
{
	return unpack_uint32_to_rg16(asuint(value));
}

float floatPack1616To32(in float2 value)
{
	return asfloat(pack_rg16_to_uint32(value));
}
#define DECODE_NORMAL(normal_flt3)\
		normal_flt3 = normal_flt3*2-float3_one;\
		normal_flt3 = normalize(normal_flt3);


#else
	#error unknown shader
#endif //DIRECT3D11

#endif /* __BASE_H__ */
