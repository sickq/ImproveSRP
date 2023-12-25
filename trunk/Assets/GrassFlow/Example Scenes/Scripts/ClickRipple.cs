﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace GrassFlow.Examples {
    public class ClickRipple : MonoBehaviour {

        public bool ripple = true;
        public float rippleRate = 0.1f;
        public float contactOffset = 1f;
        public Collider grassCol;
        public float ripStrength;
        public float ripDecayRate;
        public float ripSpeed;
        public float ripRadius;
        public float physicsPushDist = 5f;

        float timer = 0;

        Collider[] colliders = new Collider[5];

        Ray ray;
        RaycastHit hit;

        private void Update() {
            if (Input.GetMouseButton(0) && !Input.GetMouseButton(1) && Time.time - rippleRate > timer) {

                timer = Time.time;
                ray = Camera.main.ScreenPointToRay(Input.mousePosition);

                if (grassCol.Raycast(ray, out hit, 9999f)) {
                    if (ripple) {
                        GrassFlowRenderer.AddRipple(hit.point + hit.normal * contactOffset, ripStrength, ripDecayRate, ripSpeed, ripRadius);
                    }


                    int cols = Physics.OverlapSphereNonAlloc(hit.point, physicsPushDist, colliders);
                    if (cols > 0) {
                        for (int i = 0; i < cols; i++) {
                            Rigidbody rb = colliders[i].attachedRigidbody;
                            if (rb) {
                                rb.AddExplosionForce(ripStrength * 2f, hit.point, physicsPushDist, 0.1f, ForceMode.Impulse);
                            }
                        }
                    }
                }
            }
        }



    }
}