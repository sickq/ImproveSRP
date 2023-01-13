#ifndef _AS_INCLUDE
    #define _AS_INCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    TEXTURE2D(_IntegralCPDensityLUT);
    SAMPLER(sampler_IntegralCPDensityLUT);
    
    uniform float2 _DensityScaleHeight;
    uniform float _PlanetRadius;
    uniform float _AtmosphereHeight;
    uniform float _SurfaceHeight;
    
    uniform float3 _ScatteringR;
    uniform float3 _ScatteringM;
    uniform float3 _ExtinctionR;
    uniform float3 _ExtinctionM;
    uniform float _MieG;
    
    uniform half3 _LightFromOuterSpace;
    uniform float _SunIntensity;
    uniform float _SunMieG;

    SamplerState _trilinearClampSampler;

    //CS独有的参数
    Texture2D<float3> _InScatteringLUT;
    

#endif