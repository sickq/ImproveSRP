#ifndef _PRECOMPUTATION_INCLUDE
    #define _PRECOMPUTATION_INCLUDE
    
    #include "ASInclude.hlsl"

    float3 Transmittance(float cosAngle01, float height01)
    {
        float2 particleDensityCP = _IntegralCPDensityLUT.SampleLevel(_trilinearClampSampler, float2(cosAngle01, height01), 0.0).xy;
        float3 TrCP = particleDensityCP.x * _ExtinctionR;
        float3 TmCP = particleDensityCP.y * _ExtinctionM;
        return exp(-TrCP - TmCP);
    }

#endif