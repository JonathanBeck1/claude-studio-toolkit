# Curl Noise Particles (GPU-driven)

## When to use

Hero backgrounds where you need 5,000–50,000 particles flowing in a coherent, organic motion field — neither random (chaotic) nor scripted (mechanical). Curl noise produces divergence-free flow, so particles never bunch up or thin out — they drift in continuous streams.

**Reference-only.** Ambient particle fields are a logged owner rejection ("seizure-y" — `brain/design-taste.md`) and a listed slop indicator. Never propose this as a hero atmosphere or background fill — only ever as a deliberate accent around a defined subject.

This is the wrong pattern for: literal data viz where particle count maps to a value (use simple instanced meshes), explosion / impact effects (use a one-shot animation), narrative path-following (use spline-driven animation).

## What it gives you

Particles flow along an invisible 3D vector field that evolves over time. Visually: organic, water-like, perpetually in motion without ever looking random.

## Required setup

You need a `BufferGeometry` with per-particle positions stored in an attribute, plus a custom shader that computes the next position from the current position via curl noise. Two implementation paths:

### Path A — CPU-driven (≤ 5,000 particles)

Update positions in JS each frame, push to a `Float32BufferAttribute`. Simple but capped by per-frame JS budget.

### Path B — GPU-driven via FBO ping-pong (≥ 5,000 particles)

Store positions in a floating-point texture. Each frame, render a fullscreen quad to a second texture using a fragment shader that reads the current position and writes the next position. Swap textures (ping-pong). Sample the texture in the particle vertex shader to place each point.

For TakeTwo work, default to Path B. Path A is a fallback only.

## Code recipe — Path B (GPU-driven)

Two render targets for ping-pong:

```js
import * as THREE from 'three';

const PARTICLE_COUNT_SQRT = 256; // 256x256 = 65,536 particles
const PARTICLE_COUNT = PARTICLE_COUNT_SQRT * PARTICLE_COUNT_SQRT;

const positionRTOptions = {
  type: THREE.FloatType,
  format: THREE.RGBAFormat,
  minFilter: THREE.NearestFilter,
  magFilter: THREE.NearestFilter,
};

const rtA = new THREE.WebGLRenderTarget(PARTICLE_COUNT_SQRT, PARTICLE_COUNT_SQRT, positionRTOptions);
const rtB = new THREE.WebGLRenderTarget(PARTICLE_COUNT_SQRT, PARTICLE_COUNT_SQRT, positionRTOptions);
let readRT = rtA, writeRT = rtB;
```

Update shader (fragment, runs once per particle per frame):

```glsl
#include <curl-noise>

uniform sampler2D positionTexture;
uniform float time;
uniform float deltaTime;
uniform float fieldScale;
uniform float speed;

varying vec2 vUv;

void main() {
  vec3 pos = texture2D(positionTexture, vUv).xyz;
  vec3 flow = curl(pos * fieldScale + time * 0.1) * speed * deltaTime;
  gl_FragColor = vec4(pos + flow, 1.0);
}
```

The `#include <curl-noise>` resolves to `shaders/curl-noise.glsl` via `vite-plugin-glsl`.

Render shader (vertex, places points in scene):

```glsl
uniform sampler2D positionTexture;
attribute vec2 uv2; // mapping from particle index to texture coordinate

void main() {
  vec3 pos = texture2D(positionTexture, uv2).xyz;
  vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
  gl_Position = projectionMatrix * mvPosition;
  gl_PointSize = 2.0 * (300.0 / -mvPosition.z);
}
```

Per-frame loop:

```js
// 1. Update positions
updateMaterial.uniforms.positionTexture.value = readRT.texture;
updateMaterial.uniforms.time.value = elapsed;
updateMaterial.uniforms.deltaTime.value = delta;
renderer.setRenderTarget(writeRT);
renderer.render(updateScene, updateCamera); // updateScene = fullscreen quad with updateMaterial

// 2. Swap
[readRT, writeRT] = [writeRT, readRT];

// 3. Render particles using the new positions
renderMaterial.uniforms.positionTexture.value = readRT.texture;
renderer.setRenderTarget(null);
renderer.render(scene, camera);
```

## Tunable parameters

| Uniform | Default | Range | Effect |
|---|---|---|---|
| `fieldScale` | 0.5 | 0.1 – 2.0 | Higher = tighter swirls, more chaotic |
| `speed` | 0.3 | 0.05 – 1.5 | Particle drift velocity |
| `time` multiplier (in shader: `time * 0.1`) | 0.1 | 0.01 – 0.5 | How fast the field itself evolves |
| `gl_PointSize` constant (300.0) | 300 | 100 – 800 | Pixel size of particles at z = -1 |

## Common pitfalls

1. **Float texture support not requested.** WebGL2 supports `RGBA32F` natively, but you must enable `OES_texture_float_linear` if using linear filtering. We use `NearestFilter` so this isn't needed, but leave a comment for future maintainers.
2. **Particles drift to infinity.** The noise field has no boundary. Either add a soft re-spawn rule (if `length(pos) > maxRadius`, randomize within a sphere) or use a domain-warped noise that loops.
3. **Initial positions are zeros.** All 65,536 particles spawn at the origin and stream out radially — looks like a fountain, not a field. Initialize the texture with random positions in a unit sphere on first frame.
4. **`gl_PointSize` too small on retina.** Particles disappear on high-DPI displays. Multiply size by `pixelRatio` in the vertex shader OR render as instanced quads instead of `Points`.
5. **Update step runs at variable framerate.** If frame drops happen, particles teleport. Cap `deltaTime` at 1/30s minimum to prevent ugly jumps.

## Reference

See `references.md` → entries for Lusion (subtle ambient particle field) and exp.is (more aggressive curl flow as hero subject).
