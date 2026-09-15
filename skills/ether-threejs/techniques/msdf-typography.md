# MSDF Typography (troika-three-text)

## When to use

Type that lives inside the 3D scene — not overlaid in HTML, not extruded into geometry — and that needs to read as type, not as a 3D model. MSDF is the right choice when the letterforms are compositional elements that respond to camera motion, react to scene lighting through a custom material, or need to render with particles and depth-correct layering in the same draw call budget.

This is the right pattern for: a hero wordmark at viewport scale (wordmark-as-subject, following the Zajno and Akufen model), type integrated into scroll-driven 3D scenes, labels or callouts inside a WebGL data visualization, any case where you need the text to take a custom shader — glow, scan lines, dissolve into particles.

Note the division of labor in the engine: `ether/text` is type as **form** (`extrudedWord`, per-letter `ExtrudeGeometry`), and `ether/text/msdf` is type as **text** — legible copy in the scene. They are separate entry points so a site that only extrudes never pulls troika in.

This is the wrong pattern for: body text, long-form reading copy, text that needs browser accessibility and selection (use HTML for that), type on a flat card that never enters 3D space (CSS with a web font is lighter and more accessible), anything that can be solved with a `<p>` tag.

**When to choose MSDF over the two common alternatives:**

- **vs `CanvasTexture` of rendered HTML:** Canvas text rasterizes to a fixed pixel resolution. Zoom in, pan close, or scale up and you see the bitmap blur. MSDF is resolution-independent — the SDF field is rendered sharp at any zoom level because the shader recomputes the edge from the signed-distance value, not from pixel coverage. On a 4K viewport with a hero-scale wordmark, the difference is immediately visible.

- **vs `TextGeometry` + `FontLoader` (extruded text geometry):** Three.js extruded text works by generating actual polygon faces for each glyph. Triangle counts scale with curve quality — a high-quality "O" at print sharpness requires thousands of triangles. The result reads as a 3D-printed plastic shape: it catches directional light across its faces and bevels in a way that signals "game object" rather than "type." MSDF renders a flat signed-distance field sampled in the fragment shader, so the letter reads as type with controlled optical properties. You can give it depth via material tricks (glow, subsurface, rim) without it reading as extruded plastic.

## What it gives you

Type that is fully integrated into the 3D scene: it orbits with the camera, interleaves with particles in z-space, and takes your own material. Assign a material to a troika `Text` and troika derives an MSDF-aware variant of it — your shader keeps its identity, and troika's glyph coverage is multiplied into the alpha afterwards. The letterforms stay crisp from body size through viewport-spanning hero display at any DPR.

## Required setup

`troika-three-text` is an **optional peer dependency** of the engine. Install it in the site:

```bash
npm install troika-three-text
```

`troika-three-utils` is *not* a dependency and you do not need it. Its `createDerivedMaterial` is what troika-three-text uses internally on whatever material you hand it; reaching for it directly adds an unpinned package to do something the `material` option already does.

Troika parses the font file at runtime and builds the SDF atlas on demand, caching it across `Text` instances that share the same font URL. You do not pre-generate atlases.

**Font format: `.ttf`, `.otf`, or `.woff`.** Not `.woff2` — troika's parser (Typr, plus a woff→otf shim) throws `woff2 fonts not supported` on one. This rules out the URL you get from a Google Fonts `@font-face` rule, which is woff2 in every modern-browser variant. Serve your own file:

```
/fonts/display-700.woff
```

Self-hosting is the engine's position for a second reason: `msdfText` requires the `font` option precisely so troika cannot quietly fall back to fetching a hosted Google font, and a premium site should not ship CDN type.

**Characters outside the font's coverage** still route to troika's unicode-font-resolver, whose data is fetched from jsDelivr by default. Set `unicodeFontsURL` to your own copy to keep the page off a third-party CDN entirely — or keep the text inside the font's coverage and the resolver never runs.

## Code recipe

### Start with `msdfText` — the engine already wraps the awkward part

`msdfText` from `ether/text/msdf` does three things you would otherwise
get wrong: it preflights the font URL (troika's loader only *logs* a
failed fetch and never calls back, so an unreachable font hangs forever),
it promisifies `sync`, and it resolves only once the glyph atlas is
ready — so the first frame the mesh renders is complete.

```ts
import * as THREE from 'three';
import { msdfText } from 'ether/text/msdf';

export async function createHeroLabel(scene: THREE.Scene) {
  const material = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    transparent: true,
    depthTest: false,   // hero type draws over the field — see Pitfall 3
  });

  const label = await msdfText({
    text: 'STUDIO',
    font: '/fonts/display-700.woff',
    fontSize: 1.8,            // world units; default 1
    sdfGlyphSize: 128,        // default 64 — see Tunable parameters
    anchorX: 'center',        // defaults are already 'center' / 'middle'
    anchorY: 'middle',
    material,
  });

  label.mesh.renderOrder = 999;
  scene.add(label.mesh);

  // Layout is ready the moment the promise resolves. blockBounds is
  // [minX, minY, maxX, maxY] of the whole block, in world units.
  const b = label.mesh.textRenderInfo!.blockBounds;
  console.log('text width:', b[2] - b[0]);

  return label;   // { mesh, dispose } — hand dispose to BaseScene.track()
}
```

### `sync()` takes a callback; it does not return a Promise

This is the single most common integration bug, and `await text.sync()`
is the shape it takes. `sync(callback?)` returns `undefined`, so awaiting
it resolves on the next microtask — long before the font has been
fetched, parsed, and rasterized. The layout values you then read are
`null` or zero, and the bug is invisible on a warm cache.

If you are driving a raw `Text` rather than `msdfText` — because you are
re-typesetting an existing mesh after a property change — promisify it
yourself:

```ts
await new Promise<void>((resolve) => {
  label.mesh.text = 'SECOND TAKE';
  label.mesh.sync(() => resolve());
});
```

### Custom material — pass it to `msdfText`, troika derives the rest

`msdfText`'s `material` option is the whole mechanism. Assign any
material to a troika `Text` and troika derives an MSDF-aware variant of
it on read, so your shader keeps its identity and you inherit the glyph
sampling for free. No extra package, no injection hooks.

Understand the ORDER, because it is the reverse of what you would guess:
**your fragment shader runs first and sets `gl_FragColor`; troika's
transform runs after and multiplies the glyph coverage into the alpha**
(`gl_FragColor.a *= edgeAlpha`, plus a `discard` outside the glyph). So:

- Your material owns the RGB. Gradients, sweeps, scan lines, dissolve
  masks — all of it works, and troika clips the result to the letterform.
- Your material **cannot read** the MSDF distance. The distance helpers
  are defined in troika's derived layer, which does not exist yet when
  your `main()` runs. An edge glow keyed off `gl_FragColor.a` reads your
  own alpha, not glyph coverage, and produces a uniform tint over the
  whole glyph rather than a band at its edge.
- For an actual edge treatment, use troika's own: `outlineWidth` /
  `outlineColor` / `outlineBlur` for a halo, `strokeWidth` /
  `strokeColor` for an inline rule. They are applied inside the same
  derived shader where the distance field is in scope. One TypeScript
  caveat: troika ships `.d.ts` files it does not point `package.json` at,
  so the kit carries its own ambient declaration of the surface
  `msdfText` uses. `outlineWidth` is in it; `outlineColor`,
  `outlineBlur`, and the stroke properties are not, and setting them on a
  typed `mesh` is a compile error until that declaration is widened.

A vertical color sweep, which is the kind of thing a custom material is
genuinely for:

```ts
import * as THREE from 'three';
import { msdfText } from 'ether/text/msdf';

const material = new THREE.ShaderMaterial({
  transparent: true,
  uniforms: {
    uColorA: { value: new THREE.Color(0x8b5cf6) },  // example accent
    uColorB: { value: new THREE.Color(0x2dd4bf) },
    uMix:    { value: 0 },
  },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: /* glsl */ `
    uniform vec3 uColorA;
    uniform vec3 uColorB;
    uniform float uMix;
    varying vec2 vUv;
    void main() {
      // Alpha 1.0 here: troika multiplies glyph coverage in afterwards.
      gl_FragColor = vec4(mix(uColorA, uColorB, clamp(vUv.y + uMix, 0.0, 1.0)), 1.0);
    }
  `,
});

const label = await msdfText({
  text: 'STUDIO',
  font: '/fonts/display-700.woff',
  fontSize: 1.8,
  sdfGlyphSize: 128,
  material,       // `color` is ignored when you supply this
});
```

Animate it from the scene's `tick`, not a private rAF — `SceneManager`
already owns the loop:

```ts
tick(time: number, deltaTime: number): void {
  material.uniforms.uMix!.value = 0.4 * Math.sin(time * 0.5);
}
```

### Layering over particles — depth control

When hero type must render in front of a particle system regardless of z-order:

Set these on the material you hand to `msdfText`, before the call — the
mesh's own `material` property is typed `Material | Material[]` (it is a
`Mesh`), so reaching through it to set a flag does not compile, and the
object you would reach is troika's derived wrapper rather than yours.

```ts
// Disable depth testing so the text always draws over whatever is behind it.
// Trades depth correctness for guaranteed visibility.
// Only appropriate for hero type — not for body copy or labels in 3D space.
const material = new THREE.MeshBasicMaterial({
  color: 0xffffff,
  transparent: true,   // alpha edge pixels must not punch holes
  depthTest: false,
});

const label = await msdfText({ text: 'STUDIO', font: '/fonts/display-700.woff', material });
label.mesh.renderOrder = 999;   // draw last, after particles (renderOrder 0)
```

For type that should depth-sort correctly with particles (ambient labels,
call-outs), leave `depthTest` at its default `true` and `renderOrder` at
0, keeping `transparent: true`. If z-fighting occurs, nudge `renderOrder`
by 1 relative to the particle mesh.

## Tunable parameters

| Property | Default | Range / Options | Effect |
|---|---|---|---|
| `fontSize` | `1` (kit default) | 0.1 – 10+ (world units) | Em-square height in three.js world units. Scale it against what the camera actually sees: at `BaseScene`'s defaults (50° FOV, camera at z=4) the visible height at the origin is `2 * 4 * tan(25°)` ≈ 3.7 units, so `fontSize: 1.5` is an em roughly 40% of viewport height — display scale, and a six-letter word at that size spans most of the width on a 16:9 viewport. Recompute for your own FOV and camera distance rather than carrying a number over. |
| `sdfGlyphSize` | `64` (kit default) | 32 / 64 / 128 / 256 | Resolution of the SDF atlas per glyph, in pixels. 64 is correct for body and mid-size display. At hero scale on a 2× or 3× DPR display, the 64px SDF shows soft edges — bump to 128 for hero type. 256 adds almost no visible improvement over 128 except on very large or extremely thin-stroked faces, and costs 4× the VRAM of 128. Must be set before the first sync; changing it afterward requires a re-sync. |
| `material` | none | any `THREE.Material` | Your own material, which troika derives an MSDF-aware variant of. Supplying it makes `color` a no-op. |
| `unicodeFontsURL` | jsDelivr | your own mirror | Where troika's unicode-font-resolver fetches fallback font data for characters `font` does not cover. Only reached when such a character appears. |
| `letterSpacing` | `0` | −0.5 – 2.0 (em units) | Adds or removes tracking between glyphs, in em units. Positive values open the type; negative values tighten it. At hero scale, `letterSpacing: 0.05` adds a premium display feel without looking editorial-template. Values above 0.3 begin to read like an Akufen-style extreme stretch — intentional there, slop elsewhere. |
| `lineHeight` | `'normal'` | `'normal'`, or a multiple like 1.0 – 2.0 | Height of each line, as a multiple of `fontSize`. The default is the string `'normal'`, not a number — troika derives a reasonable height from the font's own ascender/descender metrics, which is nearly always better than a guessed multiplier. Override only when a design spec gives you one. Single-line hero type ignores it. |

## Common pitfalls

1. **`await text.sync()` does not wait for anything.**
   `sync(callback?)` returns `undefined`. Awaiting `undefined` resolves on the next microtask, so every line after the `await` still runs before the font has been fetched, parsed, rasterized, and laid out — and `textRenderInfo` is still `null`, `geometry.boundingBox` still zero. Centering, collision detection, snap-to-grid, anything reading glyph dimensions gets garbage, and a warm cache can hide it on the machine where it was written. Either use `msdfText`, which resolves on the callback, or wrap `sync` in a Promise yourself. It *is* safe to add the mesh to the scene before the atlas is built — troika updates the geometry in place and the object renders as nothing until then.

2. **A `.woff2` font URL fails at parse time, not at fetch time.**
   Troika parses font files itself rather than handing them to the browser, and its parser handles `.ttf`, `.otf`, and `.woff` only — a `.woff2` throws `woff2 fonts not supported`. This bites hardest when the font URL is copied out of a Google Fonts `@font-face` rule, which serves woff2 to every browser that matters. The fetch succeeds, so nothing looks wrong in the network panel; the text simply never appears. Convert to `.woff` (or serve the `.ttf`/`.otf` you licensed) and host it yourself. A second reason to self-host: `msdfText` makes `font` required specifically so troika cannot fall back to fetching a hosted Google font behind your back.

3. **Soft edges on hero type at high DPR — `sdfGlyphSize` too low.**
   The default `sdfGlyphSize: 64` renders a 64×64 px SDF cell per glyph in the atlas. For body-size type on a standard display this is sharp. For viewport-spanning hero type on a 2× or 3× DPR display, the 64px cell is not enough resolution — the edges look slightly blurred and the stroke weight feels inconsistent. Set `sdfGlyphSize: 128` for any hero-scale instance, before the first sync; changing it after the atlas is built requires a new one. VRAM cost scales quadratically: 128 costs 4× a 64, 256 costs 16×. For hero type, 128 is the correct default; leave 64 for body.

4. **Depth conflict with particle layers — z-fighting or partial occlusion.**
   Text and particles rendered at similar world-space z values produce z-fighting: the text partially or intermittently disappears behind particle sprites depending on per-frame GPU rasterization order. Two fixes with different tradeoffs:
   - **(a) Always-on-top:** `depthTest: false` on the material you pass in, plus `mesh.renderOrder = 999`. The text draws last and ignores the depth buffer. Guaranteed visibility from any camera angle. Trade-off: breaks depth correctness (text will render in front of geometry that should occlude it). Use this only for hero type where "type is always legible" is the design intent.
   - **(b) Depth-correct transparent sort:** Keep `depthTest: true` and `transparent: true`. Manually sort particle positions by camera distance each frame and set `renderOrder` accordingly. Correct but adds per-frame JS cost. Use this for scene-integrated labels where depth accuracy matters (data viz, 3D callouts).
   For a hero wordmark, default to (a).

5. **A custom shader that tries to read the glyph edge tints the whole letter.**
   The intuition is that troika samples the MSDF first and your code runs after — it is the other way round. Your fragment shader sets `gl_FragColor`; troika's derived layer then computes `edgeAlpha` from the distance field, multiplies it into `gl_FragColor.a`, and discards fragments outside the glyph. So an effect keyed off `gl_FragColor.a` in your own shader is reading your own alpha, which is usually a constant. Symptom: the glow or sweep appears, but flat across every glyph instead of banded at the edges. Own the RGB in your material; leave the edge to troika's `outlineWidth` / `strokeWidth` family.

6. **The handle's `dispose()` frees the geometry and nothing else.**
   `msdfText` returns `{ mesh, dispose }`, and that `dispose` calls troika's `mesh.dispose()` — which is one line: `this.geometry.dispose()`. The material is not in it. What troika *does* do is register a listener on the base material you passed in, so disposing **your** material cascades to the derived copy it built. So track both, or a route change leaks the derived shader program every time:

   ```ts
   const material = this.track(new THREE.MeshBasicMaterial({ transparent: true }));
   const label = this.track(await msdfText({ text: 'STUDIO', font: '/fonts/display-700.woff', material }));
   ```

   `BaseScene.track()` takes anything with a `dispose()`, so both the handle and the material go through the same path, and the scene's `dispose()` drains them. If you supplied no material at all, troika's shared default is not yours to dispose — the handle alone is correct.

## Reference

See `references.md`:

- **Zajno** entry: The homepage hero sets a massive custom wordmark ("zajno®") at approximately 60% of viewport height — type as the entire hero subject, with a product photograph composited as a secondary element beneath it. The annotation calls out "wordmark-as-hero is a legitimate alternative to 3D-object-as-hero." MSDF makes this viable in a three.js scene because the letters hold sharp edges at that scale without raster blur. What to copy: the commitment to type at hero scale, and the discipline of letting it be the primary compositional weight. What to skip: their specific glyph treatment and registered-trademark detail are house style — copy the scale-and-weight strategy, not the specifics.

- **Active Theory** entry: A holographic chrome logomark in deep black space, with a sparse trailing particle burst. The type treatment here is embedded in a 3D scene that owns the full viewport — the logo sits inside the WebGL context, not above it in HTML. This is the integration model that MSDF enables: type as a scene object rather than a DOM overlay. What to copy: the dark field as the prerequisite for any type-in-scene treatment — you need the background contrast budget for the letterforms and the glow to register. What to skip: the chrome/holographic logo material is a fresnel-driven shader (see `techniques/fresnel-iridescence.md`) applied to extruded geometry, not MSDF — distinguish between the type-in-scene composition strategy (copyable) and their specific logomark material (different technique file).
