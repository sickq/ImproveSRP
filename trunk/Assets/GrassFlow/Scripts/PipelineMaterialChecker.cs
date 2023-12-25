
#if UNITY_EDITOR

using System;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

using static GrassFlow.ShaderVariantHelper;
using UnityEngine.SceneManagement;

namespace GrassFlow {

    [ExecuteInEditMode]
    public class PipelineMaterialChecker : MonoBehaviour {

        static RenderPipelineAsset GetRenderPipelineAsset() {
#if UNITY_2019_3_OR_NEWER
            return GraphicsSettings.currentRenderPipeline;
#else
            return GraphicsSettings.renderPipelineAsset;
#endif
        }

        public static bool CheckURP() {
            if (GetRenderPipelineAsset()) {
                if (GetRenderPipelineAsset().GetType().ToString().Contains("Universal")) {
                    return true;
                }
            }
            return false;
        }


        private void Start() {

            //make sure we don't run this on non example scenes just in case someone mistakenly copies it into their project
            if (!SceneManager.GetActiveScene().path.Contains("GrassFlow/Example Scenes/")) {
                Debug.Log("GrassFlow Material Helper exists in your scene, this script is not required or useful outside of the example scenes.");
                return;
            }


            int pipeIdx = 0;
            string shader = "Standard";

            bool urp = CheckURP();

            if (urp) {
                pipeIdx = 1;
                shader = "Universal Render Pipeline/Simple Lit";
            }

            void FixMat(Material mat) {
                if (mat && mat.shader.name != shader && urp) {
                    var mainTex = mat.GetTexture("_MainTex");
                    var mainScale = mat.GetTextureScale("_MainTex");
                    var mainOffset = mat.GetTextureOffset("_MainTex");
                    var mainCol = mat.GetColor("_Color");
                    mat.shader = Shader.Find(shader);
                    mat.SetTexture("_BaseMap", mainTex);
                    mat.SetTextureScale("_BaseMap", mainScale);
                    mat.SetTextureOffset("_BaseMap", mainOffset);
                    mat.SetColor("_BaseColor", mainCol);
                }
            }

            Renderer[] rends = FindObjectsOfType<MeshRenderer>();
            foreach (var rend in rends) {
                foreach (var mat in rend.sharedMaterials) {
                    FixMat(mat);
                }
            }

            rends = FindObjectsOfType<SkinnedMeshRenderer>();
            foreach (var rend in rends) {
                foreach (var mat in rend.sharedMaterials) {
                    FixMat(mat);
                }
            }

            var grasses = FindObjectsOfType<GrassFlowRenderer>();
            foreach (var gf in grasses) {
                foreach (var gMesh in gf.terrainMeshes) {

                    if (gMesh.renderType == GrassFlowRenderer.GrassRenderType.Terrain) {
                        Material mat = gMesh.terrainObject.materialTemplate;
                        Texture tex = mat.GetTexture("_Detail");
                        FixMat(mat);
                        mat.mainTexture = tex;
                    }

                    foreach (var lod in gMesh.customMeshLods) {
                        var grassMat = lod.lodMat;
                        if (grassMat && grassMat.GetInt(pipeTypeID) != pipeIdx) {
                            grassMat.SetInt(pipeTypeID, pipeIdx);
                            ShaderVariantHelper.HandleVariantGuiAndCompilation(gf, grassMat, 0, true, false);
                        }
                    }
                }
            }
        }



    }
}

#endif