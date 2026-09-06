import * as THREE from 'three';
import { BaseScene } from 'ether/core';
import type { QualityProfile } from 'ether/quality';
import { createHeroComposer } from 'ether/postfx';
import { ScrollBridge, createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';
import { COLOR_RIM_A, COLOR_RIM_B, LENIS_DURATION } from '../../constants';
import vertexShader from '../../../shaders/hero/sculpture.vert.glsl?raw';
import fragmentShader from '../../../shaders/hero/sculpture.frag.glsl?raw';

export class HomeScene extends BaseScene {
  private scroll: ScrollBridge | null = null;
  private cameraTrigger: ScrollProgressTrigger | null = null;
  private material: THREE.ShaderMaterial;

  constructor(renderer: THREE.WebGLRenderer, quality: QualityProfile) {
    super();
    this.composer = createHeroComposer(renderer, this.scene, this.camera, {
      enableDither: quality.enableDither,
      multisampling: quality.msaaSamples,
    }).composer;
    this.material = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms: {
        uTime: { value: 0 },
        uColorRimA: { value: COLOR_RIM_A },
        uColorRimB: { value: COLOR_RIM_B },
        uFresnelExp: { value: 5 },
      },
    });
  }

  async enterTransition(): Promise<void> {
    this.scroll = new ScrollBridge({ duration: LENIS_DURATION, smoothWheel: true, syncTouch: true });
    this.cameraTrigger = createScrollProgress((p) => {
      this.camera.position.z = 4 + p * 4;
    }, { end: 'bottom bottom', scrub: 0.8 });
  }

  tick(time: number): void {
    this.scroll?.raf(time);
    this.material.uniforms.uTime.value = time;
  }

  async exitTransition(): Promise<void> {}

  dispose(): void {
    this.cameraTrigger?.kill();
    this.scroll?.destroy();
    this.material.dispose();
  }
}
