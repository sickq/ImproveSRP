using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace DistantLands.Cozy
{
    public class CozySystem : MonoBehaviour
    {
        [Range(0, 1)]
        public float weight = 1;
        [Range(0, 1)]
        public float targetWeight = 1;

        public void OnEnable()
        {
            CozyWeather.instance.SetupSystems();
        }

        public void SkipTime(MeridiemTime time)
        {

        }
    }
}