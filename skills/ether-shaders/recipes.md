# Shaders — Technique Recipes

Reference Claude reads when `ether-shaders` is invoked. Engine cites are ether repo paths (`src/...`). The site-side recipes (§3, §4) describe the pattern a production hero material uses; that shader is private, so the snippets are illustrative skeletons with the tuning left to you, not copies.

**Engine vs site boundary (read first):**
- **Engine owns** (`src/`): `DitherEffect`, `createHeroComposer` / `createNightComposer`, `ShaderQuad` (backdrop primitive), `extrudedWord` (text pipeline). Brand-agnostic.
- **Your site owns** (`src/shaders/<scene>/`): the hero material (fresnel rim + displacement) and backdrop shaders. Brand identity lives here. Don't promote to the engine without a generalization pass (uniform-driven palette, etc.).

**GLSL is imported via `?raw`** everywhere. Match that pattern even if `vite-plugin-glsl` is configured.

---

## 1. Hero composer preset — bloom + dither (`src/postfx/heroComposer.ts`)

```ts
export function createHeroComposer(renderer, scene, camera, options: HeroComposerOptions = {}): HeroComposer {
  const { enableDither = true, multisampling = 0 } = options;
  const composer = new EffectComposer(renderer, { multisampling });
  composer.addPass(new RenderPass(scene, camera));

  const bloom = new BloomEffect({
    intensity: 0.06,             // restrained — bloom is sensed, not seen
    luminanceThreshold: 0.65,    // only the bright accent core triggers it
    luminanceSmoothing: 0.2,
    mipmapBlur: true,
    kernelSize: KernelSize.MEDIUM,
  });

  const dither = enableDither ? new DitherEffect() : undefined;
  composer.addPass(new EffectPass(camera, ...(dither ? [bloom, dither] : [bloom])));
  return { composer, bloom, dither };
}
```

Key facts:
- **LDR composer (no `frameBufferType: HalfFloatType`).** Values clip at 1.0 deliberately — this is the bloom containment strategy. `createNightComposer` is the HDR variant (`hdr: true` → half-float buffers + ACES tone mapping) for scenes whose light IS emissive geometry.
- **Bloom intensity `0.06` is the ceiling** for the hero preset. Higher reads as glow-spam. If you need more visible bloom, raise `luminanceThreshold` to gate it harder, not `intensity`.
- **Quality-tier wiring:** every tier runs the composer; the per-tier differences live in the quality profile. Pass `{ enableDither: quality.enableDither, multisampling: quality.msaaSamples }` — composer MSAA is the antialiasing that actually reaches the screen once passes render to textures.
- **Don't parameterize beyond recognition.** If you need a different mood, write a second preset. Don't grow this function into a config zoo.
- **Returns `{ composer, bloom, dither }`** so a tweaks panel can bind `bloom.intensity` live.

**When to use:** any dark scene with a single bright accent that needs the felt-not-seen bloom + grain. Different aesthetics get their own preset.

---

## 2. Dither effect — 8×8 Bayer (`src/postfx/DitherEffect.ts`, `src/shaders/dither.glsl`)

```ts
import { Effect, BlendFunction } from 'postprocessing';
import dither from '../shaders/dither.glsl?raw';

const ditherFragment = /* glsl */`
  ${dither}
  void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
    float d = dither8x8(gl_FragCoord.xy);
    outputColor = vec4(inputColor.rgb + (d - 0.5) / 64.0, inputColor.a);
  }
`;

export class DitherEffect extends Effect {
  constructor() {
    super('DitherEffect', ditherFragment, { blendFunction: BlendFunction.NORMAL });
  }
}
```

`src/shaders/dither.glsl` provides `float dither8x8(vec2 fragCoord)` returning 0..1 from an 8×8 Bayer matrix. The effect adds `(d - 0.5) / 64.0` to each color channel — a barely-perceptible perturbation that breaks up gradient banding without producing visible texture noise.

**When to use:**
- Dark gradients (a navy backdrop is the canonical case).
- Any scene with banding visible on smooth color transitions.
- Every quality tier — it merges into bloom's fullscreen pass, so it is effectively free.

**When NOT to use:**
- Already-noisy content (caustics, particles, displacement-heavy shaders). Adding dither on top is a free pass with no benefit.
- HDR composers (the `/ 64.0` constant is calibrated for LDR clipping).

---

## 3. Iridescent fresnel rim material — pattern (site-owned)

The "dimensional type with iridescent rim" treatment, as a pattern. Tune the constants yourself against your renders; the values that make a given brand read are part of that brand's shader.

```glsl
precision highp float;

uniform vec3 uColorBase, uColorRimA, uColorRimB, uColorAccent;
uniform float uFresnelExp;   // rim sharpness — a uniform so portrait can widen it
uniform float uAlpha;        // scroll-driven master alpha (material: transparent = true)

varying vec3 vNormal;
varying vec3 vViewDir;

void main() {
  vec3 N = normalize(vNormal);
  if (!gl_FrontFacing) N = -N;               // light the inside of letters correctly
  vec3 V = normalize(vViewDir);

  // Two lights: a warm key plus a dimmer cool fill so back-facing slabs never go dead-black.
  float lambert = max(dot(N, KEY_DIR), 0.0) + max(dot(N, FILL_DIR), 0.0) * FILL_STRENGTH;

  // Grazing-angle rim, exponent-shaped.
  float fresnel = pow(1.0 - max(dot(N, V), 0.0), uFresnelExp);

  // Dual-color rim by surface orientation — up-facing tilts one accent, down-facing the other.
  vec3 rim = mix(uColorRimA, uColorRimB, smoothstep(-0.3, 0.6, N.y));

  vec3 base = uColorBase * AMBIENT + uColorBase * lambert * KEY_GAIN
            + uColorAccent * ACCENT_GAIN * smoothstep(ACCENT_LO, 1.0, lambert);

  // Cap the rim mix well below 1.0 so it accents the silhouette instead of replacing the body.
  gl_FragColor = vec4(mix(base, rim, fresnel * RIM_CAP), uAlpha);
}
```

Principles:
- **Two lights, not one.** A single directional light produces a flat read on extruded type; a dim cool fill gives sculptural depth without fighting the rim.
- **Uniform-driven fresnel exponent.** High on desktop confines the rim to truly grazing angles and avoids the "ghost letter" read where lit bevels register as a second glyph; lower in portrait so the rim stays visible at small pixel-per-letter sizes.
- **Dual-color rim by normal Y.** A single-color rim reads as chroma-key, not iridescence.
- **Cap the rim mix.** Past roughly half, the rim overwrites the base and the type loses its body — it starts to read as a separate object floating in front.
- **`uAlpha` for scroll-driven fade,** driven by a ScrollTrigger (see `ether-scroll` §5), with `transparent: true` on the material.
- **Colors arrive as uniforms** from the site's constants module — never hardcoded vec3s.

**When to use:** dimensional brand-as-form treatments — the brand mark itself as the hero subject. The same material on a generic word reads as a copy; brand-as-form works when the subject IS the brand.

---

## 4. Cheap-noise vertex displacement — pattern (site-owned)

```glsl
uniform float uTime, uDisplacement, uPointerWarp;
uniform vec2 uPointer;

float cheapNoise(vec3 p) {
  return sin(p.x * FX + uTime * TX) * sin(p.y * FY - uTime * TY) * sin(p.z * FZ + uTime * TZ);
}

void main() {
  // Pointer proximity in a screen-ish projection boosts displacement locally.
  vec2 screenP = position.xy / max(abs(position.z) + DEPTH_BIAS, 0.5);
  float pointerProx = exp(-length(screenP - uPointer * POINTER_SCALE) * FALLOFF);
  float local = uDisplacement * (1.0 + pointerProx * uPointerWarp * WARP_GAIN);

  vec3 displaced = position + normal * cheapNoise(position * FREQ) * local * CEILING;
  // ... project as usual
}
```

Principles:
- **Sin-based, not 3D curl noise.** Mobile perf budget: roughly an order of magnitude cheaper per vertex, and a similar read for surface "breathing".
- **A displacement ceiling.** Find the value where bevels still read crisp; past it they blur. When you change it, log the old and new numbers in a comment.
- **Pointer-proximity boost** — influence felt more than seen; the form never visibly chases the cursor.
- **`uDisplacement` ramps** from an intro value to a rest value — this drives the dispersal-to-form transition; keep both in the constants module.

---

## 5. ExtrudedWord text pipeline (`src/text/extrudedWord.ts`)

```ts
import { extrudedWord } from 'ether/text';

const letters = await extrudedWord('HELLO', '/fonts/display.ttf', {
  fontSize: 100,          // opentype path-coordinate size (default 100)
  capHeightRatio: 0.7,    // cap height / em for the face
  targetCapHeight: 1,     // world units the cap height should occupy
  extrude: { depth: 16, bevelEnabled: true, bevelThickness: 1.2, bevelSize: 0.8, bevelSegments: 8, curveSegments: 10 },
});

for (const l of letters) {
  // l.char, l.geometry (ExtrudeGeometry), l.assembledPosition, l.assembledScale
}
```

Three-pass pipeline:
1. Per-glyph extrusions — opentype loads the TTF (or takes a loaded `Font`), converts each glyph to an SVG path, `SVGLoader` handles glyph holes (counters in O, A), `ExtrudeGeometry` produces the mesh.
2. Word bounding box.
3. Centre + flip + record per-letter `assembledPosition` / `assembledScale` for animation choreography.

**Defaults:** `depth: 16`; `bevelEnabled: true, bevelThickness: 1.2, bevelSize: 0.8, bevelSegments: 8` — an 8-segment bevel gives smooth shading without exploding the polygon count; `curveSegments: 10` — lower (4–6) for performance, higher (16+) for hero-tier display.

**Per-letter handles** for animation: each letter is its own geometry — use `assembledPosition` as the intro's target pose and animate letters independently.

**MSDF is not in the engine.** For crisp flat type at viewport scale see the `msdf-typography` technique in `ether-threejs`. `extrudedWord` is the dimensional-type path.

**When to use:** hero brand-as-form; section titles where dimensional type sells the premium frame.

**When NOT to use:**
- Body copy. Use HTML + CSS.
- Anything that needs to wrap. ExtrudeGeometry doesn't.
- Anything that must be screen-reader accessible without extra work — the DOM stays empty, so provide an `aria-label`-bearing wrapper.

---

## 6. ShaderQuad backdrop primitive (`src/primitives/ShaderQuad.ts`)

```ts
import { ShaderQuad } from 'ether/primitives';
import frag from './my-backdrop.frag.glsl?raw';

const backdrop = new ShaderQuad({
  fragmentShader: frag,
  uniforms: {
    uColor: { value: new THREE.Color('#101418') },
  },
});
scene.add(backdrop.mesh);
```

Key facts:
- **Geometry:** a large plane behind the scene, big enough to fill the viewport at any reasonable FOV.
- **`renderOrder = -10`, `depthWrite = false`, `depthTest = false`, `frustumCulled = false`.** Always renders first, never writes depth, never culls — the "draw everything behind everything else" pattern.
- **Auto-wired uniforms:** `uTime` (advances per frame) and `uAspect` (viewport width/height). Don't declare these manually.

**When to use:** any full-viewport shader backdrop — caustics, gradients, generative wallpapers. A site's caustics layer can wrap this in its own class and follow the same pattern.

**When NOT to use:** anything the user needs to read or interact with (text, buttons, cards). Those are regular meshes with proper depth.

---

## 7. New ShaderMaterial — procedure

1. **Confirm against the slop checklist** in `ether-threejs`. A custom shader is the answer to "no MeshBasicMaterial / MeshStandardMaterial on hero elements."
2. **GLSL files live next to the consumer.** Site-specific shaders go in `src/shaders/<scene>/`. Reusable shaders (likely none until a second consumer) go in the engine's `src/shaders/`.
3. **Import via `?raw`:** `import frag from './x.frag.glsl?raw'`.
4. **Wire `uTime` through the scene's tick method** — your tick reads `time` and writes `material.uniforms.uTime.value = time` (or use a `tickUniforms` method on a wrapping class).
5. **Brand tokens through uniforms.** Pull colors from your constants module, not hardcoded vec3s in the shader. If tokens are mirrored in CSS, update both.
6. **Add `precision highp float;`** at the top of fragment shaders explicitly.
7. **Test against postprocessing.** If your material relies on values > 1.0, the LDR composer clips them. Either rework to stay in 0..1 (preferred) or use the night preset.

---

## 8. Slop indicators (do not ship)

- `MeshBasicMaterial` or `MeshStandardMaterial` on hero elements.
- Bloom `intensity > 0.1` on the hero preset.
- Bloom `luminanceThreshold < 0.5` (whole scene blooms).
- Hardcoded `vec3(...)` colors in shaders instead of token uniforms.
- Ambient particle fields with no narrative function (see `ether-threejs`).
- Custom material without `uTime` wired through the engine's tick.
- `dat.gui` left in production builds.
- `console.log` inside shader hot paths.
- ExtrudedWord with `curveSegments < 6` on a hero treatment (visible polygon edges on glyph curves).
- Iridescent rim without the dual-color mix by normal direction — a single-color rim reads as chroma-key, not iridescence.
- Promoting a site shader to the engine without generalizing the color palette to uniforms.

---

## 9. Pitfalls (read before debugging shader issues)

- **Bloom looks blown out / hazy.** The LDR composer is at its ceiling. Don't raise `intensity`; raise `luminanceThreshold` to gate harder.
- **Type ghosts (front face + bevel reading as two letters).** Fresnel exponent too low (rim spreading onto bevel surfaces). Raise `uFresnelExp`.
- **Banding on the backdrop gradient.** Add `DitherEffect` to the composer. If already present, the banding may be on the source gradient — check the colors aren't so close that quantization is inevitable.
- **Vertex displacement blurs the form.** Multiplier past the ceiling. Lower it on letter-extrusion geometry; lower still on small details.
- **Material doesn't fade on scroll.** Forgot `transparent: true` on the material, OR the `uAlpha` uniform isn't wired to the scroll trigger. See `ether-scroll` §5.
- **`?raw` import returns undefined.** `optimizeDeps.exclude: ['ether']` missing in your Vite/Astro config. Without it esbuild pre-bundling chokes on the import syntax.
- **GLSL changes don't hot-reload.** `?raw` imports go through Vite's normal asset watch, not `vite-plugin-glsl`. If HMR is stuck, restart the dev server.

---

## Engine citation index

- `src/postfx/heroComposer.ts` — `createHeroComposer` (LDR bloom + dither), `createNightComposer` (HDR/ACES variant)
- `src/postfx/DitherEffect.ts` — dither pass
- `src/shaders/dither.glsl` — Bayer matrix function
- `src/text/extrudedWord.ts` — `extrudedWord(word, fontSource, options)` + `ExtrudedLetter`
- `src/primitives/ShaderQuad.ts` — backdrop primitive
