# MSDF Typography (troika-three-text)

## When to use

Type that lives inside the 3D scene — not overlaid in HTML, not extruded into geometry — and that needs to read as type, not as a 3D model. MSDF is the right choice when the letterforms are compositional elements that respond to camera motion, react to scene lighting through a custom material, or need to render with particles and depth-correct layering in the same draw call budget.

This is the right pattern for: the hero wordmark at viewport scale (the studio's wordmark on `/`, wordmark-as-subject following the Zajno and Akufen model), type integrated into scroll-driven 3D scenes, labels or callouts inside a WebGL data visualization, any case where you need the text to take a custom shader — glow, scan lines, dissolve into particles.

This is the wrong pattern for: body text, long-form reading copy, text that needs browser accessibility and selection (use HTML for that), type on a flat card that never enters 3D space (CSS with a web font is lighter and more accessible), anything that can be solved with a `<p>` tag.

**When to choose MSDF over the two common alternatives:**

- **vs `CanvasTexture` of rendered HTML:** Canvas text rasterizes to a fixed pixel resolution. Zoom in, pan close, or scale up and you see the bitmap blur. MSDF is resolution-independent — the SDF field is rendered sharp at any zoom level because the shader recomputes the edge from the signed-distance value, not from pixel coverage. On a 4K viewport with a hero-scale wordmark, the difference is immediately visible.

- **vs `TextGeometry` + `FontLoader` (extruded text geometry):** Three.js extruded text works by generating actual polygon faces for each glyph. Triangle counts scale with curve quality — a high-quality "O" at print sharpness requires thousands of triangles. The result reads as a 3D-printed plastic shape: it catches directional light across its faces and bevels in a way that signals "game object" rather than "type." MSDF renders a flat signed-distance field sampled in the fragment shader, so the letter reads as type with controlled optical properties. You can give it depth via material tricks (glow, subsurface, rim) without it reading as extruded plastic.

## What it gives you

Type that is fully integrated into the 3D scene: it orbits with the camera, interleaves with particles in z-space, and accepts any GLSL material. With `createDerivedMaterial` from `troika-three-utils`, you can inject custom uniforms and fragment code while keeping troika's MSDF sampling intact — so you get the edge glow, dissolve, or color sweep that your art direction calls for without rewriting the SDF sampling logic. The letterforms stay crisp from 12px body size through viewport-spanning hero display at any DPR.

## Required setup

Install:

```bash
npm install troika-three-text troika-three-utils
```

`troika-three-text` handles MSDF atlas generation transparently at runtime from any TTF, OTF, WOFF, or WOFF2 input. You do not pre-generate font atlases. Pass a font URL to `text.font` and troika fetches, parses, and builds the SDF atlas on first use, caching it for subsequent `Text` instances that share the same font URL.

`troika-three-utils` provides `createDerivedMaterial` — the recommended way to inject custom shader code into a troika text material without breaking troika's internal SDF sampling.

**Font choice (example: Staatliches, a condensed display face):**

```
https://fonts.gstatic.com/s/staatliches/v13/HI_OiY8KO6hCsQSoAPmtMbectJG9O9PS.woff2
```

This is the Google Fonts CDN URL for Staatliches v13. Google Fonts CDN URLs are versioned — if the font file is updated, the URL changes. Verify the current URL at https://fonts.googleapis.com/css2?family=Staatliches and pull the `src: url(...)` from the `@font-face` rule. The `text.font` property accepts this URL directly; troika fetches it on first `sync()` call.

## Code recipe

### Basic instantiation and font loading

```js
import * as THREE from 'three';
import { Text } from 'troika-three-text';

// Create the Text object
const label = new Text();

// Set font — Staatliches from Google Fonts CDN
label.font = 'https://fonts.gstatic.com/s/staatliches/v13/HI_OiY8KO6hCsQSoAPmtMbectJG9O9PS.woff2';

// Core properties
label.text = 'TAKE TWO';
label.fontSize = 1.2;              // world units
label.color = 0xffffff;

// Anchor at the visual center of the bounding box — almost always what you want
label.anchorX = 'center';
label.anchorY = 'middle';

// Position in scene space
label.position.set(0, 0, 0);

// Add to scene before sync() — troika will update geometry in-place when ready
scene.add(label);

// sync() returns a Promise that resolves when the font atlas is built and
// the geometry is laid out. MUST be awaited before reading layout values.
await label.sync();

// Safe to read bounding box only after await
label.geometry.computeBoundingBox();
const bbox = label.geometry.boundingBox;
console.log('text width:', bbox.max.x - bbox.min.x);
```

### Custom material — brand glow via `createDerivedMaterial`

`createDerivedMaterial` from `troika-three-utils` wraps a base material and injects custom uniforms and GLSL code. Troika's MSDF sampling runs first and populates `gl_FragColor` with the correctly anti-aliased glyph alpha; your `fragmentMainOutro` code runs after and can modify that output. This is the correct pattern — do not construct a raw `THREE.ShaderMaterial` for troika text, because you will lose the MSDF sampling logic.

```js
import * as THREE from 'three';
import { Text } from 'troika-three-text';
import { createDerivedMaterial } from 'troika-three-utils';

// Base material — troika's MSDF needs transparent: true so glyph alpha is respected
const baseMaterial = new THREE.MeshBasicMaterial({
  color: 0xffffff,
  transparent: true,
});

// Inject a brand-colored edge glow
const glowMaterial = createDerivedMaterial(baseMaterial, {
  uniforms: {
    uGlowColor:    { value: new THREE.Color(0x8b5cf6) }, // example accent
    uGlowStrength: { value: 1.0 },                        // 0 = no glow, 2 = heavy
  },
  fragmentMainOutro: `
    // gl_FragColor.a holds the MSDF-computed glyph alpha at this point.
    // smoothstep creates a soft band at the glyph edge (alpha ~0.45–0.5).
    // edgeGlow is 1.0 at the edge and falls to 0.0 inside and outside the glyph.
    float edgeGlow = 1.0 - smoothstep(0.45, 0.5, gl_FragColor.a);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, uGlowColor, edgeGlow * uGlowStrength);
  `,
});

const heroText = new Text();
heroText.font = 'https://fonts.gstatic.com/s/staatliches/v13/HI_OiY8KO6hCsQSoAPmtMbectJG9O9PS.woff2';
heroText.text = 'TAKE TWO';
heroText.fontSize = 1.8;
heroText.anchorX = 'center';
heroText.anchorY = 'middle';
heroText.material = glowMaterial;

scene.add(heroText);
await heroText.sync();
```

Animate the glow strength from the render loop:

```js
function animate(time) {
  requestAnimationFrame(animate);

  // Pulse the glow — range 0.6 to 1.4, period ~4 seconds
  glowMaterial.uniforms.uGlowStrength.value = 1.0 + 0.4 * Math.sin(time * 0.001 * Math.PI * 0.5);

  composer.render(deltaTime); // or renderer.render(scene, camera)
}
```

### Layering over particles — depth control

When hero type must render in front of a particle system regardless of z-order:

```js
// Disable depth testing so the text always draws over whatever is behind it.
// This trades depth correctness for guaranteed visibility.
// Only appropriate for hero type — not for body copy or labels in 3D space.
heroText.material.depthTest = false;
heroText.renderOrder = 999;   // draw last, after particles (renderOrder 0)
```

For type that should depth-sort correctly with particles (ambient labels, call-outs):

```js
// Leave depthTest: true (the default) and keep renderOrder at 0.
// If z-fighting occurs, nudge renderOrder by 1 relative to the particle mesh.
// Use material.transparent = true so alpha edge pixels don't punch holes.
heroText.material.transparent = true;
```

### Full hero setup with layout centering

```js
import * as THREE from 'three';
import { Text } from 'troika-three-text';
import { createDerivedMaterial } from 'troika-three-utils';

export async function createHeroText(scene) {
  const baseMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    transparent: true,
  });

  const glowMaterial = createDerivedMaterial(baseMaterial, {
    uniforms: {
      uGlowColor:    { value: new THREE.Color(0x8b5cf6) },
      uGlowStrength: { value: 1.0 },
    },
    fragmentMainOutro: `
      float edgeGlow = 1.0 - smoothstep(0.45, 0.5, gl_FragColor.a);
      gl_FragColor.rgb = mix(gl_FragColor.rgb, uGlowColor, edgeGlow * uGlowStrength);
    `,
  });

  const label = new Text();
  label.font     = 'https://fonts.gstatic.com/s/staatliches/v13/HI_OiY8KO6hCsQSoAPmtMbectJG9O9PS.woff2';
  label.text     = 'TAKE TWO';
  label.fontSize = 1.8;
  label.anchorX  = 'center';
  label.anchorY  = 'middle';
  label.material = glowMaterial;

  // Hero type always draws over particles
  label.material.depthTest = false;
  label.renderOrder        = 999;

  // Increase SDF glyph resolution for large hero display (see Tunable parameters)
  label.sdfGlyphSize = 128;

  scene.add(label);

  // MUST await before reading geometry or doing layout-dependent work
  await label.sync();

  return { label, glowMaterial };
}
```

## Tunable parameters

| Property | Default | Range / Options | Effect |
|---|---|---|---|
| `fontSize` | (none, required) | 0.1 – 10+ (world units) | Sets the em-square height in three.js world units. 1.0 = 1 unit. Scale to match your camera's field of view — at a typical 75° FOV with camera at z=5, `fontSize: 1.5` produces roughly viewport-spanning hero type. |
| `sdfGlyphSize` | `64` | 32 / 64 / 128 / 256 | Resolution of the SDF atlas per glyph, in pixels. 64 is correct for body and mid-size display. At hero scale on a 2× or 3× DPR display, the 64px SDF shows soft edges — bump to 128 for hero type. 256 adds almost no visible improvement over 128 except on very large or extremely thin-stroked faces, and costs 4× the VRAM of 128. Must be set before the first `sync()` call; changing it afterward requires a re-sync. |
| `uGlowStrength` (uniform) | `1.0` | 0.0 – 2.0 | Controls how strongly the edge glow color replaces the base color at glyph edges. 0 = no glow (base color only). 1.0 = full glow blend at the edge. Above 1.5 the glow saturates and starts to read as a bloom artifact rather than an edge treatment — stay below 1.4 for hero work. |
| `uGlowColor` (uniform) | `0x8b5cf6` (violet) | your brand accents | The color mixed into the edge band. Example cue: one accent at hero rest state, animate toward a second `0x2dd4bf` on hover or scroll entry. Avoid warm colors against the dark field — the contrast collapse makes the glow disappear. |
| `letterSpacing` | `0` | −0.5 – 2.0 (em units) | Adds or removes tracking between glyphs, in em units. Positive values open the type; negative values tighten it. At hero scale, `letterSpacing: 0.05` adds a premium display feel without looking editorial-template. Values above 0.3 begin to read like an Akufen-style extreme stretch — intentional there, slop elsewhere. |
| `lineHeight` | `1.2` | 1.0 – 2.0 | Line height multiplier for multi-line blocks. Only relevant for body-style text blocks in the scene; hero single-line type ignores it. |

## Common pitfalls

1. **Font loading is async — bounding box reads zero before `await text.sync()`.**
   `text.sync()` returns a Promise. Troika fetches the font file, parses it, generates the SDF atlas, and lays out the glyphs asynchronously. If you read `text.geometry.boundingBox` or try to center the text using layout values before the Promise resolves, you get null or zero. This is one of the most common bugs when first integrating troika. Pattern: always `await text.sync()` before any code that depends on layout — centering, collision detection, snap-to-grid, anything that reads glyph dimensions. It is safe to add the `Text` to the scene before `sync()` — troika will update the geometry in-place when ready and the object renders as invisible until the atlas is built.

2. **Soft edges on hero type at high DPR — `sdfGlyphSize` too low.**
   The default `sdfGlyphSize: 64` renders a 64×64 px SDF cell per glyph in the atlas. For body-size type on a standard display this is sharp. For viewport-spanning hero type on a 2× or 3× DPR display, the 64px cell is not enough resolution — the edges look slightly blurred and the stroke weight feels inconsistent. Set `sdfGlyphSize: 128` for any hero-scale `Text` instance. Set it before the first `sync()` call; changing it after the atlas is built requires a new `sync()`. VRAM cost scales quadratically: 128 costs 4× a 64, 256 costs 16×. For hero type, 128 is the correct default; leave 64 for body.

3. **Depth conflict with particle layers — z-fighting or partial occlusion.**
   Text and particles rendered at similar world-space z values produce z-fighting: the text partially or intermittently disappears behind particle sprites depending on per-frame GPU rasterization order. Two fixes with different tradeoffs:
   - **(a) Always-on-top:** `text.material.depthTest = false; text.renderOrder = 999;` — the text draws last and ignores the depth buffer. Guaranteed visibility from any camera angle. Trade-off: breaks depth correctness (text will render in front of geometry that should occlude it). Use this only for hero type where "type is always legible" is the design intent.
   - **(b) Depth-correct transparent sort:** Keep `depthTest: true` and `transparent: true`. Manually sort particle positions by camera distance each frame and set `renderOrder` accordingly. Correct but adds per-frame JS cost. Use this for scene-integrated labels where depth accuracy matters (data viz, 3D callouts).
   For a hero wordmark, default to (a).

4. **`createDerivedMaterial` `fragmentMainOutro` timing — modifying `gl_FragColor` before MSDF runs.**
   Troika's MSDF sampling populates `gl_FragColor` (including the critical alpha channel that defines glyph coverage). `fragmentMainOutro` code runs after troika's sampling. Do not attempt to inject code in `fragmentMainIntro` or `vertexMainOutro` to read or modify the MSDF alpha — those run before or during, not after, and `gl_FragColor` is not set yet. If your custom shader needs to key off the glyph edge, it must live in `fragmentMainOutro`. Symptom of getting this wrong: the glow or custom color appears but is not clipped to the glyph shape — the entire quad renders with the effect, not just the letterforms.

## Reference

See `references.md`:

- **Zajno** entry: The homepage hero sets a massive custom wordmark ("zajno®") at approximately 60% of viewport height — type as the entire hero subject, with a product photograph composited as a secondary element beneath it. The annotation calls out "wordmark-as-hero is a legitimate alternative to 3D-object-as-hero." MSDF makes this viable in a three.js scene because the letters hold sharp edges at that scale without raster blur. What to copy: the commitment to type at hero scale, and the discipline of letting it be the primary compositional weight. What to skip: their specific glyph treatment and registered-trademark detail are house style — copy the scale-and-weight strategy, not the specifics.

- **Active Theory** entry: A holographic chrome logomark in deep black space, with a sparse trailing particle burst. The type treatment here is embedded in a 3D scene that owns the full viewport — the logo sits inside the WebGL context, not above it in HTML. This is the integration model that MSDF enables: type as a scene object rather than a DOM overlay. What to copy: the dark field as the prerequisite for any type-in-scene treatment — you need the background contrast budget for the letterforms and the glow to register. What to skip: the chrome/holographic logo material is a fresnel-driven shader (see `techniques/fresnel-iridescence.md`) applied to extruded geometry, not MSDF — distinguish between the type-in-scene composition strategy (copyable) and their specific logomark material (different technique file).
