# Postprocessing Chain (`ether/postfx` over vanruesc `postprocessing`)

## When to use

Use a postprocessing chain when the raw three.js render needs color grading, controlled bloom on bright highlight peaks, or dithering to kill gradient banding on dark-field hero scenes. A single `EffectPass` merges every effect into one fragment shader at compile time, so adding an effect costs ALU, not an extra render target.

This is the right pattern for: a dark hero scene with one bright accent, an emissive-heavy night scene whose light *is* geometry, any page where a visible gradient bands on low-bit-depth displays, any page where bloom is required to give bright highlights somewhere to go.

This is the wrong pattern for: landing pages where the 3D element is low-complexity and already band-free, pages where there is no 3D scene at all (don't create a WebGL canvas just for postprocessing), any context where the extra GPU cost exceeds the render budget. If you only need one effect, ask whether a CSS filter handles it before wiring a composer.

Never use three.js's built-in `EffectComposer` from `three/examples/jsm/postprocessing/EffectComposer.js`. It runs each effect in its own full-screen pass and does not merge them. Use the vanruesc `postprocessing` library — every effect inside a single `EffectPass` is merged at compile time into one fragment shader.

## Use the engine's composer, not a hand-rolled one

`ether/postfx` owns composer construction. There is one composer shape — **render → your effects → (ACES when `hdr`) → (dither)** — and three presets that are tunings of it. Reach for a preset when its tuning fits your scene; reach for `createComposer` when it doesn't. Do not assemble `EffectComposer` / `RenderPass` / `EffectPass` by hand in scene code — you will re-derive the ordering, the dither, and the half-float decision, and get one of them wrong.

| Export | Chain | Bloom tuning | Use for |
|---|---|---|---|
| `createHeroComposer` | render → bloom → dither | `intensity 0.06`, `luminanceThreshold 0.65`, `luminanceSmoothing 0.2`, `mipmapBlur`, `KernelSize.MEDIUM` | Dark scene, one bright accent (luminous type, a lit mark). LDR by design. |
| `createNightComposer` | render → bloom → (ACES) → dither | `intensity 0.38`, `luminanceThreshold 0.62`, `luminanceSmoothing 0.25`, `mipmapBlur`, `KernelSize.LARGE` | Emissive-heavy scenes (neon, lit windows). Accepts `hdr`. |
| `createLightComposer` | render → dither | none | Pale grounds. Bloom on a pale field blooms the field. |
| `createComposer` | render → your `effects` → (ACES when `hdr`) → (dither) | whatever you pass | Anything the presets mis-tune. LUT grades go here. |

The hero preset's `0.06` is not a placeholder to raise. It is the intensity ceiling for a restrained look — bloom should be sensed, not seen. If you want a different mood, write a second preset on `createComposer` rather than parameterising the hero preset beyond recognition.

```ts
import { createHeroComposer } from 'ether/postfx';

// In a BaseScene subclass constructor:
this.composer = createHeroComposer(renderer, this.scene, this.camera, {
  enableDither: quality.enableDither,
  multisampling: quality.msaaSamples,
}).composer;
```

The preset factories return the handles too — `{ composer, effects, bloom, dither }` — so keep the return value when you want to tune bloom or flip the dither live rather than only the `.composer` field.

### Antialiasing lives on the composer, not the context

Passes render into textures that bypass the canvas framebuffer, so the renderer's context `antialias` flag is visually dead the moment a composer runs. Real edge AA is `multisampling` on the composer's internal targets (WebGL2), which tile-based mobile GPUs resolve nearly for free. Pass `multisampling: quality.msaaSamples` from `ether/quality` and stop thinking about the context flag.

### HDR is a composer option, not a renderer setting

`hdr: true` gives the composer half-float buffers *and* an ACES `ToneMappingEffect` inside the chain. This is the only thing that makes tone mapping happen: render-to-target bypasses the renderer's own tone mapping entirely, so without `hdr` the renderer's `toneMappingExposure` is a dead knob and highlights hard-clip at 1.0. That clipping is deliberate for the restrained presets — it is bloom containment without a tone-mapping pass. Turn `hdr` on when the scene's light is emissive geometry that needs a filmic shoulder, not as a default.

### Dither

`DitherEffect` is exported from `ether/postfx` — import it, do not redefine it. It is a per-pixel hash grain, seeded per time step, applied **through the sRGB transfer** so the noise is one output step peak to peak at every luminance (the same amplitude applied in linear light is several steps in the darks). A few ALU ops merged into the same fullscreen pass as everything else. Every preset ends with it, on every quality tier, because without it dark gradients band and mobile OLED posterization reads as wrong colors.

It is **not** a Bayer matrix and it takes no `#include`. The 8×8 ordered Bayer chunk in `ether/shaders` (`dither.glsl`, also exported as the `dither` string) is a standalone chunk for your *own* materials; `DitherEffect` does not use it.

```ts
import { createComposer, DitherEffect } from 'ether/postfx';
```

### Color grading

Grade with a real LUT through postprocessing's `LUT3DEffect`, loaded by the engine's `loadLUT`:

```ts
import { LUT3DEffect } from 'postprocessing';
import { createComposer, loadLUT } from 'ether/postfx';

const lut = await loadLUT('/grades/your-grade.cube'); // .cube or .3dl
const { composer } = createComposer(renderer, scene, camera, {
  effects: [new LUT3DEffect(lut, { tetrahedralInterpolation: true })],
  multisampling: quality.msaaSamples,
});
```

`loadLUT` picks `LUT3dlLoader` or `LUTCubeLoader` off the file extension and resolves to a `LookupTexture`. It fetches the file itself and rejects on an HTTP error or a body that does not parse as a LUT; postprocessing's own `loadAsync` never settles in either case, which would leave a scene's `preload()` pending. On devices without float 3D textures, call `lut.convertToUint8()` before building the effect.

Two API names that recipes tend to invent and that do **not** exist in `postprocessing` 6.39: `LUTLoader` (the loaders are `LUTCubeLoader` and `LUT3dlLoader`) and `LookupTexture3D.createIdentity` (`LookupTexture3D` is a deprecated alias of `LookupTexture`, and the identity factory is `LookupTexture.createNeutral(size)`). A LUT is a grade, not a look — material identity still has to come from the shaders.

### Chromatic aberration

`ChromaticAberrationEffect` ships in `postprocessing` but no engine preset includes it. If you want it, pass it in `effects` and keep the offset at a bias so low it reads as optical depth rather than a filter — around `(0.0015, 0.0015)`, visible only at the highest-contrast peripheral edges. Above `0.003` it reads as an Instagram filter. It costs an extra texture fetch per pixel, so skip it on mobile.

### Per-frame and resize

`composer.render(deltaTime)` replaces `renderer.render(scene, camera)`. Do not call both — the scene would draw twice and the chain would run over already-composited output. On resize, call both `renderer.setSize(w, h)` and `composer.setSize(w, h)`: the composer owns its own render targets and will otherwise stay at the old resolution.

## Tunable parameters

| Parameter | Location | Engine value | Range | Effect |
|---|---|---|---|---|
| `BloomEffect.intensity` | hero preset | `0.06` | `0.03 – 0.12` | Multiplier on the bloom contribution for a dark scene with a single accent. This is the ceiling for restraint, not a starting point to raise. Above ~0.15 in a hero scene the whole bright area halos rather than just the peaks. |
| `BloomEffect.intensity` | night preset | `0.38` | `0.25 – 0.5` | Emissive-heavy tuning. The hero preset's value reads as dead neon in a scene with hundreds of emitters against near-black. |
| `BloomEffect.luminanceThreshold` | hero / night | `0.65` / `0.62` | `0.55 – 0.8` | Pixels below this luminance contribute zero bloom. Higher = only the brightest accent core triggers it. Drop it and you pick up all lit surfaces, which reads as glow. |
| `BloomEffect.luminanceSmoothing` | hero / night | `0.2` / `0.25` | `0.1 – 0.3` | Soft width of the threshold ramp. Too wide and midtones contribute, which is the scattergun slop pattern. |
| `BloomEffect.kernelSize` | hero / night | `MEDIUM` / `LARGE` | `SMALL / MEDIUM / LARGE` | Mipmap-blur kernel. LARGE is right for emitter halos and a perf trap everywhere else — it costs significantly more for a modest visual radius gain. |
| `ComposerOptions.multisampling` | `createComposer` | `0` | `0 / 2 / 4 / 8` | MSAA on the composer's targets — the AA that actually reaches the screen. Drive it from `quality.msaaSamples`; 0 disables. |
| `ComposerOptions.hdr` | `createComposer` | `false` | `true / false` | Half-float buffers plus an in-chain ACES pass. The only thing that makes `toneMappingExposure` live. Off means highlights clip at 1.0, which is intentional bloom containment. |
| `ComposerOptions.enableDither` | `createComposer` | `true` | `true / false` | Leave it on. Drive from `quality.enableDither` if you must expose it; the prod path never turns it off. |
| `ChromaticAberrationEffect.offset` | your `effects` | not shipped | `0.0005 – 0.003` | Per-channel UV offset. `0.0015` adds optical depth and is invisible to untrained eyes. Above `0.003` reads as a filter. |

## Common pitfalls

1. **Expecting `renderer.toneMapping` to reach the composer.** It does not. Passes render into the composer's own targets, which bypass the renderer's tone mapping entirely, so setting `renderer.toneMapping = ACESFilmicToneMapping` and then compositing gets you nothing and `toneMappingExposure` silently does nothing. Tone mapping in a composed chain comes from `hdr: true` on `createComposer`, which adds half-float buffers and an ACES `ToneMappingEffect` in the effect chain. Symptom of getting this wrong: exposure is a dead slider and highlights clip flat at white with no shoulder.

2. **Trusting the context `antialias` flag.** Same root cause. `new WebGLRenderer({ antialias: true })` antialiases the default framebuffer, which the composer stops drawing to. Edges alias anyway. Fix: `multisampling` on the composer.

3. **Hand-rolling the composer in scene code.** Every scene that builds its own `EffectComposer` re-decides pass order, whether dither is last, and whether the buffers are half-float. Use `createHeroComposer` / `createNightComposer` / `createLightComposer`, or `createComposer` with an `effects` array. The one legitimate reason to touch raw `postprocessing` types in scene code is constructing an effect to *pass in* (a `LUT3DEffect`, say).

4. **Redefining `DitherEffect` locally.** An inline copy with `#include <dither>` and a Bayer matrix is a different effect from the one the engine ships: the engine's applies hash noise through the sRGB transfer, one output step peak to peak, so the grain is uniform across luminance instead of several steps deep in the darks where banding actually lives. Import `DitherEffect` from `ether/postfx`.

5. **Effect ordering inside the chain.** Order within `effects` is the merge order in the fused shader, and it matters. Bloom before grading: if the LUT runs first, the graded midtones cross the bloom threshold and the highlights lose their special status. Grading before chromatic aberration: otherwise the LUT re-maps the per-channel shifts and corrupts the fringe color. Dither last: subsequent passes re-quantize the dithered output and banding reappears — `createComposer` guarantees this for you by appending the dither after your effects and the ACES pass. Getting the order wrong produces incorrect output with no error or warning.

6. **Calling both `renderer.render()` and `composer.render()`.** Once a composer is wired its `RenderPass` handles the scene render internally. Keeping the old `renderer.render(scene, camera)` in the loop draws the scene twice and runs the effect chain over already-composited output — doubled exposure and wrong intermediate buffers. Delete it.

7. **`composer.setSize()` not called on resize.** The composer owns its intermediates. Call it alongside `renderer.setSize()`, or the output is a stretched blur that doesn't match the viewport.

## Appendix — raw wiring

You need this only when working outside the engine, or when reading `ether/postfx` to understand what it does for you.

```js
import { HalfFloatType } from 'three';
import {
  EffectComposer, RenderPass, EffectPass,
  BloomEffect, KernelSize, ToneMappingEffect, ToneMappingMode,
} from 'postprocessing';

const composer = new EffectComposer(renderer, {
  multisampling: 4,
  frameBufferType: HalfFloatType, // only when you want HDR + an ACES pass
});

composer.addPass(new RenderPass(scene, camera));

const bloom = new BloomEffect({
  intensity: 0.06,
  luminanceThreshold: 0.65,
  luminanceSmoothing: 0.2,
  mipmapBlur: true,
  kernelSize: KernelSize.MEDIUM,
});

// One EffectPass — the effects merge into a single fragment shader.
composer.addPass(new EffectPass(
  camera,
  bloom,
  new ToneMappingEffect({ mode: ToneMappingMode.ACES_FILMIC }),
  new DitherEffect(),
));
```

That is the whole of `createComposer`. If you find yourself writing it in scene code, you are duplicating the engine.

## Reference

See `references.md`:

- **Locomotive** entry: A single deliberate post-process effect (pixelation) applied to a portrait on a saturated-blue field. The annotation calls out "one effect, one element, not the whole scene" as the premium signal — it constrains GPU cost and reads as a compositional decision rather than a filter. The lesson: every effect in the chain must earn its place. Dither always earns it (it fixes a real quantization problem). Bloom earns it only when the scene has bright peaks that need somewhere to go. Add nothing for decoration alone.

- **Studio Lumio** entry: Screenshot captured at the entry gate only — site content beyond the gate was not available at capture time. Studio Lumio is publicly known for audio-reactive WebGL with a strong postprocessing aesthetic. The annotation notes the audio consent gate as a composed design object, which implies the chain runs behind it from the first frame. Lesson: wire the composer before any interactive gate opens, so the effect chain is live at first paint.

- **ZAJNO / Bonhomme:** Neither entry directly demonstrates a postprocessing chain — ZAJNO is annotated for its MSDF type-as-hero technique, and the Bonhomme Paris entry has an unresolved screenshot (bonhomme.lol was captured instead of bonhommeparis.com). Locomotive is the verified in-file reference for restrained effect use. Revisit Bonhomme after re-capturing the correct domain; do not cite unreliable captures as evidence.
