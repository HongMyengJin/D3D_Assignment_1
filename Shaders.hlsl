#define Texture_Color 0
#define Texture_Texture 2
#define Texture_Normal 2
#define Texture_Illumination 3
#define Texture_ObjectID_zDepth 4
#define Texture_NormalV 5
#define Texture_Depth 6
struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;
	float4					m_cSpecular; //a = power
	float4					m_cEmissive;

};

cbuffer cbFrameworkInfo : register(b0)
{
	float 		gfCurrentTime;
	float		gfElapsedTime;
};


cbuffer cbCameraInfo : register(b1)
{
	matrix		gmtxView : packoffset(c0);
	matrix		gmtxProjection : packoffset(c4);
	float3		gvCameraPosition : packoffset(c8);
	matrix		gmtxInverseProjection : packoffset(c12);
};

cbuffer cbGameObjectInfo : register(b2)
{
	matrix		gmtxGameObject : packoffset(c0); // 16
	MATERIAL	gMaterial : packoffset(c4); // 16
	uint		gnTexturesMask : packoffset(c8); // 1

};

cbuffer cbTextureInfo : register(b3)
{
	matrix		gmtxTexture : packoffset(c0); // 16
};

cbuffer cbDrawOptions : register(b5)
{
	int4 gvDrawOptions : packoffset(c0);
};
#include "Light.hlsl"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//#define _WITH_VERTEX_LIGHTING

#define MATERIAL_ALBEDO_MAP			0x01
#define MATERIAL_SPECULAR_MAP		0x02
#define MATERIAL_NORMAL_MAP			0x04
#define MATERIAL_METALLIC_MAP		0x08
#define MATERIAL_EMISSION_MAP		0x10
#define MATERIAL_DETAIL_ALBEDO_MAP	0x20
#define MATERIAL_DETAIL_NORMAL_MAP	0x40

//#define _WITH_STANDARD_TEXTURE_MULTIPLE_DESCRIPTORS

#ifdef _WITH_STANDARD_TEXTURE_MULTIPLE_DESCRIPTORS
Texture2D gtxtAlbedoTexture : register(t6);
Texture2D gtxtSpecularTexture : register(t7);
Texture2D gtxtNormalTexture : register(t8);
Texture2D gtxtMetallicTexture : register(t9);
Texture2D gtxtEmissionTexture : register(t10);
Texture2D gtxtDetailAlbedoTexture : register(t11);
Texture2D gtxtDetailNormalTexture : register(t12);
#else
Texture2D gtxtStandardTextures[7] : register(t6);
#endif

SamplerState gssWrap : register(s0);

Texture2D gtxtTexture : register(t0);
struct VS_STANDARD_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 bitangent : BITANGENT;
};

struct VS_STANDARD_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float3 normalW : NORMAL;
	float3 tangentW : TANGENT;
	float3 bitangentW : BITANGENT;
	float2 uv : TEXCOORD;
};

VS_STANDARD_OUTPUT VSStandard(VS_STANDARD_INPUT input)
{
	VS_STANDARD_OUTPUT output;

	output.positionW = (float3)mul(float4(input.position, 1.0f), gmtxGameObject);
	output.normalW = mul(input.normal, (float3x3)gmtxGameObject);
	output.tangentW = (float3)mul(float4(input.tangent, 1.0f), gmtxGameObject);
	output.bitangentW = (float3)mul(float4(input.bitangent, 1.0f), gmtxGameObject);
	output.position = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

float4 PSStandard(VS_STANDARD_OUTPUT input) : SV_TARGET
{
	float4 cAlbedoColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cSpecularColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cNormalColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cMetallicColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cEmissionColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

#ifdef _WITH_STANDARD_TEXTURE_MULTIPLE_DESCRIPTORS
	if (gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtAlbedoTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtSpecularTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtNormalTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtMetallicTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtEmissionTexture.Sample(gssWrap, input.uv);
#else
	if (gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtStandardTextures[0].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtStandardTextures[1].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtStandardTextures[2].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtStandardTextures[3].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtStandardTextures[4].Sample(gssWrap, input.uv);
#endif

	float4 cIllumination = float4(1.0f, 1.0f, 1.0f, 1.0f);

	float4 cColor = cAlbedoColor + cSpecularColor + cEmissionColor;

	//if (cAlbedoColor.a < 0.95)
	//	cColor.a = 0.32;
	if (gnTexturesMask & MATERIAL_NORMAL_MAP)
	{
		float3 normalW = input.normalW;
		float3x3 TBN = float3x3(normalize(input.tangentW), normalize(input.bitangentW), normalize(input.normalW));
		float3 vNormal = normalize(cNormalColor.rgb * 2.0f - 1.0f); //[0, 1] → [-1, 1]
		normalW = normalize(mul(vNormal, TBN));
		cIllumination = Lighting(input.positionW, normalW);
		cColor = lerp(cColor, cIllumination, 0.5f);
	}

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SKYBOX_CUBEMAP_INPUT
{
	float3 position : POSITION;
};

struct VS_SKYBOX_CUBEMAP_OUTPUT
{
	float3	positionL : POSITION;
	float4	position : SV_POSITION;
};

VS_SKYBOX_CUBEMAP_OUTPUT VSSkyBox(VS_SKYBOX_CUBEMAP_INPUT input)
{
	VS_SKYBOX_CUBEMAP_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.positionL = input.position;

	return(output);
}

TextureCube gtxtSkyCubeTexture : register(t13);
SamplerState gssClamp : register(s1);

float4 PSSkyBox(VS_SKYBOX_CUBEMAP_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtSkyCubeTexture.Sample(gssClamp, input.positionL);

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SPRITE_TEXTURED_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
};

struct VS_SPRITE_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

VS_SPRITE_TEXTURED_OUTPUT VSTextured(VS_SPRITE_TEXTURED_INPUT input)
{
	VS_SPRITE_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

float4 PSTextured(VS_SPRITE_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTexture.Sample(gssWrap, input.uv);

	return(cColor);
}

VS_SPRITE_TEXTURED_OUTPUT VSSpriteAnimation(VS_SPRITE_TEXTURED_INPUT input)
{
	VS_SPRITE_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.uv = mul(float3(input.uv, 1.0f), (float3x3)(gmtxTexture)).xy;
	//output.uv = input.uv;
	return(output);
}

/*
float4 PSTextured(VS_SPRITE_TEXTURED_OUTPUT input, uint nPrimitiveID : SV_PrimitiveID) : SV_TARGET
{
	float4 cColor;
	if (nPrimitiveID < 2)
		cColor = gtxtTextures[0].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 4)
		cColor = gtxtTextures[1].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 6)
		cColor = gtxtTextures[2].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 8)
		cColor = gtxtTextures[3].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 10)
		cColor = gtxtTextures[4].Sample(gWrapSamplerState, input.uv);
	else
		cColor = gtxtTextures[5].Sample(gWrapSamplerState, input.uv);
	float4 cColor = gtxtTextures[NonUniformResourceIndex(nPrimitiveID/2)].Sample(gWrapSamplerState, input.uv);

	return(cColor);
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
Texture2D gtxtTerrainTexture : register(t14);
Texture2D gtxtDetailTexture : register(t15);


float4 PSTerrain(VS_SPRITE_TEXTURED_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtTerrainTexture.Sample(gssWrap, input.uv);

	return(cColor);
}

struct VS_TERRAIN_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct VS_TERRAIN_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
	VS_TERRAIN_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.color = input.color;
	output.uv0 = input.uv0;
	output.uv1 = input.uv1;

	return(output);
}

float4 PSTerrain(VS_TERRAIN_OUTPUT input) : SV_TARGET
{
	float4 cBaseTexColor = gtxtTerrainTexture.Sample(gssWrap, input.uv0);
	float4 cDetailTexColor = gtxtDetailTexture.Sample(gssWrap, input.uv1);
	float fAlpha = gtxtTerrainTexture.Sample(gssWrap, input.uv0);

	//float4 cColor = cBaseTexColor * 0.5f + cDetailTexColor * 0.5f;
	float4 cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));

	return(cColor);
}


Texture2D gtxtWaterBaseTexture : register(t3);
Texture2D gtxtWaterDetailTexture : register(t4);

struct VS_WATER_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	//	float2 uv1 : TEXCOORD1;
};

struct VS_WATER_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD0;
	//	float2 uv1 : TEXCOORD1;
};

VS_WATER_OUTPUT VSRippleWater(VS_WATER_INPUT input)
{
	VS_WATER_OUTPUT output;

	//	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f + input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(input.position.x * 0.01f) * 45.0f + cos(input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f) * 45.0f + cos(gfCurrentTime * 1.0f + input.position.z * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 0.5f + ((input.position.x * input.position.x) + (input.position.z * input.position.z)) * 0.01f) * 35.0f;
	//	input.position.y += sin(gfCurrentTime * 1.0f + (((input.position.x * input.position.x) + (input.position.z * input.position.z)) - (1000 * 1000) * 2) * 0.0001f) * 10.0f;

	//	input.position.y += sin(gfCurrentTime * 1.0f + (((input.position.x * input.position.x) + (input.position.z * input.position.z))) * 0.0001f) * 10.0f;
	input.position.y += sin(gfCurrentTime * 0.5f + input.position.x * 0.01f) * 45.0f + cos(gfCurrentTime * 1.0f + input.position.z * 0.01f) * 35.0f;
	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	//	output.color = input.color;
	output.color = (input.position.y / 200.0f) + 0.55f;
	output.uv0 = input.uv0;
	//	output.uv1 = input.uv1;

	return(output);
}

float4 PSRippleWater(VS_WATER_OUTPUT input) : SV_TARGET
{
	//	float4 cBaseTexColor = gtxtWaterBaseTexture.Sample(gSamplerState, input.uv0);
		float4 cBaseTexColor = gtxtWaterBaseTexture.Sample(gssWrap, float2(input.uv0.x, input.uv0.y - abs(sin(gfCurrentTime)) * 0.0151f));
		//	float4 cColor = input.color * 0.3f + cBaseTexColor * 0.7f;
			float4 cDetailTexColor = gtxtWaterDetailTexture.Sample(gssWrap, input.uv0 * 10.0f);
			float4 cColor = (cBaseTexColor * 0.3f + cDetailTexColor * 0.7f) + float4(0.0f, 0.0f, 0.15f, 0.0f);
			cColor *= input.color;

			return(cColor);
}


// 큐브 출력 쉐이더

struct VS_DIFFUSED_INPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
};

struct VS_DIFFUSED_OUTPUT
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
};

VS_DIFFUSED_OUTPUT VSCube(VS_DIFFUSED_INPUT input)
{
	VS_DIFFUSED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.color = input.color;

	return(output);
}

float4 PSCube(VS_DIFFUSED_OUTPUT input) : SV_TARGET
{
	return(input.color);
}


// PostProcessing
///////////////////////////////////////////////////////////////////////////////
float4 VSPostProcessing(uint nVertexID : SV_VertexID) : SV_POSITION
{
	if (nVertexID == 0) return(float4(-1.0f, +1.0f, 0.0f, 1.0f));
	if (nVertexID == 1) return(float4(+1.0f, +1.0f, 0.0f, 1.0f));
	if (nVertexID == 2) return(float4(+1.0f, -1.0f, 0.0f, 1.0f));

	if (nVertexID == 3) return(float4(-1.0f, +1.0f, 0.0f, 1.0f));
	if (nVertexID == 4) return(float4(+1.0f, -1.0f, 0.0f, 1.0f));
	if (nVertexID == 5) return(float4(-1.0f, -1.0f, 0.0f, 1.0f));

	return(float4(0, 0, 0, 0));
}

float4 PSPostProcessing(float4 position : SV_POSITION) : SV_Target
{
	return(float4(0.0f, 0.0f, 0.0f, 1.0f));
}
struct VS_SCREEN_RECT_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD0;
	float3 viewSpaceDir : TEXCOORD1;
};

VS_SCREEN_RECT_TEXTURED_OUTPUT VSScreenRectSamplingTextured(uint nVertexID : SV_VertexID)
{
	VS_SCREEN_RECT_TEXTURED_OUTPUT output = (VS_SCREEN_RECT_TEXTURED_OUTPUT)0;

	if (nVertexID == 0) { output.position = float4(-1.0f, +1.0f, 0.0f, 1.0f); output.uv = float2(0.0f, 0.0f); }
	else if (nVertexID == 1) { output.position = float4(+1.0f, +1.0f, 0.0f, 1.0f); output.uv = float2(1.0f, 0.0f); }
	else if (nVertexID == 2) { output.position = float4(+1.0f, -1.0f, 0.0f, 1.0f); output.uv = float2(1.0f, 1.0f); }

	else if (nVertexID == 3) { output.position = float4(-1.0f, +1.0f, 0.0f, 1.0f); output.uv = float2(0.0f, 0.0f); }
	else if (nVertexID == 4) { output.position = float4(+1.0f, -1.0f, 0.0f, 1.0f); output.uv = float2(1.0f, 1.0f); }
	else if (nVertexID == 5) { output.position = float4(-1.0f, -1.0f, 0.0f, 1.0f); output.uv = float2(0.0f, 1.0f); }

	output.viewSpaceDir = mul(output.position, gmtxInverseProjection).xyz;

	return(output);
}

float4 GetColorFromDepth(float fDepth)
{
	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	if (fDepth > 1.0f) cColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
	else if (fDepth < 0.00625f) cColor = float4(1.0f, 0.0f, 0.0f, 1.0f); // 스카이박스
	else if (fDepth < 0.0125f) cColor = float4(0.0f, 1.0f, 0.0f, 1.0f); // 모델
	else if (fDepth < 0.025f) cColor = float4(0.0f, 0.0f, 1.0f, 1.0f);
	else if (fDepth < 0.05f) cColor = float4(1.0f, 1.0f, 0.0f, 1.0f);
	else if (fDepth < 0.075f) cColor = float4(0.0f, 1.0f, 1.0f, 1.0f);
	else if (fDepth < 0.1f) cColor = float4(1.0f, 0.5f, 0.5f, 1.0f);
	else if (fDepth < 0.4f) cColor = float4(0.5f, 1.0f, 1.0f, 1.0f);
	else if (fDepth < 0.6f) cColor = float4(1.0f, 0.0f, 1.0f, 1.0f);
	else if (fDepth < 0.8f) cColor = float4(0.5f, 0.5f, 1.0f, 1.0f);
	else if (fDepth < 0.9f) cColor = float4(0.5f, 1.0f, 0.5f, 1.0f);
	else cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	return(cColor);
}


static float gfLaplacians[9] = { -1.0f, -1.0f, -1.0f, -1.0f, 8.0f, -1.0f, -1.0f, -1.0f, -1.0f };
static int2 gnOffsets[9] = { { -1,-1 }, { 0,-1 }, { 1,-1 }, { -1,0 }, { 0,0 }, { 1,0 }, { -1,1 }, { 0,1 }, { 1,1 } };

float4 LaplacianEdge(float4 position)
{
	float fObjectEdgeness = 0.0f, fNormalEdgeness = 0.0f, fDepthEdgeness = 0.0f;
	float3 f3NormalEdgeness = float3(0.0f, 0.0f, 0.0f), f3DepthEdgeness = float3(0.0f, 0.0f, 0.0f);
	if ((uint(position.x) >= 1) || (uint(position.y) >= 1) || (uint(position.x) <= gtxtStandardTextures[0].Length.x - 2) || (uint(position.y) <= gtxtStandardTextures[0].Length.y - 2))
	{
		float fObjectID = gtxtStandardTextures[4][int2(position.xy)].r;
		for (int input = 0; input < 9; input++)
		{
			//			if (fObjectID != gtxtStandardTextures[4][int2(position.xy) + gnOffsets[input]].r) fObjectEdgeness = 1.0f;

			float3 f3Normal = gtxtStandardTextures[1][int2(position.xy) + gnOffsets[input]].xyz * 2.0f - 1.0f;
			float3 f3Depth = gtxtStandardTextures[6][int2(position.xy) + gnOffsets[input]].xyz * 2.0f - 1.0f;
			f3NormalEdgeness += gfLaplacians[input] * f3Normal;
			f3DepthEdgeness += gfLaplacians[input] * f3Depth;
		}
		fNormalEdgeness = f3NormalEdgeness.r * 0.3f + f3NormalEdgeness.g * 0.59f + f3NormalEdgeness.b * 0.11f;
		fDepthEdgeness = f3DepthEdgeness.r * 0.3f + f3DepthEdgeness.g * 0.59f + f3DepthEdgeness.b * 0.11f;
	}
	float3 cColor = gtxtStandardTextures[0][int2(position.xy)].rgb;
	/*
		float fNdotV = 1.0f - dot(gtxtStandardTextures[1][int2(position.xy)].xyz * 2.0f - 1.0f, gf3CameraDirection);
		float fNormalThreshold = (saturate((fNdotV - 0.5f) / (1.0f - 0.5f)) * 7.0f) + 1.0f;
		float fDepthThreshold = 150.0f * gtxtStandardTextures[6][int2(position.xy)].r * fNormalThreshold;
	*/
	if (fObjectEdgeness == 1.0f)
		cColor = float3(1.0f, 0.0f, 0.0f);
	else// =>
	{
		cColor.g += fNormalEdgeness * 100.f;
		cColor.r += fDepthEdgeness * 100.f;
		//		cColor.g += (fNormalEdgeness > fNormalThreshold) ? 1.0f : 0.0f;
		//		cColor.r += (fDepthEdgeness > fDepthThreshold) ? 1.0f : 0.0f;
	}

	return(float4(cColor, 1.0f));
}

float4 AlphaBlend(float4 top, float4 bottom)
{
	float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
	float alpha = top.a + bottom.a * (1 - top.a);

	return(float4(color, alpha));
}

float4 Outline(VS_SCREEN_RECT_TEXTURED_OUTPUT input)
{
	float fHalfScaleFloor = floor(1.0f * 0.5f);
	float fHalfScaleCeil = ceil(1.0f * 0.5f);

	float2 f2BottomLeftUV = input.uv - float2((1.0f / gtxtStandardTextures[0].Length.x), (1.0f / gtxtStandardTextures[0].Length.y)) * fHalfScaleFloor;
	float2 f2TopRightUV = input.uv + float2((1.0f / gtxtStandardTextures[0].Length.x), (1.0f / gtxtStandardTextures[0].Length.y)) * fHalfScaleCeil;
	float2 f2BottomRightUV = input.uv + float2((1.0f / gtxtStandardTextures[0].Length.x) * fHalfScaleCeil, -(1.0f / gtxtStandardTextures[0].Length.y * fHalfScaleFloor));
	float2 f2TopLeftUV = input.uv + float2(-(1.0f / gtxtStandardTextures[0].Length.x) * fHalfScaleFloor, (1.0f / gtxtStandardTextures[0].Length.y) * fHalfScaleCeil);

	float3 f3NormalV0 = gtxtStandardTextures[6].Sample(gssWrap, f2BottomLeftUV).rgb;
	float3 f3NormalV1 = gtxtStandardTextures[6].Sample(gssWrap, f2TopRightUV).rgb;
	float3 f3NormalV2 = gtxtStandardTextures[6].Sample(gssWrap, f2BottomRightUV).rgb;
	float3 f3NormalV3 = gtxtStandardTextures[6].Sample(gssWrap, f2TopLeftUV).rgb;

	float fDepth0 = gtxtStandardTextures[6].Sample(gssWrap, f2BottomLeftUV).b;
	float fDepth1 = gtxtStandardTextures[6].Sample(gssWrap, f2TopRightUV).b;
	float fDepth2 = gtxtStandardTextures[6].Sample(gssWrap, f2BottomRightUV).b;
	float fDepth3 = gtxtStandardTextures[6].Sample(gssWrap, f2TopLeftUV).b;

	float3 f3NormalV = f3NormalV0 * 2.0f - 1.0f;
	float fNdotV = 1.0f - dot(f3NormalV, -input.viewSpaceDir);

	float fNormalThreshold01 = saturate((fNdotV - 0.5f) / (1.0f - 0.5f));
	float fNormalThreshold = (fNormalThreshold01 * 7.0f) + 1.0f;

	float fDepthThreshold = 1.5f * fDepth0 * fNormalThreshold;

	float fDepthDifference0 = fDepth1 - fDepth0;
	float fDepthDifference1 = fDepth3 - fDepth2;
	float fDdgeDepth = sqrt(pow(fDepthDifference0, 2) + pow(fDepthDifference1, 2)) * 100.0f;
	fDdgeDepth = (fDdgeDepth > 0.0125f) ? 1.0f : 0.0f;

	float3 fNormalDifference0 = f3NormalV1 - f3NormalV0;
	float3 fNormalDifference1 = f3NormalV3 - f3NormalV2;
	float fEdgeNormal = sqrt(dot(fNormalDifference0, fNormalDifference0) + dot(fNormalDifference1, fNormalDifference1));
	fEdgeNormal = (fEdgeNormal > 0.001f) ? 1.0f : 0.0f;

	float fEdge = max(fDdgeDepth, fEdgeNormal);
	float4 f4EdgeColor = float4(1.0f, 1.0f, 1.0f, 1.0f * fEdgeNormal);

	float4 f4Color = gtxtStandardTextures[0].Sample(gssWrap, input.uv);

	return(AlphaBlend(f4EdgeColor, f4Color));
}

float4 PSScreenRectSamplingTextured(VS_SCREEN_RECT_TEXTURED_OUTPUT input) : SV_Target
{
	float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	switch (gvDrawOptions.x)
	{
		case 84: //'T'
		{
			cColor = gtxtStandardTextures[2].Sample(gssWrap, input.uv);
			break;
		}
		case 76: //'L'
		{
			cColor = gtxtStandardTextures[3].Sample(gssWrap, input.uv);
			break;
		}
		case 78: //'N'
		{
			cColor = gtxtStandardTextures[1].Sample(gssWrap, input.uv);
			break;
		}
		case 68: //'D'
		{
			float fDepth = gtxtStandardTextures[6].Load(uint3((uint)input.position.x, (uint)input.position.y, 0)).r;
			cColor = GetColorFromDepth(1.0f - fDepth);
			break;
		}
		case 90: //'Z' 
		{
			float fDepth = gtxtStandardTextures[5].Load(uint3((uint)input.position.x, (uint)input.position.y, 0)).r;
			cColor = GetColorFromDepth(fDepth);
			break;
		}
		case 79: //'O'
		{
			uint fObjectID = (uint)gtxtStandardTextures[4].Load(uint3((uint)input.position.x, (uint)input.position.y, 0)).r;
			//			uint fObjectID = (uint)gtxtInputTextures[4][int2(input.position.xy)].r;
			if (fObjectID == 0) cColor.rgb = float3(1.0f, 1.0f, 1.0f);
			else if (fObjectID <= 1000) cColor.rgb = float3(1.0f, 0.0f, 0.0f);
			else if (fObjectID <= 2000) cColor.rgb = float3(0.0f, 1.0f, 0.0f);
			else if (fObjectID <= 3000) cColor.rgb = float3(0.0f, 0.0f, 1.0f);
			else if (fObjectID <= 4000) cColor.rgb = float3(0.0f, 1.0f, 1.0f);
			else if (fObjectID <= 5000) cColor.rgb = float3(1.0f, 1.0f, 0.0f);
			else if (fObjectID <= 6000) cColor.rgb = float3(1.0f, 1.0f, 1.0f);
			else if (fObjectID <= 7000) cColor.rgb = float3(1.0f, 0.5f, 0.5f);
			else cColor.rgb = float3(0.3f, 0.75f, 0.5f);

			//			cColor.rgb = fObjectID;
			break;
		}
		case 69: //'E'
		{
			//cColor = gtxtStandardTextures[6].Sample(gssWrap, input.uv);
			cColor = LaplacianEdge(input.position);
			//cColor = Outline(input);
			if (cColor.r <= 1.f)
				discard;
			break;
		}
	}
	return(cColor);
}

