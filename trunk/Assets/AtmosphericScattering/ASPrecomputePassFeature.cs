using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ASPrecomputePassFeature : ScriptableRendererFeature
{
    private ASPrecomputePass m_ScriptablePass;
    public AtmosphericScatteringData config;
    public RenderPassEvent Event = RenderPassEvent.BeforeRendering;
    
    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new ASPrecomputePass(config);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = Event;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    
    private class ASPrecomputePass : ScriptableRenderPass
    {
        private Texture2D m_HemiSphereRandomNormlizedVecLUT;
        
        private RenderTargetHandle integrateCPDensityLUT;
        private RenderTargetHandle RWIntergalCPDensityLUT;
        private RenderTargetHandle RWSunOnSurfaceLUT;
        private RenderTargetHandle RWInScatteringLUT;
        private RenderTargetHandle RWAmbientLUT;

        private AtmosphericScatteringData asConfig;
        public ASPrecomputePass(AtmosphericScatteringData config)
        {
            asConfig = config;
            integrateCPDensityLUT.Init("_IntegralCPDensityLUT");
            RWIntergalCPDensityLUT.Init("_RWintegralCPDensityLUT");
            
            RWSunOnSurfaceLUT.Init("_RWsunOnSurfaceLUT");
            
            RWInScatteringLUT.Init("_RWinScatteringLUT");
            
            RWAmbientLUT.Init("_RWambientLUT");
            
            if (m_HemiSphereRandomNormlizedVecLUT == null)
            {
                m_HemiSphereRandomNormlizedVecLUT = new Texture2D(512, 1, TextureFormat.RGB24, false, true);
                m_HemiSphereRandomNormlizedVecLUT.filterMode = FilterMode.Point;
                m_HemiSphereRandomNormlizedVecLUT.Apply();
                for (int i = 0; i < m_HemiSphereRandomNormlizedVecLUT.width; ++i)
                {
                    var randomVec = UnityEngine.Random.onUnitSphere;
                    m_HemiSphereRandomNormlizedVecLUT.SetPixel(i, 0, new Color(randomVec.x, Mathf.Abs(randomVec.y), randomVec.z));
                }
            }
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, ProfilingSampler.Get(ASProfilerType.Precompute)))
            {
                SetCommonParams(cmd, asConfig);

                var desc = new RenderTextureDescriptor(asConfig.integrateCPDensityLUTSize.x, asConfig.integrateCPDensityLUTSize.y, RenderTextureFormat.RGFloat, 0);
                desc.vrUsage = VRTextureUsage.None; // We only need one for both eyes in VR
                desc.sRGB = false;
                desc.useMipMap = false;
                desc.enableRandomWrite = true;

                var computerShader = asConfig.computerShader_IntegrateCPDensity;
                cmd.GetTemporaryRT(RWIntergalCPDensityLUT.id, desc, FilterMode.Bilinear);
                int index = computerShader.FindKernel("CSIntergalCPDensity");
                cmd.SetComputeTextureParam(computerShader, index, RWIntergalCPDensityLUT.id, RWIntergalCPDensityLUT.Identifier());
                ASUtils.Dispatch(computerShader, index, asConfig.integrateCPDensityLUTSize);
                cmd.SetGlobalTexture(ASShaderPropertyIDs.IntergalCPDensityLUT, RWIntergalCPDensityLUT.Identifier());

                var sunOnSurfaceDesc = desc;
                sunOnSurfaceDesc.width = asConfig.sunOnSurfaceLUTSize.x;
                sunOnSurfaceDesc.height = asConfig.sunOnSurfaceLUTSize.y;
                sunOnSurfaceDesc.graphicsFormat = GraphicsFormat.R16G16B16A16_UNorm;
                computerShader = asConfig.computerShader_Sun;
                index = computerShader.FindKernel("CSsunOnSurface");
                cmd.GetTemporaryRT(RWSunOnSurfaceLUT.id, sunOnSurfaceDesc, FilterMode.Bilinear);
                cmd.SetComputeTextureParam(computerShader, index, RWSunOnSurfaceLUT.id, RWSunOnSurfaceLUT.Identifier());
                cmd.SetComputeTextureParam(computerShader, index, ASShaderPropertyIDs.IntergalCPDensityLUT, RWIntergalCPDensityLUT.Identifier());
                ASUtils.Dispatch(computerShader, index, asConfig.sunOnSurfaceLUTSize);
                
                var inScatteringLUTDesc = desc;
                inScatteringLUTDesc.width = asConfig.inScatteringLUTSize.x;
                inScatteringLUTDesc.height = asConfig.inScatteringLUTSize.y;
                inScatteringLUTDesc.graphicsFormat = GraphicsFormat.R16G16B16A16_UNorm;
                computerShader = asConfig.computerShader_InScattering;
                index = computerShader.FindKernel("CSInScattering");
                cmd.GetTemporaryRT(RWInScatteringLUT.id, sunOnSurfaceDesc, FilterMode.Bilinear);
                cmd.SetComputeTextureParam(computerShader, index, RWInScatteringLUT.id, RWInScatteringLUT.Identifier());
                cmd.SetComputeTextureParam(computerShader, index, ASShaderPropertyIDs.IntergalCPDensityLUT, RWIntergalCPDensityLUT.Identifier());
                ASUtils.Dispatch(computerShader, index, asConfig.inScatteringLUTSize);
                cmd.SetGlobalTexture(ASShaderPropertyIDs.InScatteringLUT, RWInScatteringLUT.Identifier());
                
                var size = new Vector2Int(asConfig.ambientLUTSize, 1);
                var ambientLUTDesc = desc;
                ambientLUTDesc.width = asConfig.ambientLUTSize;
                ambientLUTDesc.height = 1;
                ambientLUTDesc.graphicsFormat = GraphicsFormat.R16G16B16A16_UNorm;
                computerShader = asConfig.computerShader_Ambient;
                index = computerShader.FindKernel("CSAmbient");
                cmd.GetTemporaryRT(RWAmbientLUT.id, ambientLUTDesc, FilterMode.Bilinear);
                cmd.SetComputeTextureParam(computerShader, index, RWAmbientLUT.id, RWAmbientLUT.Identifier());
                cmd.SetComputeTextureParam(computerShader, index, ASShaderPropertyIDs.HemiSphereRandomNormalizedVecLUT, m_HemiSphereRandomNormlizedVecLUT);
                cmd.SetComputeTextureParam(computerShader, index, ASShaderPropertyIDs.InScatteringLUT, RWInScatteringLUT.Identifier());
                ASUtils.Dispatch(computerShader, index, size);

            }
            context.ExecuteCommandBuffer(cmd);
            
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }

        private void SetCommonParams(CommandBuffer cmd, AtmosphericScatteringData config)
        {
            cmd.SetGlobalVector(ASShaderPropertyIDs.kDensityScaleHeight, new Vector4(config.rDensityScale, config.mDensityScale));
            cmd.SetGlobalFloat(ASShaderPropertyIDs.kPlanetRadius, config.planetRadius);
            cmd.SetGlobalFloat(ASShaderPropertyIDs.kAtmosphereHeight, config.atmosphereHeight);
            cmd.SetGlobalFloat(ASShaderPropertyIDs.kSurfaceHeight, config.surfaceHeight);
            cmd.SetGlobalVector(ASShaderPropertyIDs.kIncomingLight, config.lightFromOuterSpace);
            cmd.SetGlobalFloat(ASShaderPropertyIDs.kSunIntensity, config.sunIntensity);
            cmd.SetGlobalFloat(ASShaderPropertyIDs.kSunMieG, config.sunMieG);
            
            
            
            Shader.SetGlobalFloat(ASShaderPropertyIDs.kDistanceScale, config.distanceScale);
            //地球的数据：
            //private readonly Vector4 _rayleighSct = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f; 
            //private readonly Vector4 _mieSct = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f; 
            var rCoef = config.rCoef * 0.000001f;
            var mCoef = config.mCoef * 0.00001f;
            Shader.SetGlobalVector(ASShaderPropertyIDs.kScatteringR, rCoef * config.rScatterStrength);
            Shader.SetGlobalVector(ASShaderPropertyIDs.kScatteringM, mCoef * config.mScatterStrength);
            Shader.SetGlobalVector(ASShaderPropertyIDs.kExtinctionR, rCoef * config.rExtinctionStrength);
            Shader.SetGlobalVector(ASShaderPropertyIDs.kExtinctionM, mCoef * config.mExtinctionStrength);
            Shader.SetGlobalFloat(ASShaderPropertyIDs.kMieG, config.mieG);

            if (asConfig.lightShaft) Shader.EnableKeyword(ASShaderPropertyIDs.kLightShaft);
            else Shader.DisableKeyword(ASShaderPropertyIDs.kLightShaft);
        }
        
    }


}


