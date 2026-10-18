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

  constructor(renderer: THREE.WebGLRenderer, quality: QualityProfile) {
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
git init -q -b main
git add -A
git -c user.name=Studio -c user.email=studio@example.invalid commit -qm "Add the hero scene"
cat > src/scene/constants.ts <<'EOF'
import * as THREE from 'three';

export const COLOR_BG = new THREE.Color(0x101418);
export const COLOR_RIM_A = new THREE.Color(0x8b5cf6);
export const COLOR_RIM_B = new THREE.Color(0x2dd4bf);
export const RIM_FRESNEL_EXP = 4;

export const LENIS_DURATION = 1.2;
export const CAMERA_Z_START = 4;
export const CAMERA_Z_END = 8;
EOF
perl -0pi -e 's/COLOR_RIM_B \} from/COLOR_RIM_B, RIM_FRESNEL_EXP } from/; s/uFresnelExp: \{ value: 5 \}/uFresnelExp: { value: RIM_FRESNEL_EXP }/' src/scene/scenes/home/HomeScene.ts
perl -0pi -e 's/smoothstep\(-0\.3, 0\.6, N\.y\)/smoothstep(-0.5, 0.8, N.y)/' src/shaders/hero/sculpture.frag.glsl
