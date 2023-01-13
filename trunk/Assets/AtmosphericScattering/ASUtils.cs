using UnityEngine;

public static class ASUtils
{
    public static void Dispatch(ComputeShader cs, int kernel, Vector2Int lutSize)
    {
        if (cs == null)
        {
            Debug.LogWarningFormat("Computer shader for precompute scattering lut is empty");
            return;
        }
        
        uint threadNumX, threadNumY, threadNumZ;
        cs.GetKernelThreadGroupSizes(kernel, out threadNumX, out threadNumY, out threadNumZ);
        cs.Dispatch(kernel, lutSize.x / (int) threadNumX,
            lutSize.y / (int) threadNumY, 1);
    }
}

public enum ASProfilerType
{
    Precompute,
}

public static class ASShaderPropertyIDs
{
    public static readonly int _IntergalCPDensityLUT = Shader.PropertyToID("_IntegralCPDensityLUT");
    public static readonly int kDensityScaleHeight = Shader.PropertyToID("_DensityScaleHeight");
    public static readonly int kPlanetRadius = Shader.PropertyToID("_PlanetRadius");
    public static readonly int kAtmosphereHeight = Shader.PropertyToID("_AtmosphereHeight");
    public static readonly int kSurfaceHeight = Shader.PropertyToID("_SurfaceHeight");
    public static readonly int kDistanceScale = Shader.PropertyToID("_DistanceScale");
    
    public static readonly int kIncomingLight = Shader.PropertyToID("_LightFromOuterSpace");
    public static readonly int kSunIntensity = Shader.PropertyToID("_SunIntensity");
    public static readonly int kSunMieG = Shader.PropertyToID("_SunMieG");
    public static readonly int kMieG = Shader.PropertyToID("_MieG");

}