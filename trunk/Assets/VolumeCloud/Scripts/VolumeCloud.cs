using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing/VolumeCloud", typeof(UniversalRenderPipeline))]
    public sealed class VolumeCloud : VolumeComponent, IPostProcessComponent
    {
        [Header("VolumeCloud")]
        public TextureParameter BaseTex = new TextureParameter(null);
        
        public TextureParameter LowFrequencyNoiseTex = new TextureParameter(null);
        public TextureParameter HighFrequencyNoiseTex = new TextureParameter(null);
        public TextureParameter SampleNoiseTex = new TextureParameter(null);
        public TextureParameter DensityHeightTex = new TextureParameter(null);
        public TextureParameter WeatherTex = new TextureParameter(null);
        
        public ClampedFloatParameter Absorption = new ClampedFloatParameter(1f, 0f, 1f);
        public ClampedFloatParameter LightAbsorption = new ClampedFloatParameter(1f, 0f, 1f);
        public ClampedFloatParameter _G = new ClampedFloatParameter(0.65f, 0f, 1f);
        public ClampedFloatParameter _BeerPower = new ClampedFloatParameter(0.65f, 0f, 1f);
        public FloatParameter UVScale = new FloatParameter(0.025f);
        public FloatParameter Wind_X_Speed = new FloatParameter(0.004f);
        public FloatParameter Wind_Y_Speed = new FloatParameter(0.004f);
        
        public bool IsActive() => true;

        public bool IsTileCompatible() => false;
    }

}

