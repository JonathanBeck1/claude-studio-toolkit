# Fresnel Iridescence (custom ShaderMaterial)

## When to use

Hero-scale geometry where the surface needs to read as a real material — glass, oil-on-water, anodized metal, soap film — and you want the color to shift with view angle rather than sit flat. The iridescent fresnel is what sells "this is a physical object in the room" on a single primitive or imported model. Lusion's homepage cluster is the canonical example: a uniform material across all instances reads as premium because every surface responds to light the same way.

This is the right material for: hero objects on `/`, the rotating logomark on `/about`, single-mesh accents on case-study covers, anywhere a `MeshStandardMaterial` would read as plastic and a `MeshPhysicalMaterial.iridescence` would be too uniform / too "demo scene."

This is the wrong material for: backgrounds (the angle-dependent shift requires foreground attention to register), large flat planes (fresnel needs curvature to express), text geometry (iridescence on letterforms reads as Y2K chrome — use MSDF + a flat fill), particles (point sprites have no normals). Also wrong if the brand palette needs to stay literal — iridescence by definition reinterprets brand color across the surface.

## What it gives you

A surface where the rim and grazing-angle pixels glow with a shifting palette (e.g. violet → teal → coral) while the front-facing pixels stay near-black or near-base-color. As the camera or object rotates, the bright bands sweep across the geometry — the object reads as having a real coating, not a painted texture. With a low fresnel power the whole surface tints; with a high power only the silhouette edges glow and the rest reads as deep black.

## Required setup

A single `THREE.ShaderMaterial` carrying:
- a vertex shader that emits world-space normal and world-space view direction to the fragment stage,
- a fragment shader that computes the fresnel term and uses it to mix between three palette colors,
- a uniforms object exposing the tunables in the table below,
- `side: THREE.DoubleSide` if the geometry is open / single-sided (most decorative primitives),
- `transparent: false` (iridescence is opaque; transparency creates depth-sort headaches with no visual gain).

For glTF imports you must:
1. Traverse the loaded scene and replace each `MeshStandardMaterial` with the `ShaderMaterial`.
2. Give every mesh smooth normals — fresnel is unwatchable without them, and the artifact looks like faceted noise. A mesh with no `normal` attribute at all just needs `geometry.computeVertexNormals()`. A mesh exported *flat-shaded* needs more than that: flat shading is encoded as split vertices, so recomputing normals over them re-derives the same per-face values. Weld first with `mergeVertices`, then recompute (see the recipe below).
3. Confirm `renderer.outputColorSpace = THREE.SRGBColorSpace` is set once on the renderer; otherwise the palette will look washed-out and incorrect (see Pitfalls). `SceneManager` already sets this on the renderer it owns.

## Code recipe

### Vertex shader

```glsl
varying vec3 vWorldNormal;
varying vec3 vViewDir;

void main() {
  vec4 worldPos = modelMatrix * vec4(position, 1.0);

  // World-space normal. Do NOT reach for `transpose(inverse(mat3(modelMatrix)))`
  // here: both functions are GLSL ES 3.00, and a `ShaderMaterial` compiles as
  // GLSL ES 1.00 unless you set `glslVersion: THREE.GLSL3` — the program fails
  // to compile with "no matching overloaded function found". Transforming the
  // normal as a direction is correct for rigid and uniformly scaled meshes,
  // which covers every decorative primitive; a non-uniformly scaled mesh needs
  // its own inverse-transpose passed in as a uniform.
  vWorldNormal = normalize((modelMatrix * vec4(normal, 0.0)).xyz);

  // cameraPosition is a built-in ShaderMaterial uniform (world-space).
  vViewDir = normalize(cameraPosition - worldPos.xyz);

  gl_Position = projectionMatrix * viewMatrix * worldPos;
}
```

### Fragment shader

```glsl
precision highp float;

uniform vec3 uColorA;       // violet
uniform vec3 uColorB;       // teal
uniform vec3 uColorC;       // coral
uniform vec3 uBaseColor;    // deep base (front-facing pixels)
uniform float uFresnelPower;
uniform float uIntensity;
uniform float uHueShift;    // 0..1, rotates the palette around the surface

varying vec3 vWorldNormal;
varying vec3 vViewDir;

// ... shaders/fresnel.glsl here — defines fresnel() and iridescence() ...

void main() {
  vec3 N = normalize(vWorldNormal);
  vec3 V = normalize(vViewDir);

  // Backface correction: if we're looking at the inside of the mesh,
  // flip the normal so the fresnel term is well-defined on both sides.
  if (!gl_FrontFacing) {
    N = -N;
  }

  float f = fresnel(N, V, uFresnelPower);

  // Sweep the palette by view angle, with an authored hue offset.
  // fract() wraps, so the palette cycles rather than clamping at the rim.
  vec3 iridescent = iridescence(fract(f + uHueShift), uColorA, uColorB, uColorC);

  // Mix base toward iridescent by fresnel strength, then scale.
  vec3 color = mix(uBaseColor, iridescent, f) * uIntensity;

  gl_FragColor = vec4(color, 1.0);
}
```

`shaders/fresnel.glsl`, a sibling of this file, is where those two
helpers live:

```glsl
float fresnel(vec3 normal, vec3 viewDir, float power);
vec3  iridescence(float viewDot, vec3 c0, vec3 c1, vec3 c2);
```

It is a **standalone reference snippet you paste**, not a module. The
engine ships no fresnel chunk — `ether/shaders` exports only `dither` —
and there is no `#include` mechanism to reach one with anyway:
angle-bracket includes are three.js's own `ShaderChunk` syntax, and an
unregistered name fails at program compile even with a GLSL bundler
plugin installed. Reusable chunks in this codebase are strings you
compose, or files you import with Vite's `?raw`.

### JS wiring

The two shader files are yours to create; the convention is a
`src/shaders/` tree beside your scenes, pulled in with `?raw`.

```ts
import * as THREE from 'three';
import vertexShader from '../../shaders/iridescent.vert.glsl?raw';
import fragmentShader from '../../shaders/iridescent.frag.glsl?raw';

// Example accent palette. Hex → linear-ish vec3 (renderer handles sRGB output).
const COLOR_A = new THREE.Color(0x8b5cf6); // violet
const COLOR_B = new THREE.Color(0x2dd4bf); // teal
const COLOR_C = new THREE.Color(0xfb7185); // coral
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

```ts
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

/** Weld split vertices, then recompute — the only way to smooth a
 *  flat-shaded export. computeVertexNormals() alone re-derives the same
 *  faceted normals, because flat shading IS the split. */
function smoothNormals(geometry: THREE.BufferGeometry): THREE.BufferGeometry {
  const welded = mergeVertices(geometry);
  welded.computeVertexNormals();
  return welded;
}

export async function applyToGLTF(scene: THREE.Scene, url: string) {
  const gltf = await new GLTFLoader().loadAsync(url);
  const material = createIridescentMaterial();

  gltf.scene.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;

    // Replace whatever the DCC tool exported — usually MeshStandardMaterial.
    child.material = material;

    const geometry = child.geometry as THREE.BufferGeometry;
    if (!geometry.attributes.normal) {
      // DRACO and some exporters drop normals entirely; three.js does not
      // recompute them for you.
      geometry.computeVertexNormals();
    }
    // Flat shading survives the import as split vertices and cannot be
    // detected from the geometry. Call smoothNormals(geometry) on the
    // meshes you KNOW were exported faceted, or fix it at export.

    child.castShadow = true;
    child.receiveShadow = false; // iridescence reads better unshadowed.
  });

  scene.add(gltf.scene);
  return material;
}
```

Renderer setup, if you own the renderer yourself. `SceneManager` already
sets the color space, and deliberately leaves tone mapping off — see
pitfall 3.

```ts
renderer.outputColorSpace = THREE.SRGBColorSpace;
```

## Tunable parameters

| Uniform | Default | Range | Effect |
|---|---|---|---|
| `uFresnelPower` | 2.5 | 0.5 – 8.0 | Lower = whole surface tints iridescent; higher = only the silhouette glows and the body falls to `uBaseColor`. 2.5 is a clean glass-edge feel; 5+ reads as anodized metal. |
| `uIntensity` | 1.0 | 0.2 – 2.5 | Output multiplier. Push above 1.0 only on an HDR composer (`createComposer(..., { hdr: true })`) — otherwise the brights clip to white and you lose the palette. |
| `uHueShift` | 0.0 | 0.0 – 1.0 | Rotates which palette color sits at the silhouette. Animate slowly (≈ 0.05 / second) for a "breathing" coating; leave fixed for a stable identity. |
| `uBaseColor` | `#0a0a12` | any near-black | The front-facing color. Keep dark — a bright base washes out the iridescent rim. White base turns the effect into a pearl, which has its place but is not the dark-field look this recipe targets. |
| `uColorA` / `uColorB` / `uColorC` | violet / teal / coral | your brand accents | The three-stop palette. Reordering swaps which accent reads at peak fresnel — violet-first is one studio's established cue. |

## Common pitfalls

1. **Backfaces render black or invert the gradient.** Open geometry (a single-sided ribbon, an unwelded glTF) hits the fragment shader on the back side with normals pointing away from the camera, so `dot(N, V)` goes negative and fresnel breaks. Fix: set `side: THREE.DoubleSide` on the material AND flip the normal inside the fragment shader using `if (!gl_FrontFacing) N = -N;` (already in the recipe). Don't rely on either alone — `DoubleSide` without the flip still inverts the term, and the flip without `DoubleSide` still culls the back face.

2. **Colors look washed out, muddy, or oversaturated.** The renderer is outputting in linear space when the browser expects sRGB. Set `renderer.outputColorSpace = THREE.SRGBColorSpace` once at setup. `THREE.Color(0x8b5cf6)` will then be displayed at the hex you authored. Without this line, the palette shifts perceptually toward gray and the violet → teal transition reads as a gray smear.

3. **Iridescent peaks clip to white in postprocessing.** The fresnel rim, multiplied by `uIntensity`, easily exceeds 1.0 — that's intended for HDR. Reaching for `renderer.toneMapping = THREE.ACESFilmicToneMapping` will not fix it: the moment a composer runs, every pass renders into a texture and the renderer's own tone mapping is bypassed entirely. That is why `SceneManager` sets `NoToneMapping` deliberately, and why the default composer is LDR — values clip at 1.0, which is what keeps bloom contained on the restrained presets. The actual fix is `createComposer(renderer, scene, camera, { hdr: true })` from `ether/postfx`: half-float buffers plus an ACES `ToneMappingEffect` fused into the same fullscreen pass, which is what makes `toneMappingExposure` a live knob and gives the emitters a filmic shoulder. Symptom of getting this wrong: the rim looks pure white in screenshots even though the shader is outputting something like `vec3(1.4, 0.8, 2.1)`.

4. **Faceted / noisy iridescence on imported models.** The mesh has flat or missing normals, and the two cases need different fixes. Missing: `child.geometry.attributes.normal` is undefined (DRACO-compressed glTFs sometimes drop normals to save bytes, assuming a runtime recompute that three.js does not do) — `computeVertexNormals()` is enough. Flat-shaded: the normal attribute is present and the vertices are *split*, one set per face. Recomputing normals over split vertices yields the same faceted result, so the guard `if (!geometry.attributes.normal) computeVertexNormals()` skips exactly the case that looks worst. Weld first — `mergeVertices()` from `BufferGeometryUtils` — then recompute, and know that welding also collapses the UV and tangent splits the exporter made on purpose. Best fixed at export.

5. **The effect "looks the same" from every angle.** Either the camera isn't moving (orbit it during dev to verify), or `uFresnelPower` is so low (≤ 0.5) that the whole surface saturates to `uColorB`, or the geometry has no curvature for the normal to vary across (a flat plane will show one constant fresnel value across its entire face). Fix in priority order: orbit the camera → raise power to 2.0+ → swap the geometry for something curved.

## Reference implementation

The shipped version of this technique is the hero sculpture material in
the site the engine was extracted from:
`src/shaders/hero/sculpture.frag.glsl` and its matching
`sculpture.vert.glsl`, wired in `src/scene/scenes/home/HeroSculpture.ts`.
Read it for three decisions this recipe only describes:

- **Two lights, not zero.** A warm key plus a cool fill at 35% keeps
  back-facing slabs off dead black. A pure fresnel term over an unlit
  base gives you a glowing outline around a void; the fill is what makes
  it read as a solid object.
- **The rim is capped, not additive.** The fresnel term drives a `mix`
  toward the rim color at 60% maximum, so the silhouette accents the base
  rather than overwriting it.
- **The exponent is a uniform, and it is responsive.** 5.0 on desktop
  confines the rim to genuinely grazing angles; portrait drops to ~2.5,
  because at small pixel-per-letter sizes a thin rim disappears
  altogether. Anything tuned by eye at one viewport needs a second value
  for the other.

It also uses the same two GLSL-1 safe moves as the recipe above: the
world normal by direction transform, and the `!gl_FrontFacing` flip.

## Reference

See `references.md` → **Lusion** entry. The cylinder cluster on Lusion's homepage is the canonical implementation of this material applied with discipline: a single iridescent fresnel response across many primitives, paired with a near-black field so the rim glow registers. Copy the material restraint (one shader, three palette stops, dark base) — invent your own primitive.
