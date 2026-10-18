# Shaders — Technique Recipes

Reference Claude reads when `ether-shaders` is invoked. Engine cites are ether repo paths (`src/...`). The site-side recipes (§3, §4) describe the pattern a production hero material uses; that shader is private, so the snippets are illustrative skeletons with the tuning left to you, not copies.

**Engine vs site boundary (read first):**
- **Engine owns** (`src/`): `DitherEffect`, `createHeroComposer` / `createNightComposer`, `ShaderQuad` (backdrop primitive), `extrudedWord` (text pipeline). Brand-agnostic.
- **Your site owns** (`src/shaders/<scene>/`): the hero material (fresnel rim + displacement) and backdrop shaders. Brand identity lives here. Don't promote to the engine without a generalization pass (uniform-driven palette, etc.).

**Follow the project's configured shader import convention** (`vite-plugin-glsl`, `?raw`, or inline strings). When adding a shader, use what the codebase already does; don't mix strategies without a reason. The engine's own sources use `?raw`, which is why a git / `file:` install needs `optimizeDeps.exclude: ['ether']`. Samples below use `?raw` as the example.

---

## 1. Hero composer preset — bloom + dither (`src/postfx/heroComposer.ts`, chain in `src/postfx/composer.ts`)

A preset is a *tuning*, not a composer. It picks its effects and hands them to `createComposer`; that function owns the chain.

```ts
export function createHeroComposer(
  renderer: THREE.WebGLRenderer,
  scene: THREE.Scene,
  camera: THREE.Camera,
  options: PresetOptions = {},
): BloomComposer {
  const bloom = new BloomEffect({
    intensity: 0.06,             // restrained — bloom is sensed, not seen
    luminanceThreshold: 0.65,    // only the bright accent core triggers it
    luminanceSmoothing: 0.2,
    mipmapBlur: true,
    kernelSize: KernelSize.MEDIUM,
  });
  return { ...createComposer(renderer, scene, camera, { ...options, effects: [bloom] }), bloom };
}
```

Key facts:
- **`createComposer` is the one composer shape.** One `RenderPass`, then ONE `EffectPass` fusing your effects → (ACES when `hdr`) → dither. `postprocessing` merges them into a single shader, so an extra effect costs ALU, not a render target. Reach for `createComposer` directly when a preset's tuning is wrong for your scene.
- **LDR by design.** `createHeroComposer` never passes `hdr`, so buffers stay 8-bit and values clip at 1.0 — that clipping IS the bloom containment. `hdr` lives on `ComposerOptions`; among the presets only `createNightComposer` re-exposes it (`NightComposerOptions`). It switches on half-float buffers plus an ACES `ToneMappingEffect`, which is also what makes `toneMappingExposure` a live knob instead of a dead one.
- **Bloom intensity `0.06` is the ceiling** for the hero preset. Higher reads as glow-spam. If you need more visible bloom, raise `luminanceThreshold` to gate it harder, not `intensity`.
- **Quality-tier wiring:** every tier runs the composer *with* dither — the profile ships `enablePostFX: true` and `enableDither: true` on LOW, MID and HIGH alike, and the only per-tier difference is `msaaSamples` (HIGH 4 / MID 2 / LOW 0). Pass `{ enableDither: quality.enableDither, multisampling: quality.msaaSamples }` and let the profile decide; composer MSAA is the antialiasing that actually reaches the screen once passes render to textures.
- **Don't parameterize beyond recognition.** If you need a different mood, write a second preset on `createComposer`. Don't grow this function into a config zoo.
- **Returns `BloomComposer`** — `{ composer, effects, dither?, bloom }` — so a tweaks panel can bind `bloom.intensity` live.

**When to use:** any dark scene with a single bright accent that needs the felt-not-seen bloom + grain. Different aesthetics get their own preset: `createNightComposer` for scenes whose light IS emissive geometry (hotter bloom, `LARGE` kernel, optional HDR), `createLightComposer` for a pale ground where bloom would just lift the whole field (dither only).

---

## 2. Dither effect — per-pixel hash grain (`src/postfx/DitherEffect.ts`)

```ts
import { Effect, BlendFunction } from 'postprocessing';

const ditherFragment = /* glsl */`
  void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
    // Effects run in linear light and the pass encodes to sRGB afterwards, so the
    // noise goes in through the encoded domain: one output step peak to peak at
    // every luminance, where the same amount in linear was several steps in the darks.
    float seed = floor(time * 6.0);
    float d = fract(sin(dot(gl_FragCoord.xy + vec2(fract(seed * 0.73) * 61.0, fract(seed * 0.91) * 83.0), vec2(12.9898, 78.233))) * 43758.5453);
    vec3 encoded = sRGBTransferOETF(vec4(inputColor.rgb, 1.0)).rgb + (d - 0.5) / 255.0;
    outputColor = vec4(sRGBTransferEOTF(vec4(encoded, 1.0)).rgb, inputColor.a);
  }
`;

export class DitherEffect extends Effect {
  constructor() {
    super('DitherEffect', ditherFragment, { blendFunction: BlendFunction.NORMAL });
  }
}
```

Three things make this correct rather than merely noisy:
- **It perturbs in the encoded domain, not in linear light.** Effects run linear and the pass encodes to sRGB afterwards, so the grain is applied through `sRGBTransferOETF` and undone with `sRGBTransferEOTF`. The amplitude `(d - 0.5) / 255.0` is therefore **one output step peak to peak at every luminance** — uniform across the ramp. The same amount added in linear light was worth several output steps in the darks and almost nothing in the highlights, which is the bug this replaced.
- **Per-pixel hash, not an ordered matrix.** A `sin`/`fract` hash of `gl_FragCoord`, so there is no 8×8 tile to catch the eye as texture.
- **Reseeded ~6×/second** (`floor(time * 6.0)`), so the grain moves slowly instead of freezing into a fixed pattern on a static frame.

**Not the Bayer chunk.** `ether/shaders` ships a standalone 8×8 ordered matrix (`dither8x8`, in `src/shaders/dither.glsl`) for use inside *your own* materials. `DitherEffect` does not use it — don't wire one up expecting the other.

**When to use:**
- Dark gradients — a deep, near-black backdrop is the canonical case.
- Any scene with banding visible on smooth color transitions.
- Every quality tier, and every preset — it merges into the same fullscreen pass as bloom, so it is effectively free.

**When NOT to use:**
- Already-noisy content (caustics, particles, displacement-heavy shaders). Adding dither on top is a free pass with no benefit.

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

**MSDF ships in the engine too — pick the right one.** `msdfText` lives at `ether/text/msdf` (`src/text/msdf/index.ts`), its own entry point so the optional `troika-three-text` peer is pulled in only by sites that import it. It returns `Promise<MSDFText>` — `{ mesh, dispose }` — resolved once troika's glyph atlas is ready, so the first frame it renders is complete.

```ts
import { msdfText } from 'ether/text/msdf';

const caption = await msdfText({ text: 'Chapter One', font: '/fonts/display.woff', fontSize: 0.4 });
scene.add(caption.mesh);
```

Serve your own font file (`.ttf` / `.otf` / `.woff` — troika's parser does not read woff2); the URL is preflighted and its first bytes checked, so an unreachable URL, a woff2, or an HTML page served in its place rejects instead of hanging forever. Characters your font doesn't cover fall back to troika's unicode-font-resolver, whose data comes from jsDelivr unless you set `unicodeFontsURL` to your own copy; if that fetch is blocked, the call rejects after `timeoutMs` (default 10000). Raise `sdfGlyphSize` from its default 64 to 128 when the camera ranges close enough to read the glyph edge. Pass your own `material` and troika derives an MSDF-aware variant of it, so a custom `ShaderMaterial` keeps its identity.

**`extrudedWord` is type as FORM; `msdfText` is type as TEXT** — legible copy inside the scene: captions, chapter heads, UI in the world.

**When to use:** hero brand-as-form; section titles where dimensional type sells the premium frame.

**When NOT to use:**
- Body copy. Use HTML + CSS.
- Anything that needs to wrap. ExtrudeGeometry doesn't.
- Anything that must be screen-reader accessible without extra work — the DOM stays empty, so provide an `aria-label`-bearing wrapper.

---

## 6. ShaderQuad backdrop primitive (`src/primitives/ShaderQuad.ts`)

```ts
import { ShaderQuad } from 'ether/primitives';
import vert from './my-backdrop.vert.glsl?raw';
import frag from './my-backdrop.frag.glsl?raw';

const backdrop = new ShaderQuad({
  vertexShader: vert,     // required — there is no default passthrough
  fragmentShader: frag,
  uniforms: {
    // Placeholder. Real values come from your site's constants module.
    uBaseColor: { value: new THREE.Color('#101418') },
  },
});
scene.add(backdrop.mesh);
// per frame / on resize / on teardown
backdrop.tick(elapsed);
backdrop.resize(w, h);
backdrop.dispose();
```

Key facts:
- **Geometry:** a `PlaneGeometry`, `width` 50 × `height` 32 at `z = -8` by default — oversized to overshoot the frustum at any reasonable FOV. All three are options.
- **`renderOrder = -10`, `depthWrite = false`, `depthTest = false`, `frustumCulled = false`** by default. Always renders first, never writes depth, never culls — the "draw everything behind everything else" pattern.
- **Auto-wired uniforms:** `uTime` (written by `tick(time)`) and `uAspect` (written by `resize(w, h)`). Don't declare these in `uniforms` — the class adds them.
- **Colors are yours, not the primitive's.** `ShaderQuad` owns the wiring; the palette arrives as uniforms from the consuming site. A site's caustics layer wraps this class and injects its own base/hint colors.

**When to use:** any full-viewport shader backdrop — caustics, gradients, generative wallpapers. A site's caustics layer can wrap this in its own class and follow the same pattern.

**When NOT to use:** anything the user needs to read or interact with (text, buttons, cards). Those are regular meshes with proper depth.

---

## 7. New ShaderMaterial — procedure

1. **Confirm against the slop checklist** in `ether-threejs`. A custom shader is the answer to "no MeshBasicMaterial / MeshStandardMaterial on hero elements."
2. **GLSL files live next to the consumer.** Site-specific shaders go in `src/shaders/<scene>/`. Reusable shaders (likely none until a second consumer) go in the engine's `src/shaders/`.
3. **Import by the project's existing convention** — e.g. `?raw`: `import frag from './x.frag.glsl?raw'`.
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
- **Banding on the backdrop gradient.** Add `DitherEffect` to the composer (`enableDither` defaults true on `createComposer`, so this usually means the composer isn't running at all). If it IS present, the banding is on the source gradient — check the colors aren't so close that quantization is inevitable. Don't reach for the `dither8x8` Bayer chunk here; that's for use inside a material, and the effect already covers the frame.
- **Vertex displacement blurs the form.** Multiplier past the ceiling. Lower it on letter-extrusion geometry; lower still on small details.
- **Material doesn't fade on scroll.** Forgot `transparent: true` on the material, OR the `uAlpha` uniform isn't wired to the scroll trigger. See `ether-scroll` §5.
- **`?raw` import returns undefined.** `optimizeDeps.exclude: ['ether']` missing in your Vite/Astro config. Without it esbuild pre-bundling chokes on the import syntax.
- **GLSL changes don't hot-reload.** `?raw` imports go through Vite's normal asset watch, not `vite-plugin-glsl`. If HMR is stuck, restart the dev server.

---

## Engine citation index

Cite the file and the symbol, never a line number — these files move.

- `src/postfx/composer.ts` — `createComposer` + `ComposerOptions` / `Composer`. The actual chain every preset runs through.
- `src/postfx/heroComposer.ts` — `createHeroComposer` (restrained LDR bloom), `createNightComposer` (hotter bloom for emissive-heavy scenes, optional `hdr`), `createLightComposer` (dither only); `PresetOptions`, `NightComposerOptions`, `BloomComposer`.
- `src/postfx/DitherEffect.ts` — `DitherEffect`, the per-pixel hash grain applied through the sRGB transfer.
- `src/shaders/dither.glsl` — standalone `dither8x8` Bayer matrix chunk for your own materials. Not used by `DitherEffect`.
- `src/quality/quality.ts` — `detectQuality` / `QualityProfile`. Where `enablePostFX`, `enableDither` and `msaaSamples` are actually decided.
- `src/text/extrudedWord.ts` — `extrudedWord(word, fontSource, options)` → `Promise<ExtrudedLetter[]>`.
- `src/text/msdf/index.ts` — `msdfText(options)` → `Promise<MSDFText>`, exported as `ether/text/msdf`.
- `src/primitives/ShaderQuad.ts` — backdrop primitive.
