// Made with Amplify Shader Editor v1.9.1.5
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Distant Lands/Cozy/Stylized Clouds Soft"
{
	Properties
	{
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)


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
			Comp Always
			Pass Zero
			Fail Keep
			ZFail Keep
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
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

			

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_SRP_VERSION 120108


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
				float4 ase_texcoord : TEXCOORD0;
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

			float4 CZY_CloudColor;
			float CZY_FilterSaturation;
			float CZY_FilterValue;
			float4 CZY_FilterColor;
			float4 CZY_CloudFilterColor;
			float4 CZY_CloudHighlightColor;
			float4 CZY_SunFilterColor;
			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float3 CZY_SunDirection;
			half CZY_SunFlareFalloff;
			float3 CZY_MoonDirection;
			half CZY_MoonFlareFalloff;
			float4 CZY_CloudMoonColor;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			half CZY_CloudFlareFalloff;
			float4 CZY_AltoCloudColor;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			float CZY_CloudThickness;


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
			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			

			VertexOutput VertexFunction ( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.ase_texcoord3.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord3.zw = 0;

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
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float3 hsvTorgb2_g6 = RGBToHSV( CZY_CloudColor.rgb );
				float3 hsvTorgb3_g6 = HSVToRGB( float3(hsvTorgb2_g6.x,saturate( ( hsvTorgb2_g6.y + CZY_FilterSaturation ) ),( hsvTorgb2_g6.z + CZY_FilterValue )) );
				float4 temp_output_10_0_g6 = ( float4( hsvTorgb3_g6 , 0.0 ) * CZY_FilterColor );
				float4 CloudColor860 = ( temp_output_10_0_g6 * CZY_CloudFilterColor );
				float3 hsvTorgb2_g5 = RGBToHSV( CZY_CloudHighlightColor.rgb );
				float3 hsvTorgb3_g5 = HSVToRGB( float3(hsvTorgb2_g5.x,saturate( ( hsvTorgb2_g5.y + CZY_FilterSaturation ) ),( hsvTorgb2_g5.z + CZY_FilterValue )) );
				float4 temp_output_10_0_g5 = ( float4( hsvTorgb3_g5 , 0.0 ) * CZY_FilterColor );
				float4 CloudHighlightColor875 = ( temp_output_10_0_g5 * CZY_SunFilterColor );
				float2 texCoord850 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float4 lerpResult1162 = lerp( CloudHighlightColor875 , CloudColor860 , saturate( (2.0 + (ComplexCloudDensity965 - 0.0) * (0.7 - 2.0) / (1.0 - 0.0)) ));
				float3 normalizeResult859 = normalize( ( WorldPosition - _WorldSpaceCameraPos ) );
				float dotResult861 = dot( normalizeResult859 , CZY_SunDirection );
				float temp_output_869_0 = abs( (dotResult861*0.5 + 0.5) );
				half LightMask876 = saturate( pow( temp_output_869_0 , CZY_SunFlareFalloff ) );
				float CloudThicknessDetails1129 = ( VoroDetails932.y * saturate( ( CumulusCoverage853 - 0.8 ) ) );
				float3 normalizeResult862 = normalize( ( WorldPosition - _WorldSpaceCameraPos ) );
				float dotResult866 = dot( normalizeResult862 , CZY_MoonDirection );
				half MoonlightMask877 = saturate( pow( abs( (dotResult866*0.5 + 0.5) ) , CZY_MoonFlareFalloff ) );
				float3 hsvTorgb2_g7 = RGBToHSV( CZY_CloudMoonColor.rgb );
				float3 hsvTorgb3_g7 = HSVToRGB( float3(hsvTorgb2_g7.x,saturate( ( hsvTorgb2_g7.y + CZY_FilterSaturation ) ),( hsvTorgb2_g7.z + CZY_FilterValue )) );
				float4 temp_output_10_0_g7 = ( float4( hsvTorgb3_g7 , 0.0 ) * CZY_FilterColor );
				float4 MoonlightColor880 = ( temp_output_10_0_g7 * CZY_CloudFilterColor );
				float4 lerpResult1186 = lerp( ( lerpResult1162 + ( LightMask876 * CloudHighlightColor875 * ( 1.0 - CloudThicknessDetails1129 ) ) + ( MoonlightMask877 * MoonlightColor880 * ( 1.0 - CloudThicknessDetails1129 ) ) ) , ( CloudColor860 * float4( 0.5660378,0.5660378,0.5660378,0 ) ) , CloudThicknessDetails1129);
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float3 normalizeResult939 = normalize( ( WorldPosition - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float SimpleRadiance1106 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + NimbusLightTransport1107 + ChemtrailsFinal1081 + CirrusAlpha1083 ) );
				float4 lerpResult1190 = lerp( CloudColor860 , lerpResult1186 , ( 1.0 - SimpleRadiance1106 ));
				float CloudLight872 = saturate( pow( temp_output_869_0 , CZY_CloudFlareFalloff ) );
				float4 lerpResult1163 = lerp( float4( 0,0,0,0 ) , CloudHighlightColor875 , ( saturate( ( CumulusCoverage853 - 1.0 ) ) * CloudDetail1005 * CloudLight872 ));
				float4 SunThroughClouds1154 = ( lerpResult1163 * 1.3 );
				float3 hsvTorgb2_g8 = RGBToHSV( CZY_AltoCloudColor.rgb );
				float3 hsvTorgb3_g8 = HSVToRGB( float3(hsvTorgb2_g8.x,saturate( ( hsvTorgb2_g8.y + CZY_FilterSaturation ) ),( hsvTorgb2_g8.z + CZY_FilterValue )) );
				float4 temp_output_10_0_g8 = ( float4( hsvTorgb3_g8 , 0.0 ) * CZY_FilterColor );
				float4 CirrusCustomLightColor1198 = ( CloudColor860 * ( temp_output_10_0_g8 * CZY_CloudFilterColor ) );
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord3.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float ACCustomLightsClipping1171 = ( AltoCumulusLightTransport1128 * ( SimpleRadiance1106 > Clipping1035 ? 0.0 : 1.0 ) );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord3.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float CSCustomLightsClipping1156 = ( CirrostratLightTransport1123 * ( SimpleRadiance1106 > Clipping1035 ? 0.0 : 1.0 ) );
				float CustomRadiance1188 = saturate( ( ACCustomLightsClipping1171 + CSCustomLightsClipping1156 ) );
				float4 lerpResult1179 = lerp( ( lerpResult1190 + SunThroughClouds1154 ) , CirrusCustomLightColor1198 , CustomRadiance1188);
				float4 FinalCloudColor1173 = lerpResult1179;
				
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				
				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float3 Color = FinalCloudColor1173.rgb;
				float Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
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
			
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }

			ZWrite On
			ZTest LEqual
			AlphaToMask Off
			ColorMask 0

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_SRP_VERSION 120108


			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#define SHADERPASS SHADERPASS_SHADOWCASTER

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			#define ASE_NEEDS_FRAG_WORLD_POSITION


			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
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

			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			float CZY_CloudThickness;


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			

			float3 _LightDirection;
			float3 _LightPosition;

			VertexOutput VertexFunction( VertexInput v )
			{
				VertexOutput o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

				o.ase_texcoord2.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord2.zw = 0;

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

				float3 normalWS = TransformObjectToWorldDir( v.ase_normal );

				#if _CASTING_PUNCTUAL_LIGHT_SHADOW
					float3 lightDirectionWS = normalize(_LightPosition - positionWS);
				#else
					float3 lightDirectionWS = _LightDirection;
				#endif

				float4 clipPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

				#if UNITY_REVERSED_Z
					clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
				#else
					clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) && defined(ASE_NEEDS_FRAG_SHADOWCOORDS)
					VertexPositionInputs vertexInput = (VertexPositionInputs)0;
					vertexInput.positionWS = positionWS;
					vertexInput.positionCS = clipPos;
					o.shadowCoord = GetShadowCoord( vertexInput );
				#endif

				o.clipPos = clipPos;

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float2 texCoord850 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord2.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float3 normalizeResult939 = normalize( ( WorldPosition - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				

				float Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;

				#ifdef _ALPHATEST_ON
					#ifdef _ALPHATEST_SHADOW_ON
						clip(Alpha - AlphaClipThresholdShadow);
					#else
						clip(Alpha - AlphaClipThreshold);
					#endif
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
			
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask 0
			AlphaToMask Off

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_SRP_VERSION 120108


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
				float4 ase_texcoord : TEXCOORD0;
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

			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			float CZY_CloudThickness;


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			

			VertexOutput VertexFunction( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.ase_texcoord2.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord2.zw = 0;

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
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float2 texCoord850 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord2.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float3 normalizeResult939 = normalize( ( WorldPosition - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				

				float Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
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
			#define ASE_SRP_VERSION 120108


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
				float4 ase_texcoord : TEXCOORD0;
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

			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			float CZY_CloudThickness;


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
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
				o.ase_texcoord1.xyz = ase_worldPos;
				
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;
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
				o.clipPos = TransformWorldToHClip(positionWS);

				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float2 texCoord850 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float3 ase_worldPos = IN.ase_texcoord1.xyz;
				float3 normalizeResult939 = normalize( ( ase_worldPos - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				

				surfaceDescription.Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
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
			#define ASE_SRP_VERSION 120108


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
				float4 ase_texcoord : TEXCOORD0;
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

			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			float CZY_CloudThickness;


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
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
				o.ase_texcoord1.xyz = ase_worldPos;
				
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;
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
				o.clipPos = TransformWorldToHClip(positionWS);
				return o;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 vertex : INTERNALTESSPOS;
				float3 ase_normal : NORMAL;
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float2 texCoord850 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float3 ase_worldPos = IN.ase_texcoord1.xyz;
				float3 normalizeResult939 = normalize( ( ase_worldPos - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				

				surfaceDescription.Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
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
			#define ASE_SRP_VERSION 120108


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
				float4 ase_texcoord : TEXCOORD0;
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

			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			float CZY_CloudThickness;


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
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
				o.ase_texcoord2.xyz = ase_worldPos;
				
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				o.ase_texcoord2.w = 0;
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
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float2 texCoord850 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord1.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float3 ase_worldPos = IN.ase_texcoord2.xyz;
				float3 normalizeResult939 = normalize( ( ase_worldPos - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				

				surfaceDescription.Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
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
			#define ASE_SRP_VERSION 120108


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
				float4 ase_texcoord : TEXCOORD0;
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
			float CZY_WindSpeed;
			float CZY_MainCloudScale;
			float CZY_CumulusCoverageMultiplier;
			float CZY_DetailScale;
			float CZY_DetailAmount;
			float CZY_BorderHeight;
			float CZY_BorderVariation;
			float CZY_BorderEffect;
			float CZY_AltocumulusScale;
			float2 CZY_AltocumulusWindSpeed;
			float CZY_AltocumulusMultiplier;
			sampler2D CZY_ChemtrailsTexture;
			float CZY_ChemtrailsMoveSpeed;
			float CZY_ChemtrailsMultiplier;
			sampler2D CZY_CirrostratusTexture;
			float CZY_CirrostratusMoveSpeed;
			float CZY_CirrostratusMultiplier;
			sampler2D CZY_CirrusTexture;
			float CZY_CirrusMoveSpeed;
			float CZY_CirrusMultiplier;
			float CZY_ClippingThreshold;
			float3 CZY_StormDirection;
			float CZY_NimbusHeight;
			float CZY_NimbusMultiplier;
			float CZY_NimbusVariation;
			float CZY_CloudThickness;


			float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
			float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
			float snoise( float2 v )
			{
				const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
				float2 i = floor( v + dot( v, C.yy ) );
				float2 x0 = v - i + dot( i, C.xx );
				float2 i1;
				i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289( i );
				float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
				float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac( p * C.www ) - 1.0;
				float3 h = abs( x ) - 0.5;
				float3 ox = floor( x + 0.5 );
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot( m, g );
			}
			
					float2 voronoihash904( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi904( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash904( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash911( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi911( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash911( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash907( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi907( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash907( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1026( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1026( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1026( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return (F2 + F1) * 0.5;
					}
			
					float2 voronoihash1059( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1059( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1059( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
					}
			
					float2 voronoihash1114( float2 p )
					{
						
						p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
						return frac( sin( p ) *43758.5453);
					}
			
					float voronoi1114( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
					{
						float2 n = floor( v );
						float2 f = frac( v );
						float F1 = 8.0;
						float F2 = 8.0; float2 mg = 0;
						for ( int j = -1; j <= 1; j++ )
						{
							for ( int i = -1; i <= 1; i++ )
						 	{
						 		float2 g = float2( i, j );
						 		float2 o = voronoihash1114( n + g );
								o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
								float d = 0.5 * dot( r, r );
						 		if( d<F1 ) {
						 			F2 = F1;
						 			F1 = d; mg = g; mr = r; id = o;
						 		} else if( d<F2 ) {
						 			F2 = d;
						
						 		}
						 	}
						}
						return F1;
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
				o.ase_texcoord2.xyz = ase_worldPos;
				
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				o.ase_texcoord2.w = 0;
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
				float4 ase_texcoord : TEXCOORD0;

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
				o.ase_texcoord = v.ase_texcoord;
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
				o.ase_texcoord = patch[0].ase_texcoord * bary.x + patch[1].ase_texcoord * bary.y + patch[2].ase_texcoord * bary.z;
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

				float2 texCoord850 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 Pos852 = texCoord850;
				float mulTime848 = _TimeParameters.x * ( 0.001 * CZY_WindSpeed );
				float TIme849 = mulTime848;
				float simplePerlin2D944 = snoise( ( Pos852 + ( TIme849 * float2( 0.2,-0.4 ) ) )*( 100.0 / CZY_MainCloudScale ) );
				simplePerlin2D944 = simplePerlin2D944*0.5 + 0.5;
				float SimpleCloudDensity978 = simplePerlin2D944;
				float time904 = 0.0;
				float2 voronoiSmoothId904 = 0;
				float2 temp_output_917_0 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) );
				float2 coords904 = temp_output_917_0 * ( 140.0 / CZY_MainCloudScale );
				float2 id904 = 0;
				float2 uv904 = 0;
				float voroi904 = voronoi904( coords904, time904, id904, uv904, 0, voronoiSmoothId904 );
				float time911 = 0.0;
				float2 voronoiSmoothId911 = 0;
				float2 coords911 = temp_output_917_0 * ( 500.0 / CZY_MainCloudScale );
				float2 id911 = 0;
				float2 uv911 = 0;
				float voroi911 = voronoi911( coords911, time911, id911, uv911, 0, voronoiSmoothId911 );
				float2 appendResult918 = (float2(voroi904 , voroi911));
				float2 VoroDetails932 = appendResult918;
				float CumulusCoverage853 = CZY_CumulusCoverageMultiplier;
				float ComplexCloudDensity965 = (0.0 + (min( SimpleCloudDensity978 , ( 1.0 - VoroDetails932.x ) ) - ( 1.0 - CumulusCoverage853 )) * (1.0 - 0.0) / (1.0 - ( 1.0 - CumulusCoverage853 )));
				float time907 = 0.0;
				float2 voronoiSmoothId907 = 0;
				float2 coords907 = ( Pos852 + ( TIme849 * float2( 0.3,0.2 ) ) ) * ( 100.0 / CZY_DetailScale );
				float2 id907 = 0;
				float2 uv907 = 0;
				float fade907 = 0.5;
				float voroi907 = 0;
				float rest907 = 0;
				for( int it907 = 0; it907 <3; it907++ ){
				voroi907 += fade907 * voronoi907( coords907, time907, id907, uv907, 0,voronoiSmoothId907 );
				rest907 += fade907;
				coords907 *= 2;
				fade907 *= 0.5;
				}//Voronoi907
				voroi907 /= rest907;
				float temp_output_999_0 = ( (0.0 + (( 1.0 - voroi907 ) - 0.3) * (0.5 - 0.0) / (1.0 - 0.3)) * 0.1 * CZY_DetailAmount );
				float DetailedClouds1085 = saturate( ( ComplexCloudDensity965 + temp_output_999_0 ) );
				float CloudDetail1005 = temp_output_999_0;
				float2 texCoord902 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_986_0 = ( texCoord902 - float2( 0.5,0.5 ) );
				float dotResult1039 = dot( temp_output_986_0 , temp_output_986_0 );
				float BorderHeight979 = ( 1.0 - CZY_BorderHeight );
				float temp_output_975_0 = ( -2.0 * ( 1.0 - CZY_BorderVariation ) );
				float clampResult1080 = clamp( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( BorderHeight979 * temp_output_975_0 ) + (dotResult1039 - 0.0) * (( temp_output_975_0 * -4.0 ) - ( BorderHeight979 * temp_output_975_0 )) / (1.0 - 0.0)) ) ) * 10.0 * CZY_BorderEffect ) , -1.0 , 1.0 );
				float BorderLightTransport1120 = clampResult1080;
				float time1026 = 0.0;
				float2 voronoiSmoothId1026 = 0;
				float mulTime988 = _TimeParameters.x * 0.003;
				float2 coords1026 = (Pos852*1.0 + ( float2( 1,-2 ) * mulTime988 )) * 10.0;
				float2 id1026 = 0;
				float2 uv1026 = 0;
				float voroi1026 = voronoi1026( coords1026, time1026, id1026, uv1026, 0, voronoiSmoothId1026 );
				float time1059 = ( 10.0 * mulTime988 );
				float2 voronoiSmoothId1059 = 0;
				float2 coords1059 = IN.ase_texcoord1.xy * 10.0;
				float2 id1059 = 0;
				float2 uv1059 = 0;
				float voroi1059 = voronoi1059( coords1059, time1059, id1059, uv1059, 0, voronoiSmoothId1059 );
				float AltoCumulusPlacement1098 = saturate( ( ( ( 1.0 - 0.0 ) - (1.0 + (voroi1026 - 0.0) * (-0.5 - 1.0) / (1.0 - 0.0)) ) - voroi1059 ) );
				float time1114 = 51.2;
				float2 voronoiSmoothId1114 = 0;
				float2 coords1114 = (Pos852*1.0 + ( CZY_AltocumulusWindSpeed * TIme849 )) * ( 100.0 / CZY_AltocumulusScale );
				float2 id1114 = 0;
				float2 uv1114 = 0;
				float fade1114 = 0.5;
				float voroi1114 = 0;
				float rest1114 = 0;
				for( int it1114 = 0; it1114 <2; it1114++ ){
				voroi1114 += fade1114 * voronoi1114( coords1114, time1114, id1114, uv1114, 0,voronoiSmoothId1114 );
				rest1114 += fade1114;
				coords1114 *= 2;
				fade1114 *= 0.5;
				}//Voronoi1114
				voroi1114 /= rest1114;
				float AltoCumulusLightTransport1128 = ( ( AltoCumulusPlacement1098 * ( 0.1 > voroi1114 ? (0.5 + (voroi1114 - 0.0) * (0.0 - 0.5) / (0.15 - 0.0)) : 0.0 ) * CZY_AltocumulusMultiplier ) > 0.2 ? 1.0 : 0.0 );
				float mulTime927 = _TimeParameters.x * 0.01;
				float simplePerlin2D967 = snoise( (Pos852*1.0 + mulTime927)*2.0 );
				float mulTime916 = _TimeParameters.x * CZY_ChemtrailsMoveSpeed;
				float cos920 = cos( ( mulTime916 * 0.01 ) );
				float sin920 = sin( ( mulTime916 * 0.01 ) );
				float2 rotator920 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos920 , -sin920 , sin920 , cos920 )) + float2( 0.5,0.5 );
				float cos955 = cos( ( mulTime916 * -0.02 ) );
				float sin955 = sin( ( mulTime916 * -0.02 ) );
				float2 rotator955 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos955 , -sin955 , sin955 , cos955 )) + float2( 0.5,0.5 );
				float mulTime930 = _TimeParameters.x * 0.01;
				float simplePerlin2D971 = snoise( (Pos852*1.0 + mulTime930)*4.0 );
				float4 ChemtrailsPattern1037 = ( ( saturate( simplePerlin2D967 ) * tex2D( CZY_ChemtrailsTexture, (rotator920*0.5 + 0.0) ) ) + ( tex2D( CZY_ChemtrailsTexture, rotator955 ) * saturate( simplePerlin2D971 ) ) );
				float2 texCoord963 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_987_0 = ( texCoord963 - float2( 0.5,0.5 ) );
				float dotResult1034 = dot( temp_output_987_0 , temp_output_987_0 );
				float ChemtrailsFinal1081 = ( ( ChemtrailsPattern1037 * saturate( (0.4 + (dotResult1034 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - ( CZY_ChemtrailsMultiplier * 0.5 ) ) ? 1.0 : 0.0 );
				float mulTime1019 = _TimeParameters.x * 0.01;
				float simplePerlin2D1051 = snoise( (Pos852*1.0 + mulTime1019)*2.0 );
				float mulTime1004 = _TimeParameters.x * CZY_CirrostratusMoveSpeed;
				float cos962 = cos( ( mulTime1004 * 0.01 ) );
				float sin962 = sin( ( mulTime1004 * 0.01 ) );
				float2 rotator962 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos962 , -sin962 , sin962 , cos962 )) + float2( 0.5,0.5 );
				float cos1024 = cos( ( mulTime1004 * -0.02 ) );
				float sin1024 = sin( ( mulTime1004 * -0.02 ) );
				float2 rotator1024 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos1024 , -sin1024 , sin1024 , cos1024 )) + float2( 0.5,0.5 );
				float mulTime1010 = _TimeParameters.x * 0.01;
				float simplePerlin2D1043 = snoise( (Pos852*10.0 + mulTime1010)*4.0 );
				float4 CirrostratPattern1097 = ( ( saturate( simplePerlin2D1051 ) * tex2D( CZY_CirrostratusTexture, (rotator962*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrostratusTexture, (rotator1024*1.5 + 0.75) ) * saturate( simplePerlin2D1043 ) ) );
				float2 texCoord1063 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_1076_0 = ( texCoord1063 - float2( 0.5,0.5 ) );
				float dotResult1070 = dot( temp_output_1076_0 , temp_output_1076_0 );
				float clampResult1101 = clamp( ( CZY_CirrostratusMultiplier * 0.5 ) , 0.0 , 0.98 );
				float CirrostratLightTransport1123 = ( ( CirrostratPattern1097 * saturate( (0.4 + (dotResult1070 - 0.0) * (2.0 - 0.4) / (0.1 - 0.0)) ) ).r > ( 1.0 - clampResult1101 ) ? 1.0 : 0.0 );
				float mulTime903 = _TimeParameters.x * 0.01;
				float simplePerlin2D950 = snoise( (Pos852*1.0 + mulTime903)*2.0 );
				float mulTime898 = _TimeParameters.x * CZY_CirrusMoveSpeed;
				float cos924 = cos( ( mulTime898 * 0.01 ) );
				float sin924 = sin( ( mulTime898 * 0.01 ) );
				float2 rotator924 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos924 , -sin924 , sin924 , cos924 )) + float2( 0.5,0.5 );
				float cos935 = cos( ( mulTime898 * -0.02 ) );
				float sin935 = sin( ( mulTime898 * -0.02 ) );
				float2 rotator935 = mul( Pos852 - float2( 0.5,0.5 ) , float2x2( cos935 , -sin935 , sin935 , cos935 )) + float2( 0.5,0.5 );
				float mulTime959 = _TimeParameters.x * 0.01;
				float simplePerlin2D946 = snoise( (Pos852*1.0 + mulTime959) );
				simplePerlin2D946 = simplePerlin2D946*0.5 + 0.5;
				float4 CirrusPattern961 = ( ( saturate( simplePerlin2D950 ) * tex2D( CZY_CirrusTexture, (rotator924*1.5 + 0.75) ) ) + ( tex2D( CZY_CirrusTexture, (rotator935*1.0 + 0.0) ) * saturate( simplePerlin2D946 ) ) );
				float2 texCoord958 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_989_0 = ( texCoord958 - float2( 0.5,0.5 ) );
				float dotResult982 = dot( temp_output_989_0 , temp_output_989_0 );
				float4 temp_output_1044_0 = ( CirrusPattern961 * saturate( (0.0 + (dotResult982 - 0.0) * (2.0 - 0.0) / (0.2 - 0.0)) ) );
				float Clipping1035 = CZY_ClippingThreshold;
				float CirrusAlpha1083 = ( ( temp_output_1044_0 * ( CZY_CirrusMultiplier * 10.0 ) ).r > Clipping1035 ? 1.0 : 0.0 );
				float3 ase_worldPos = IN.ase_texcoord2.xyz;
				float3 normalizeResult939 = normalize( ( ase_worldPos - _WorldSpaceCameraPos ) );
				float3 normalizeResult970 = normalize( CZY_StormDirection );
				float dotResult974 = dot( normalizeResult939 , normalizeResult970 );
				float2 texCoord921 = IN.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 temp_output_948_0 = ( texCoord921 - float2( 0.5,0.5 ) );
				float dotResult949 = dot( temp_output_948_0 , temp_output_948_0 );
				float temp_output_964_0 = ( -2.0 * ( 1.0 - ( CZY_NimbusVariation * 0.9 ) ) );
				float NimbusLightTransport1107 = saturate( ( ( ( CloudDetail1005 + SimpleCloudDensity978 ) * saturate( (( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 ) + (( dotResult974 + ( CZY_NimbusHeight * 4.0 * dotResult949 ) ) - 0.5) * (( temp_output_964_0 * -4.0 ) - ( ( 1.0 - CZY_NimbusMultiplier ) * temp_output_964_0 )) / (7.0 - 0.5)) ) ) * 10.0 ) );
				float FinalAlpha1228 = saturate( ( DetailedClouds1085 + BorderLightTransport1120 + AltoCumulusLightTransport1128 + ChemtrailsFinal1081 + CirrostratLightTransport1123 + CirrusAlpha1083 + NimbusLightTransport1107 ) );
				

				surfaceDescription.Alpha = saturate( ( FinalAlpha1228 + ( FinalAlpha1228 * 2.0 * CZY_CloudThickness ) ) );
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
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;800;-1136,-432;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;2;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;805;-1008,-496;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;802;-880,-496;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.CommentaryNode;820;3776,-1856;Inherit;False;2340.552;1688.827;;2;843;831;Chemtrails Block;1,0.9935331,0.4575472,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;821;16,-464;Inherit;False;2974.933;2000.862;;5;840;838;834;833;830;Cumulus Cloud Block;0.4392157,1,0.7085855,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;822;3456,1792;Inherit;False;2654.838;1705.478;;3;845;842;827;Cirrostratus Block;0.4588236,0.584294,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;823;-208,-3360;Inherit;False;3038.917;2502.995;;4;847;841;836;835;Finalization Block;0.6196079,0.9508546,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;824;6400,-1856;Inherit;False;2297.557;1709.783;;2;846;844;Cirrus Block;1,0.6554637,0.4588236,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;825;32,1840;Inherit;False;3128.028;1619.676;;3;837;832;828;Altocumulus Cloud Block;0.6637449,0.4708971,0.6981132,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;826;-3984,-3648;Inherit;False;2254.259;1199.93;;45;892;891;890;889;888;887;886;885;884;883;882;881;880;879;878;877;876;875;874;873;872;871;870;869;868;867;866;865;864;863;862;861;860;859;858;857;856;855;854;853;852;851;850;849;848;Variable Declaration;0.6196079,0.9508546,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;827;3504,2848;Inherit;False;1600.229;583.7008;Final;13;1222;1123;1112;1102;1101;1093;1092;1090;1088;1082;1076;1070;1063;;0.4588236,0.584294,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;828;112,1936;Inherit;False;2021.115;830.0204;Placement Noise;18;1218;1141;1098;1084;1075;1069;1062;1059;1056;1054;1049;1048;1042;1026;1016;1002;991;988;;0.6637449,0.4708971,0.6981132,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;829;6032,208;Inherit;False;2713.637;1035.553;;30;1211;1210;1209;1208;1107;1057;1053;1047;1036;1027;1025;1020;1012;1000;996;990;977;974;970;966;964;953;952;949;948;945;939;934;925;921;Nimbus Block;0.5,0.5,0.5,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;830;64,192;Inherit;False;1226.633;651.0015;Simple Density;20;1206;1200;1052;978;944;932;926;922;919;918;917;911;908;905;904;897;896;895;894;893;;0.4392157,1,0.7085855,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;831;3824,-1792;Inherit;False;2197.287;953.2202;Pattern;24;1216;1143;1111;1037;1030;994;984;981;980;976;972;971;967;955;951;942;938;931;930;929;928;927;920;916;;1,0.9935331,0.4575472,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;832;2176,1920;Inherit;False;939.7803;621.1177;Lighting & Clipping;11;1217;1199;1198;1197;1196;1171;1134;1132;1130;1127;1073;;0.6637449,0.4708971,0.6981132,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;833;80,992;Inherit;False;1813.036;453.4427;Final Detailing;17;1203;1202;1201;1085;1077;1066;1045;1005;999;954;947;913;910;907;906;900;899;;0.4392157,1,0.7085855,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;834;1360,-240;Inherit;False;1576.124;399.0991;Highlights;11;1225;1184;1163;1158;1155;1154;1151;1144;1142;1136;1122;;0.4392157,1,0.7085855,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;835;-144,-1872;Inherit;False;2881.345;950.1069;Final Coloring;35;1215;1194;1191;1190;1187;1186;1185;1183;1182;1181;1180;1179;1177;1176;1174;1173;1170;1166;1165;1164;1162;1159;1157;1152;1150;1149;1148;1147;1146;1145;1135;1133;1121;1072;1035;;0.6196079,0.9508546,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;836;-128,-2544;Inherit;False;1393.195;555.0131;Simple Radiance;8;1108;1106;1105;1103;1100;1099;1096;1091;;0.6196079,0.9508546,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;837;112,2800;Inherit;False;2200.287;555.4289;Main Noise;15;1221;1220;1219;1128;1116;1115;1114;1113;1104;1095;1094;1089;1065;1060;1029;;0.6637449,0.4708971,0.6981132,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;838;48,-272;Inherit;False;1283.597;293.2691;Thickness Details;7;1224;1129;1125;1117;1109;1087;1071;;0.4392157,1,0.7085855,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;839;3680,224;Inherit;False;2111.501;762.0129;;21;1207;1205;1204;1131;1120;1080;1039;1038;1033;1031;1023;1015;1003;997;993;986;979;975;960;956;902;Cloud Border Block;1,0.5882353,0.685091,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;840;1344,336;Inherit;False;1154;500;Complex Density;9;1227;1226;1017;1001;995;973;969;965;937;;0.4392157,1,0.7085855,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;841;1312,-2544;Inherit;False;1393.195;555.0131;Custom Radiance;5;1192;1188;1169;1161;1160;;0.6196079,0.9508546,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;842;3488,1840;Inherit;False;2197.287;953.2202;Pattern;25;1223;1097;1086;1079;1074;1068;1067;1064;1058;1051;1046;1043;1032;1024;1022;1019;1018;1014;1011;1010;1009;1004;998;962;957;;0.4588236,0.584294,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;843;3840,-784;Inherit;False;1600.229;583.7008;Final;12;1213;1139;1138;1118;1081;1061;1041;1040;1034;1021;987;963;;1,0.9935331,0.4575472,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;844;6432,-1792;Inherit;False;2197.287;953.2202;Pattern;25;1214;1050;1028;992;985;983;968;961;959;950;946;941;940;936;935;933;924;923;915;914;912;909;903;901;898;;1,0.6554637,0.4588236,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;845;5136,2848;Inherit;False;916.8853;383.8425;Lighting & Clipping;6;1172;1156;1140;1137;1126;1124;;0.4588236,0.584294,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;846;6448,-784;Inherit;False;1735.998;586.5895;Final;14;1212;1110;1083;1078;1055;1044;1013;1008;1007;1006;989;982;958;943;;1,0.6554637,0.4588236,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;847;-160,-3248;Inherit;False;951.3906;629.7021;Final Alpha;10;1228;1195;1193;1189;1178;1175;1168;1167;1153;1119;;0.6196079,0.9508546,1,1;0;0
Node;AmplifyShaderEditor.SimpleTimeNode;848;-2768,-3264;Inherit;False;1;0;FLOAT;10;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;849;-2608,-3280;Inherit;False;TIme;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;850;-2816,-3440;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;851;-2912,-3280;Inherit;False;2;2;0;FLOAT;0.001;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;852;-2608,-3456;Inherit;False;Pos;-1;True;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;853;-2016,-3504;Inherit;False;CumulusCoverage;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldSpaceCameraPos;854;-3920,-3040;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldPosInputsNode;855;-3856,-3184;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleSubtractOpNode;856;-3664,-2800;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.WorldPosInputsNode;857;-3856,-2864;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleSubtractOpNode;858;-3664,-3120;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.NormalizeNode;859;-3552,-3120;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;860;-3328,-3536;Inherit;False;CloudColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.DotProductOpNode;861;-3392,-3120;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NormalizeNode;862;-3552,-2800;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector3Node;863;-3616,-2672;Inherit;False;Global;CZY_MoonDirection;CZY_MoonDirection;7;1;[HideInInspector];Create;True;0;0;0;False;0;False;0,0,0;-0.6518188,-0.7577517,0.03073904;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.PowerNode;864;-2880,-2992;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldSpaceCameraPos;865;-3920,-2720;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.DotProductOpNode;866;-3392,-2800;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;867;-3264,-3120;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0.5;False;2;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;868;-3264,-2800;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0.5;False;2;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;869;-3040,-3120;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;870;-3040,-2800;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;871;-2752,-3120;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;872;-2576,-2992;Inherit;False;CloudLight;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;873;-2896,-2800;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;874;-2720,-2976;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;875;-3328,-3360;Inherit;False;CloudHighlightColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;876;-2608,-3136;Half;False;LightMask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;877;-2608,-2800;Half;False;MoonlightMask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;878;-2752,-2800;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.PowerNode;879;-2896,-3120;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;880;-2640,-3552;Inherit;False;MoonlightColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;881;-3568,-3360;Inherit;False;Filter Color;-1;;5;84bcc1baa84e09b4fba5ba52924b2334;2,13,1,14,0;1;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;882;-3616,-3536;Inherit;False;Filter Color;-1;;6;84bcc1baa84e09b4fba5ba52924b2334;2,13,0,14,1;1;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;883;-2848,-3552;Inherit;False;Filter Color;-1;;7;84bcc1baa84e09b4fba5ba52924b2334;2,13,0,14,1;1;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.ColorNode;884;-3872,-3536;Inherit;False;Global;CZY_CloudColor;CZY_CloudColor;0;3;[HideInInspector];[HDR];[Header];Create;True;1;General Cloud Settings;0;0;False;0;False;0.7264151,0.7264151,0.7264151,0;0.7505031,0.8238728,0.8520919,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;885;-3872,-3360;Inherit;False;Global;CZY_CloudHighlightColor;CZY_CloudHighlightColor;1;2;[HideInInspector];[HDR];Create;True;0;0;0;False;0;False;1,1,1,0;4.162221,4.162221,4.162221,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;887;-3136,-2912;Half;False;Global;CZY_CloudFlareFalloff;CZY_CloudFlareFalloff;5;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;888;-3152,-2672;Half;False;Global;CZY_MoonFlareFalloff;CZY_MoonFlareFalloff;3;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;15.94;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;889;-3120,-3248;Inherit;False;Global;CZY_WindSpeed;CZY_WindSpeed;4;1;[HideInInspector];Create;False;0;0;0;False;0;False;0;0.75;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;890;-3136,-2992;Half;False;Global;CZY_SunFlareFalloff;CZY_SunFlareFalloff;4;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;21.4;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;891;-2320,-3504;Inherit;False;Global;CZY_CumulusCoverageMultiplier;CZY_CumulusCoverageMultiplier;5;2;[HideInInspector];[Header];Create;False;1;Cumulus Clouds;0;0;False;0;False;1;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;892;-3600,-2992;Inherit;False;Global;CZY_SunDirection;CZY_SunDirection;6;1;[HideInInspector];Create;True;0;0;0;False;0;False;0,0,0;0.1627289,0.986641,-0.007673949;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.Vector2Node;893;112,560;Inherit;False;Constant;_CloudWind2;Cloud Wind 2;14;1;[HideInInspector];Create;True;0;0;0;False;0;False;0.3,0.2;0.1,0.2;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.GetLocalVarNode;894;112,496;Inherit;False;849;TIme;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;895;560,592;Inherit;False;2;0;FLOAT;140;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;896;320,256;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;897;352,560;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;898;6704,-1296;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;899;320,1200;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;900;112,1168;Inherit;False;849;TIme;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;901;6992,-1424;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;902;3824,496;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleTimeNode;903;7056,-1568;Inherit;False;1;0;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.VoronoiNode;904;752,528;Inherit;False;0;0;1;3;1;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.GetLocalVarNode;905;112,288;Inherit;False;849;TIme;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;906;288,1088;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.VoronoiNode;907;624,1152;Inherit;True;0;0;1;0;3;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.SimpleDivideOpNode;908;560,704;Inherit;False;2;0;FLOAT;500;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;909;7040,-1056;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;910;480,1248;Inherit;False;2;0;FLOAT;100;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.VoronoiNode;911;752,672;Inherit;False;0;0;1;3;1;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.GetLocalVarNode;912;7056,-1648;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;913;480,1152;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;914;6960,-1248;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.02;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;915;6944,-1328;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;916;4096,-1296;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;917;560,480;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;918;928,608;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;919;352,432;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RotatorNode;920;4560,-1424;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;921;6240,720;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;922;544,272;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;923;7280,-1040;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RotatorNode;924;7168,-1424;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.WorldPosInputsNode;925;6128,288;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleDivideOpNode;926;544,368;Inherit;False;2;0;FLOAT;100;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;927;4448,-1568;Inherit;False;1;0;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;928;4384,-1424;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;929;4448,-1648;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;930;4416,-976;Inherit;False;1;0;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;931;4320,-1328;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;932;1072,608;Inherit;False;VoroDetails;-1;True;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;933;7312,-1632;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.WorldSpaceCameraPos;934;6064,448;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RotatorNode;935;7184,-1264;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;936;7376,-1264;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;937;1360,496;Inherit;False;932;VoroDetails;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;938;4672,-1040;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.NormalizeNode;939;6480,368;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SaturateNode;941;7712,-1024;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;942;4416,-1056;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;943;7568,-448;Inherit;False;1035;Clipping;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;944;736,272;Inherit;True;Simplex2D;True;False;2;0;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;945;6944,1088;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.9;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;946;7504,-1024;Inherit;False;Simplex2D;True;False;2;0;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;947;800,1136;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;948;6464,704;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DotProductOpNode;949;6656,720;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;950;7536,-1616;Inherit;False;Simplex2D;False;False;2;0;FLOAT2;0,0;False;1;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;951;4768,-1424;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;952;6352,368;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.OneMinusNode;953;7072,1088;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;954;960,1152;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0.3;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.RotatorNode;955;4656,-1264;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;956;4032,848;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;957;4432,2384;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1.5;False;2;FLOAT;0.75;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;958;6512,-576;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleTimeNode;959;7040,-976;Inherit;False;1;0;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;960;4032,736;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;961;8336,-1376;Inherit;False;CirrusPattern;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RotatorNode;962;4224,2208;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;963;3920,-576;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;964;7232,1056;Inherit;False;2;2;0;FLOAT;-2;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;965;2256,432;Inherit;False;ComplexCloudDensity;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;966;6912,608;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;4;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;967;4912,-1616;Inherit;False;Simplex2D;False;False;2;0;FLOAT2;0,0;False;1;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;968;7712,-1616;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;969;1536,496;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.NormalizeNode;970;6528,496;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;971;4896,-1024;Inherit;False;Simplex2D;False;False;2;0;FLOAT2;0,0;False;1;FLOAT;4;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;973;1648,496;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;974;6704,368;Inherit;True;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;975;4208,816;Inherit;False;2;2;0;FLOAT;-2;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;977;7168,960;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;978;960,272;Inherit;False;SimpleCloudDensity;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;979;4192,736;Inherit;False;BorderHeight;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;980;5104,-1024;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;981;5328,-1264;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.DotProductOpNode;982;6864,-576;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;983;7936,-1248;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;984;5104,-1616;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;985;7936,-1472;Inherit;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;986;4048,496;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;987;4144,-576;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;988;224,2624;Inherit;False;1;0;FLOAT;0.003;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;989;6704,-576;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;990;7392,960;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;991;432,2512;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;993;4400,816;Inherit;False;2;2;0;FLOAT;-4;False;1;FLOAT;-4;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;994;5328,-1488;Inherit;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;995;1568,416;Inherit;False;978;SimpleCloudDensity;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;996;7392,1056;Inherit;False;2;2;0;FLOAT;-4;False;1;FLOAT;-4;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;998;4080,2576;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;999;1152,1152;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0.1;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1000;7088,528;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;1001;1904,672;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1002;448,2368;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1003;4400,720;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;1004;3760,2336;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1005;1312,1056;Inherit;False;CloudDetail;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1006;7184,-672;Inherit;False;961;CirrusPattern;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1007;7264,-576;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1008;7424,-512;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;10;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1009;4112,1984;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;1010;4096,2656;Inherit;False;1;0;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1011;4048,2208;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TFHCRemapNode;1012;7584,896;Inherit;True;5;0;FLOAT;0;False;1;FLOAT;0.5;False;2;FLOAT;7;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1013;7008,-576;Inherit;True;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.2;False;3;FLOAT;0;False;4;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1014;3984,2304;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1015;4608,480;Inherit;False;978;SimpleCloudDensity;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1016;608,2416;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TFHCRemapNode;1017;2080,448;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0.3;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1018;4000,2400;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.02;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;1019;4112,2064;Inherit;False;1;0;FLOAT;0.01;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1020;7616,784;Inherit;False;978;SimpleCloudDensity;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1021;4464,-576;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.1;False;3;FLOAT;0.4;False;4;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1022;4336,2608;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;10;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1023;4832,432;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RotatorNode;1024;4224,2368;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SaturateNode;1025;7856,896;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.VoronoiNode;1026;784,2416;Inherit;True;0;0;1;3;1;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;10;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.GetLocalVarNode;1027;7664,688;Inherit;False;1005;CloudDetail;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1028;8112,-1360;Inherit;True;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1029;352,3136;Inherit;False;849;TIme;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1030;5504,-1376;Inherit;True;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1031;4656,400;Inherit;False;1005;CloudDetail;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1032;4352,2016;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1033;4992,544;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;1034;4320,-576;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1035;1984,-1232;Inherit;False;Clipping;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1036;7840,736;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1037;5728,-1376;Inherit;False;ChemtrailsPattern;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1038;4864,576;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;1039;4240,496;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1040;4576,-672;Inherit;False;1037;ChemtrailsPattern;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1041;4640,-576;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1042;1008,2368;Inherit;True;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;1;False;4;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;1043;4560,2608;Inherit;False;Simplex2D;False;False;2;0;FLOAT2;0,0;False;1;FLOAT;4;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1044;7424,-640;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;1;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1045;1040,1056;Inherit;False;965;ComplexCloudDensity;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1046;4416,2208;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1.5;False;2;FLOAT;0.75;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1047;8000,832;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;1048;1136,2144;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1049;1072,2592;Inherit;False;2;2;0;FLOAT;10;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1050;7376,-1424;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1.5;False;2;FLOAT;0.75;False;1;FLOAT2;0
Node;AmplifyShaderEditor.NoiseGeneratorNode;1051;4576,2016;Inherit;False;Simplex2D;False;False;2;0;FLOAT2;0,0;False;1;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;1052;928,528;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1053;8288,848;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1054;928,2128;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.2;False;3;FLOAT;0;False;4;FLOAT;3;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1055;7584,-544;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;1056;1280,2144;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1057;8144,832;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;10;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1058;4768,2608;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.VoronoiNode;1059;1344,2368;Inherit;True;0;0;1;0;1;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;12.27;False;2;FLOAT;10;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.GetLocalVarNode;1060;512,2928;Inherit;False;852;Pos;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;1061;4800,-368;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;1062;192,2048;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;1063;3584,3072;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1065;544,3056;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1066;1312,1136;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1067;4768,2016;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;1069;608,2064;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;1070;3984,3072;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;1071;784,-224;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.GetLocalVarNode;1072;2000,-1376;Inherit;False;1228;FinalAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1073;2656,2304;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1074;4992,2384;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;1075;1440,2144;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;1076;3808,3072;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SaturateNode;1077;1520,1136;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;1078;7760,-544;Inherit;False;2;4;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1079;4992,2160;Inherit;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.ClampOpNode;1080;5344,576;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;-1;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1081;5200,-544;Inherit;False;ChemtrailsFinal;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;1082;4688,3088;Inherit;False;2;4;0;COLOR;0,0,0,0;False;1;FLOAT;0.5754717;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1083;7936,-544;Inherit;False;CirrusAlpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1084;1600,2144;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1085;1680,1120;Inherit;False;DetailedClouds;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1086;5168,2272;Inherit;True;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;1087;608,-112;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.8;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;1088;4512,3264;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;1089;752,3120;Inherit;False;2;0;FLOAT;100;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1090;4128,3072;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.1;False;3;FLOAT;0.4;False;4;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1091;192,-2144;Inherit;False;1083;CirrusAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1092;4240,2960;Inherit;False;1097;CirrostratPattern;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1093;4320,3072;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;1094;1264,2992;Inherit;True;2;4;0;FLOAT;0.1;False;1;FLOAT;0.3;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1095;1088,3104;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.15;False;3;FLOAT;0.5;False;4;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1096;144,-2368;Inherit;False;1120;BorderLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1097;5392,2272;Inherit;False;CirrostratPattern;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1098;1776,2144;Inherit;False;AltoCumulusPlacement;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1099;144,-2288;Inherit;False;1107;NimbusLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1100;416,-2352;Inherit;False;5;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;1101;4368,3264;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.98;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1102;4208,3264;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1103;176,-2448;Inherit;False;1085;DetailedClouds;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1104;1264,2912;Inherit;False;1098;AltoCumulusPlacement;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1105;176,-2208;Inherit;False;1081;ChemtrailsFinal;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1106;720,-2352;Inherit;False;SimpleRadiance;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1107;8464,848;Inherit;True;NimbusLightTransport;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1108;576,-2336;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1109;560,-224;Inherit;False;932;VoroDetails;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1110;7712,-656;Inherit;False;CirrusLightTransport;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1111;4688,-1632;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1112;4480,2992;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;1113;688,2944;Inherit;False;3;0;FLOAT2;0,0;False;1;FLOAT;1;False;2;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.VoronoiNode;1114;880,3008;Inherit;True;0;0;1;0;2;False;1;False;False;False;4;0;FLOAT2;0,0;False;1;FLOAT;51.2;False;2;FLOAT;3;False;3;FLOAT;0;False;3;FLOAT;0;FLOAT2;1;FLOAT2;2
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1115;1504,2928;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;1116;1664,2928;Inherit;True;2;4;0;FLOAT;0.1;False;1;FLOAT;0.2;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1117;768,-112;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;1118;5040,-544;Inherit;False;2;4;0;COLOR;0,0,0,0;False;1;FLOAT;0.5;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1119;-112,-3024;Inherit;False;1128;AltoCumulusLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1121;864,-1200;Inherit;False;1106;SimpleRadiance;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;1122;1760,-112;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1123;4864,3088;Inherit;False;CirrostratLightTransport;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1124;5200,3136;Inherit;False;1035;Clipping;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1125;928,-192;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1126;5184,3040;Inherit;False;1106;SimpleRadiance;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1127;2256,2448;Inherit;False;1035;Clipping;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1128;1936,2944;Inherit;False;AltoCumulusLightTransport;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1129;1056,-208;Inherit;False;CloudThicknessDetails;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1130;2240,2368;Inherit;False;1106;SimpleRadiance;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1131;5200,560;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;10;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Compare;1132;2464,2368;Inherit;False;2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1133;176,-1040;Inherit;False;1129;CloudThicknessDetails;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1134;2336,2272;Inherit;False;1128;AltoCumulusLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1135;-64,-1600;Inherit;False;965;ComplexCloudDensity;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1136;2096,-160;Inherit;False;875;CloudHighlightColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.Compare;1137;5408,3040;Inherit;False;2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1138;4656,-368;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1139;4816,-640;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1140;5280,2960;Inherit;False;1123;CirrostratLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;1141;416,2048;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0.5;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;1142;1872,64;Inherit;False;872;CloudLight;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1143;4336,-1248;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.02;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1144;1872,-16;Inherit;False;1005;CloudDetail;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1145;160,-1312;Inherit;False;1129;CloudThicknessDetails;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;1146;176,-1600;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;2;False;4;FLOAT;0.7;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1147;320,-1696;Inherit;False;860;CloudColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1148;368,-1504;Inherit;False;876;LightMask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1149;320,-1408;Inherit;False;875;CloudHighlightColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1150;368,-1600;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1151;2544,-112;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;1;False;1;COLOR;0
Node;AmplifyShaderEditor.OneMinusNode;1152;1120,-1360;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1153;240,-3040;Inherit;False;7;7;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1154;2704,-112;Inherit;False;SunThroughClouds;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1155;1904,-112;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1156;5744,2976;Inherit;False;CSCustomLightsClipping;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1157;336,-1136;Inherit;False;880;MoonlightColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;1158;2336,16;Inherit;False;Constant;_2;2;15;1;[HideInInspector];Create;True;0;0;0;False;0;False;1.3;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1159;560,-1424;Inherit;False;3;3;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1160;1552,-2240;Inherit;False;1156;CSCustomLightsClipping;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1161;1552,-2336;Inherit;False;1171;ACCustomLightsClipping;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;1162;544,-1680;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.LerpOp;1163;2336,-128;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1164;736,-1376;Inherit;False;860;CloudColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1165;576,-1152;Inherit;False;3;3;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.ClipNode;1166;2224,-1472;Inherit;False;3;0;COLOR;0,0,0,0;False;1;FLOAT;1;False;2;FLOAT;0.5;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1167;-32,-2784;Inherit;False;1083;CirrusAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1168;-96,-2864;Inherit;False;1123;CirrostratLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1169;1840,-2288;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1170;912,-1392;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0.5660378,0.5660378,0.5660378,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1171;2800,2304;Inherit;False;ACCustomLightsClipping;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1172;5600,2976;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1174;352,-1216;Inherit;False;877;MoonlightMask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1175;-80,-2704;Inherit;False;1107;NimbusLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1176;736,-1520;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1177;816,-1296;Inherit;False;1129;CloudThicknessDetails;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1178;-48,-2944;Inherit;False;1081;ChemtrailsFinal;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;1179;1824,-1456;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;1,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1180;1568,-1264;Inherit;False;1188;CustomRadiance;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1181;272,-1776;Inherit;False;875;CloudHighlightColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.OneMinusNode;1182;416,-1040;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;1183;1536,-1456;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1184;2096,-80;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1185;1088,-1616;Inherit;False;860;CloudColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.LerpOp;1186;1072,-1504;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;1,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1187;1296,-1360;Inherit;False;1154;SunThroughClouds;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1188;2144,-2304;Inherit;False;CustomRadiance;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SaturateNode;1189;384,-3024;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;1190;1296,-1488;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1191;1536,-1328;Inherit;False;1198;CirrusCustomLightColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SaturateNode;1192;1984,-2288;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1193;-80,-3120;Inherit;False;1120;BorderLightTransport;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;1194;400,-1312;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1195;-48,-3200;Inherit;False;1085;DetailedClouds;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;1196;2704,2048;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0.7159576,0.8624095,0.8773585,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;1197;2512,1984;Inherit;False;860;CloudColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1198;2864,2048;Inherit;False;CirrusCustomLightColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FunctionNode;1199;2432,2096;Inherit;False;Filter Color;-1;;8;84bcc1baa84e09b4fba5ba52924b2334;2,13,0,14,1;1;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.Vector2Node;1200;112,368;Inherit;False;Constant;_CloudWind1;Cloud Wind 1;13;1;[HideInInspector];Create;True;0;0;0;False;0;False;0.2,-0.4;0.6,-0.8;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.RangedFloatNode;1201;304,1312;Inherit;False;Global;CZY_DetailScale;CZY_DetailScale;2;1;[HideInInspector];Create;False;0;0;0;False;0;False;0.5;1.5;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1202;960,1312;Inherit;False;Global;CZY_DetailAmount;CZY_DetailAmount;3;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;25;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector2Node;1203;112,1280;Inherit;False;Constant;_DetailWind;Detail Wind;17;0;Create;True;0;0;0;False;0;False;0.3,0.2;0.3,0.8;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.RangedFloatNode;1204;3760,848;Inherit;False;Global;CZY_BorderVariation;CZY_BorderVariation;5;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;0.956;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1205;3760,736;Inherit;False;Global;CZY_BorderHeight;CZY_BorderHeight;4;2;[HideInInspector];[Header];Create;False;1;Border Clouds;0;0;False;0;False;1;0.846;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1206;304,352;Inherit;False;Global;CZY_MainCloudScale;CZY_MainCloudScale;1;1;[HideInInspector];Create;False;0;0;0;False;0;False;10;12;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1207;4880,688;Inherit;False;Global;CZY_BorderEffect;CZY_BorderEffect;1;1;[HideInInspector];Create;True;0;0;0;False;0;False;0;1;-1;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1208;6640,608;Inherit;False;Global;CZY_NimbusHeight;CZY_NimbusHeight;3;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;1209;6336,512;Inherit;False;Global;CZY_StormDirection;CZY_StormDirection;4;1;[HideInInspector];Create;False;0;0;0;False;0;False;0,0,0;0.06420752,0,-0.9979365;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;1210;6800,976;Inherit;False;Global;CZY_NimbusMultiplier;CZY_NimbusMultiplier;1;2;[HideInInspector];[Header];Create;False;1;Nimbus Clouds;0;0;False;0;False;1;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1211;6672,1088;Inherit;False;Global;CZY_NimbusVariation;CZY_NimbusVariation;2;1;[HideInInspector];Create;False;0;0;0;False;0;False;1;0.945;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1212;7056,-336;Inherit;False;Global;CZY_CirrusMultiplier;CZY_CirrusMultiplier;11;2;[HideInInspector];[Header];Create;False;1;Cirrus Clouds;0;0;False;0;False;1;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1213;4368,-368;Inherit;False;Global;CZY_ChemtrailsMultiplier;CZY_ChemtrailsMultiplier;14;1;[HideInInspector];Create;False;1;Chemtrails;0;0;False;0;False;1;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1214;6464,-1296;Inherit;False;Global;CZY_CirrusMoveSpeed;CZY_CirrusMoveSpeed;12;1;[HideInInspector];Create;False;0;0;0;False;0;False;0;0.5;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1215;1680,-1120;Inherit;False;Global;CZY_ClippingThreshold;CZY_ClippingThreshold;1;1;[HideInInspector];Create;False;0;0;0;False;0;False;0.5;0.5;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1216;3856,-1296;Inherit;False;Global;CZY_ChemtrailsMoveSpeed;CZY_ChemtrailsMoveSpeed;15;1;[HideInInspector];Create;False;0;0;0;False;0;False;0;0.5;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;1217;2208,2096;Inherit;False;Global;CZY_AltoCloudColor;CZY_AltoCloudColor;0;2;[HideInInspector];[HDR];Create;False;0;0;0;False;0;False;1,1,1,0;1.083397,1.392001,1.382235,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector2Node;1218;224,2368;Inherit;False;Constant;_ACMoveSpeed;ACMoveSpeed;14;0;Create;True;0;0;0;False;0;False;1,-2;5,20;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.Vector2Node;1219;272,3008;Inherit;False;Global;CZY_AltocumulusWindSpeed;CZY_AltocumulusWindSpeed;3;1;[HideInInspector];Create;False;0;0;0;False;0;False;1,-2;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.RangedFloatNode;1220;496,3232;Inherit;False;Global;CZY_AltocumulusScale;CZY_AltocumulusScale;2;1;[HideInInspector];Create;False;0;0;0;False;0;False;3;0.67;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1221;1264,3216;Inherit;False;Global;CZY_AltocumulusMultiplier;CZY_AltocumulusMultiplier;1;2;[HideInInspector];[Header];Create;False;1;Altocumulus Clouds;0;0;False;0;False;0;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1222;3936,3264;Inherit;False;Global;CZY_CirrostratusMultiplier;CZY_CirrostratusMultiplier;4;2;[HideInInspector];[Header];Create;False;1;Cirrostratus Clouds;0;0;False;0;False;1;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;1223;3520,2336;Inherit;False;Global;CZY_CirrostratusMoveSpeed;CZY_CirrostratusMoveSpeed;5;1;[HideInInspector];Create;False;0;0;0;False;0;False;0;0.5;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1224;384,-112;Inherit;False;853;CumulusCoverage;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1225;1520,-112;Inherit;False;853;CumulusCoverage;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;1226;1680,672;Inherit;False;853;CumulusCoverage;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode;1227;1856,448;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1228;560,-3040;Inherit;False;FinalAlpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;799;-1456,-496;Inherit;False;1228;FinalAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;352;-948.2714,-629.483;Inherit;False;1173;FinalCloudColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1173;2443,-1478;Inherit;False;FinalCloudColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;1120;5488,576;Inherit;False;BorderLightTransport;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;997;4592,576;Inherit;True;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;-2;False;4;FLOAT;3;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;801;-1424,-351;Inherit;False;Global;CZY_CloudThickness;CZY_CloudThickness;6;1;[HDR];Create;False;0;0;0;False;0;False;1;4;0;4;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;940;7568,-1248;Inherit;True;Property;_TextureSample1;Texture Sample 1;0;0;Create;True;0;0;0;False;0;False;-1;None;9b3476b4df9abf8479476bae1bcd8a84;True;0;False;white;Auto;False;Instance;992;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;1068;4624,2384;Inherit;True;Property;_TextureSample0;Texture Sample 0;1;0;Create;True;0;0;0;False;0;False;-1;None;9b3476b4df9abf8479476bae1bcd8a84;True;0;False;white;Auto;False;Instance;1064;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;1064;4624,2176;Inherit;True;Global;CZY_CirrostratusTexture;CirrostratusTexture;1;0;Create;False;0;0;0;False;0;False;-1;bf43c8d7b74e204469465f36dfff7d6a;bf43c8d7b74e204469465f36dfff7d6a;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;976;4960,-1472;Inherit;True;Global;CZY_ChemtrailsTexture;CZY_ChemtrailsTexture;2;0;Create;False;0;0;0;False;0;False;-1;9b3476b4df9abf8479476bae1bcd8a84;9b3476b4df9abf8479476bae1bcd8a84;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;972;4960,-1264;Inherit;True;Property;_ChemtrailsTex2;Chemtrails Tex 2;2;0;Create;True;0;0;0;False;0;False;-1;None;9b3476b4df9abf8479476bae1bcd8a84;True;0;False;white;Auto;False;Instance;976;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;992;7568,-1456;Inherit;True;Global;CZY_CirrusTexture;CZY_CirrusTexture;0;0;Create;True;0;0;0;False;0;False;-1;None;302629ebb64a0e345948779662fc2cf3;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;886;-3088,-3552;Inherit;False;Global;CZY_CloudMoonColor;CZY_CloudMoonColor;0;2;[HideInInspector];[HDR];Create;False;0;0;0;False;0;False;1,1,1,0;0,0,0,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;807;-400,-624;Float;False;True;-1;2;EmptyShaderGUI;0;13;Distant Lands/Cozy/Stylized Clouds Soft;2992e84f91cbeb14eab234972e07ea9d;True;Forward;0;1;Forward;8;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;1;False;;False;False;False;False;False;False;False;False;True;True;True;221;False;;255;False;;255;False;;7;False;;2;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;True;2;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalForward;False;False;0;Hidden/InternalErrorShader;0;0;Standard;23;Surface;1;637952289623616075;  Blend;0;0;Two Sided;2;638050878722904710;Forward Only;0;0;Cast Shadows;1;0;  Use Shadow Threshold;0;0;Receive Shadows;1;0;GPU Instancing;1;0;LOD CrossFade;0;0;Built-in Fog;0;0;DOTS Instancing;0;0;Meta Pass;0;0;Extra Pre Pass;0;0;Tessellation;0;0;  Phong;0;0;  Strength;0.5,False,;0;  Type;0;0;  Tess;16,False,;0;  Min;10,False,;0;  Max;25,False,;0;  Edge Length;16,False,;0;  Max Displacement;25,False,;0;Vertex Position,InvertActionOnDeselection;1;0;0;10;False;True;True;True;False;False;True;True;True;True;False;;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;806;-678.2959,-671.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ExtraPrePass;0;0;ExtraPrePass;5;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;0;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;808;-678.2959,-671.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ShadowCaster;0;2;ShadowCaster;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=ShadowCaster;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;809;-678.2959,-671.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthOnly;0;3;DepthOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;False;False;True;1;LightMode=DepthOnly;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;810;-678.2959,-671.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Meta;0;4;Meta;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;255;False;;255;False;;255;False;;7;False;;1;False;;1;False;;1;False;;7;False;;1;False;;1;False;;1;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Meta;False;False;0;Hidden/InternalErrorShader;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;811;-644.2959,-581.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Universal2D;0;5;Universal2D;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=Universal2D;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;812;-644.2959,-581.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;SceneSelectionPass;0;6;SceneSelectionPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=SceneSelectionPass;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;813;-644.2959,-581.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ScenePickingPass;0;7;ScenePickingPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Picking;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;814;-644.2959,-581.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormals;0;8;DepthNormals;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;815;-644.2959,-581.1561;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormalsOnly;0;9;DepthNormalsOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;3;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;True;9;d3d11;metal;vulkan;xboxone;xboxseries;playstation;ps4;ps5;switch;0;;0;0;Standard;0;False;0
WireConnection;800;0;799;0
WireConnection;800;2;801;0
WireConnection;805;0;799;0
WireConnection;805;1;800;0
WireConnection;802;0;805;0
WireConnection;848;0;851;0
WireConnection;849;0;848;0
WireConnection;851;1;889;0
WireConnection;852;0;850;0
WireConnection;853;0;891;0
WireConnection;856;0;857;0
WireConnection;856;1;865;0
WireConnection;858;0;855;0
WireConnection;858;1;854;0
WireConnection;859;0;858;0
WireConnection;860;0;882;0
WireConnection;861;0;859;0
WireConnection;861;1;892;0
WireConnection;862;0;856;0
WireConnection;864;0;869;0
WireConnection;864;1;887;0
WireConnection;866;0;862;0
WireConnection;866;1;863;0
WireConnection;867;0;861;0
WireConnection;868;0;866;0
WireConnection;869;0;867;0
WireConnection;870;0;868;0
WireConnection;871;0;879;0
WireConnection;872;0;874;0
WireConnection;873;0;870;0
WireConnection;873;1;888;0
WireConnection;874;0;864;0
WireConnection;875;0;881;0
WireConnection;876;0;871;0
WireConnection;877;0;878;0
WireConnection;878;0;873;0
WireConnection;879;0;869;0
WireConnection;879;1;890;0
WireConnection;880;0;883;0
WireConnection;881;1;885;0
WireConnection;882;1;884;0
WireConnection;883;1;886;0
WireConnection;895;1;1206;0
WireConnection;897;0;894;0
WireConnection;897;1;893;0
WireConnection;898;0;1214;0
WireConnection;899;0;900;0
WireConnection;899;1;1203;0
WireConnection;904;0;917;0
WireConnection;904;2;895;0
WireConnection;907;0;913;0
WireConnection;907;2;910;0
WireConnection;908;1;1206;0
WireConnection;910;1;1201;0
WireConnection;911;0;917;0
WireConnection;911;2;908;0
WireConnection;913;0;906;0
WireConnection;913;1;899;0
WireConnection;914;0;898;0
WireConnection;915;0;898;0
WireConnection;916;0;1216;0
WireConnection;917;0;896;0
WireConnection;917;1;897;0
WireConnection;918;0;904;0
WireConnection;918;1;911;0
WireConnection;919;0;905;0
WireConnection;919;1;1200;0
WireConnection;920;0;928;0
WireConnection;920;2;931;0
WireConnection;922;0;896;0
WireConnection;922;1;919;0
WireConnection;923;0;909;0
WireConnection;923;2;959;0
WireConnection;924;0;901;0
WireConnection;924;2;915;0
WireConnection;926;1;1206;0
WireConnection;931;0;916;0
WireConnection;932;0;918;0
WireConnection;933;0;912;0
WireConnection;933;2;903;0
WireConnection;935;0;901;0
WireConnection;935;2;914;0
WireConnection;936;0;935;0
WireConnection;938;0;942;0
WireConnection;938;2;930;0
WireConnection;939;0;952;0
WireConnection;941;0;946;0
WireConnection;944;0;922;0
WireConnection;944;1;926;0
WireConnection;945;0;1211;0
WireConnection;946;0;923;0
WireConnection;947;0;907;0
WireConnection;948;0;921;0
WireConnection;949;0;948;0
WireConnection;949;1;948;0
WireConnection;950;0;933;0
WireConnection;951;0;920;0
WireConnection;952;0;925;0
WireConnection;952;1;934;0
WireConnection;953;0;945;0
WireConnection;954;0;947;0
WireConnection;955;0;928;0
WireConnection;955;2;1143;0
WireConnection;956;0;1204;0
WireConnection;957;0;1024;0
WireConnection;960;0;1205;0
WireConnection;961;0;1028;0
WireConnection;962;0;1011;0
WireConnection;962;2;1014;0
WireConnection;964;1;953;0
WireConnection;965;0;1017;0
WireConnection;966;0;1208;0
WireConnection;966;2;949;0
WireConnection;967;0;1111;0
WireConnection;968;0;950;0
WireConnection;969;0;937;0
WireConnection;970;0;1209;0
WireConnection;971;0;938;0
WireConnection;973;0;969;0
WireConnection;974;0;939;0
WireConnection;974;1;970;0
WireConnection;975;1;956;0
WireConnection;977;0;1210;0
WireConnection;978;0;944;0
WireConnection;979;0;960;0
WireConnection;980;0;971;0
WireConnection;981;0;972;0
WireConnection;981;1;980;0
WireConnection;982;0;989;0
WireConnection;982;1;989;0
WireConnection;983;0;940;0
WireConnection;983;1;941;0
WireConnection;984;0;967;0
WireConnection;985;0;968;0
WireConnection;985;1;992;0
WireConnection;986;0;902;0
WireConnection;987;0;963;0
WireConnection;989;0;958;0
WireConnection;990;0;977;0
WireConnection;990;1;964;0
WireConnection;991;0;1218;0
WireConnection;991;1;988;0
WireConnection;993;0;975;0
WireConnection;994;0;984;0
WireConnection;994;1;976;0
WireConnection;996;0;964;0
WireConnection;999;0;954;0
WireConnection;999;2;1202;0
WireConnection;1000;0;974;0
WireConnection;1000;1;966;0
WireConnection;1001;0;1226;0
WireConnection;1003;0;979;0
WireConnection;1003;1;975;0
WireConnection;1004;0;1223;0
WireConnection;1005;0;999;0
WireConnection;1007;0;1013;0
WireConnection;1008;0;1212;0
WireConnection;1012;0;1000;0
WireConnection;1012;3;990;0
WireConnection;1012;4;996;0
WireConnection;1013;0;982;0
WireConnection;1014;0;1004;0
WireConnection;1016;0;1002;0
WireConnection;1016;2;991;0
WireConnection;1017;0;1227;0
WireConnection;1017;1;1001;0
WireConnection;1018;0;1004;0
WireConnection;1021;0;1034;0
WireConnection;1022;0;998;0
WireConnection;1022;2;1010;0
WireConnection;1023;0;1031;0
WireConnection;1023;1;1015;0
WireConnection;1024;0;1011;0
WireConnection;1024;2;1018;0
WireConnection;1025;0;1012;0
WireConnection;1026;0;1016;0
WireConnection;1028;0;985;0
WireConnection;1028;1;983;0
WireConnection;1030;0;994;0
WireConnection;1030;1;981;0
WireConnection;1032;0;1009;0
WireConnection;1032;2;1019;0
WireConnection;1033;0;1023;0
WireConnection;1033;1;1038;0
WireConnection;1034;0;987;0
WireConnection;1034;1;987;0
WireConnection;1035;0;1215;0
WireConnection;1036;0;1027;0
WireConnection;1036;1;1020;0
WireConnection;1037;0;1030;0
WireConnection;1038;0;997;0
WireConnection;1039;0;986;0
WireConnection;1039;1;986;0
WireConnection;1041;0;1021;0
WireConnection;1042;0;1026;0
WireConnection;1043;0;1022;0
WireConnection;1044;0;1006;0
WireConnection;1044;1;1007;0
WireConnection;1046;0;962;0
WireConnection;1047;0;1036;0
WireConnection;1047;1;1025;0
WireConnection;1049;1;988;0
WireConnection;1050;0;924;0
WireConnection;1051;0;1032;0
WireConnection;1052;0;904;0
WireConnection;1053;0;1057;0
WireConnection;1054;0;1069;0
WireConnection;1055;0;1044;0
WireConnection;1055;1;1008;0
WireConnection;1056;0;1048;0
WireConnection;1056;1;1042;0
WireConnection;1057;0;1047;0
WireConnection;1058;0;1043;0
WireConnection;1059;1;1049;0
WireConnection;1061;0;1138;0
WireConnection;1065;0;1219;0
WireConnection;1065;1;1029;0
WireConnection;1066;0;1045;0
WireConnection;1066;1;999;0
WireConnection;1067;0;1051;0
WireConnection;1069;0;1141;0
WireConnection;1069;1;1141;0
WireConnection;1070;0;1076;0
WireConnection;1070;1;1076;0
WireConnection;1071;0;1109;0
WireConnection;1073;0;1134;0
WireConnection;1073;1;1132;0
WireConnection;1074;0;1068;0
WireConnection;1074;1;1058;0
WireConnection;1075;0;1056;0
WireConnection;1075;1;1059;0
WireConnection;1076;0;1063;0
WireConnection;1077;0;1066;0
WireConnection;1078;0;1055;0
WireConnection;1078;1;943;0
WireConnection;1079;0;1067;0
WireConnection;1079;1;1064;0
WireConnection;1080;0;1131;0
WireConnection;1081;0;1118;0
WireConnection;1082;0;1112;0
WireConnection;1082;1;1088;0
WireConnection;1083;0;1078;0
WireConnection;1084;0;1075;0
WireConnection;1085;0;1077;0
WireConnection;1086;0;1079;0
WireConnection;1086;1;1074;0
WireConnection;1087;0;1224;0
WireConnection;1088;0;1101;0
WireConnection;1089;1;1220;0
WireConnection;1090;0;1070;0
WireConnection;1093;0;1090;0
WireConnection;1094;1;1114;0
WireConnection;1094;2;1095;0
WireConnection;1095;0;1114;0
WireConnection;1097;0;1086;0
WireConnection;1098;0;1084;0
WireConnection;1100;0;1103;0
WireConnection;1100;1;1096;0
WireConnection;1100;2;1099;0
WireConnection;1100;3;1105;0
WireConnection;1100;4;1091;0
WireConnection;1101;0;1102;0
WireConnection;1102;0;1222;0
WireConnection;1106;0;1108;0
WireConnection;1107;0;1053;0
WireConnection;1108;0;1100;0
WireConnection;1110;0;1044;0
WireConnection;1111;0;929;0
WireConnection;1111;2;927;0
WireConnection;1112;0;1092;0
WireConnection;1112;1;1093;0
WireConnection;1113;0;1060;0
WireConnection;1113;2;1065;0
WireConnection;1114;0;1113;0
WireConnection;1114;2;1089;0
WireConnection;1115;0;1104;0
WireConnection;1115;1;1094;0
WireConnection;1115;2;1221;0
WireConnection;1116;0;1115;0
WireConnection;1117;0;1087;0
WireConnection;1118;0;1139;0
WireConnection;1118;1;1061;0
WireConnection;1122;0;1225;0
WireConnection;1123;0;1082;0
WireConnection;1125;0;1071;1
WireConnection;1125;1;1117;0
WireConnection;1128;0;1116;0
WireConnection;1129;0;1125;0
WireConnection;1131;0;1033;0
WireConnection;1131;2;1207;0
WireConnection;1132;0;1130;0
WireConnection;1132;1;1127;0
WireConnection;1137;0;1126;0
WireConnection;1137;1;1124;0
WireConnection;1138;0;1213;0
WireConnection;1139;0;1040;0
WireConnection;1139;1;1041;0
WireConnection;1141;0;1062;0
WireConnection;1143;0;916;0
WireConnection;1146;0;1135;0
WireConnection;1150;0;1146;0
WireConnection;1151;0;1163;0
WireConnection;1151;1;1158;0
WireConnection;1152;0;1121;0
WireConnection;1153;0;1195;0
WireConnection;1153;1;1193;0
WireConnection;1153;2;1119;0
WireConnection;1153;3;1178;0
WireConnection;1153;4;1168;0
WireConnection;1153;5;1167;0
WireConnection;1153;6;1175;0
WireConnection;1154;0;1151;0
WireConnection;1155;0;1122;0
WireConnection;1156;0;1172;0
WireConnection;1159;0;1148;0
WireConnection;1159;1;1149;0
WireConnection;1159;2;1194;0
WireConnection;1162;0;1181;0
WireConnection;1162;1;1147;0
WireConnection;1162;2;1150;0
WireConnection;1163;1;1136;0
WireConnection;1163;2;1184;0
WireConnection;1165;0;1174;0
WireConnection;1165;1;1157;0
WireConnection;1165;2;1182;0
WireConnection;1166;0;1179;0
WireConnection;1166;1;1072;0
WireConnection;1166;2;1035;0
WireConnection;1169;0;1161;0
WireConnection;1169;1;1160;0
WireConnection;1170;0;1164;0
WireConnection;1171;0;1073;0
WireConnection;1172;0;1140;0
WireConnection;1172;1;1137;0
WireConnection;1176;0;1162;0
WireConnection;1176;1;1159;0
WireConnection;1176;2;1165;0
WireConnection;1179;0;1183;0
WireConnection;1179;1;1191;0
WireConnection;1179;2;1180;0
WireConnection;1182;0;1133;0
WireConnection;1183;0;1190;0
WireConnection;1183;1;1187;0
WireConnection;1184;0;1155;0
WireConnection;1184;1;1144;0
WireConnection;1184;2;1142;0
WireConnection;1186;0;1176;0
WireConnection;1186;1;1170;0
WireConnection;1186;2;1177;0
WireConnection;1188;0;1192;0
WireConnection;1189;0;1153;0
WireConnection;1190;0;1185;0
WireConnection;1190;1;1186;0
WireConnection;1190;2;1152;0
WireConnection;1192;0;1169;0
WireConnection;1194;0;1145;0
WireConnection;1196;0;1197;0
WireConnection;1196;1;1199;0
WireConnection;1198;0;1196;0
WireConnection;1199;1;1217;0
WireConnection;1227;0;995;0
WireConnection;1227;1;973;0
WireConnection;1228;0;1189;0
WireConnection;1173;0;1179;0
WireConnection;1120;0;1080;0
WireConnection;997;0;1039;0
WireConnection;997;3;1003;0
WireConnection;997;4;993;0
WireConnection;940;1;936;0
WireConnection;1068;1;957;0
WireConnection;1064;1;1046;0
WireConnection;976;1;951;0
WireConnection;972;1;955;0
WireConnection;992;1;1050;0
WireConnection;807;2;352;0
WireConnection;807;3;802;0
ASEEND*/
//CHKSM=2DDF97F477B3CCC99A41365BD8B64BFCE2BBF1D6