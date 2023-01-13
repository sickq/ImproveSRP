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
        private RenderTargetHandle integrateCPDensityLUT;
        private RenderTargetHandle RWintergalCPDensityLUT;

        private AtmosphericScatteringData asConfig;
        public ASPrecomputePass(AtmosphericScatteringData config)
        {
            asConfig = config;
            integrateCPDensityLUT.Init("_IntegralCPDensityLUT");
            RWintergalCPDensityLUT.Init("_RWintegralCPDensityLUT");
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

                var desc = new RenderTextureDescriptor(1024, 1024, RenderTextureFormat.RGFloat, 0);
                desc.vrUsage = VRTextureUsage.None; // We only need one for both eyes in VR
                desc.sRGB = false;
                desc.useMipMap = false;
                desc.enableRandomWrite = true;
                
                
                cmd.GetTemporaryRT(RWintergalCPDensityLUT.id, desc, FilterMode.Bilinear);
                int index = asConfig.computerShader_IntegrateCPDensity.FindKernel("CSIntergalCPDensity");
                uint threadNumX, threadNumY, threadNumZ;
                asConfig.computerShader_IntegrateCPDensity.GetKernelThreadGroupSizes(index, out threadNumX, out threadNumY, out threadNumZ);
                ASUtils.Dispatch(asConfig.computerShader_IntegrateCPDensity, index, asConfig.integrateCPDensityLUTSize);
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
        }
        
    }


}


