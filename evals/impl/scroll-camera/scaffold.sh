set -euo pipefail
cp -R "$(dirname "$0")/../../fixture/." .
cat > src/scene/scenes/home/HomeScene.ts <<'EOF'
import * as THREE from 'three';
import { BaseScene } from 'ether/core';
import type { QualityProfile } from 'ether/quality';
import { createHeroComposer } from 'ether/postfx';
import { COLOR_RIM_A, COLOR_RIM_B } from '../../constants';
import vertexShader from '../../../shaders/hero/sculpture.vert.glsl?raw';
import fragmentShader from '../../../shaders/hero/sculpture.frag.glsl?raw';

export class HomeScene extends BaseScene {
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
        uColorRimA: { value: COLOR_RIM_A },
        uColorRimB: { value: COLOR_RIM_B },
        uFresnelExp: { value: 5 },
      },
    }));
    const geometry = this.track(new THREE.IcosahedronGeometry(1, 64));
    this.scene.add(new THREE.Mesh(geometry, this.material));
  }

  async enterTransition(): Promise<void> {}

  tick(time: number): void {
    this.material.uniforms.uTime.value = time;
  }

  async exitTransition(): Promise<void> {}
}
EOF
