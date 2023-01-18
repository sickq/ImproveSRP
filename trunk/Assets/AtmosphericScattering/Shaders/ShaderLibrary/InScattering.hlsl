﻿#ifndef _AC2_SCATTERING_INCLUDED
    #define _AC2_SCATTERING_INCLUDED
    
    // IntegrateInscattering
    // P - current integration point
    // A - camera position
    // C - top of the atmosphere
    #include "ASInclude.hlsl"
    #include "ASMath.hlsl"
    
    void ApplyPhaseFunction(inout float3 scatterR, inout float3 scatterM, float cosAngle)
    {
        scatterR *= RayleighPhase(cosAngle);
        scatterM *= MiePhaseHGCS(cosAngle, _MieG);
    }
    
    float3 RenderSun(float3 scatterM, float cosAngle)
    {
        //return scatterM * Sun(cosAngle);
        return scatterM * MiePhaseHG(cosAngle, _SunMieG) * 0.003;
    }
    
    void GetAtmosphereDensity(float3 position, float3 planetCenter, float3 lightDir, out float2 densityAtP, out float2 particleDensityCP)
    {
        float height = length(position - planetCenter) - _PlanetRadius;
        densityAtP = ParticleDensity(height, _DensityScaleHeight.xy);
        
        float cosAngle = dot(normalize(position - planetCenter), lightDir.xyz);
        
        particleDensityCP = SAMPLE_TEXTURE2D_LOD(_IntegralCPDensityLUT, sampler_IntegralCPDensityLUT, float2(cosAngle * 0.5 + 0.5, (height / _AtmosphereHeight)), 0).xy;
        //particleDensityCP = _IntegralCPDensityLUT.Sample(sampler_IntegralCPDensityLUT, float2(cosAngle * 0.5 + 0.5, (height / _AtmosphereHeight))).xy;
    }
    
    void ComputeLocalInscattering(float2 densityAtP, float2 particleDensityCP, float2 particleDensityAP, out float3 localInscatterR, out float3 localInscatterM)
    {
        float2 particleDensityCPA = particleDensityAP + particleDensityCP;
        
        float3 Tr = particleDensityCPA.x * _ExtinctionR;
        float3 Tm = particleDensityCPA.y * _ExtinctionM;
        
        float3 extinction = exp( - (Tr + Tm));
        
        localInscatterR = densityAtP.x * extinction;
        localInscatterM = densityAtP.y * extinction;
    }
    
    float3 IntegrateInscattering(float3 rayStart, float3 rayDir, float rayLength, float3 planetCenter, float distanceScale, float3 lightDir, float sampleCount, out float3 extinction)
    {
        float3 step = rayDir * (rayLength / sampleCount);
        float stepSize = length(step) * distanceScale;
        
        float2 particleDensityAP = 0;
        float3 scatterR = 0;
        float3 scatterM = 0;
        
        float2 densityAtP;
        float2 particleDensityCP;
        
        float2 prevDensityAtP;
        float3 prevLocalInscatterR, prevLocalInscatterM;
        GetAtmosphereDensity(rayStart, planetCenter, lightDir, prevDensityAtP, particleDensityCP);
        ComputeLocalInscattering(prevDensityAtP, particleDensityCP, particleDensityAP, prevLocalInscatterR, prevLocalInscatterM);
        
        //TODO loop vs Unroll?
        [loop]
        for (float s = 1.0; s < sampleCount; s += 1)
        {
            float3 p = rayStart + step * s;
            
            GetAtmosphereDensity(p, planetCenter, lightDir, densityAtP, particleDensityCP);
            particleDensityAP += (densityAtP + prevDensityAtP) * (stepSize / 2.0);
            
            prevDensityAtP = densityAtP;
            
            float3 localInscatterR, localInscatterM;
            ComputeLocalInscattering(densityAtP, particleDensityCP, particleDensityAP, localInscatterR, localInscatterM);
            
            scatterR += (localInscatterR + prevLocalInscatterR) * (stepSize / 2.0);
            scatterM += (localInscatterM + prevLocalInscatterM) * (stepSize / 2.0);
            
            prevLocalInscatterR = localInscatterR;
            prevLocalInscatterM = localInscatterM;
        }
        
        float3 m = scatterM;
        float cosAngle = dot(rayDir, lightDir.xyz);
        
        ApplyPhaseFunction(scatterR, scatterM, cosAngle);
        
        float3 lightInscatter = (scatterR * _ScatteringR + scatterM * _ScatteringM) * _LightFromOuterSpace.xyz;
        #if defined(_RENDERSUN)
            lightInscatter += RenderSun(m, cosAngle) * _SunIntensity;
        #endif
        
        // Extinction
        extinction = exp( - (particleDensityAP.x * _ExtinctionR + particleDensityAP.y * _ExtinctionM));
        
        return lightInscatter.xyz;
    }
    
#endif