# Fresnel Iridescence (custom ShaderMaterial)

## When to use

Hero-scale geometry where the surface needs to read as a real material — glass, oil-on-water, anodized metal, soap film — and you want the color to shift with view angle rather than sit flat. The iridescent fresnel is what sells "this is a physical object in the room" on a single primitive or imported model. Lusion's homepage cluster is the canonical example: a uniform material across all instances reads as premium because every surface responds to light the same way.

This is the right material for: hero objects on `/`, the rotating logomark on `/about`, single-mesh accents on case-study covers, anywhere a `MeshStandardMaterial` would read as plastic and a `MeshPhysicalMaterial.iridescence` would be too uniform / too "demo scene."

This is the wrong material for: backgrounds (the angle-dependent shift requires foreground attention to register), large flat planes (fresnel needs curvature to express), text geometry (iridescence on letterforms reads as Y2K chrome — use MSDF + a flat fill), particles (point sprites have no normals). Also wrong if the brand palette needs to stay literal — iridescence by definition reinterprets brand color across the surface.

## What it gives you

A surface where the rim and grazing-angle pixels glow with a shifting palette (violet → teal → coral on TakeTwo work) while the front-facing pixels stay near-black or near-base-color. As the camera or object rotates, the bright bands sweep across the geometry — the object reads as having a real coating, not a painted texture. With a low fresnel power the whole surface tints; with a high power only the silhouette edges glow and the rest reads as deep black.

## Required setup

A single `THREE.ShaderMaterial` carrying:
- a vertex shader that emits world-space normal and world-space view direction to the fragment stage,
- a fragment shader that computes the fresnel term and uses it to mix between three palette colors,
- a uniforms object exposing the tunables in the table below,
- `side: THREE.DoubleSide` if the geometry is open / single-sided (most decorative primitives),
- `transparent: false` (iridescence is opaque; transparency creates depth-sort headaches with no visual gain).

For glTF imports you must:
1. Traverse the loaded scene and replace each `MeshStandardMaterial` with the `ShaderMaterial`.
2. Call `geometry.computeVertexNormals()` on any mesh whose source was flat-shaded or which lost normals during DRACO compression — fresnel is unwatchable without smooth normals, and the artifact looks like faceted noise.
3. Confirm `renderer.outputColorSpace = THREE.SRGBColorSpace` is set once on the renderer; otherwise the palette will look washed-out and incorrect (see Pitfalls).

## Code recipe

### Vertex shader

```glsl
varying vec3 vWorldNormal;
varying vec3 vViewDir;

void main() {
  vec4 worldPos = modelMatrix * vec4(position, 1.0);

  // World-space normal. Use the inverse-transpose of modelMatrix's 3x3
  // (three.js does NOT auto-provide a worldNormalMatrix, so derive it).
  mat3 normalWorldMatrix = transpose(inverse(mat3(modelMatrix)));
  vWorldNormal = normalize(normalWorldMatrix * normal);

  // cameraPosition is a built-in ShaderMaterial uniform (world-space).
  vViewDir = normalize(cameraPosition - worldPos.xyz);

  gl_Position = projectionMatrix * viewMatrix * worldPos;
}
```

### Fragment shader

```glsl
#include <fresnel>

uniform vec3 uColorA;       // violet
uniform vec3 uColorB;       // teal
uniform vec3 uColorC;       // coral
uniform vec3 uBaseColor;    // deep base (front-facing pixels)
uniform float uFresnelPower;
uniform float uIntensity;
uniform float uHueShift;    // 0..1, rotates the palette around the surface

varying vec3 vWorldNormal;
varying vec3 vViewDir;

// Three-stop gradient: A at t=0, B at t=0.5, C at t=1.
vec3 sampleIridescence(float t) {
  vec3 ab = mix(uColorA, uColorB, smoothstep(0.0, 0.5, t));
  vec3 bc = mix(uColorB, uColorC, smoothstep(0.5, 1.0, t));
  return mix(ab, bc, step(0.5, t));
}

void main() {
  vec3 N = normalize(vWorldNormal);
  vec3 V = normalize(vViewDir);

  // Backface correction: if we're looking at the inside of the mesh,
  // flip the normal so the fresnel term is well-defined on both sides.
  if (!gl_FrontFacing) {
    N = -N;
  }

  // fresnel() comes from shaders/fresnel.glsl — equivalent to
  // pow(1.0 - max(dot(N, V), 0.0), uFresnelPower).
  float f = fresnel(N, V, uFresnelPower);

  // Sweep the palette by view angle, with an authored hue offset.
  float t = fract(f + uHueShift);
  vec3 iridescent = sampleIridescence(t);

  // Mix base toward iridescent by fresnel strength, then scale.
  vec3 color = mix(uBaseColor, iridescent, f) * uIntensity;

  gl_FragColor = vec4(color, 1.0);
}
```

The `#include <fresnel>` resolves to `shaders/fresnel.glsl` via `vite-plugin-glsl`. Until that file exists (Task 14), you can inline the helper:

```glsl
float fresnel(vec3 N, vec3 V, float power) {
  return pow(1.0 - max(dot(N, V), 0.0), power);
}
```

### JS wiring

```js
import * as THREE from 'three';
import vertexShader from './fresnel-iridescence.vert?raw';
import fragmentShader from './fresnel-iridescence.frag?raw';

// TakeTwo accent colors. Hex → linear-ish vec3 (renderer handles sRGB output).
const COLOR_A = new THREE.Color(0xe66cff); // violet
const COLOR_B = new THREE.Color(0x59ffe2); // teal
const COLOR_C = new THREE.Color(0xff7d4e); // coral
const BASE    = new THREE.Color(0x0a0a12); // deep ink

export function createIridescentMaterial() {
  return new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader,
    side: THREE.DoubleSide,
    transparent: false,
    uniforms: {
      uColorA:       { value: COLOR_A },
      uColorB:       { value: COLOR_B },
      uColorC:       { value: COLOR_C },
      uBaseColor:    { value: BASE },
      uFresnelPower: { value: 2.5 },
      uIntensity:    { value: 1.0 },
      uHueShift:     { value: 0.0 },
    },
  });
}
```

### Apply to an imported glTF mesh

```js
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
const material = createIridescentMaterial();

loader.load('/models/hero.glb', (gltf) => {
  gltf.scene.traverse((child) => {
    if (!child.isMesh) return;

    // Replace whatever the DCC tool exported — usually MeshStandardMaterial.
    child.material = material;

    // If the source mesh was flat-shaded or had normals stripped by DRACO,
    // recompute them. Fresnel on flat normals shows the faceting.
    if (!child.geometry.attributes.normal) {
      child.geometry.computeVertexNormals();
    }
    // Optional: smooth normals across UV seams that DCC tools sometimes split.
    // child.geometry.computeVertexNormals();

    child.castShadow = true;
    child.receiveShadow = false; // iridescence reads better unshadowed.
  });

  scene.add(gltf.scene);
});

// Required once at renderer setup so the palette displays correctly:
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
```

## Tunable parameters

| Uniform | Default | Range | Effect |
|---|---|---|---|
| `uFresnelPower` | 2.5 | 0.5 – 8.0 | Lower = whole surface tints iridescent; higher = only the silhouette glows and the body falls to `uBaseColor`. 2.5 is a clean glass-edge feel; 5+ reads as anodized metal. |
| `uIntensity` | 1.0 | 0.2 – 2.5 | Output multiplier. Push above 1.0 only with tone mapping enabled — otherwise the brights clip to white and you lose the palette. |
| `uHueShift` | 0.0 | 0.0 – 1.0 | Rotates which palette color sits at the silhouette. Animate slowly (≈ 0.05 / second) for a "breathing" coating; leave fixed for a stable identity. |
| `uBaseColor` | `#0a0a12` | any near-black | The front-facing color. Keep dark — a bright base washes out the iridescent rim. White base turns the effect into a pearl, which has its place but is not the TakeTwo look. |
| `uColorA` / `uColorB` / `uColorC` | violet / teal / coral | brand accents only | The three-stop palette. Reordering swaps which accent reads at peak fresnel — violet-first is the established TakeTwo cue. |

## Common pitfalls

1. **Backfaces render black or invert the gradient.** Open geometry (a single-sided ribbon, an unwelded glTF) hits the fragment shader on the back side with normals pointing away from the camera, so `dot(N, V)` goes negative and fresnel breaks. Fix: set `side: THREE.DoubleSide` on the material AND flip the normal inside the fragment shader using `if (!gl_FrontFacing) N = -N;` (already in the recipe). Don't rely on either alone — `DoubleSide` without the flip still inverts the term, and the flip without `DoubleSide` still culls the back face.

2. **Colors look washed out, muddy, or oversaturated.** The renderer is outputting in linear space when the browser expects sRGB. Set `renderer.outputColorSpace = THREE.SRGBColorSpace` once at setup. `THREE.Color(0xe66cff)` will then be displayed at the hex you authored. Without this line, the palette shifts perceptually toward gray and the violet → teal transition reads as a gray smear.

3. **Iridescent peaks clip to white in postprocessing.** The fresnel rim, multiplied by `uIntensity`, easily exceeds 1.0 — that's intended for HDR. But if your postprocessing chain (bloom, color grade) runs without tone mapping, the over-bright pixels clip in the composer and the palette disappears at the silhouette. Fix: enable `renderer.toneMapping = THREE.ACESFilmicToneMapping` and tune `toneMappingExposure`. If you're rendering through `EffectComposer`, also confirm the final pass writes to an sRGB target (or set `renderTarget.texture.colorSpace = THREE.SRGBColorSpace` on the composer's write target). Symptom of getting this wrong: the rim looks pure white in screenshots even though the WebGL inspector shows the shader is outputting `vec3(1.4, 0.8, 2.1)`.

4. **Faceted / noisy iridescence on imported models.** The mesh has flat or missing normals. Always check the imported geometry: if `child.geometry.attributes.normal` is undefined or the mesh was exported flat-shaded, call `child.geometry.computeVertexNormals()` after assignment. DRACO-compressed glTFs sometimes drop normals to save bytes — exporters strip them assuming the runtime will recompute, which three.js does not do automatically.

5. **The effect "looks the same" from every angle.** Either the camera isn't moving (orbit it during dev to verify), or `uFresnelPower` is so low (≤ 0.5) that the whole surface saturates to `uColorB`, or the geometry has no curvature for the normal to vary across (a flat plane will show one constant fresnel value across its entire face). Fix in priority order: orbit the camera → raise power to 2.0+ → swap the geometry for something curved.

## Reference

See `references.md` → **Lusion** entry. The cylinder cluster on Lusion's homepage is the canonical implementation of this material applied with discipline: a single iridescent fresnel response across many primitives, paired with a near-black field so the rim glow registers. Copy the material restraint (one shader, three palette stops, dark base) — invent your own primitive.
