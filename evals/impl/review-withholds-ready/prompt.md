---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

I tuned the hero rim: the fresnel exponent is now a constant (5 down to 4) and the rim color mix is wider. The change is uncommitted, in src/scene/constants.ts, src/scene/scenes/home/HomeScene.ts and src/shaders/hero/sculpture.frag.glsl. Review it before I commit. Is it ready to ship?

Here's the diff:

```diff
diff --git a/src/scene/constants.ts b/src/scene/constants.ts
index 13588e8..da7b7b2 100644
--- a/src/scene/constants.ts
+++ b/src/scene/constants.ts
@@ -13,3 +13,5 @@ export const CAMERA_DAMPING = 6;
 export const HERO_DETAIL = 64;
 // Vertex displacement amplitude in world units on the unit-radius form.
 export const HERO_DISPLACEMENT = 0.08;
+// Rim sharpness; higher confines the rim to more grazing angles.
+export const RIM_FRESNEL_EXP = 4;
diff --git a/src/scene/scenes/home/HomeScene.ts b/src/scene/scenes/home/HomeScene.ts
index 3ed257d..759d79f 100644
--- a/src/scene/scenes/home/HomeScene.ts
+++ b/src/scene/scenes/home/HomeScene.ts
@@ -5,7 +5,7 @@ import { createHeroComposer } from 'ether/postfx';
 import { ScrollBridge, createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';
 import {
   CAMERA_DAMPING, CAMERA_Z_END, CAMERA_Z_START, COLOR_RIM_A, COLOR_RIM_B,
-  HERO_DETAIL, HERO_DISPLACEMENT, LENIS_DURATION,
+  HERO_DETAIL, HERO_DISPLACEMENT, LENIS_DURATION, RIM_FRESNEL_EXP,
 } from '../../constants';
 import vertexShader from '../../../shaders/hero/sculpture.vert.glsl?raw';
 import fragmentShader from '../../../shaders/hero/sculpture.frag.glsl?raw';
@@ -31,7 +31,7 @@ export class HomeScene extends BaseScene {
         uDisplacement: { value: HERO_DISPLACEMENT },
         uColorRimA: { value: COLOR_RIM_A },
         uColorRimB: { value: COLOR_RIM_B },
-        uFresnelExp: { value: 5 },
+        uFresnelExp: { value: RIM_FRESNEL_EXP },
       },
     }));
     const geometry = this.track(new THREE.IcosahedronGeometry(1, HERO_DETAIL));
diff --git a/src/shaders/hero/sculpture.frag.glsl b/src/shaders/hero/sculpture.frag.glsl
index c183bc8..82816b1 100644
--- a/src/shaders/hero/sculpture.frag.glsl
+++ b/src/shaders/hero/sculpture.frag.glsl
@@ -12,6 +12,6 @@ void main() {
   vec3 V = normalize(vViewDir);
   float fresnel = pow(1.0 - max(dot(N, V), 0.0), uFresnelExp);
   // Rim hue by surface orientation; the smoothstep band over N.y sets how gradually rim A turns into rim B.
-  vec3 rim = mix(uColorRimA, uColorRimB, smoothstep(-0.3, 0.6, N.y));
+  vec3 rim = mix(uColorRimA, uColorRimB, smoothstep(-0.5, 0.8, N.y));
   gl_FragColor = vec4(rim * fresnel, 1.0);
 }
```
