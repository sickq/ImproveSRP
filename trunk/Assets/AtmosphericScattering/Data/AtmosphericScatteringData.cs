using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "AtmosphericScatteringAsset", menuName = "大气配置/AtmosphericScatteringAsset")]
public class AtmosphericScatteringData : ScriptableObject
{
    public enum RenderMode
    {
        Reference,
        Optimized
    }
    
    public float distanceScale = 1.0f;
        
    public Vector3 rCoef = new Vector3(5.8f, 13.5f, 33.1f);
    public float rScatterStrength = 1f;
    public float rExtinctionStrength = 1f;

    public Vector3 mCoef = new Vector3(2.0f, 2.0f, 2.0f);
    public float mScatterStrength = 1f;
    public float mExtinctionStrength = 1f;
    public float mieG = 0.625f;
    
    public bool lightShaft = true;
    
    
    [ColorUsage(false, true)]
    public Color lightFromOuterSpace = new Color(4, 4, 4, 4);

    public float planetRadius = 6371000.0f;
    public float atmosphereHeight = 80000.0f;
    public float surfaceHeight;

    [Header("Particles")]
    public float rDensityScale = 7994.0f;

    public float mDensityScale = 1200;

    [Header("Sun Disk")]
    public float sunIntensity = 0.75f;

    [Range(-1, 1)]
    public float sunMieG = 0.98f;

    [Header("Precomputation")]
    public ComputeShader computerShader_Sun;
    public ComputeShader computerShader_Ambient;
    public ComputeShader computerShader_InScattering;
    public ComputeShader computerShader_IntegrateCPDensity;

    public Vector2Int integrateCPDensityLUTSize = new Vector2Int(512, 512);
    public Vector2Int sunOnSurfaceLUTSize = new Vector2Int(512, 512);
    public int ambientLUTSize = 512;
    public Vector2Int inScatteringLUTSize = new Vector2Int(1024, 1024);
    
}
