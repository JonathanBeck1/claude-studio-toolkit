set -euo pipefail
cp -R "$(dirname "$0")/../../fixture/." .
cat > src/scene/scenes/home/HomeScene.ts <<'EOF'
import * as THREE from 'three';
import { BaseScene } from 'ether/core';
import type { QualityProfile } from 'ether/quality';
import { createHeroComposer } from 'ether/postfx';
import { ScrollBridge, createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';
import { CAMERA_Z_END, CAMERA_Z_START, COLOR_RIM_A, COLOR_RIM_B, LENIS_DURATION } from '../../constants';
import vertexShader from '../../../shaders/hero/sculpture.vert.glsl?raw';
import fragmentShader from '../../../shaders/hero/sculpture.frag.glsl?raw';

export class HomeScene extends BaseScene {
  private scroll: ScrollBridge | null = null;
  private cameraTrigger: ScrollProgressTrigger | null = null;
  private cameraTarget = 0;
  private material: THREE.ShaderMaterial;
  private geometry = new THREE.IcosahedronGeometry(1, 64);
  private noise: THREE.Texture | null = null;
  private pointer = new THREE.Vector2();

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
        uNoise: { value: null },
        uPointer: { value: this.pointer },
        uColorRimA: { value: COLOR_RIM_A },
        uColorRimB: { value: COLOR_RIM_B },
        uFresnelExp: { value: 5 },
      },
    }));
    this.scene.add(new THREE.Mesh(this.geometry, this.material));
    window.addEventListener('pointermove', this.onPointerMove);
  }

  override async preload(): Promise<void> {
    this.noise = await new THREE.TextureLoader().loadAsync('/textures/noise.webp');
    this.material.uniforms.uNoise.value = this.noise;
  }

  private onPointerMove = (e: PointerEvent): void => {
    this.pointer.set((e.clientX / innerWidth) * 2 - 1, -(e.clientY / innerHeight) * 2 + 1);
  };

  async enterTransition(): Promise<void> {
    this.scroll = this.quality.enableSmoothScroll
      ? new ScrollBridge({ duration: LENIS_DURATION, smoothWheel: true, syncTouch: true })
      : null;
    this.cameraTrigger = createScrollProgress((p) => {
      this.cameraTarget = p;
    }, { end: 'bottom bottom' });
  }

  tick(time: number, deltaTime: number): void {
    this.scroll?.raf(time);
    const z = THREE.MathUtils.lerp(CAMERA_Z_START, CAMERA_Z_END, this.cameraTarget);
    this.camera.position.z += (z - this.camera.position.z) * (1 - Math.exp(-6 * deltaTime));
    this.material.uniforms.uTime.value = time;
  }

  async exitTransition(): Promise<void> {
    this.cameraTrigger?.kill();
    this.cameraTrigger = null;
    this.scroll?.destroy();
    this.scroll = null;
  }

  override dispose(): void {
    this.cameraTrigger?.kill();
    this.scroll?.destroy();
  }
}
EOF
