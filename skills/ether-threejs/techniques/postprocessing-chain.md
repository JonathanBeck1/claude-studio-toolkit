# Postprocessing Chain (vanruesc `postprocessing` library)

## When to use

Use a postprocessing chain when the raw three.js render needs color grading, controlled bloom on iridescent highlight peaks, or dithering to kill gradient banding on dark-field hero scenes — and when all three of those needs appear together. A single `EffectPass` merges them into one shader dispatch, so the cost is one extra full-screen quad draw per frame rather than N separate passes.

This is the right pattern for: a dark hero scene (iridescent fresnel surfaces plus atmospheric gradients), any page where a tone-mapped HDR render feeds into a visible gradient that bands on low-bit-depth displays, any page where bloom is required to make fresnel highlights pop past 1.0 without blowing to white.

This is the wrong pattern for: landing pages where the entire 3D element is low-complexity and already band-free (skip the dither pass), pages where there is no 3D scene at all (don't create a WebGL canvas just for postprocessing), any context where the extra GPU cost of an EffectComposer exceeds the render budget. If you only need one effect, ask whether a CSS filter or a simpler `ShaderPass`-equivalent handles it before wiring the full chain.

Never use three.js's built-in `EffectComposer` from `three/examples/jsm/postprocessing/EffectComposer.js`. It runs each effect in its own full-screen pass and does not merge them. Use the vanruesc `postprocessing` library — every effect inside a single `EffectPass` is merged at compile time into one fragment shader.

## What it gives you

- **Bloom** that catches iridescent peaks above 1.0 without turning the whole image glowy. With mipmap-blur and a high threshold (~0.85), only the very brightest surface highlights bloom — the rest of the image is untouched. The effect reads as "material has energy" not "someone turned the bloom slider up."
- **Color grading via LUT** that corrects the final image into a defined palette. In v1 this is an identity LUT (no-op); during art direction, swap it for a .cube or .png LUT generated in DaVinci Resolve or Photoshop. Ensures the output color space is authored, not whatever `ACESFilmicToneMapping` happens to produce.
- **Chromatic aberration** at a bias so low it reads as optical depth rather than a filter. Offset `(0.0015, 0.0015)` means the color fringing is visible only in the highest-contrast edges at the periphery — not the center, not everywhere, not at Instagram-filter strength.
- **Dithering** applied last to break gradient banding on dark atmospheric backgrounds. An 8×8 Bayer matrix adds ±1/128 per channel of structured noise to the final pixel, which is below the threshold of perception but above the threshold of the display's quantization. Banding disappears; posterization disappears.

## Required setup

Install:

```bash
npm install postprocessing
```

This library requires a standard `WebGLRenderer` from three.js (r152+). Set the renderer's `outputColorSpace` and `toneMapping` before constructing the composer — the composer inherits these settings from the renderer at construction time.

## Code recipe

### Imports

```js
import * as THREE from 'three';
import {
  EffectComposer,
  RenderPass,
  EffectPass,
  BloomEffect,
  KernelSize,
  BlendFunction,
  ChromaticAberrationEffect,
  LUT3DEffect,
  LookupTexture3D,
  Effect,
} from 'postprocessing';
```

### Renderer setup (must precede composer construction)

```js
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);

// Must be set BEFORE constructing EffectComposer.
// The composer reads outputColorSpace from the renderer and wires the final
// output pass to sRGB. If you set this after construction, color space is wrong.
renderer.outputColorSpace = THREE.SRGBColorSpace;

// Tone mapping is applied in the final pass when frameBufferType is HalfFloat.
// Without this, HDR values (iridescent peaks > 1.0) clip to white.
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;

document.body.appendChild(renderer.domElement);
```

### EffectComposer construction

```js
// HalfFloatType preserves HDR values (> 1.0) through the entire chain.
// Required for iridescent surfaces where fresnel peaks exceed 1.0.
// Without this, bloom has nothing to bloom — the bright values are already clipped.
const composer = new EffectComposer(renderer, {
  frameBufferType: THREE.HalfFloatType,
});
```

### Custom DitherEffect class

This must be defined before the effect chain is assembled. The fragment shader references `shaders/dither.glsl` (created in Task 14) via `vite-plugin-glsl`. The `#include <dither>` directive resolves to an 8×8 Bayer dither function `dither8x8(vec2 coord)` that returns a float in [0, 1].

```js
import { Effect, BlendFunction } from 'postprocessing';

const ditherFragment = /* glsl */`
  #include <dither>
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

The `(d - 0.5) / 64.0` formula centers the dither noise at zero (mean offset = 0) and scales it to ±1/128 per channel. This is below the threshold of conscious perception on any current display calibration but above the display's quantization step, which is what breaks banding.

### Loading a LUT (identity placeholder for v1)

```js
// In v1, create a 16-cube identity LUT (no-op — output equals input).
// During art direction, replace with a loaded .cube or .png LUT from
// DaVinci Resolve or Photoshop. The swap requires only one line change here.
const lut = LookupTexture3D.createIdentity(16);

// To load a real LUT from a .png file (when available):
// const lut = await new LUTLoader().loadAsync('/luts/grade.png');
```

### Mobile gating

Mobile GPUs have narrower ALU bandwidth. Apply lighter passes on small viewports:

```js
const isMobile = window.matchMedia('(max-width: 900px)').matches;

// Bloom: reduce kernel size on mobile to cut the blur sample count.
const bloomEffect = new BloomEffect({
  intensity: 0.4,
  luminanceThreshold: 0.85,
  luminanceSmoothing: 0.075,
  mipmapBlur: true,
  kernelSize: isMobile ? KernelSize.SMALL : KernelSize.MEDIUM,
});

// Chromatic aberration: skip entirely on mobile.
// The offset is so subtle it adds no visual value at mobile viewport widths,
// and it costs an extra texture fetch per pixel.
const chromaticAberration = isMobile
  ? null
  : new ChromaticAberrationEffect({
      offset: new THREE.Vector2(0.0015, 0.0015),
      radialModulation: false,
    });

const ditherEffect = new DitherEffect();
const lutEffect = new LUT3DEffect(lut);
```

### Assembling the chain

Pass ordering is non-negotiable — see Pitfalls. RenderPass first, then a single EffectPass containing all four effects in this order: Bloom → LUT → ChromaticAberration → Dither.

```js
const renderPass = new RenderPass(scene, camera);

// Build the effects array conditionally based on mobile gating.
// ChromaticAberrationEffect is null on mobile — filter it out.
const effects = [bloomEffect, lutEffect, chromaticAberration, ditherEffect].filter(Boolean);

const effectPass = new EffectPass(camera, ...effects);

composer.addPass(renderPass);
composer.addPass(effectPass);
```

### Per-frame loop

`composer.render(deltaTime)` replaces `renderer.render(scene, camera)`. Do not call both.

```js
let lastTime = performance.now();

function animate() {
  requestAnimationFrame(animate);

  const now = performance.now();
  const deltaTime = Math.min((now - lastTime) / 1000, 1 / 30); // cap at 1/30s
  lastTime = now;

  // Update scene objects, uniforms, etc. here.

  // This is the only render call — composer handles the scene render internally.
  composer.render(deltaTime);
}

animate();
```

### Resize handling

```js
window.addEventListener('resize', () => {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h);
  composer.setSize(w, h); // must match — composer owns its own render targets
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
});
```

## Tunable parameters

| Parameter | Location | Default | Range | Effect |
|---|---|---|---|---|
| `BloomEffect.intensity` | `BloomEffect` options | `0.4` | `0.1 – 0.8` | Multiplier on the bloom contribution. Premium range: 0.3–0.5. Above 0.8 reads as slop — the whole bright area halos, not just the peaks. Never set above 1.0 for premium work. |
| `BloomEffect.luminanceThreshold` | `BloomEffect` options | `0.85` | `0.7 – 0.95` | Pixels below this luminance contribute zero bloom. Higher threshold = only the very brightest surface highlights bloom. 0.85 catches iridescent fresnel peaks and misses everything else. At 0.7 you start picking up all lit surfaces, which reads as glow. |
| `BloomEffect.luminanceSmoothing` | `BloomEffect` options | `0.075` | `0.02 – 0.15` | Soft width of the threshold ramp. Lower = sharper cutoff between "blooms" and "doesn't bloom." 0.05–0.1 is the premium range. Above 0.15 the ramp is so wide that midtones contribute, which is the scattergun slop pattern. |
| `BloomEffect.kernelSize` | `BloomEffect` options | `KernelSize.MEDIUM` | `SMALL / MEDIUM / LARGE` | Size of the mipmap-blur kernel. MEDIUM on desktop, SMALL on mobile. LARGE is a common perf trap — it doubles the blur radius visually but costs significantly more. |
| `ChromaticAberrationEffect.offset` | `ChromaticAberrationEffect` options | `Vector2(0.0015, 0.0015)` | `0.0005 – 0.003` | Per-channel pixel offset in UV space. Above 0.003 reads as an Instagram filter. Below 0.001 is imperceptible on most displays but still breaks mono-channel fringing on high-DPI. 0.0015 is the sweet spot: adds optical depth, invisible to untrained eyes. |
| `renderer.toneMappingExposure` | renderer | `1.0` | `0.8 – 1.4` | Global EV adjustment before tone mapping compresses the HDR signal. Increase to push bloom peaks brighter before compression; decrease if the overall scene reads too hot. Touch this during art direction, not during setup. |
| `DitherEffect` dither scale (`/ 64.0`) | `DitherEffect` fragment | `64.0` | `32.0 – 128.0` | Controls dither noise amplitude. `/ 64.0` = ±1/128 per channel. If banding is still visible at 64.0, lower toward 32.0. If grain is perceptible in flat areas, raise toward 128.0. |

## Common pitfalls

1. **Tone mapping conflict between renderer and composer.** Setting `renderer.toneMapping = ACESFilmicToneMapping` does not automatically apply to composer passes — the composer renders through its own chain of HalfFloat render targets where tone mapping is not applied mid-chain. The vanruesc library applies tone mapping in the final output pass only when the composer is initialized with `frameBufferType: THREE.HalfFloatType` AND the renderer's `toneMapping` is set before composer construction. If you set `renderer.toneMapping` after construction, or construct the composer without `HalfFloatType`, tone mapping silently fails and HDR values clip. Symptom: the scene looks identically correct with and without the composer, then suddenly blows out when bloom is added. Fix: always set `renderer.outputColorSpace` and `renderer.toneMapping` before `new EffectComposer(...)`, and always pass `frameBufferType: THREE.HalfFloatType`.

2. **sRGB color space order.** The postprocessing chain operates in linear light space through all intermediate passes. The final conversion to sRGB happens in the last output step, driven by `renderer.outputColorSpace = THREE.SRGBColorSpace`. If that line is missing, the chain outputs linear values to the canvas and the browser interprets them as sRGB — everything looks washed out and over-bright, like the gamma is wrong (because it is). If you set `outputColorSpace` after the composer is constructed but before any render, it may or may not take depending on library version — set it first and don't move it. Common symptom: a saturated violet accent renders as a pale lavender.

3. **Calling both `renderer.render()` and `composer.render()` in the same frame.** Once the composer is wired, `composer.render(deltaTime)` handles the base scene render internally via its `RenderPass`. If you also call `renderer.render(scene, camera)` in the same animation loop, the scene draws twice: once to the canvas and once through the pass chain. The effect chain runs over a canvas that already has composited output — the result is doubled exposure and incorrect intermediate buffers. Remove `renderer.render(scene, camera)` entirely from the animation loop once `composer.render(deltaTime)` is in place.

4. **Pass ordering matters — bloom must precede grading, grading must precede aberration, dither must be last.** If the LUT is applied before bloom, the graded mid-tones contribute to the bloom threshold and the highlights lose their special status — the bloom picks up everything at the graded luminance levels rather than the raw HDR peaks. If chromatic aberration is applied before the LUT, the per-channel color shifts are re-mapped by the LUT, corrupting the fringe color that the aberration effect is supposed to produce. If dither is not last, subsequent passes re-quantize the dithered output and banding reappears. The vanruesc `EffectPass` merges all effects in the order they are passed to the constructor — `new EffectPass(camera, bloomEffect, lutEffect, chromaticAberration, ditherEffect)`. Getting this order wrong produces incorrect visual output with no error or warning.

5. **`composer.setSize()` not called on resize.** The composer owns its internal render targets (the HalfFloat intermediates). If `renderer.setSize()` is called but `composer.setSize()` is not, the composer's targets stay at the old resolution. The result is a blurry or stretched output that does not match the viewport. Always call both in the resize handler, in that order.

## Reference

See `references.md`:

- **Locomotive** entry: A single deliberate post-process effect (pixelation) applied to a portrait on a saturated-blue field. The annotation in `references.md` specifically calls out "one effect, one element, not the whole scene" as the premium signal — constrains GPU cost and reads as a compositional decision rather than a filter. The lesson for premium work: every pass in the chain must earn its place. Dither and subtle CA are always defensible (they fix real technical problems). Bloom is defensible only if iridescent surfaces are in the scene and the HDR peaks need a place to go. Add no pass for decoration alone.

- **Studio Lumio** entry: Screenshot captured at the entry gate only — site content beyond the gate was not available at capture time. Studio Lumio is publicly known for audio-reactive WebGL with a strong postprocessing aesthetic. The annotation notes the audio consent gate as a composed design object, which implies the postprocessing chain runs behind it from the first frame. Lesson: wire the composer before any interactive gate opens, so the effect chain is live at first paint.

- **ZAJNO / Bonhomme:** Neither `references.md` entry directly demonstrates a postprocessing chain — ZAJNO is annotated for its MSDF type-as-hero technique, and the Bonhomme Paris entry has an unresolved screenshot (bonhomme.lol was captured instead of bonhommeparis.com). If you are looking for restrained-bloom examples to reference during art direction, Locomotive is the verified in-file reference. Revisit the Bonhomme entry after re-capturing `bonhommeparis.com` — the studio's public reputation is for narrative scrollytelling with persistent canvas, which would include a postprocessing chain, but do not cite unreliable captures as evidence.
