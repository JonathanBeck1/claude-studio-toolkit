# TakeTwo Shaders — Technique Recipes

Reference Claude reads when `aether-shaders` is invoked. Each recipe cites real `file:line` from the kit + site so it ages with the codebase.

**Kit vs site boundary (read first):**
- **Kit owns** (`clients/taketwo-media/kit/src/`): `DitherEffect`, `createHeroComposer`, `ShaderQuad` (backdrop primitive), `extrudedWord` (text pipeline). These are brand-agnostic — any future client can pull them.
- **Site owns** (`clients/taketwo-media/site/src/shaders/hero/`): `sculpture.vert.glsl` (iridescent fresnel + cheap-noise displacement), `sculpture.frag.glsl`, `caustics.{vert,frag}.glsl`. Brand-specific to TakeTwo. Don't promote to kit without a generalization pass (uniform-driven color palette, etc.).

**GLSL is imported via `?raw`** everywhere in the codebase. `vite-plugin-glsl` is configured in `astro.config.ts:7-12` but never used in practice. Use `?raw`, match the existing pattern.

---

## 1. Hero composer preset — bloom + dither (`kit/src/postfx/heroComposer.ts:37-62`)

```ts
export function createHeroComposer(
  renderer: THREE.WebGLRenderer,
  scene: THREE.Scene,
  camera: THREE.Camera,
  options: HeroComposerOptions = {},
): EffectComposer {
  const { enableDither = true } = options;
  const composer = new EffectComposer(renderer);

  composer.addPass(new RenderPass(scene, camera));

  const bloom = new BloomEffect({
    intensity: 0.06,             // restrained — bloom is sensed, not seen
    luminanceThreshold: 0.65,    // only the violet text core triggers it
    luminanceSmoothing: 0.2,
    mipmapBlur: true,
    kernelSize: KernelSize.MEDIUM,
  });

  const effects: Effect[] = [bloom];
  if (enableDither) effects.push(new DitherEffect());

  composer.addPass(new EffectPass(camera, ...effects));
  return composer;
}
```

Key facts:
- **LDR composer (no `frameBufferType: HalfFloatType`).** Values clip at 1.0 deliberately — this is the bloom containment strategy. Without it bloom blooms forever and you need a `ToneMappingEffect` pass to rein it in. See comment at `heroComposer.ts:23-25`.
- **Bloom intensity `0.06` is the ceiling.** Higher reads as glow-spam. If you need more visible bloom, raise `luminanceThreshold` to gate it harder, not `intensity`.
- **Quality-tier wiring:** LOW skips the composer entirely (`SceneManager` falls back to `renderer.render(scene, camera)` when `scene.composer` is undefined). MID passes `{ enableDither: false }`. HIGH uses defaults. See `heroComposer.ts:26-35`.
- **Don't parameterize beyond recognition.** Comment at `:27-29` is policy: if you need a different mood, write a second preset. Don't grow this function into a config zoo.

**When to use:** any dark TakeTwo scene with a single bright accent color that needs the felt-not-seen bloom + grain. New clients with different aesthetics get their own composer preset.

---

## 2. Dither effect — 8×8 Bayer (`kit/src/postfx/DitherEffect.ts`, `kit/src/shaders/dither.glsl`)

```ts
// kit/src/postfx/DitherEffect.ts
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

The shader at `kit/src/shaders/dither.glsl` provides `float dither8x8(vec2 fragCoord)` returning 0..1 from an 8×8 Bayer matrix. The effect adds `(d - 0.5) / 64.0` to each color channel — a barely-perceptible perturbation that breaks up gradient banding without producing visible texture noise.

**When to use:**
- Dark gradients (the TakeTwo navy backdrop is the canonical case).
- Any scene with banding visible on smooth color transitions.

**When NOT to use:**
- Already-noisy content (caustics, particles, displacement-heavy shaders). Adding dither on top is a free pass with no benefit.
- LOW tier (skip the dither pass to save the extra fullscreen blit).
- HDR composers (the `/ 64.0` constant is calibrated for LDR clipping).

**The `?raw` import** is the canonical pattern. `vite-plugin-glsl` is configured but every consumer uses `?raw` directly. Don't switch styles mid-codebase.

---

## 3. Iridescent fresnel fragment shader (`site/src/shaders/hero/sculpture.frag.glsl`)

Site-owned. TakeTwo-specific. Canonical reference for "dimensional type with iridescent rim" — the v4 hero treatment that landed.

Key passages:

**Two-light Lambert** (`:51-54`):
```glsl
vec3 keyDir  = normalize(vec3( 0.5,  1.0,  0.6));
vec3 fillDir = normalize(vec3(-0.6, -0.3,  0.4));
float lambert = max(dot(N, keyDir), 0.0)
              + max(dot(N, fillDir), 0.0) * 0.35;
```

Warm key from upper-right + cool fill from lower-left at 35%. Stops back-facing slabs from going dead-flat black. Single directional light produces a flat read on extruded type — two-light gives it sculptural depth without fighting the fresnel rim.

**Uniform-driven fresnel exponent** (`:60`):
```glsl
float fresnel = pow(1.0 - max(dot(N, V), 0.0), uFresnelExp);
```

`uFresnelExp` is a uniform (not a constant) so portrait scenes can widen the rim. Desktop default `5.0` confines rim to truly grazing angles. Portrait drops to `~2.5` so rim covers more surface and stays visible at smaller pixel-per-letter sizes. Comment at `:30-34, :56-59` is the calibration log.

**Rim color mix by normal Y** (`:72`):
```glsl
vec3 rim = mix(uColorRimA, uColorRimB, smoothstep(-0.3, 0.6, N.y));
```

Up-facing normals tilt violet (`uColorRimA`), down-facing tilt teal (`uColorRimB`). The `smoothstep(-0.3, 0.6, N.y)` window gives a gradual rather than hard transition. Brand-token-driven — change the palette in `scene/constants.ts` AND `styles/global.css` (mirrored), not in the shader.

**Final mix capped at 60% fresnel** (`:73`):
```glsl
vec3 color = mix(base, rim, fresnel * 0.6);
```

Even at full grazing angle, the rim is only 60% of the final color. Above that the rim overwrites the base and the type loses its sculptural body. 60% accents the silhouette; higher feels like a separate object floating in front.

**`uAlpha` for scroll-driven fade** (`:75`):
```glsl
gl_FragColor = vec4(color, uAlpha);
```

Driven by the canvas-dim ScrollTrigger (`HomeScene.ts:401-412`). Material has `transparent: true` set in `HeroSculpture.ts`. See `aether-scroll` recipes §5 for the trigger pattern.

**When to use:** dimensional brand-as-form treatments (hero sculptures, service-as-form chapter heads). Generalize the color palette to uniforms if porting to a future scene.

---

## 4. Cheap-noise vertex displacement (`site/src/shaders/hero/sculpture.vert.glsl`)

```glsl
float cheapNoise(vec3 p) {
  return sin(p.x * 1.7 + uTime * 0.3)
       * sin(p.y * 1.9 - uTime * 0.2)
       * sin(p.z * 2.1 + uTime * 0.25);
}

void main() {
  vec3 displaced = position;

  vec2 screenP = position.xy / max(abs(position.z) + 1.5, 0.5);
  float pointerProx = exp(-length(screenP - uPointer * 1.2) * 1.2);
  float local = uDisplacement * (1.0 + pointerProx * uPointerWarp * 2.0);

  float n = cheapNoise(position * 1.6) * local;
  displaced += normal * n * 0.14;
  // ...
}
```

Key facts:
- **Sin-based, not 3D curl noise.** Mobile perf budget. Curl noise is ~10× more expensive per vertex. Sin produces a similar visual quality for surface breathing.
- **The `0.14` multiplier** at `:42` is the displacement ceiling. Was `0.18` pre-polish — comment at `:40-41` is the log. Bevels read crisp at `0.14`; at `0.18` they blur.
- **Pointer-proximity boost** (`:33-37`) adds local displacement where the cursor is. Falloff via screen-space `exp(-length * 1.2)`. Multiplied through `uPointerWarp` (currently `1.0`, not exposed for tweaking).
- **`uDisplacement` ramps** from `INTRO_DISPLACEMENT` during the chaos animation to `FINAL_DISPLACEMENT` once assembled. Constants in `scene/constants.ts`. Drives the dispersal-to-form transition.

**When to use:** any dimensional brand-as-form treatment that needs subtle "breathing" without blurring the form itself. Tune the multiplier ceiling per scene — never higher than 0.2 on letter-extrusion geometry.

---

## 5. ExtrudedWord text pipeline (`kit/src/text/extrudedWord.ts`)

```ts
import { extrudedWord } from 'aether/text';

const result = extrudedWord('TAKETWO', {
  fontUrl: '/fonts/Staatliches-Regular.ttf',
  depth: 16,
  bevelEnabled: true,
  bevelThickness: 1.2,
  bevelSize: 0.8,
  bevelSegments: 8,
  curveSegments: 10,
});
```

Three-pass pipeline (`extrudedWord.ts:95-198`):
1. Build per-glyph extrusions (`:127-151`) — opentype loads the TTF, converts each glyph to SVG path, SVGLoader handles glyph holes (counters in 'O', 'A'), ExtrudeGeometry produces the mesh.
2. Compute word bbox (`:155-168`).
3. Centre + flip Y (TTF coords are Y-up, three.js is Y-up but glyph paths invert) + record per-letter `assembledPosition` / `assembledScale` for animation choreography (`:173-195`).

**Defaults** (`extrudedWord.ts:50-58`):
- `depth: 16` — extrusion depth in world units.
- `bevelEnabled: true, bevelThickness: 1.2, bevelSize: 0.8, bevelSegments: 8` — 8-segment bevel gives smooth shading without exploding the polygon count.
- `curveSegments: 10` — glyph curve resolution. Lower (4-6) for performance, higher (16+) for hero-tier display.

**Per-letter handles** for animation:
- `result.letters[i].assembledPosition` — where the letter sits when the word is assembled. Use as the target for intro reveal.
- `result.letters[i].assembledScale` — final scale at assembled state.
- Each letter is its own mesh — can be animated independently.

**MSDF not yet in the kit.** Roadmap is `troika-three-text` at `kit/README.md:133`. Until then, `extrudedWord` is the canonical text path. Don't reach for an MSDF library mid-feature — that's a kit-level decision.

**When to use:**
- Hero: brand-as-form (`TAKETWO`).
- Service pages: service-as-form (`WEB`, `SOFTWARE`, `AI` — per `brain/design-taste.md`).
- Section titles where dimensional type sells the premium frame.

**When NOT to use:**
- Body copy. Use HTML + CSS.
- Anything that needs to wrap. ExtrudeGeometry doesn't.
- Anything that needs to be screen-reader accessible. The DOM stays empty — provide an `aria-label`-bearing wrapper for accessibility.

---

## 6. ShaderQuad backdrop primitive (`kit/src/primitives/ShaderQuad.ts:56-110`)

```ts
import { ShaderQuad } from 'aether/primitives';
import frag from './my-backdrop.frag.glsl?raw';

const backdrop = new ShaderQuad({
  fragmentShader: frag,
  uniforms: {
    uColor: { value: new THREE.Color('#0a0e1a') },
  },
});
scene.add(backdrop.mesh);
```

Key facts:
- **Geometry:** `PlaneGeometry(50, 32)` at `z=-8`. Big enough to fill viewport at any reasonable FOV.
- **`renderOrder = -10`, `depthWrite = false`, `depthTest = false`, `frustumCulled = false`.** Always renders first, doesn't write to depth buffer, doesn't cull. The "draw everything behind everything else" pattern.
- **Auto-wired uniforms:** `uTime` (advances per frame, `:99`) and `uAspect` (viewport width/height, `:104`). Don't declare these manually — `ShaderQuad` handles them.

**When to use:** any full-viewport shader backdrop. Caustics, gradients, generative wallpapers. The TakeTwo hero's caustics layer sits on its own class (`HeroCaustics`) but follows this pattern.

**When NOT to use:** anything the user needs to read or interact with (text, buttons, cards). Those are regular meshes with proper depth.

---

## 7. New ShaderMaterial — procedure

When adding a new ShaderMaterial to a TakeTwo scene:

1. **Confirm against the slop checklist** in `aether-threejs` skill. Custom shader is the answer to "no MeshBasicMaterial / MeshStandardMaterial on hero elements."
2. **GLSL files live next to the consumer.** Site-specific shaders go in `site/src/shaders/<scene>/`. Reusable shaders (likely none until a second client) go in `kit/src/shaders/`.
3. **Import via `?raw`:** `import frag from './x.frag.glsl?raw'`.
4. **Wire `uTime` through the scene's tick method** — your tick reads `time` and writes `material.uniforms.uTime.value = time` (or use `tickUniforms` on a wrapping class as `HeroSculpture` does).
5. **Brand tokens through uniforms.** Pull colors from `scene/constants.ts`, not hardcoded vec3s in the shader. Update `global.css` if the token changes.
6. **Add `precision highp float;`** at the top of fragment shaders explicitly. three.js prepends it by default but stating it inline makes the intent durable across pipeline changes (`sculpture.frag.glsl:20-23` is the example).
7. **Test against postprocessing.** If your material relies on values > 1.0, the LDR composer clips them. Either rework to stay in 0..1 (preferred) or skip the hero composer for this scene.

---

## 8. Slop indicators (do not ship)

- `MeshBasicMaterial` or `MeshStandardMaterial` on hero elements.
- Bloom `intensity > 0.1`.
- Bloom `luminanceThreshold < 0.5` (whole scene blooms).
- Hardcoded `vec3(...)` colors in shaders instead of brand-token uniforms.
- Ambient particle fields (covered by `aether-threejs` and `brain/design-taste.md`).
- Custom material without `uTime` wired through the manager's tick.
- `dat.gui` left in production builds.
- `console.log` inside shader hot paths.
- ExtrudedWord with `curveSegments < 6` on a hero treatment (visible polygon edges on glyph curves).
- Iridescent rim without the dual-color mix (`uColorRimA` ↔ `uColorRimB` by normal Y) — single-color rim reads as ChromaKey, not iridescence.
- Promoting `sculpture.{vert,frag}.glsl` to the kit without generalizing the color palette to uniforms.

---

## 9. Pitfalls (read before debugging shader issues)

- **Bloom looks blown out / hazy.** LDR composer is at the ceiling. Don't raise `intensity`; raise `luminanceThreshold` to gate harder.
- **Type ghosts (front face + bevel reading as two letters).** Fresnel exponent too low (rim spreading onto bevel surfaces). Raise `uFresnelExp` toward 5.0. See `sculpture.frag.glsl:30-34`.
- **Banding on backdrop gradient.** Add `DitherEffect` to the composer. If already present, banding may be on the source gradient — check the actual colors aren't truly close enough to trigger gradient quantization.
- **Vertex displacement blurs the form.** Multiplier too high. Cap at 0.14 on letter-extrusion geometry; lower on smaller details.
- **Material doesn't fade on scroll.** Forgot `transparent: true` on the material, OR `uAlpha` uniform isn't wired to the scroll trigger. See `aether-scroll` recipes §5 for the canvas-dim trigger.
- **`?raw` import returns undefined.** `optimizeDeps.exclude: ['aether']` missing in `astro.config.ts`. Required for the kit's `?raw` consumers to work — without it esbuild pre-bundling chokes on the import syntax.
- **GLSL changes don't hot-reload.** `vite-plugin-glsl`'s `compress` is `false` in dev (`astro.config.ts:11`) — but you're using `?raw`, which doesn't go through the plugin. HMR works via Vite's normal asset-watch. If broken, the dev server needs a restart.

---

## File-line citation index

For grep-friendly verification:

- `clients/taketwo-media/kit/src/postfx/heroComposer.ts:37-62` — composer factory
- `clients/taketwo-media/kit/src/postfx/heroComposer.ts:48-54` — bloom params
- `clients/taketwo-media/kit/src/postfx/heroComposer.ts:23-25` — LDR rationale
- `clients/taketwo-media/kit/src/postfx/DitherEffect.ts:2-10` — dither pass setup
- `clients/taketwo-media/kit/src/shaders/dither.glsl` — Bayer matrix function
- `clients/taketwo-media/site/src/shaders/hero/sculpture.frag.glsl:51-54` — two-light Lambert
- `clients/taketwo-media/site/src/shaders/hero/sculpture.frag.glsl:60` — uniform fresnel exponent
- `clients/taketwo-media/site/src/shaders/hero/sculpture.frag.glsl:72` — rim color mix
- `clients/taketwo-media/site/src/shaders/hero/sculpture.frag.glsl:73` — 60% rim cap
- `clients/taketwo-media/site/src/shaders/hero/sculpture.vert.glsl:24-28` — cheapNoise function
- `clients/taketwo-media/site/src/shaders/hero/sculpture.vert.glsl:42` — 0.14 multiplier
- `clients/taketwo-media/kit/src/text/extrudedWord.ts:50-58` — extrude defaults
- `clients/taketwo-media/kit/src/text/extrudedWord.ts:127-198` — three-pass pipeline
- `clients/taketwo-media/kit/src/primitives/ShaderQuad.ts:56-110` — backdrop primitive
- `clients/taketwo-media/kit/README.md:133` — MSDF roadmap (troika-three-text)
