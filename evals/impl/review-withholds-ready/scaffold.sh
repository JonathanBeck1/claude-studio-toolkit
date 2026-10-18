set -euo pipefail
cp -R "$(dirname "$0")/../../fixture/." .
cat > src/scene/constants.ts <<'TS'
import * as THREE from 'three';

export const COLOR_BG = new THREE.Color(0x101418);
export const COLOR_RIM_A = new THREE.Color(0x8b5cf6);
export const COLOR_RIM_B = new THREE.Color(0x2dd4bf);

export const LENIS_DURATION = 1.2;
export const CAMERA_Z_START = 4;
export const CAMERA_Z_END = 8;
// Exponential ease rate per second; higher catches up to the scroll position faster.
export const CAMERA_DAMPING = 6;
// Icosahedron subdivision level, dense enough for the vertex displacement to read as a swell.
export const HERO_DETAIL = 64;
// Vertex displacement amplitude in world units on the unit-radius form.
export const HERO_DISPLACEMENT = 0.08;
TS
cat > src/shaders/hero/sculpture.vert.glsl <<'GLSL'
uniform float uTime;
uniform float uDisplacement;

varying vec3 vNormal;
varying vec3 vViewDir;

// Spatial frequency of the swells over the unit-radius form.
const float NOISE_FREQ = 2.0;
// Unequal per-axis drift rates so the surface never visibly loops.
const vec3 DRIFT = vec3(0.4, 0.3, 0.5);

// Sin-product noise: much cheaper per vertex than curl noise, with a similar breathing read.
float cheapNoise(vec3 p) {
  return sin(p.x + uTime * DRIFT.x) * sin(p.y - uTime * DRIFT.y) * sin(p.z + uTime * DRIFT.z);
}

void main() {
  vec3 displaced = position + normal * cheapNoise(position * NOISE_FREQ) * uDisplacement;
  vNormal = normalMatrix * normal;
  vec4 mv = modelViewMatrix * vec4(displaced, 1.0);
  vViewDir = -mv.xyz;
  gl_Position = projectionMatrix * mv;
}
GLSL
perl -0pi -e 's|(  vec3 rim = )|  // Rim hue by surface orientation; the smoothstep band over N.y sets how gradually rim A turns into rim B.\n$1|' src/shaders/hero/sculpture.frag.glsl
cat > src/scene/scenes/home/HomeScene.ts <<'TS'
import * as THREE from 'three';
import { BaseScene } from 'ether/core';
import type { QualityProfile } from 'ether/quality';
import { createHeroComposer } from 'ether/postfx';
import { ScrollBridge, createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';
import {
  CAMERA_DAMPING, CAMERA_Z_END, CAMERA_Z_START, COLOR_RIM_A, COLOR_RIM_B,
  HERO_DETAIL, HERO_DISPLACEMENT, LENIS_DURATION,
} from '../../constants';
import vertexShader from '../../../shaders/hero/sculpture.vert.glsl?raw';
import fragmentShader from '../../../shaders/hero/sculpture.frag.glsl?raw';

export class HomeScene extends BaseScene {
  private scroll: ScrollBridge | null = null;
  private cameraTrigger: ScrollProgressTrigger | null = null;
  private cameraTarget = 0;
  private cameraProgress = 0;
  private material: THREE.ShaderMaterial;

  constructor(renderer: THREE.WebGLRenderer, private quality: QualityProfile) {
    super();
    this.composer = createHeroComposer(renderer, this.scene, this.camera, {
      enableDither: quality.enableDither,
      multisampling: quality.msaaSamples,
    }).composer;
    this.material = this.track(new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms: {
        uTime: { value: 0 },
        uDisplacement: { value: HERO_DISPLACEMENT },
        uColorRimA: { value: COLOR_RIM_A },
        uColorRimB: { value: COLOR_RIM_B },
        uFresnelExp: { value: 5 },
      },
    }));
    const geometry = this.track(new THREE.IcosahedronGeometry(1, HERO_DETAIL));
    this.scene.add(new THREE.Mesh(geometry, this.material));
    this.camera.position.z = CAMERA_Z_START;
  }

  async enterTransition(): Promise<void> {
    // Reduced motion keeps native scroll and a fixed camera.
    if (this.quality.reducedMotion) return;
    this.scroll = this.quality.enableSmoothScroll
      ? new ScrollBridge({ duration: LENIS_DURATION, smoothWheel: true, syncTouch: true })
      : null;
    this.setupScrollTrigger();
  }

  tick(time: number, deltaTime: number): void {
    this.scroll?.raf(time);
    this.cameraProgress += (this.cameraTarget - this.cameraProgress) * (1 - Math.exp(-CAMERA_DAMPING * deltaTime));
    this.camera.position.z = THREE.MathUtils.lerp(CAMERA_Z_START, CAMERA_Z_END, this.cameraProgress);
    // Reduced motion freezes the surface rather than slowing it.
    if (!this.quality.reducedMotion) this.material.uniforms.uTime.value = time;
  }

  async exitTransition(): Promise<void> {
    this.killTriggers();
  }

  override dispose(): void {
    this.killTriggers();
    super.dispose();
  }

  private setupScrollTrigger(): void {
    this.cameraTrigger = createScrollProgress((p) => {
      this.cameraTarget = p;
    }, { end: 'bottom bottom' });
  }

  private killTriggers(): void {
    this.cameraTrigger?.kill();
    this.cameraTrigger = null;
    this.scroll?.destroy();
    this.scroll = null;
  }
}
TS
git init -q -b main
git add -A
git -c user.name=Studio -c user.email=studio@example.invalid commit -qm "Add the hero scene"
cat >> src/scene/constants.ts <<'TS'
// Rim sharpness; higher confines the rim to more grazing angles.
export const RIM_FRESNEL_EXP = 4;
TS
perl -0pi -e 's/LENIS_DURATION,\n\}/LENIS_DURATION, RIM_FRESNEL_EXP,\n}/; s/uFresnelExp: \{ value: 5 \}/uFresnelExp: { value: RIM_FRESNEL_EXP }/' src/scene/scenes/home/HomeScene.ts
perl -0pi -e 's/smoothstep\(-0\.3, 0\.6, N\.y\)/smoothstep(-0.5, 0.8, N.y)/' src/shaders/hero/sculpture.frag.glsl
