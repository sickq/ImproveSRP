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