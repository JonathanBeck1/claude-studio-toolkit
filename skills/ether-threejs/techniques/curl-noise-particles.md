# Curl Noise Particles (GPU-driven)

## When to use

Hero backgrounds where you need 5,000–50,000 particles flowing in a coherent, organic motion field — neither random (chaotic) nor scripted (mechanical). Curl noise produces divergence-free flow, so particles never bunch up or thin out — they drift in continuous streams.

**Reference-only.** Ambient particle fields are a logged owner rejection ("seizure-y" was one studio owner's verdict on a real build) and a listed slop indicator. Never propose this as a hero atmosphere or background fill — only ever as a deliberate accent around a defined subject.

This is the wrong pattern for: literal data viz where particle count maps to a value (use simple instanced meshes), explosion / impact effects (use a one-shot animation), narrative path-following (use spline-driven animation).

## What it gives you

Particles flow along an invisible 3D vector field that evolves over time. Visually: organic, water-like, perpetually in motion without ever looking random.

## Required setup

You need a `BufferGeometry` with per-particle positions stored in an attribute, plus a custom shader that computes the next position from the current position via curl noise. Two implementation paths:

### Path A — CPU-driven (≤ 5,000 particles)

Update positions in JS each frame, push to a `Float32BufferAttribute`. Simple but capped by per-frame JS budget.

### Path B — GPU-driven via FBO ping-pong (≥ 5,000 particles)

Store positions in a floating-point texture. Each frame, render a fullscreen quad to a second texture using a fragment shader that reads the current position and writes the next position. Swap textures (ping-pong). Sample the texture in the particle vertex shader to place each point.

For premium studio work, default to Path B. Path A is a fallback only.

## Where the GLSL lives

The engine ships no curl chunk, and there is no `#include` mechanism to
reach one with. `ether/shaders` exports each chunk it *does* ship two
ways — as a named string (`import { dither } from 'ether/shaders'`) and
as the file itself (`import dither from 'ether/shaders/dither.glsl?raw'`)
— and sites keep their own shaders under `src/shaders/`, pulled in with
Vite's `?raw`. Nothing in the engine or the site it was extracted from
uses `#include` in GLSL at all.

The curl chunk this skill carries — `shaders/curl-noise.glsl`, a sibling
of this file — is a **standalone reference snippet**, not a module. Paste
it above `main()` in your update shader, or drop it in your own
`src/shaders/` and compose the two sources in JS. It exposes one entry
point:

```glsl
vec3 curl(vec3 p);   // divergence-free flow vector at p
```

Note that `#include <curl-noise>` would not work even with a GLSL bundler
installed — angle-bracket includes are three.js's own `ShaderChunk`
syntax, resolved against three's chunk registry, and a name that isn't
registered fails at program compile.

## Code recipe — Path B (GPU-driven)

Update shader (fragment, runs once per particle per frame). Paste
`shaders/curl-noise.glsl` where the comment is:

```glsl
precision highp float;

uniform sampler2D uPositions;
uniform float uTime;
uniform float uDelta;
uniform float uFieldScale;
uniform float uSpeed;
uniform float uMaxRadius;

varying vec2 vUv;

// ... curl chunk here ...

void main() {
  vec3 pos = texture2D(uPositions, vUv).xyz;

  vec3 flow = curl(pos * uFieldScale + uTime * 0.1) * uSpeed * uDelta;
  pos += flow;

  // The field has no boundary — without a respawn rule the cloud
  // dissolves outward over a few minutes. Fold escapees back toward the
  // core on the opposite side, jittered by the field itself so they
  // don't respawn onto a visible shell.
  if (length(pos) > uMaxRadius) {
    pos = -pos * 0.2 + curl(pos * 3.7) * 0.3;
  }

  gl_FragColor = vec4(pos, 1.0);
}
```

Its vertex shader is the usual clip-space pass-through — the update quad
covers NDC exactly, so the projection matrices are not involved:

```glsl
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = vec4(position.xy, 0.0, 1.0);
}
```

Render shader (vertex, places points in the scene). It samples the
position texture in the *vertex* stage — fine on WebGL2, which guarantees
at least 16 vertex texture units, but zero are guaranteed on WebGL1:

```glsl
uniform sampler2D uPositions;
uniform float uPointScale;
uniform float uPixelRatio;

// One texel per particle — see createParticleGeometry().
attribute vec2 aRef;

varying float vDepth;

void main() {
  vec3 pos = texture2D(uPositions, aRef).xyz;
  vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
  gl_Position = projectionMatrix * mvPosition;

  // uPixelRatio keeps the dot the same apparent size on retina, where a
  // raw pixel size renders half as large as authored.
  gl_PointSize = uPointScale * uPixelRatio / max(-mvPosition.z, 0.001);
  vDepth = -mvPosition.z;
}
```

```glsl
precision highp float;

uniform vec3 uColor;
uniform float uFadeNear;
uniform float uFadeFar;

varying float vDepth;

void main() {
  // Round the point sprite; square dots read as a bug.
  vec2 d = gl_PointCoord - 0.5;
  float alpha = 1.0 - smoothstep(0.35, 0.5, length(d));
  alpha *= 1.0 - smoothstep(uFadeNear, uFadeFar, vDepth);
  if (alpha <= 0.0) discard;
  gl_FragColor = vec4(uColor, alpha);
}
```

The JS side: two render targets, a seed texture, and the index→texel
attribute the render vertex shader reads.

```ts
import * as THREE from 'three';

const SIDE = 256;               // 256 x 256 = 65,536 particles
const COUNT = SIDE * SIDE;

const rtOptions: THREE.RenderTargetOptions = {
  type: THREE.FloatType,
  format: THREE.RGBAFormat,
  minFilter: THREE.NearestFilter,
  magFilter: THREE.NearestFilter,
  depthBuffer: false,
};

export function createPingPong() {
  let read = new THREE.WebGLRenderTarget(SIDE, SIDE, rtOptions);
  let write = new THREE.WebGLRenderTarget(SIDE, SIDE, rtOptions);
  return {
    get read() { return read; },
    get write() { return write; },
    swap() { const t = read; read = write; write = t; },
    dispose() { read.dispose(); write.dispose(); },
  };
}

/** Starting positions in a unit sphere. Skip this and all 65,536 particles
 *  spawn at the origin and stream out radially — a fountain, not a field. */
export function createSeedTexture(): THREE.DataTexture {
  const data = new Float32Array(COUNT * 4);
  for (let i = 0; i < COUNT; i++) {
    const r = Math.cbrt(Math.random());
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    data[i * 4 + 0] = r * Math.sin(phi) * Math.cos(theta);
    data[i * 4 + 1] = r * Math.sin(phi) * Math.sin(theta);
    data[i * 4 + 2] = r * Math.cos(phi);
    data[i * 4 + 3] = 1;
  }
  const seed = new THREE.DataTexture(data, SIDE, SIDE, THREE.RGBAFormat, THREE.FloatType);
  seed.minFilter = THREE.NearestFilter;
  seed.magFilter = THREE.NearestFilter;
  seed.needsUpdate = true;
  return seed;
}

/** One texel coordinate per particle — what the render vertex shader
 *  samples the position texture with. */
export function createParticleGeometry(): THREE.BufferGeometry {
  const refs = new Float32Array(COUNT * 2);
  for (let i = 0; i < COUNT; i++) {
    refs[i * 2 + 0] = ((i % SIDE) + 0.5) / SIDE;
    refs[i * 2 + 1] = (Math.floor(i / SIDE) + 0.5) / SIDE;
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('aRef', new THREE.BufferAttribute(refs, 2));
  // Points still needs `position`, even though the vertex shader ignores it.
  geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(COUNT * 3), 3));
  geometry.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 100);
  return geometry;
}
```

Per-frame: run the position pass into the write target, swap, then let
the scene render read the result. Restoring the previous render target
rather than forcing `null` is what makes this safe to call from a scene
that renders through a composer.

```ts
export class CurlField {
  private rt = createPingPong();
  private seed: THREE.DataTexture | null = createSeedTexture();
  private updateScene = new THREE.Scene();
  private updateCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

  constructor(
    private updateMaterial: THREE.ShaderMaterial,
    private renderMaterial: THREE.ShaderMaterial,
  ) {
    const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), updateMaterial);
    quad.frustumCulled = false;
    this.updateScene.add(quad);
  }

  /** Run the position pass, then swap. Call from tick(), before the scene render. */
  update(renderer: THREE.WebGLRenderer, elapsed: number, delta: number): void {
    // First pass reads the seed; every pass after reads the last result.
    this.updateMaterial.uniforms.uPositions!.value = this.seed ?? this.rt.read.texture;
    this.updateMaterial.uniforms.uTime!.value = elapsed;
    // Cap dt — a dropped frame otherwise teleports every particle.
    this.updateMaterial.uniforms.uDelta!.value = Math.min(delta, 1 / 30);

    const previousTarget = renderer.getRenderTarget();
    renderer.setRenderTarget(this.rt.write);
    renderer.render(this.updateScene, this.updateCamera);
    renderer.setRenderTarget(previousTarget);
    this.rt.swap();

    if (this.seed) {
      this.seed.dispose();
      this.seed = null;
    }
    this.renderMaterial.uniforms.uPositions!.value = this.rt.read.texture;
  }

  dispose(): void {
    this.rt.dispose();
    this.seed?.dispose();
    this.updateScene.traverse((o) => {
      if (o instanceof THREE.Mesh) o.geometry.dispose();
    });
  }
}
```

`SceneManager` never calls this for you — the scene owns it. Call
`update()` at the top of the scene's `tick()`, and `dispose()` from the
scene's `dispose()` (or hand it to `BaseScene`'s `track()`, which takes
anything with a `dispose()`).

## Tunable parameters

| Uniform | Default | Range | Effect |
|---|---|---|---|
| `uFieldScale` | 0.5 | 0.1 – 2.0 | Higher = tighter swirls, more chaotic |
| `uSpeed` | 0.3 | 0.05 – 1.5 | Particle drift velocity |
| `uTime` multiplier (in shader: `uTime * 0.1`) | 0.1 | 0.01 – 0.5 | How fast the field itself evolves |
| `uMaxRadius` | 3.0 | 1.0 – 10.0 | Respawn boundary. Below the visible extent of the cloud and you see particles pop; well above it and the cloud thins out before anything recycles. |
| `uPointScale` | 600 | 200 – 1600 | Point size in pixels at one world unit from the camera, before DPR. |
| `e` in `curl()` | 0.01 (in the shipped chunk) | 0.005 – 0.2 | Central-difference step. Smaller reads more detail out of the noise and costs nothing extra; too small and float precision turns the difference into noise of its own. Editing it means editing your pasted copy of the chunk. |

## Common pitfalls

1. **Float render targets are not universally renderable.** Sampling `RGBA32F` is one capability; *rendering into* it is another. On WebGL2 that needs `EXT_color_buffer_float` — three.js requests it, but where it is missing the framebuffer comes back incomplete and the position pass silently writes nothing. Fall back to `THREE.HalfFloatType`, covered by the much more widely available `EXT_color_buffer_half_float`; half-float has ample precision for positions in a bounded field. (`OES_texture_float_linear` is a separate extension, and only matters for linear filtering — `NearestFilter` here needs none of it.)
2. **Particles drift to infinity.** The noise field has no boundary. The `uMaxRadius` respawn in the update shader above is the cheap fix; the alternative is a domain-warped noise that loops.
3. **Initial positions are zeros.** A freshly allocated render target reads back as zeros, so every particle spawns at the origin and streams out radially — a fountain, not a field. `createSeedTexture()` above feeds the first update pass from a `DataTexture` instead, which avoids needing to render or copy into the target to prime it.
4. **`gl_PointSize` too small on retina.** Particles disappear on high-DPI displays because `gl_PointSize` is in framebuffer pixels, not CSS pixels. Multiply by the renderer's pixel ratio (`uPixelRatio` above) — or render instanced quads instead of `Points` if you need per-particle rotation or a texture.
5. **Update step runs at variable framerate.** If frame drops happen, particles teleport. Clamp `deltaTime` to 1/30 s before it reaches the shader (`Math.min(delta, 1 / 30)` above) to prevent ugly jumps.
6. **The update pass leaks its render target.** `renderer.setRenderTarget(null)` after the position pass unbinds whatever the caller had bound — which breaks the scene the moment it renders through a composer rather than straight to the canvas. Save and restore instead, as `CurlField.update()` does.

## Reference

See `references.md` → entries for Lusion (subtle ambient particle field) and exp.is (more aggressive curl flow as hero subject).
