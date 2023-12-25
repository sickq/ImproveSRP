using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace DistantLands.Cozy
{
    [ExecuteAlways]
    public class CozyReportsModule : CozyModule
    {


    }

#if UNITY_EDITOR
    [CustomEditor(typeof(CozyReportsModule))]
    public class E_CozyReports : E_CozyModule
    {

        CozyReportsModule t;

        void OnEnable()
        {

            t = (CozyReportsModule)target;

        }

        public override GUIContent GetGUIContent()
        {

            return new GUIContent("    Reports", (Texture)Resources.Load("Reports"), "Passes information on the current weather system to the editor.");

        }

        public override void OnInspectorGUI()
        {


            DisplayInCozyWindow();

        }
        
        public override void OpenDocumentationURL()
        {
            Application.OpenURL("https://distant-lands.gitbook.io/cozy-stylized-weather-documentation/how-it-works/modules/reports-module");
        }

        public override void DisplayInCozyWindow()
        {
            foreach (E_CozyModule module in E_CozyWeather.editors)
            {
                module.GetReportsInformation();
            }
        }

    }
#endif
}
