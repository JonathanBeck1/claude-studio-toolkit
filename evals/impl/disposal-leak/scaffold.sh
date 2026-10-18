set -euo pipefail
cp -R "$(dirname "$0")/../../fixture/." .
cat >> src/scene/constants.ts <<'EOF'

export const INTRO_DURATION = 2.0;
export const EXIT_FADE_DURATION = 0.6;
EOF
cat > src/scene/scenes/home/HomeScene.ts <<'EOF'
import * as THREE from 'three';
import gsap from 'gsap';
import { BaseScene } from 'ether/core';
import type { QualityProfile } from 'ether/quality';
import { createHeroComposer } from 'ether/postfx';
import { ScrollBridge, createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';
import {
  CAMERA_Z_END, CAMERA_Z_START, COLOR_RIM_A, COLOR_RIM_B,
  EXIT_FADE_DURATION, INTRO_DURATION, LENIS_DURATION,
} from '../../constants';
import vertexShader from '../../../shaders/hero/sculpture.vert.glsl?raw';
import fragmentShader from '../../../shaders/hero/sculpture.frag.glsl?raw';

export class HomeScene extends BaseScene {
  private scroll: ScrollBridge | null = null;
  private cameraTrigger: ScrollProgressTrigger | null = null;
  private cameraTarget = 0;
  private reveal = { value: 0 };
  private material: THREE.ShaderMaterial;
  private geometry = new THREE.IcosahedronGeometry(1, 64);

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
        uReveal: { value: 0 },
        uNoise: { value: null },
        uColorRimA: { value: COLOR_RIM_A },
        uColorRimB: { value: COLOR_RIM_B },
        uFresnelExp: { value: 5 },
      },
    }));
    this.scene.add(new THREE.Mesh(this.geometry, this.material));
  }

  override async preload(): Promise<void> {
    this.material.uniforms.uNoise.value = this.track(
      await new THREE.TextureLoader().loadAsync('/textures/noise.webp'),
    );
  }

  async enterTransition(): Promise<void> {
    this.scroll = this.quality.enableSmoothScroll
      ? new ScrollBridge({ duration: LENIS_DURATION, smoothWheel: true, syncTouch: true })
      : null;
    const pump = (now: number): void => {
      this.scroll?.lenis.raf(now);
      requestAnimationFrame(pump);
    };
    requestAnimationFrame(pump);

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      this.reveal.value = 1;
    } else {
      await new Promise<void>((resolve) => {
        gsap.to(this.reveal, { value: 1, duration: INTRO_DURATION, ease: 'expo.out', onComplete: resolve });
      });
    }
    // Triggers measure the settled page, so they wait for the intro.
    this.setupScrollTrigger();
  }

  private setupScrollTrigger(): void {
    this.cameraTrigger = createScrollProgress((p) => {
      this.cameraTarget = p;
    }, { end: 'bottom bottom' });
  }

  private killTriggers(): void {
    this.cameraTrigger?.kill();
    this.cameraTrigger = null;
  }

  tick(time: number, deltaTime: number): void {
    const z = THREE.MathUtils.lerp(CAMERA_Z_START, CAMERA_Z_END, this.cameraTarget);
    this.camera.position.z += (z - this.camera.position.z) * (1 - Math.exp(-6 * deltaTime));
    this.material.uniforms.uTime.value = time;
    this.material.uniforms.uReveal.value = this.reveal.value;
  }

  async exitTransition(): Promise<void> {
    this.killTriggers();
    this.scroll?.destroy();
    this.scroll = null;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    await new Promise<void>((resolve) => {
      gsap.to(this.reveal, { value: 0, duration: EXIT_FADE_DURATION, ease: 'power2.out', onComplete: resolve });
    });
  }

  override dispose(): void {
    this.killTriggers();
    this.scroll?.destroy();
    this.scroll = null;
  }
}
EOF
