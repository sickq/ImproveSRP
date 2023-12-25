// Made with Amplify Shader Editor v1.9.1.5
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Stylized Fog (Physical Height)"
{
	Properties
	{
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)
		[ASEEnd]_FogVariationTexture("Fog Variation Texture", 2D) = "white" {}


		//_TessPhongStrength( "Tess Phong Strength", Range( 0, 1 ) ) = 0.5
		//_TessValue( "Tess Max Tessellation", Range( 1, 32 ) ) = 16
		//_TessMin( "Tess Min Distance", Float ) = 10
		//_TessMax( "Tess Max Distance", Float ) = 25
		//_TessEdgeLength ( "Tess Edge length", Range( 2, 50 ) ) = 16
		//_TessMaxDisp( "Tess Max Displacement", Float ) = 25

		[HideInInspector] _QueueOffset("_QueueOffset", Float) = 0
        [HideInInspector] _QueueControl("_QueueControl", Float) = -1

        [HideInInspector][NoScaleOffset] unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
	}

	SubShader
	{
		LOD 0

		

		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "UniversalMaterialType"="Unlit" }

		Cull Front
		AlphaToMask Off

		Stencil
		{
			Ref 221
			ReadMask 222
			WriteMask 222
			Comp NotEqual
			Pass Keep
		}

		HLSLINCLUDE
		#pragma target 3.5
		#pragma prefer_hlslcc gles
		// ensure rendering platforms toggle list is visible

		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

		#ifndef ASE_TESS_FUNCS
		#define ASE_TESS_FUNCS
		float4 FixedTess( float tessValue )
		{
			return tessValue;
		}

		float CalcDistanceTessFactor (float4 vertex, float minDist, float maxDist, float tess, float4x4 o2w, float3 cameraPos )
		{
			float3 wpos = mul(o2w,vertex).xyz;
			float dist = distance (wpos, cameraPos);
			float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
			return f;
		}

		float4 CalcTriEdgeTessFactors (float3 triVertexFactors)
		{
			float4 tess;
			tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
			tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
			tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
			tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
			return tess;
		}

		float CalcEdgeTessFactor (float3 wpos0, float3 wpos1, float edgeLen, float3 cameraPos, float4 scParams )
		{
			float dist = distance (0.5 * (wpos0+wpos1), cameraPos);
			float len = distance(wpos0, wpos1);
			float f = max(len * scParams.y / (edgeLen * dist), 1.0);
			return f;
		}

		float DistanceFromPlane (float3 pos, float4 plane)
		{
			float d = dot (float4(pos,1.0f), plane);
			return d;
		}

		bool WorldViewFrustumCull (float3 wpos0, float3 wpos1, float3 wpos2, float cullEps, float4 planes[6] )
		{
			float4 planeTest;
			planeTest.x = (( DistanceFromPlane(wpos0, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos1, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos2, planes[0]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.y = (( DistanceFromPlane(wpos0, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos1, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos2, planes[1]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.z = (( DistanceFromPlane(wpos0, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos1, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos2, planes[2]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.w = (( DistanceFromPlane(wpos0, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos1, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
						  (( DistanceFromPlane(wpos2, planes[3]) > -cullEps) ? 1.0f : 0.0f );
			return !all (planeTest);
		}

		float4 DistanceBasedTess( float4 v0, float4 v1, float4 v2, float tess, float minDist, float maxDist, float4x4 o2w, float3 cameraPos )
		{
			float3 f;
			f.x = CalcDistanceTessFactor (v0,minDist,maxDist,tess,o2w,cameraPos);
			f.y = CalcDistanceTessFactor (v1,minDist,maxDist,tess,o2w,cameraPos);
			f.z = CalcDistanceTessFactor (v2,minDist,maxDist,tess,o2w,cameraPos);

			return CalcTriEdgeTessFactors (f);
		}

		float4 EdgeLengthBasedTess( float4 v0, float4 v1, float4 v2, float edgeLength, float4x4 o2w, float3 cameraPos, float4 scParams )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;
			tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
			tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
			tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
			tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			return tess;
		}

		float4 EdgeLengthBasedTessCull( float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement, float4x4 o2w, float3 cameraPos, float4 scParams, float4 planes[6] )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;

			if (WorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement, planes))
			{
				tess = 0.0f;
			}
			else
			{
				tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
				tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
				tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
				tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			}
			return tess;
		}
		#endif //ASE_TESS_FUNCS
		ENDHLSL

		
		Pass
		{
			
			Name "Forward"
			Tags { "LightMode"="UniversalForward" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite Off
			ZTest Always
			Offset 0 , 0
			ColorMask RGBA

			

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _RECEIVE_SHADOWS_OFF 1
			#define ASE_SRP_VERSION 120108
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma multi_compile _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma shader_feature _ _SAMPLE_GI
			#pragma multi_compile _ DEBUG_DISPLAY

			#pragma vertex vert
			#pragma fragment frag

			#define SHADERPASS SHADERPASS_UNLIT

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"

			#define ASE_NEEDS_FRAG_WORLD_POSITION


			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 worldPos : TEXCOORD0;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					float4 shadowCoord : TEXCOORD1;
				#endif
				#ifdef ASE_FOG
					float fogFactor : TEXCOORD2;
				#endif
				float4 ase_texcoord3 : TEXCOORD3;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
						#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			float4 CZY_LightColor;
			float4 CZY_FogColor1;
			float4 CZY_FogColor2;
			float CZY_FogDepthMultiplier;
			uniform float4 _CameraDepthTexture_TexelSize;
			sampler2D _FogVariationTexture;
			float3 CZY_VariationWindDirection;
			float CZY_VariationScale;
			float CZY_VariationAmount;
			float CZY_VariationDistance;
			float CZY_FogColorStart1;
			float4 CZY_FogColor3;
			float CZY_FogColorStart2;
			float4 CZY_FogColor4;
			float CZY_FogColorStart3;
			float4 CZY_FogColor5;
			float CZY_FogColorStart4;
			float CZY_LightFlareSquish;
			float3 CZY_SunDirection;
			half CZY_LightIntensity;
			half CZY_LightFalloff;
			float CZY_FilterSaturation;
			float CZY_FilterValue;
			float4 CZY_FilterColor;
			float4 CZY_SunFilterColor;
			float3 CZY_MoonDirection;
			float4 CZY_FogMoonFlareColor;
			float CZY_FogSmoothness;
			float CZY_FogOffset;
			float CZY_FogIntensity;


			float3 HSVToRGB( float3 c )
			{
				float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
				float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
				return c.z * lerp( K.xxx, saturate( p - K.xxx ), c.y );
			}
			
			float3 RGBToHSV(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = lerp( float4( c.bg, K.wz ), float4( c.gb, K.xy ), step( c.b, c.g ) );
				float4 q = lerp( float4( p.xyw, c.r ), float4( c.r, p.yzx ), step( p.x, c.r ) );
				float d = q.x - min( q.w, q.y );
				float e = 1.0e-10;
				return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}
			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDirURP75_g14( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 InvertDepthDirURP75_g11( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			

			VertexOutput VertexFunction ( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord3 = screenPos;
				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				float4 positionCS = TransformWorldToHClip( positionWS );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					o.worldPos = positionWS;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = positionCS;
					o.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				#ifdef ASE_FOG
					o.fogFactor = ComputeFogFactor( positionCS.z );
				#endif

				o.clipPos = positionCS;

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
			   return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag ( VertexOutput IN  ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 WorldPosition = IN.worldPos;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float4 screenPos = IN.ase_texcoord3;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float eyeDepth414 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy ),_ZBufferParams);
				float preDepth416 = eyeDepth414;
				float2 UV22_g15 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g15 = UnStereo( UV22_g15 );
				float2 break64_g14 = localUnStereo22_g15;
				float clampDepth69_g14 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g14 = ( 1.0 - clampDepth69_g14 );
				#else
				float staticSwitch38_g14 = clampDepth69_g14;
				#endif
				float3 appendResult39_g14 = (float3(break64_g14.x , break64_g14.y , staticSwitch38_g14));
				float4 appendResult42_g14 = (float4((appendResult39_g14*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g14 = mul( unity_CameraInvProjection, appendResult42_g14 );
				float3 temp_output_46_0_g14 = ( (temp_output_43_0_g14).xyz / (temp_output_43_0_g14).w );
				float3 In75_g14 = temp_output_46_0_g14;
				float3 localInvertDepthDirURP75_g14 = InvertDepthDirURP75_g14( In75_g14 );
				float4 appendResult49_g14 = (float4(localInvertDepthDirURP75_g14 , 1.0));
				float lerpResult371 = lerp( preDepth416 , ( preDepth416 * (( 1.0 - CZY_VariationAmount ) + (tex2D( _FogVariationTexture, (( (mul( unity_CameraToWorld, appendResult49_g14 )).xz + ( (CZY_VariationWindDirection).xz * _TimeParameters.x ) )*( 0.1 / CZY_VariationScale ) + 0.0) ).r - 0.0) * (1.0 - ( 1.0 - CZY_VariationAmount )) / (1.0 - 0.0)) ) , ( 1.0 - saturate( ( preDepth416 / CZY_VariationDistance ) ) ));
				float newFogDepth391 = lerpResult371;
				float temp_output_396_0 = ( CZY_FogDepthMultiplier * sqrt( newFogDepth391 ) );
				float temp_output_1_0_g21 = temp_output_396_0;
				float4 lerpResult28_g21 = lerp( CZY_FogColor1 , CZY_FogColor2 , saturate( ( temp_output_1_0_g21 / CZY_FogColorStart1 ) ));
				float4 lerpResult41_g21 = lerp( saturate( lerpResult28_g21 ) , CZY_FogColor3 , saturate( ( ( CZY_FogColorStart1 - temp_output_1_0_g21 ) / ( CZY_FogColorStart1 - CZY_FogColorStart2 ) ) ));
				float4 lerpResult35_g21 = lerp( lerpResult41_g21 , CZY_FogColor4 , saturate( ( ( CZY_FogColorStart2 - temp_output_1_0_g21 ) / ( CZY_FogColorStart2 - CZY_FogColorStart3 ) ) ));
				float4 lerpResult113_g21 = lerp( lerpResult35_g21 , CZY_FogColor5 , saturate( ( ( CZY_FogColorStart3 - temp_output_1_0_g21 ) / ( CZY_FogColorStart3 - CZY_FogColorStart4 ) ) ));
				float4 temp_output_423_0 = lerpResult113_g21;
				float3 hsvTorgb405 = RGBToHSV( temp_output_423_0.rgb );
				float3 appendResult440 = (float3(1.0 , CZY_LightFlareSquish , 1.0));
				float3 normalizeResult430 = normalize( ( ( WorldPosition * appendResult440 ) - _WorldSpaceCameraPos ) );
				float dotResult432 = dot( normalizeResult430 , CZY_SunDirection );
				half LightMask447 = saturate( pow( abs( ( (dotResult432*0.5 + 0.5) * CZY_LightIntensity ) ) , CZY_LightFalloff ) );
				float temp_output_401_0 = ( (temp_output_423_0).a * saturate( temp_output_396_0 ) );
				float3 hsvTorgb2_g19 = RGBToHSV( ( CZY_LightColor * hsvTorgb405.z * saturate( ( LightMask447 * ( 1.5 * temp_output_401_0 ) ) ) ).rgb );
				float3 hsvTorgb3_g19 = HSVToRGB( float3(hsvTorgb2_g19.x,saturate( ( hsvTorgb2_g19.y + CZY_FilterSaturation ) ),( hsvTorgb2_g19.z + CZY_FilterValue )) );
				float4 temp_output_10_0_g19 = ( float4( hsvTorgb3_g19 , 0.0 ) * CZY_FilterColor );
				float3 normalizeResult446 = normalize( half3(0,0,0) );
				float3 normalizeResult445 = normalize( CZY_MoonDirection );
				float dotResult443 = dot( normalizeResult446 , normalizeResult445 );
				half MoonMask434 = saturate( pow( abs( ( saturate( (dotResult443*1.0 + 0.0) ) * CZY_LightIntensity ) ) , ( CZY_LightFalloff * 3.0 ) ) );
				float3 hsvTorgb2_g18 = RGBToHSV( ( temp_output_423_0 + ( hsvTorgb405.z * saturate( ( temp_output_401_0 * MoonMask434 ) ) * CZY_FogMoonFlareColor ) ).rgb );
				float3 hsvTorgb3_g18 = HSVToRGB( float3(hsvTorgb2_g18.x,saturate( ( hsvTorgb2_g18.y + CZY_FilterSaturation ) ),( hsvTorgb2_g18.z + CZY_FilterValue )) );
				float4 temp_output_10_0_g18 = ( float4( hsvTorgb3_g18 , 0.0 ) * CZY_FilterColor );
				
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float finalAlpha417 = temp_output_401_0;
				float2 UV22_g12 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g12 = UnStereo( UV22_g12 );
				float2 break64_g11 = localUnStereo22_g12;
				float clampDepth69_g11 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g11 = ( 1.0 - clampDepth69_g11 );
				#else
				float staticSwitch38_g11 = clampDepth69_g11;
				#endif
				float3 appendResult39_g11 = (float3(break64_g11.x , break64_g11.y , staticSwitch38_g11));
				float4 appendResult42_g11 = (float4((appendResult39_g11*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g11 = mul( unity_CameraInvProjection, appendResult42_g11 );
				float3 temp_output_46_0_g11 = ( (temp_output_43_0_g11).xyz / (temp_output_43_0_g11).w );
				float3 In75_g11 = temp_output_46_0_g11;
				float3 localInvertDepthDirURP75_g11 = InvertDepthDirURP75_g11( In75_g11 );
				float4 appendResult49_g11 = (float4(localInvertDepthDirURP75_g11 , 1.0));
				float4 temp_output_345_0 = mul( unity_CameraToWorld, appendResult49_g11 );
				float lerpResult360 = lerp( finalAlpha417 , ( saturate( ( 1.0 - ( temp_output_345_0.y * 0.001 ) ) ) * finalAlpha417 ) , ( 1.0 - saturate( ( distance( temp_output_345_0 , float4( _WorldSpaceCameraPos , 0.0 ) ) / ( _ProjectionParams.z * 1.0 ) ) ) ));
				float ModifiedFogAlpha362 = saturate( lerpResult360 );
				
				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float3 Color = ( ( temp_output_10_0_g19 * CZY_SunFilterColor ) + temp_output_10_0_g18 ).rgb;
				float Alpha = saturate( ( ( 1.0 - saturate( ( ( WorldPosition.y * ( 0.1 / ( ( CZY_FogSmoothness * length( ase_objectScale ) ) * 10.0 ) ) ) + ( 1.0 - CZY_FogOffset ) ) ) ) * CZY_FogIntensity * ModifiedFogAlpha362 ) );
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;

				#ifdef _ALPHATEST_ON
					clip( Alpha - AlphaClipThreshold );
				#endif

				#if defined(_DBUFFER)
					ApplyDecalToBaseColor(IN.clipPos, Color);
				#endif

				#if defined(_ALPHAPREMULTIPLY_ON)
				Color *= Alpha;
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif

				#ifdef ASE_FOG
					Color = MixFog( Color, IN.fogFactor );
				#endif

				return half4( Color, Alpha );
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask 0
			AlphaToMask Off

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _RECEIVE_SHADOWS_OFF 1
			#define ASE_SRP_VERSION 120108
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			#define ASE_NEEDS_FRAG_WORLD_POSITION


			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				float3 worldPos : TEXCOORD0;
				#endif
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
				float4 shadowCoord : TEXCOORD1;
				#endif
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
						#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			float CZY_FogSmoothness;
			float CZY_FogOffset;
			float CZY_FogIntensity;
			float4 CZY_FogColor1;
			float4 CZY_FogColor2;
			float CZY_FogDepthMultiplier;
			uniform float4 _CameraDepthTexture_TexelSize;
			sampler2D _FogVariationTexture;
			float3 CZY_VariationWindDirection;
			float CZY_VariationScale;
			float CZY_VariationAmount;
			float CZY_VariationDistance;
			float CZY_FogColorStart1;
			float4 CZY_FogColor3;
			float CZY_FogColorStart2;
			float4 CZY_FogColor4;
			float CZY_FogColorStart3;
			float4 CZY_FogColor5;
			float CZY_FogColorStart4;


			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDirURP75_g14( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 InvertDepthDirURP75_g11( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			

			VertexOutput VertexFunction( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord2 = screenPos;
				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					o.worldPos = positionWS;
				#endif

				o.clipPos = TransformWorldToHClip( positionWS );
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = o.clipPos;
					o.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
			   return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN  ) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
					float3 WorldPosition = IN.worldPos;
				#endif

				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				#if defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
						ShadowCoords = IN.shadowCoord;
					#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
						ShadowCoords = TransformWorldToShadowCoord( WorldPosition );
					#endif
				#endif

				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float4 screenPos = IN.ase_texcoord2;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float eyeDepth414 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy ),_ZBufferParams);
				float preDepth416 = eyeDepth414;
				float2 UV22_g15 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g15 = UnStereo( UV22_g15 );
				float2 break64_g14 = localUnStereo22_g15;
				float clampDepth69_g14 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g14 = ( 1.0 - clampDepth69_g14 );
				#else
				float staticSwitch38_g14 = clampDepth69_g14;
				#endif
				float3 appendResult39_g14 = (float3(break64_g14.x , break64_g14.y , staticSwitch38_g14));
				float4 appendResult42_g14 = (float4((appendResult39_g14*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g14 = mul( unity_CameraInvProjection, appendResult42_g14 );
				float3 temp_output_46_0_g14 = ( (temp_output_43_0_g14).xyz / (temp_output_43_0_g14).w );
				float3 In75_g14 = temp_output_46_0_g14;
				float3 localInvertDepthDirURP75_g14 = InvertDepthDirURP75_g14( In75_g14 );
				float4 appendResult49_g14 = (float4(localInvertDepthDirURP75_g14 , 1.0));
				float lerpResult371 = lerp( preDepth416 , ( preDepth416 * (( 1.0 - CZY_VariationAmount ) + (tex2D( _FogVariationTexture, (( (mul( unity_CameraToWorld, appendResult49_g14 )).xz + ( (CZY_VariationWindDirection).xz * _TimeParameters.x ) )*( 0.1 / CZY_VariationScale ) + 0.0) ).r - 0.0) * (1.0 - ( 1.0 - CZY_VariationAmount )) / (1.0 - 0.0)) ) , ( 1.0 - saturate( ( preDepth416 / CZY_VariationDistance ) ) ));
				float newFogDepth391 = lerpResult371;
				float temp_output_396_0 = ( CZY_FogDepthMultiplier * sqrt( newFogDepth391 ) );
				float temp_output_1_0_g21 = temp_output_396_0;
				float4 lerpResult28_g21 = lerp( CZY_FogColor1 , CZY_FogColor2 , saturate( ( temp_output_1_0_g21 / CZY_FogColorStart1 ) ));
				float4 lerpResult41_g21 = lerp( saturate( lerpResult28_g21 ) , CZY_FogColor3 , saturate( ( ( CZY_FogColorStart1 - temp_output_1_0_g21 ) / ( CZY_FogColorStart1 - CZY_FogColorStart2 ) ) ));
				float4 lerpResult35_g21 = lerp( lerpResult41_g21 , CZY_FogColor4 , saturate( ( ( CZY_FogColorStart2 - temp_output_1_0_g21 ) / ( CZY_FogColorStart2 - CZY_FogColorStart3 ) ) ));
				float4 lerpResult113_g21 = lerp( lerpResult35_g21 , CZY_FogColor5 , saturate( ( ( CZY_FogColorStart3 - temp_output_1_0_g21 ) / ( CZY_FogColorStart3 - CZY_FogColorStart4 ) ) ));
				float4 temp_output_423_0 = lerpResult113_g21;
				float temp_output_401_0 = ( (temp_output_423_0).a * saturate( temp_output_396_0 ) );
				float finalAlpha417 = temp_output_401_0;
				float2 UV22_g12 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g12 = UnStereo( UV22_g12 );
				float2 break64_g11 = localUnStereo22_g12;
				float clampDepth69_g11 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g11 = ( 1.0 - clampDepth69_g11 );
				#else
				float staticSwitch38_g11 = clampDepth69_g11;
				#endif
				float3 appendResult39_g11 = (float3(break64_g11.x , break64_g11.y , staticSwitch38_g11));
				float4 appendResult42_g11 = (float4((appendResult39_g11*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g11 = mul( unity_CameraInvProjection, appendResult42_g11 );
				float3 temp_output_46_0_g11 = ( (temp_output_43_0_g11).xyz / (temp_output_43_0_g11).w );
				float3 In75_g11 = temp_output_46_0_g11;
				float3 localInvertDepthDirURP75_g11 = InvertDepthDirURP75_g11( In75_g11 );
				float4 appendResult49_g11 = (float4(localInvertDepthDirURP75_g11 , 1.0));
				float4 temp_output_345_0 = mul( unity_CameraToWorld, appendResult49_g11 );
				float lerpResult360 = lerp( finalAlpha417 , ( saturate( ( 1.0 - ( temp_output_345_0.y * 0.001 ) ) ) * finalAlpha417 ) , ( 1.0 - saturate( ( distance( temp_output_345_0 , float4( _WorldSpaceCameraPos , 0.0 ) ) / ( _ProjectionParams.z * 1.0 ) ) ) ));
				float ModifiedFogAlpha362 = saturate( lerpResult360 );
				

				float Alpha = saturate( ( ( 1.0 - saturate( ( ( WorldPosition.y * ( 0.1 / ( ( CZY_FogSmoothness * length( ase_objectScale ) ) * 10.0 ) ) ) + ( 1.0 - CZY_FogOffset ) ) ) ) * CZY_FogIntensity * ModifiedFogAlpha362 ) );
				float AlphaClipThreshold = 0.5;

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif
				return 0;
			}
			ENDHLSL
		}

		
		Pass
		{
			
            Name "SceneSelectionPass"
            Tags { "LightMode"="SceneSelectionPass" }

			Cull Off

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _RECEIVE_SHADOWS_OFF 1
			#define ASE_SRP_VERSION 120108
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define SHADERPASS SHADERPASS_DEPTHONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
						#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			float CZY_FogSmoothness;
			float CZY_FogOffset;
			float CZY_FogIntensity;
			float4 CZY_FogColor1;
			float4 CZY_FogColor2;
			float CZY_FogDepthMultiplier;
			uniform float4 _CameraDepthTexture_TexelSize;
			sampler2D _FogVariationTexture;
			float3 CZY_VariationWindDirection;
			float CZY_VariationScale;
			float CZY_VariationAmount;
			float CZY_VariationDistance;
			float CZY_FogColorStart1;
			float4 CZY_FogColor3;
			float CZY_FogColorStart2;
			float4 CZY_FogColor4;
			float CZY_FogColorStart3;
			float4 CZY_FogColor5;
			float CZY_FogColorStart4;


			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDirURP75_g14( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 InvertDepthDirURP75_g11( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			

			int _ObjectId;
			int _PassValue;

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float3 ase_worldPos = TransformObjectToWorld( (v.vertex).xyz );
				o.ase_texcoord.xyz = ase_worldPos;
				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord1 = screenPos;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				o.clipPos = TransformWorldToHClip(positionWS);

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float3 ase_worldPos = IN.ase_texcoord.xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float4 screenPos = IN.ase_texcoord1;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float eyeDepth414 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy ),_ZBufferParams);
				float preDepth416 = eyeDepth414;
				float2 UV22_g15 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g15 = UnStereo( UV22_g15 );
				float2 break64_g14 = localUnStereo22_g15;
				float clampDepth69_g14 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g14 = ( 1.0 - clampDepth69_g14 );
				#else
				float staticSwitch38_g14 = clampDepth69_g14;
				#endif
				float3 appendResult39_g14 = (float3(break64_g14.x , break64_g14.y , staticSwitch38_g14));
				float4 appendResult42_g14 = (float4((appendResult39_g14*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g14 = mul( unity_CameraInvProjection, appendResult42_g14 );
				float3 temp_output_46_0_g14 = ( (temp_output_43_0_g14).xyz / (temp_output_43_0_g14).w );
				float3 In75_g14 = temp_output_46_0_g14;
				float3 localInvertDepthDirURP75_g14 = InvertDepthDirURP75_g14( In75_g14 );
				float4 appendResult49_g14 = (float4(localInvertDepthDirURP75_g14 , 1.0));
				float lerpResult371 = lerp( preDepth416 , ( preDepth416 * (( 1.0 - CZY_VariationAmount ) + (tex2D( _FogVariationTexture, (( (mul( unity_CameraToWorld, appendResult49_g14 )).xz + ( (CZY_VariationWindDirection).xz * _TimeParameters.x ) )*( 0.1 / CZY_VariationScale ) + 0.0) ).r - 0.0) * (1.0 - ( 1.0 - CZY_VariationAmount )) / (1.0 - 0.0)) ) , ( 1.0 - saturate( ( preDepth416 / CZY_VariationDistance ) ) ));
				float newFogDepth391 = lerpResult371;
				float temp_output_396_0 = ( CZY_FogDepthMultiplier * sqrt( newFogDepth391 ) );
				float temp_output_1_0_g21 = temp_output_396_0;
				float4 lerpResult28_g21 = lerp( CZY_FogColor1 , CZY_FogColor2 , saturate( ( temp_output_1_0_g21 / CZY_FogColorStart1 ) ));
				float4 lerpResult41_g21 = lerp( saturate( lerpResult28_g21 ) , CZY_FogColor3 , saturate( ( ( CZY_FogColorStart1 - temp_output_1_0_g21 ) / ( CZY_FogColorStart1 - CZY_FogColorStart2 ) ) ));
				float4 lerpResult35_g21 = lerp( lerpResult41_g21 , CZY_FogColor4 , saturate( ( ( CZY_FogColorStart2 - temp_output_1_0_g21 ) / ( CZY_FogColorStart2 - CZY_FogColorStart3 ) ) ));
				float4 lerpResult113_g21 = lerp( lerpResult35_g21 , CZY_FogColor5 , saturate( ( ( CZY_FogColorStart3 - temp_output_1_0_g21 ) / ( CZY_FogColorStart3 - CZY_FogColorStart4 ) ) ));
				float4 temp_output_423_0 = lerpResult113_g21;
				float temp_output_401_0 = ( (temp_output_423_0).a * saturate( temp_output_396_0 ) );
				float finalAlpha417 = temp_output_401_0;
				float2 UV22_g12 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g12 = UnStereo( UV22_g12 );
				float2 break64_g11 = localUnStereo22_g12;
				float clampDepth69_g11 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g11 = ( 1.0 - clampDepth69_g11 );
				#else
				float staticSwitch38_g11 = clampDepth69_g11;
				#endif
				float3 appendResult39_g11 = (float3(break64_g11.x , break64_g11.y , staticSwitch38_g11));
				float4 appendResult42_g11 = (float4((appendResult39_g11*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g11 = mul( unity_CameraInvProjection, appendResult42_g11 );
				float3 temp_output_46_0_g11 = ( (temp_output_43_0_g11).xyz / (temp_output_43_0_g11).w );
				float3 In75_g11 = temp_output_46_0_g11;
				float3 localInvertDepthDirURP75_g11 = InvertDepthDirURP75_g11( In75_g11 );
				float4 appendResult49_g11 = (float4(localInvertDepthDirURP75_g11 , 1.0));
				float4 temp_output_345_0 = mul( unity_CameraToWorld, appendResult49_g11 );
				float lerpResult360 = lerp( finalAlpha417 , ( saturate( ( 1.0 - ( temp_output_345_0.y * 0.001 ) ) ) * finalAlpha417 ) , ( 1.0 - saturate( ( distance( temp_output_345_0 , float4( _WorldSpaceCameraPos , 0.0 ) ) / ( _ProjectionParams.z * 1.0 ) ) ) ));
				float ModifiedFogAlpha362 = saturate( lerpResult360 );
				

				surfaceDescription.Alpha = saturate( ( ( 1.0 - saturate( ( ( ase_worldPos.y * ( 0.1 / ( ( CZY_FogSmoothness * length( ase_objectScale ) ) * 10.0 ) ) ) + ( 1.0 - CZY_FogOffset ) ) ) ) * CZY_FogIntensity * ModifiedFogAlpha362 ) );
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
				return outColor;
			}
			ENDHLSL
		}

		
		Pass
		{
			
            Name "ScenePickingPass"
            Tags { "LightMode"="Picking" }

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _RECEIVE_SHADOWS_OFF 1
			#define ASE_SRP_VERSION 120108
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define SHADERPASS SHADERPASS_DEPTHONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
						#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			float CZY_FogSmoothness;
			float CZY_FogOffset;
			float CZY_FogIntensity;
			float4 CZY_FogColor1;
			float4 CZY_FogColor2;
			float CZY_FogDepthMultiplier;
			uniform float4 _CameraDepthTexture_TexelSize;
			sampler2D _FogVariationTexture;
			float3 CZY_VariationWindDirection;
			float CZY_VariationScale;
			float CZY_VariationAmount;
			float CZY_VariationDistance;
			float CZY_FogColorStart1;
			float4 CZY_FogColor3;
			float CZY_FogColorStart2;
			float4 CZY_FogColor4;
			float CZY_FogColorStart3;
			float4 CZY_FogColor5;
			float CZY_FogColorStart4;


			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDirURP75_g14( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 InvertDepthDirURP75_g11( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			

			float4 _SelectionID;


			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float3 ase_worldPos = TransformObjectToWorld( (v.vertex).xyz );
				o.ase_texcoord.xyz = ase_worldPos;
				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord1 = screenPos;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.w = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif
				float3 vertexValue = defaultVertexValue;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif
				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				o.clipPos = TransformWorldToHClip(positionWS);
				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float3 ase_worldPos = IN.ase_texcoord.xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float4 screenPos = IN.ase_texcoord1;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float eyeDepth414 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy ),_ZBufferParams);
				float preDepth416 = eyeDepth414;
				float2 UV22_g15 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g15 = UnStereo( UV22_g15 );
				float2 break64_g14 = localUnStereo22_g15;
				float clampDepth69_g14 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g14 = ( 1.0 - clampDepth69_g14 );
				#else
				float staticSwitch38_g14 = clampDepth69_g14;
				#endif
				float3 appendResult39_g14 = (float3(break64_g14.x , break64_g14.y , staticSwitch38_g14));
				float4 appendResult42_g14 = (float4((appendResult39_g14*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g14 = mul( unity_CameraInvProjection, appendResult42_g14 );
				float3 temp_output_46_0_g14 = ( (temp_output_43_0_g14).xyz / (temp_output_43_0_g14).w );
				float3 In75_g14 = temp_output_46_0_g14;
				float3 localInvertDepthDirURP75_g14 = InvertDepthDirURP75_g14( In75_g14 );
				float4 appendResult49_g14 = (float4(localInvertDepthDirURP75_g14 , 1.0));
				float lerpResult371 = lerp( preDepth416 , ( preDepth416 * (( 1.0 - CZY_VariationAmount ) + (tex2D( _FogVariationTexture, (( (mul( unity_CameraToWorld, appendResult49_g14 )).xz + ( (CZY_VariationWindDirection).xz * _TimeParameters.x ) )*( 0.1 / CZY_VariationScale ) + 0.0) ).r - 0.0) * (1.0 - ( 1.0 - CZY_VariationAmount )) / (1.0 - 0.0)) ) , ( 1.0 - saturate( ( preDepth416 / CZY_VariationDistance ) ) ));
				float newFogDepth391 = lerpResult371;
				float temp_output_396_0 = ( CZY_FogDepthMultiplier * sqrt( newFogDepth391 ) );
				float temp_output_1_0_g21 = temp_output_396_0;
				float4 lerpResult28_g21 = lerp( CZY_FogColor1 , CZY_FogColor2 , saturate( ( temp_output_1_0_g21 / CZY_FogColorStart1 ) ));
				float4 lerpResult41_g21 = lerp( saturate( lerpResult28_g21 ) , CZY_FogColor3 , saturate( ( ( CZY_FogColorStart1 - temp_output_1_0_g21 ) / ( CZY_FogColorStart1 - CZY_FogColorStart2 ) ) ));
				float4 lerpResult35_g21 = lerp( lerpResult41_g21 , CZY_FogColor4 , saturate( ( ( CZY_FogColorStart2 - temp_output_1_0_g21 ) / ( CZY_FogColorStart2 - CZY_FogColorStart3 ) ) ));
				float4 lerpResult113_g21 = lerp( lerpResult35_g21 , CZY_FogColor5 , saturate( ( ( CZY_FogColorStart3 - temp_output_1_0_g21 ) / ( CZY_FogColorStart3 - CZY_FogColorStart4 ) ) ));
				float4 temp_output_423_0 = lerpResult113_g21;
				float temp_output_401_0 = ( (temp_output_423_0).a * saturate( temp_output_396_0 ) );
				float finalAlpha417 = temp_output_401_0;
				float2 UV22_g12 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g12 = UnStereo( UV22_g12 );
				float2 break64_g11 = localUnStereo22_g12;
				float clampDepth69_g11 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g11 = ( 1.0 - clampDepth69_g11 );
				#else
				float staticSwitch38_g11 = clampDepth69_g11;
				#endif
				float3 appendResult39_g11 = (float3(break64_g11.x , break64_g11.y , staticSwitch38_g11));
				float4 appendResult42_g11 = (float4((appendResult39_g11*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g11 = mul( unity_CameraInvProjection, appendResult42_g11 );
				float3 temp_output_46_0_g11 = ( (temp_output_43_0_g11).xyz / (temp_output_43_0_g11).w );
				float3 In75_g11 = temp_output_46_0_g11;
				float3 localInvertDepthDirURP75_g11 = InvertDepthDirURP75_g11( In75_g11 );
				float4 appendResult49_g11 = (float4(localInvertDepthDirURP75_g11 , 1.0));
				float4 temp_output_345_0 = mul( unity_CameraToWorld, appendResult49_g11 );
				float lerpResult360 = lerp( finalAlpha417 , ( saturate( ( 1.0 - ( temp_output_345_0.y * 0.001 ) ) ) * finalAlpha417 ) , ( 1.0 - saturate( ( distance( temp_output_345_0 , float4( _WorldSpaceCameraPos , 0.0 ) ) / ( _ProjectionParams.z * 1.0 ) ) ) ));
				float ModifiedFogAlpha362 = saturate( lerpResult360 );
				

				surfaceDescription.Alpha = saturate( ( ( 1.0 - saturate( ( ( ase_worldPos.y * ( 0.1 / ( ( CZY_FogSmoothness * length( ase_objectScale ) ) * 10.0 ) ) ) + ( 1.0 - CZY_FogOffset ) ) ) ) * CZY_FogIntensity * ModifiedFogAlpha362 ) );
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = 0;
				outColor = _SelectionID;

				return outColor;
			}

			ENDHLSL
		}

		
		Pass
		{
			
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormalsOnly" }

			ZTest LEqual
			ZWrite On


			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _RECEIVE_SHADOWS_OFF 1
			#define ASE_SRP_VERSION 120108
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define VARYINGS_NEED_NORMAL_WS

			#define SHADERPASS SHADERPASS_DEPTHNORMALSONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				float3 normalWS : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
						#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			float CZY_FogSmoothness;
			float CZY_FogOffset;
			float CZY_FogIntensity;
			float4 CZY_FogColor1;
			float4 CZY_FogColor2;
			float CZY_FogDepthMultiplier;
			uniform float4 _CameraDepthTexture_TexelSize;
			sampler2D _FogVariationTexture;
			float3 CZY_VariationWindDirection;
			float CZY_VariationScale;
			float CZY_VariationAmount;
			float CZY_VariationDistance;
			float CZY_FogColorStart1;
			float4 CZY_FogColor3;
			float CZY_FogColorStart2;
			float4 CZY_FogColor4;
			float CZY_FogColorStart3;
			float4 CZY_FogColor5;
			float CZY_FogColorStart4;


			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDirURP75_g14( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 InvertDepthDirURP75_g11( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float3 ase_worldPos = TransformObjectToWorld( (v.vertex).xyz );
				o.ase_texcoord1.xyz = ase_worldPos;
				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord2 = screenPos;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.w = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				float3 normalWS = TransformObjectToWorldNormal(v.ase_normal);

				o.clipPos = TransformWorldToHClip(positionWS);
				o.normalWS.xyz =  normalWS;

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float3 ase_worldPos = IN.ase_texcoord1.xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float4 screenPos = IN.ase_texcoord2;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float eyeDepth414 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy ),_ZBufferParams);
				float preDepth416 = eyeDepth414;
				float2 UV22_g15 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g15 = UnStereo( UV22_g15 );
				float2 break64_g14 = localUnStereo22_g15;
				float clampDepth69_g14 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g14 = ( 1.0 - clampDepth69_g14 );
				#else
				float staticSwitch38_g14 = clampDepth69_g14;
				#endif
				float3 appendResult39_g14 = (float3(break64_g14.x , break64_g14.y , staticSwitch38_g14));
				float4 appendResult42_g14 = (float4((appendResult39_g14*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g14 = mul( unity_CameraInvProjection, appendResult42_g14 );
				float3 temp_output_46_0_g14 = ( (temp_output_43_0_g14).xyz / (temp_output_43_0_g14).w );
				float3 In75_g14 = temp_output_46_0_g14;
				float3 localInvertDepthDirURP75_g14 = InvertDepthDirURP75_g14( In75_g14 );
				float4 appendResult49_g14 = (float4(localInvertDepthDirURP75_g14 , 1.0));
				float lerpResult371 = lerp( preDepth416 , ( preDepth416 * (( 1.0 - CZY_VariationAmount ) + (tex2D( _FogVariationTexture, (( (mul( unity_CameraToWorld, appendResult49_g14 )).xz + ( (CZY_VariationWindDirection).xz * _TimeParameters.x ) )*( 0.1 / CZY_VariationScale ) + 0.0) ).r - 0.0) * (1.0 - ( 1.0 - CZY_VariationAmount )) / (1.0 - 0.0)) ) , ( 1.0 - saturate( ( preDepth416 / CZY_VariationDistance ) ) ));
				float newFogDepth391 = lerpResult371;
				float temp_output_396_0 = ( CZY_FogDepthMultiplier * sqrt( newFogDepth391 ) );
				float temp_output_1_0_g21 = temp_output_396_0;
				float4 lerpResult28_g21 = lerp( CZY_FogColor1 , CZY_FogColor2 , saturate( ( temp_output_1_0_g21 / CZY_FogColorStart1 ) ));
				float4 lerpResult41_g21 = lerp( saturate( lerpResult28_g21 ) , CZY_FogColor3 , saturate( ( ( CZY_FogColorStart1 - temp_output_1_0_g21 ) / ( CZY_FogColorStart1 - CZY_FogColorStart2 ) ) ));
				float4 lerpResult35_g21 = lerp( lerpResult41_g21 , CZY_FogColor4 , saturate( ( ( CZY_FogColorStart2 - temp_output_1_0_g21 ) / ( CZY_FogColorStart2 - CZY_FogColorStart3 ) ) ));
				float4 lerpResult113_g21 = lerp( lerpResult35_g21 , CZY_FogColor5 , saturate( ( ( CZY_FogColorStart3 - temp_output_1_0_g21 ) / ( CZY_FogColorStart3 - CZY_FogColorStart4 ) ) ));
				float4 temp_output_423_0 = lerpResult113_g21;
				float temp_output_401_0 = ( (temp_output_423_0).a * saturate( temp_output_396_0 ) );
				float finalAlpha417 = temp_output_401_0;
				float2 UV22_g12 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g12 = UnStereo( UV22_g12 );
				float2 break64_g11 = localUnStereo22_g12;
				float clampDepth69_g11 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g11 = ( 1.0 - clampDepth69_g11 );
				#else
				float staticSwitch38_g11 = clampDepth69_g11;
				#endif
				float3 appendResult39_g11 = (float3(break64_g11.x , break64_g11.y , staticSwitch38_g11));
				float4 appendResult42_g11 = (float4((appendResult39_g11*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g11 = mul( unity_CameraInvProjection, appendResult42_g11 );
				float3 temp_output_46_0_g11 = ( (temp_output_43_0_g11).xyz / (temp_output_43_0_g11).w );
				float3 In75_g11 = temp_output_46_0_g11;
				float3 localInvertDepthDirURP75_g11 = InvertDepthDirURP75_g11( In75_g11 );
				float4 appendResult49_g11 = (float4(localInvertDepthDirURP75_g11 , 1.0));
				float4 temp_output_345_0 = mul( unity_CameraToWorld, appendResult49_g11 );
				float lerpResult360 = lerp( finalAlpha417 , ( saturate( ( 1.0 - ( temp_output_345_0.y * 0.001 ) ) ) * finalAlpha417 ) , ( 1.0 - saturate( ( distance( temp_output_345_0 , float4( _WorldSpaceCameraPos , 0.0 ) ) / ( _ProjectionParams.z * 1.0 ) ) ) ));
				float ModifiedFogAlpha362 = saturate( lerpResult360 );
				

				surfaceDescription.Alpha = saturate( ( ( 1.0 - saturate( ( ( ase_worldPos.y * ( 0.1 / ( ( CZY_FogSmoothness * length( ase_objectScale ) ) * 10.0 ) ) ) + ( 1.0 - CZY_FogOffset ) ) ) ) * CZY_FogIntensity * ModifiedFogAlpha362 ) );
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif

				float3 normalWS = IN.normalWS;

				return half4(NormalizeNormalPerPixel(normalWS), 0.0);
			}

			ENDHLSL
		}

		
		Pass
		{
			
            Name "DepthNormalsOnly"
            Tags { "LightMode"="DepthNormalsOnly" }

			ZTest LEqual
			ZWrite On

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define _RECEIVE_SHADOWS_OFF 1
			#define ASE_SRP_VERSION 120108
			#define REQUIRE_DEPTH_TEXTURE 1


			#pragma exclude_renderers glcore gles gles3 
			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define ATTRIBUTES_NEED_TEXCOORD1
			#define VARYINGS_NEED_NORMAL_WS
			#define VARYINGS_NEED_TANGENT_WS

			#define SHADERPASS SHADERPASS_DEPTHNORMALSONLY

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			

			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				float3 normalWS : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
						#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END
			float CZY_FogSmoothness;
			float CZY_FogOffset;
			float CZY_FogIntensity;
			float4 CZY_FogColor1;
			float4 CZY_FogColor2;
			float CZY_FogDepthMultiplier;
			uniform float4 _CameraDepthTexture_TexelSize;
			sampler2D _FogVariationTexture;
			float3 CZY_VariationWindDirection;
			float CZY_VariationScale;
			float CZY_VariationAmount;
			float CZY_VariationDistance;
			float CZY_FogColorStart1;
			float4 CZY_FogColor3;
			float CZY_FogColorStart2;
			float4 CZY_FogColor4;
			float CZY_FogColorStart3;
			float4 CZY_FogColor5;
			float CZY_FogColorStart4;


			float2 UnStereo( float2 UV )
			{
				#if UNITY_SINGLE_PASS_STEREO
				float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
				UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
				#endif
				return UV;
			}
			
			float3 InvertDepthDirURP75_g14( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			
			float3 InvertDepthDirURP75_g11( float3 In )
			{
				float3 result = In;
				#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION == 70600 || ASE_SRP_VERSION == 70700 || ASE_SRP_VERSION == 70701 || ASE_SRP_VERSION >= 80301
				result *= float3(1,1,-1);
				#endif
				return result;
			}
			

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			VertexOutput VertexFunction(VertexInput v  )
			{
				VertexOutput o;
				ZERO_INITIALIZE(VertexOutput, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float3 ase_worldPos = TransformObjectToWorld( (v.vertex).xyz );
				o.ase_texcoord1.xyz = ase_worldPos;
				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord2 = screenPos;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.w = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				float3 normalWS = TransformObjectToWorldNormal(v.ase_normal);

				o.clipPos = TransformWorldToHClip(positionWS);
				o.normalWS.xyz =  normalWS;

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( VertexInput v )
			{
				VertexControl o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				o.vertex = v.vertex;
				o.ase_normal = v.ase_normal;
				
				return o;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> v)
			{
				TessellationFactors o;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(v[0].vertex, v[1].vertex, v[2].vertex, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
				return o;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			VertexOutput DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				VertexInput o = (VertexInput) 0;
				o.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
				o.ase_normal = patch[0].ase_normal * bary.x + patch[1].ase_normal * bary.y + patch[2].ase_normal * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = o.vertex.xyz - patch[i].ase_normal * (dot(o.vertex.xyz, patch[i].ase_normal) - dot(patch[i].vertex.xyz, patch[i].ase_normal));
				float phongStrength = _TessPhongStrength;
				o.vertex.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * o.vertex.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
				return VertexFunction(o);
			}
			#else
			VertexOutput vert ( VertexInput v )
			{
				return VertexFunction( v );
			}
			#endif

			half4 frag(VertexOutput IN ) : SV_TARGET
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float3 ase_worldPos = IN.ase_texcoord1.xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float4 screenPos = IN.ase_texcoord2;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float eyeDepth414 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy ),_ZBufferParams);
				float preDepth416 = eyeDepth414;
				float2 UV22_g15 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g15 = UnStereo( UV22_g15 );
				float2 break64_g14 = localUnStereo22_g15;
				float clampDepth69_g14 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g14 = ( 1.0 - clampDepth69_g14 );
				#else
				float staticSwitch38_g14 = clampDepth69_g14;
				#endif
				float3 appendResult39_g14 = (float3(break64_g14.x , break64_g14.y , staticSwitch38_g14));
				float4 appendResult42_g14 = (float4((appendResult39_g14*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g14 = mul( unity_CameraInvProjection, appendResult42_g14 );
				float3 temp_output_46_0_g14 = ( (temp_output_43_0_g14).xyz / (temp_output_43_0_g14).w );
				float3 In75_g14 = temp_output_46_0_g14;
				float3 localInvertDepthDirURP75_g14 = InvertDepthDirURP75_g14( In75_g14 );
				float4 appendResult49_g14 = (float4(localInvertDepthDirURP75_g14 , 1.0));
				float lerpResult371 = lerp( preDepth416 , ( preDepth416 * (( 1.0 - CZY_VariationAmount ) + (tex2D( _FogVariationTexture, (( (mul( unity_CameraToWorld, appendResult49_g14 )).xz + ( (CZY_VariationWindDirection).xz * _TimeParameters.x ) )*( 0.1 / CZY_VariationScale ) + 0.0) ).r - 0.0) * (1.0 - ( 1.0 - CZY_VariationAmount )) / (1.0 - 0.0)) ) , ( 1.0 - saturate( ( preDepth416 / CZY_VariationDistance ) ) ));
				float newFogDepth391 = lerpResult371;
				float temp_output_396_0 = ( CZY_FogDepthMultiplier * sqrt( newFogDepth391 ) );
				float temp_output_1_0_g21 = temp_output_396_0;
				float4 lerpResult28_g21 = lerp( CZY_FogColor1 , CZY_FogColor2 , saturate( ( temp_output_1_0_g21 / CZY_FogColorStart1 ) ));
				float4 lerpResult41_g21 = lerp( saturate( lerpResult28_g21 ) , CZY_FogColor3 , saturate( ( ( CZY_FogColorStart1 - temp_output_1_0_g21 ) / ( CZY_FogColorStart1 - CZY_FogColorStart2 ) ) ));
				float4 lerpResult35_g21 = lerp( lerpResult41_g21 , CZY_FogColor4 , saturate( ( ( CZY_FogColorStart2 - temp_output_1_0_g21 ) / ( CZY_FogColorStart2 - CZY_FogColorStart3 ) ) ));
				float4 lerpResult113_g21 = lerp( lerpResult35_g21 , CZY_FogColor5 , saturate( ( ( CZY_FogColorStart3 - temp_output_1_0_g21 ) / ( CZY_FogColorStart3 - CZY_FogColorStart4 ) ) ));
				float4 temp_output_423_0 = lerpResult113_g21;
				float temp_output_401_0 = ( (temp_output_423_0).a * saturate( temp_output_396_0 ) );
				float finalAlpha417 = temp_output_401_0;
				float2 UV22_g12 = ase_screenPosNorm.xy;
				float2 localUnStereo22_g12 = UnStereo( UV22_g12 );
				float2 break64_g11 = localUnStereo22_g12;
				float clampDepth69_g11 = SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm.xy );
				#ifdef UNITY_REVERSED_Z
				float staticSwitch38_g11 = ( 1.0 - clampDepth69_g11 );
				#else
				float staticSwitch38_g11 = clampDepth69_g11;
				#endif
				float3 appendResult39_g11 = (float3(break64_g11.x , break64_g11.y , staticSwitch38_g11));
				float4 appendResult42_g11 = (float4((appendResult39_g11*2.0 + -1.0) , 1.0));
				float4 temp_output_43_0_g11 = mul( unity_CameraInvProjection, appendResult42_g11 );
				float3 temp_output_46_0_g11 = ( (temp_output_43_0_g11).xyz / (temp_output_43_0_g11).w );
				float3 In75_g11 = temp_output_46_0_g11;
				float3 localInvertDepthDirURP75_g11 = InvertDepthDirURP75_g11( In75_g11 );
				float4 appendResult49_g11 = (float4(localInvertDepthDirURP75_g11 , 1.0));
				float4 temp_output_345_0 = mul( unity_CameraToWorld, appendResult49_g11 );
				float lerpResult360 = lerp( finalAlpha417 , ( saturate( ( 1.0 - ( temp_output_345_0.y * 0.001 ) ) ) * finalAlpha417 ) , ( 1.0 - saturate( ( distance( temp_output_345_0 , float4( _WorldSpaceCameraPos , 0.0 ) ) / ( _ProjectionParams.z * 1.0 ) ) ) ));
				float ModifiedFogAlpha362 = saturate( lerpResult360 );
				

				surfaceDescription.Alpha = saturate( ( ( 1.0 - saturate( ( ( ase_worldPos.y * ( 0.1 / ( ( CZY_FogSmoothness * length( ase_objectScale ) ) * 10.0 ) ) ) + ( 1.0 - CZY_FogOffset ) ) ) ) * CZY_FogIntensity * ModifiedFogAlpha362 ) );
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif

				float3 normalWS = IN.normalWS;

				return half4(NormalizeNormalPerPixel(normalWS), 0.0);
			}

			ENDHLSL
		}
		
	}
	
	CustomEditor "EmptyShaderGUI"
	FallBack "Hidden/Shader Graph/FallbackError"
	
	Fallback "Hidden/InternalErrorShader"
}
/*ASEBEGIN
Version=19105
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;281;570.9207,40.06461;Float;False;True;-1;2;EmptyShaderGUI;0;13;Stylized Fog (Physical Height);2992e84f91cbeb14eab234972e07ea9d;True;Forward;0;1;Forward;8;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;1;False;;False;False;False;False;False;False;False;False;True;True;True;221;False;;222;False;;222;False;;6;False;;1;False;;0;False;;0;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;True;True;2;False;;True;7;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalForward;False;False;0;Hidden/InternalErrorShader;0;0;Standard;23;Surface;1;637952286753557635;  Blend;0;0;Two Sided;2;637952286781860590;Forward Only;0;0;Cast Shadows;0;637995616325711392;  Use Shadow Threshold;0;0;Receive Shadows;0;637995616330470990;GPU Instancing;1;0;LOD CrossFade;0;0;Built-in Fog;0;0;DOTS Instancing;0;0;Meta Pass;0;0;Extra Pre Pass;0;0;Tessellation;0;0;  Phong;0;0;  Strength;0.5,False,;0;  Type;0;0;  Tess;16,False,;0;  Min;10,False,;0;  Max;25,False,;0;  Edge Length;16,False,;0;  Max Displacement;25,False,;0;Vertex Position,InvertActionOnDeselection;1;0;0;10;False;True;False;True;False;False;True;True;True;True;False;;False;0
Node;AmplifyShaderEditor.FunctionNode;345;-2784,-112;Inherit;False;Reconstruct World Position From Depth;-1;;11;e7094bcbcc80eb140b2a3dbe6a861de8;0;0;1;FLOAT4;0
Node;AmplifyShaderEditor.WireNode;346;-2480,32;Inherit;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;282;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;3;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ShadowCaster;0;2;ShadowCaster;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=ShadowCaster;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;280;768,448;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;3;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ExtraPrePass;0;0;ExtraPrePass;5;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;0;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;283;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;3;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthOnly;0;3;DepthOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;False;False;True;1;LightMode=DepthOnly;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;284;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;3;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Meta;0;4;Meta;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Meta;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.WorldPosInputsNode;312;-688,0;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleDivideOpNode;314;-496,144;Inherit;False;2;0;FLOAT;0.1;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;318;-352,32;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;321;-96,32;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;327;32,32;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;329;176,32;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;334;-208,32;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;335;-352,240;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;341;320,32;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldSpaceCameraPos;347;-2528,112;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.ProjectionParams;348;-2288,208;Inherit;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.BreakToComponentsNode;349;-2448,-112;Inherit;False;FLOAT4;1;0;FLOAT4;0,0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;350;-2288,-112;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.001;False;1;FLOAT;0
Node;AmplifyShaderEditor.DistanceOpNode;351;-2128,48;Inherit;False;2;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;352;-2080,208;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;353;-1936,48;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;354;-2160,-112;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;355;-1824,48;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;356;-2016,-112;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;358;-1712,-16;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;359;-1872,-112;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;360;-1696,-192;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;361;-1552,-192;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;363;570.9207,90.06461;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Universal2D;0;5;Universal2D;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=Universal2D;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;364;570.9207,90.06461;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;SceneSelectionPass;0;6;SceneSelectionPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=SceneSelectionPass;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;365;570.9207,90.06461;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ScenePickingPass;0;7;ScenePickingPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Picking;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;366;570.9207,90.06461;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormals;0;8;DepthNormals;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;367;570.9207,90.06461;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormalsOnly;0;9;DepthNormalsOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;True;9;d3d11;metal;vulkan;xboxone;xboxseries;playstation;ps4;ps5;switch;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.OneMinusNode;368;-2944,1040;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;369;-2768,960;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;370;-2448,912;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;371;-2208,912;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.WireNode;372;-2368,880;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;375;-2592,1136;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;150;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;376;-2464,1136;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;377;-2320,1136;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;378;-4048,752;Inherit;False;Reconstruct World Position From Depth;-1;;14;e7094bcbcc80eb140b2a3dbe6a861de8;0;0;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleAddOpNode;379;-3488,800;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;380;-3648,864;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;381;-3936,992;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;382;-3472,960;Inherit;False;2;0;FLOAT;0.1;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;383;-3712,752;Inherit;False;True;False;True;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ComponentMaskNode;384;-3888,832;Inherit;False;True;False;True;False;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;385;-3296,880;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;386;-3088,848;Inherit;True;Property;_FogVariationTexture;Fog Variation Texture;0;0;Create;True;0;0;0;False;0;False;-1;c4666b12d12d34d45b89ea8d2fe52b01;c4666b12d12d34d45b89ea8d2fe52b01;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;388;-3248,1088;Inherit;False;Global;CZY_VariationAmount;CZY_VariationAmount;11;0;Create;False;0;0;0;False;0;False;1;0.56;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;389;-2816,1232;Inherit;False;Global;CZY_VariationDistance;CZY_VariationDistance;11;0;Create;False;0;0;0;False;0;False;1;30;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;390;-3696,976;Inherit;False;Global;CZY_VariationScale;CZY_VariationScale;10;0;Create;False;0;0;0;False;0;False;1;9;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;391;-2016,912;Inherit;False;newFogDepth;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;387;-4128,831;Inherit;False;Global;CZY_VariationWindDirection;CZY_VariationWindDirection;12;0;Create;False;0;0;0;False;0;False;1,0,0;6,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;325;-96,112;Inherit;False;Global;CZY_FogIntensity;CZY_FogIntensity;8;0;Create;False;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;336;-544,240;Inherit;False;Global;CZY_FogOffset;CZY_FogOffset;9;0;Create;False;0;0;0;False;0;False;0;0.85;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;396;-1946.314,-736.6795;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SqrtOpNode;397;-2195.716,-720.2222;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;398;-1522.015,-747.1276;Inherit;False;False;False;False;True;1;0;COLOR;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;399;-1522.015,-667.1276;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;400;-1138.015,-699.1276;Inherit;False;2;2;0;FLOAT;1.5;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;401;-1298.015,-667.1276;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;402;-978.0151,-731.1276;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;403;-834.0151,-731.1276;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;404;-658.0153,-1083.128;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RGBToHSVNode;405;-1170.015,-955.1277;Inherit;False;1;0;FLOAT3;0,0,0;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleAddOpNode;406;-466.0152,-843.1276;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;407;-114.0153,-891.1276;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;408;-338.0152,-843.1276;Inherit;False;Filter Color;-1;;18;84bcc1baa84e09b4fba5ba52924b2334;2,13,1,14,1;1;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;409;-338.0152,-923.1277;Inherit;False;Filter Color;-1;;19;84bcc1baa84e09b4fba5ba52924b2334;2,13,1,14,0;1;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;412;-2305.094,-856.5167;Inherit;False;Global;CZY_FogDepthMultiplier;CZY_FogDepthMultiplier;13;0;Create;False;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.ScreenDepthNode;414;-2754.015,-555.1276;Inherit;False;0;True;1;0;FLOAT4;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;417;-610.0153,-571.1276;Inherit;False;finalAlpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;419;-976.0151,-617.1276;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;420;-832.0151,-616.1276;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;421;-626.0153,-747.1276;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;362;-1424,-192;Inherit;False;ModifiedFogAlpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;331;-96,192;Inherit;False;362;ModifiedFogAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;357;-2064,-192;Inherit;False;417;finalAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;416;-2546.015,-556.1276;Inherit;False;preDepth;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;415;-2466.015,-731.1276;Inherit;False;391;newFogDepth;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;373;-2768,864;Inherit;False;416;preDepth;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;374;-2768,1136;Inherit;False;416;preDepth;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;423;-1750.214,-831.7958;Inherit;False;Simple Gradient;-1;;21;ece53c110c682694c8953a12e134178f;0;1;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.ColorNode;411;-978.0151,-1211.128;Inherit;False;Global;CZY_LightColor;CZY_LightColor;18;1;[HDR];Create;False;0;0;0;False;0;False;0,0,0,0;1.083397,1.392001,1.382235,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.AbsOpNode;424;400,928;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;425;544,944;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;426;-112,912;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0.5;False;2;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;427;208,928;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldSpaceCameraPos;428;-1184,1024;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SaturateNode;429;704,944;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NormalizeNode;430;-624,928;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;431;-816,928;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DotProductOpNode;432;-384,912;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;433;704,1280;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;435;224,1296;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;436;400,1296;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;437;80,1296;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;438;544,1280;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;439;400,1200;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;3;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;440;-1200,896;Inherit;False;FLOAT3;4;0;FLOAT;1;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;441;-1040,816;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.WorldPosInputsNode;442;-1392,752;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.DotProductOpNode;443;-416,1232;Inherit;True;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;444;-176,1232;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NormalizeNode;445;-608,1296;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.NormalizeNode;446;-576,1216;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;447;848,928;Half;False;LightMask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;448;-656,1040;Inherit;False;Global;CZY_SunDirection;CZY_SunDirection;10;1;[HideInInspector];Create;False;0;0;0;False;0;False;1,1,0;-0.4611244,0.887069,0.02174607;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;449;-32,1088;Half;False;Global;CZY_LightIntensity;CZY_LightIntensity;16;0;Create;False;0;0;0;False;0;False;0;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;450;240,1072;Half;False;Global;CZY_LightFalloff;CZY_LightFalloff;14;0;Create;False;0;0;0;False;0;False;1;25.17635;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;451;-1456,912;Inherit;False;Global;CZY_LightFlareSquish;CZY_LightFlareSquish;12;0;Create;False;0;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;452;-816,1296;Inherit;False;Global;CZY_MoonDirection;CZY_MoonDirection;11;0;Create;False;0;0;0;False;0;False;1,0,0;0,-1,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.GetLocalVarNode;453;-752,1200;Inherit;False;-1;;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;418;-1195.015,-544.1276;Inherit;False;434;MoonMask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;413;-1170.015,-779.1276;Inherit;False;447;LightMask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;434;848,1280;Half;False;MoonMask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;422;-920.015,-504.1277;Inherit;False;Global;CZY_FogMoonFlareColor;CZY_FogMoonFlareColor;19;1;[HDR];Create;True;0;0;0;False;0;False;0.03051416,0.2017157,0.3773585,0;0,0,0,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;454;-1191.476,212.0873;Inherit;False;Global;CZY_FogSmoothness;CZY_FogSmoothness;20;0;Create;False;0;0;0;False;0;False;0.1;0.625;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;455;-951.4761,212.0873;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;100;False;1;FLOAT;0
Node;AmplifyShaderEditor.LengthOpNode;456;-1191.476,292.0873;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ObjectScaleNode;457;-1399.476,308.0873;Inherit;False;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;458;-807.4761,212.0873;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;10;False;1;FLOAT;0
WireConnection;281;2;407;0
WireConnection;281;3;341;0
WireConnection;346;0;345;0
WireConnection;314;1;458;0
WireConnection;318;0;312;2
WireConnection;318;1;314;0
WireConnection;321;0;334;0
WireConnection;327;0;321;0
WireConnection;329;0;327;0
WireConnection;329;1;325;0
WireConnection;329;2;331;0
WireConnection;334;0;318;0
WireConnection;334;1;335;0
WireConnection;335;0;336;0
WireConnection;341;0;329;0
WireConnection;349;0;345;0
WireConnection;350;0;349;1
WireConnection;351;0;346;0
WireConnection;351;1;347;0
WireConnection;352;0;348;3
WireConnection;353;0;351;0
WireConnection;353;1;352;0
WireConnection;354;0;350;0
WireConnection;355;0;353;0
WireConnection;356;0;354;0
WireConnection;358;0;355;0
WireConnection;359;0;356;0
WireConnection;359;1;357;0
WireConnection;360;0;357;0
WireConnection;360;1;359;0
WireConnection;360;2;358;0
WireConnection;361;0;360;0
WireConnection;368;0;388;0
WireConnection;369;0;386;1
WireConnection;369;3;368;0
WireConnection;370;0;373;0
WireConnection;370;1;369;0
WireConnection;371;0;372;0
WireConnection;371;1;370;0
WireConnection;371;2;377;0
WireConnection;372;0;373;0
WireConnection;375;0;374;0
WireConnection;375;1;389;0
WireConnection;376;0;375;0
WireConnection;377;0;376;0
WireConnection;379;0;383;0
WireConnection;379;1;380;0
WireConnection;380;0;384;0
WireConnection;380;1;381;0
WireConnection;382;1;390;0
WireConnection;383;0;378;0
WireConnection;384;0;387;0
WireConnection;385;0;379;0
WireConnection;385;1;382;0
WireConnection;386;1;385;0
WireConnection;391;0;371;0
WireConnection;396;0;412;0
WireConnection;396;1;397;0
WireConnection;397;0;415;0
WireConnection;398;0;423;0
WireConnection;399;0;396;0
WireConnection;400;1;401;0
WireConnection;401;0;398;0
WireConnection;401;1;399;0
WireConnection;402;0;413;0
WireConnection;402;1;400;0
WireConnection;403;0;402;0
WireConnection;404;0;411;0
WireConnection;404;1;405;3
WireConnection;404;2;403;0
WireConnection;405;0;423;0
WireConnection;406;0;423;0
WireConnection;406;1;421;0
WireConnection;407;0;409;0
WireConnection;407;1;408;0
WireConnection;408;1;406;0
WireConnection;409;1;404;0
WireConnection;417;0;401;0
WireConnection;419;0;401;0
WireConnection;419;1;418;0
WireConnection;420;0;419;0
WireConnection;421;0;405;3
WireConnection;421;1;420;0
WireConnection;421;2;422;0
WireConnection;362;0;361;0
WireConnection;416;0;414;0
WireConnection;423;1;396;0
WireConnection;424;0;427;0
WireConnection;425;0;424;0
WireConnection;425;1;450;0
WireConnection;426;0;432;0
WireConnection;427;0;426;0
WireConnection;427;1;449;0
WireConnection;429;0;425;0
WireConnection;430;0;431;0
WireConnection;431;0;441;0
WireConnection;431;1;428;0
WireConnection;432;0;430;0
WireConnection;432;1;448;0
WireConnection;433;0;438;0
WireConnection;435;0;437;0
WireConnection;435;1;449;0
WireConnection;436;0;435;0
WireConnection;437;0;444;0
WireConnection;438;0;436;0
WireConnection;438;1;439;0
WireConnection;439;0;450;0
WireConnection;440;1;451;0
WireConnection;441;0;442;0
WireConnection;441;1;440;0
WireConnection;443;0;446;0
WireConnection;443;1;445;0
WireConnection;444;0;443;0
WireConnection;445;0;452;0
WireConnection;446;0;453;0
WireConnection;447;0;429;0
WireConnection;434;0;433;0
WireConnection;455;0;454;0
WireConnection;455;1;456;0
WireConnection;456;0;457;0
WireConnection;458;0;455;0
ASEEND*/
//CHKSM=AC497D5B9F8A459128E0C2B84DCA39865CE8A3A8