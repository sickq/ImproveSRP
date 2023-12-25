// Distant Lands 2022.



using System.Collections.Generic;
using UnityEngine;
using System.Collections;
#if UNITY_EDITOR
using UnityEditor;
#endif



namespace DistantLands.Cozy.Data
{
    [System.Serializable]
    [CreateAssetMenu(menuName = "Distant Lands/Cozy/FX/Precipitation FX", order = 361)]
    public class PrecipitationFX : FXProfile
    {



        [Range(0, 0.05f)]
        public float rainAmount;
        [Range(0, 0.05f)]
        public float snowAmount;
        public float weight;
        CozyWeather weather;
        CozyClimateModule climateModule;

        public override void PlayEffect(float i)
        {
            if (!weather)
                if (InitializeEffect(null) == false)
                    return;

            climateModule.snowSpeed += snowAmount * Mathf.Clamp01(transitionTimeModifier.Evaluate(i));
            climateModule.rainSpeed += rainAmount * Mathf.Clamp01(transitionTimeModifier.Evaluate(i));
            
        }

        public override bool InitializeEffect(CozyWeather weather)
        {

            weatherSphere = weather ? weather : CozyWeather.instance;

            if (!weatherSphere.climateModule)
                return false;

            climateModule = weatherSphere.climateModule;

            return true;

        }

    }

#if UNITY_EDITOR
    [CustomEditor(typeof(PrecipitationFX))]
    [CanEditMultipleObjects]
    public class E_PrecipitationFX : E_FXProfile
    {


        void OnEnable()
        {

        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.PropertyField(serializedObject.FindProperty("rainAmount"));
            EditorGUILayout.PropertyField(serializedObject.FindProperty("snowAmount"));
            EditorGUILayout.Space();
            EditorGUILayout.PropertyField(serializedObject.FindProperty("transitionTimeModifier"));

            serializedObject.ApplyModifiedProperties();

        }

        public override void RenderInWindow(Rect pos)
        {

            float space = EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;
            var propPosA = new Rect(pos.x, pos.y + space, pos.width, EditorGUIUtility.singleLineHeight);
            var propPosB = new Rect(pos.x, pos.y + space * 2, pos.width, EditorGUIUtility.singleLineHeight);
            var propPosC = new Rect(pos.x, pos.y + space * 3, pos.width, EditorGUIUtility.singleLineHeight);

            serializedObject.Update();

            EditorGUI.PropertyField(propPosA, serializedObject.FindProperty("rainAmount"));
            EditorGUI.PropertyField(propPosB, serializedObject.FindProperty("snowAmount"));
            EditorGUI.PropertyField(propPosC, serializedObject.FindProperty("transitionTimeModifier"));

            serializedObject.ApplyModifiedProperties();
        }

        public override float GetLineHeight()
        {

            return 3;

        }

    }
#endif
}