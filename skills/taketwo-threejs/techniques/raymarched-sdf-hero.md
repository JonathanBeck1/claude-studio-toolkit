# Raymarched SDF Hero

## When to use

Hero canvases where the defining quality is organic, continuously smooth form — shapes that morph, merge, and breathe without seams — and where polygon-based geometry would require either a prohibitively high face count or a baked normal-map trick that falls apart on close inspection. Raymarched SDFs are the right tool when the form itself is the concept: metaball clusters, smooth-union compositions that feel like wet clay pressing together, procedural terrains with infinite-detail silhouettes.

Right for: blob/metaball heroes that need to feel alive (`/`), smooth-union brand shapes that don't reduce to clean CAD geometry, procedural cave/organic-interior backgrounds, hero compositions where type is visible through or behind the SDF form (type-behind-refraction, per the Resn reference).

Wrong for: scenes with many distinct objects — every ray must evaluate every SDF in the scene, so cost grows O(n) per pixel per march step and explodes quickly. Also wrong for textured surfaces (SDFs are pure math, no UV), text rendering (use MSDF), particle systems (use point primitives + curl noise — `techniques/curl-noise-particles.md`), and any context where a polygon mesh can do the job at lower fragment cost.

## What it gives you

A hero form defined entirely in math: smooth-union merging between displaced spheres that warble organically over time, shaded with a Lambert + fresnel-like color ramp using TakeTwo's violet/teal accent palette. The surface rotates slowly, two lobes pulsing and blending at their junction. Because there are no polygons, the silhouette is infinitely crisp at any resolution, and the smooth-union seam is analytically smooth — no hard edge where the meshes would intersect. The background pixels `discard` cleanly, so the form composites over whatever layer lives beneath it (particles, type, a dark field).

## Primer — signed distance fields and raymarching

A signed distance function (SDF) takes a point in 3D space and returns one number: the shortest distance from that point to the nearest surface. Positive means you are outside the surface, negative means inside, zero means you are exactly on it. The elegance is that you can compose SDFs with arithmetic: `min(a, b)` gives the union of two shapes, `max(a, -b)` subtracts `b` from `a`, `max(a, b)` gives the intersection. Inigo Quilez catalogues the full SDF primitive library at [iquilezles.org/articles/distfunctions](https://iquilezles.org/articles/distfunctions/) — this is the canonical reference, not a secondary one.

Raymarching is the rendering algorithm that uses an SDF to find where a view ray hits a surface. Start at the camera origin, step along the ray by the distance the SDF returns (since that distance is the guaranteed safe step before hitting anything), and repeat. When the returned distance falls below a threshold, the ray has hit. Because each step is the maximum safe step size rather than a fixed tiny increment, raymarching converges in 32–128 steps for typical hero-scale scenes. The cost: every visible pixel runs a loop of SDF evaluations in the fragment shader. This is significantly heavier than rasterizing polygons, and it scales with pixel count, not polygon count.

Smooth minimum (`smoothMin`) is a key building block — it blends the union of two SDFs over a radius `k`, producing a soft organic merge rather than a hard boolean union. This is what makes two spheres merge like soap bubbles rather than intersect like geometry.

## Required setup

Render the SDF to a fullscreen quad — a flat `PlaneGeometry(2, 2)` in NDC coordinates rendered without any camera transform. The SDF raymarcher reconstructs the view ray itself from UV coordinates, so the geometry is just a surface to run the fragment shader across. The SDF scene lives in a separate `THREE.Scene` (`heroScene`) so its render order and depth state don't interfere with the main scene.

```js
import * as THREE from 'three';

const quadGeometry = new THREE.PlaneGeometry(2, 2); // covers NDC -1..1

const quadMaterial = new THREE.ShaderMaterial({
  vertexShader: heroVertGLSL,
  fragmentShader: heroFragGLSL,
  uniforms: {
    uTime:             { value: 0 },
    uResolution:       { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
    uCameraPosition:   { value: new THREE.Vector3(0, 0, 4) },
    uMaxSteps:         { value: 64 },
    uSurfaceThreshold: { value: 0.001 },
    uDisplacement:     { value: 0.3 },
    uRotationSpeed:    { value: 0.2 },
    uColorA:           { value: new THREE.Color(0xe66cff) }, // violet
    uColorB:           { value: new THREE.Color(0x59ffe2) }, // teal
  },
  depthTest: false,
  depthWrite: false,
  transparent: true, // required so discard'd pixels are truly transparent
});

const heroQuad = new THREE.Mesh(quadGeometry, quadMaterial);
heroQuad.frustumCulled = false; // fullscreen — never cull
heroScene.add(heroQuad);

// Render order: SDF hero behind particles
heroQuad.renderOrder = -1;
// particleSystem.renderOrder = 0; // default
```

Resize handler — always update `uResolution` or the aspect correction breaks:

```js
window.addEventListener('resize', () => {
  quadMaterial.uniforms.uResolution.value.set(
    window.innerWidth,
    window.innerHeight
  );
});
```

## Code recipe

### Vertex shader — fullscreen passthrough

No model/view/projection transform. The quad is already in clip space. The vertex shader's sole job is to pass UVs through.

```glsl
varying vec2 vUv;

void main() {
  vUv = uv;
  gl_Position = vec4(position, 1.0);
}
```

### Fragment shader — full raymarcher

```glsl
uniform float uTime;
uniform vec2  uResolution;
uniform vec3  uCameraPosition;
uniform float uMaxSteps;
uniform float uSurfaceThreshold;
uniform float uDisplacement;
uniform float uRotationSpeed;
uniform vec3  uColorA;
uniform vec3  uColorB;

varying vec2 vUv;

const float MAX_DISTANCE = 50.0;

// ──────────────────────────────────────────────────────────────────────────────
// SDF primitives and operators
// Full catalogue: https://iquilezles.org/articles/distfunctions/
// ──────────────────────────────────────────────────────────────────────────────

// Smooth minimum — produces a blended union between two distances.
// k controls the blend radius: larger k = softer merge.
float smoothMin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// Sphere SDF centered at origin with radius r.
float sphereSDF(vec3 p, float r) {
  return length(p) - r;
}

// Rotation matrix around the Y axis.
mat3 rotateY(float a) {
  float c = cos(a), s = sin(a);
  return mat3(
     c,  0.0, -s,
    0.0, 1.0, 0.0,
     s,  0.0,  c
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Scene SDF — two displaced spheres in smooth union, slowly rotating
// ──────────────────────────────────────────────────────────────────────────────

float sceneSDF(vec3 p) {
  // Rotate the whole field so the viewer orbits the form.
  p = rotateY(uTime * uRotationSpeed) * p;

  // Sinusoidal displacement — each sphere warbles independently.
  float displaceA =
    sin(p.x * 4.0 + uTime) *
    sin(p.y * 4.0 + uTime) *
    sin(p.z * 4.0) *
    uDisplacement;

  float displaceB =
    sin(p.x * 3.0 - uTime * 0.7) *
    sin(p.y * 3.0) *
    sin(p.z * 3.0 + uTime * 0.5) *
    uDisplacement;

  float a = sphereSDF(p - vec3(-0.5, 0.0, 0.0), 0.7) + displaceA;
  float b = sphereSDF(p - vec3( 0.5, 0.0, 0.0), 0.7) + displaceB;

  // k = 0.4 gives a generous, soap-bubble-style merge at the junction.
  return smoothMin(a, b, 0.4);
}

// ──────────────────────────────────────────────────────────────────────────────
// Normal estimation — 6-tap central-difference finite difference
// eps must sit at unit-ish scale: 0.001 for fields in the 0.5..2.0 range.
// Too small (≤ 0.0001) → floating-point noise, sparkly normals.
// Too large (≥ 0.01) → smeared normals, lost surface detail.
// ──────────────────────────────────────────────────────────────────────────────

vec3 estimateNormal(vec3 p) {
  const float eps = 0.001;
  return normalize(vec3(
    sceneSDF(p + vec3(eps, 0.0, 0.0)) - sceneSDF(p - vec3(eps, 0.0, 0.0)),
    sceneSDF(p + vec3(0.0, eps, 0.0)) - sceneSDF(p - vec3(0.0, eps, 0.0)),
    sceneSDF(p + vec3(0.0, 0.0, eps)) - sceneSDF(p - vec3(0.0, 0.0, eps))
  ));
}

// ──────────────────────────────────────────────────────────────────────────────
// Main — ray setup, march loop, shading
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  // Map UV to NDC, correct for aspect ratio so the form isn't squashed.
  vec2 ndc = vUv * 2.0 - 1.0;
  ndc.x *= uResolution.x / uResolution.y;

  vec3 rayOrigin = uCameraPosition;
  vec3 rayDir    = normalize(vec3(ndc, -1.5)); // focal length ≈ 1/1.5

  // March along the ray.
  float t   = 0.0;
  bool  hit = false;

  for (int i = 0; i < 256; i++) {
    // Cast uMaxSteps as int for comparison — uniform float cast in loop.
    if (float(i) >= uMaxSteps) break;

    vec3  p = rayOrigin + rayDir * t;
    float d = sceneSDF(p);

    if (d < uSurfaceThreshold) {
      hit = true;
      break;
    }

    t += d;

    if (t > MAX_DISTANCE) break;
  }

  // ── Hit branch ──────────────────────────────────────────────────────────────

  if (hit) {
    vec3 p = rayOrigin + rayDir * t;
    vec3 n = estimateNormal(p);

    // Single key light, world-space.
    vec3  lightDir = normalize(vec3(1.0, 1.0, 1.0));
    float lambert  = max(dot(n, lightDir), 0.0);

    // Fresnel-like rim: blend uColorA (violet) to uColorB (teal) by view angle.
    // pow(..., 2.0) keeps the blend subtle — raise exponent for a tighter rim.
    float fresnelLike = pow(1.0 - max(dot(n, -rayDir), 0.0), 2.0);
    vec3  baseColor   = mix(uColorA, uColorB, fresnelLike);

    // Ambient + diffuse.
    vec3 color = baseColor * (0.2 + 0.8 * lambert);

    // Atmospheric depth fog — far-side surfaces recede without needing a skybox.
    float fog = 1.0 - smoothstep(2.0, 8.0, t);
    color *= fog;

    // fwidth-based analytical AA hook — for hero quality, compute:
    //   float edgeDist = sceneSDF(rayOrigin + rayDir * t);
    //   float fw = fwidth(edgeDist);
    //   float alpha = 1.0 - smoothstep(-fw, fw, edgeDist);
    //   gl_FragColor = vec4(color, alpha);
    // For now, fully opaque on hit.
    gl_FragColor = vec4(color, 1.0);

  } else {
    // ── Miss branch ─────────────────────────────────────────────────────────
    // transparent: true on the material means discard'd pixels composite
    // cleanly over whatever layer is below (particles, background plane, etc.).
    // See Pitfall 5 before switching between discard and alpha = 0.
    discard;
  }
}
```

### Per-frame update

```js
function animate(elapsed) {
  requestAnimationFrame(animate);

  quadMaterial.uniforms.uTime.value = elapsed * 0.001; // seconds

  // If rendering heroScene separately (recommended for render order clarity):
  renderer.autoClear = false;
  renderer.clear();

  renderer.render(heroScene, dummyCamera);  // SDF quad (renderOrder = -1)
  renderer.render(mainScene, mainCamera);   // particles, type, etc.
}
```

`dummyCamera` is any `THREE.Camera` instance — the vertex shader ignores all camera matrices, but three.js requires a camera argument to `render()`.

### Compositing with particles

The SDF hero renders at `renderOrder = -1`, so it always draws before the particle system at the default `renderOrder = 0`. For more explicit control — separate post-processing, bloom applied selectively to the SDF but not the particles — render to a separate `THREE.WebGLRenderTarget` and composite manually in a final fullscreen pass. See `techniques/postprocessing-chain.md` for the multi-pass pattern.

## Tunable parameters

| Uniform | Default | Range | Effect |
|---|---|---|---|
| `uMaxSteps` | 64 | 16 – 128 | Maximum ray march steps per pixel. Lower = faster, but the marcher misses thin features and can tunnel through geometry. 64 is stable for a two-sphere scene at this displacement level. Drop to 32 on mobile as a performance gate. |
| `uSurfaceThreshold` | 0.001 | 0.0005 – 0.005 | Hit distance below which the ray is considered to have struck the surface. Too small = misses at displacement peaks; too large = the surface looks puffy and inset from the true SDF iso-surface. |
| `uDisplacement` | 0.3 | 0.0 – 0.8 | Amplitude of the sinusoidal warble applied to each sphere. At 0.0 the spheres are clean mathematical spheres; at 0.6+ they start to look like spiky coral. Keep below 0.5 for a shape that reads as organic-but-controlled. |
| `uRotationSpeed` | 0.2 | 0.0 – 1.0 | Speed of the Y-axis field rotation (radians / second). 0.2 reads as breathing; above 0.6 it reads as spinning and loses the ambient feel. |
| `uColorA` | `#e66cff` (violet) | TakeTwo accents | The color at low view-angle incidence (front-facing pixels). Swapping `uColorA` and `uColorB` inverts the fresnel ramp — teal on-face, violet on rim. |
| `uColorB` | `#59ffe2` (teal) | TakeTwo accents | The color at high view-angle incidence (rim/silhouette pixels). The violet → teal transition is the established TakeTwo fresnel cue. |

## Common pitfalls

1. **Fragment shader too expensive for mobile.** A full-viewport raymarch at 1080p with `uMaxSteps = 64` means approximately 130 000 rays × 64 SDF evaluations + 6-tap normal estimation for each hit pixel = millions of floating-point operations per frame. Mobile GPU shader units are significantly narrower than desktop. Gate raymarched SDF to desktop using `window.innerWidth > 900 && !/Mobi|Android/i.test(navigator.userAgent)`. On mobile, either swap to a simpler polygon-based hero or render at half resolution (`renderer.setPixelRatio(0.5)` for the SDF pass only) and upscale. Do not ship the full-quality raymarch to mobile and tune `uMaxSteps` to 16 hoping it will look acceptable — at 16 steps the surface shows significant artifacts at displacement peaks.

2. **Normal estimation epsilon wrong for your SDF scale.** The 6-tap finite difference in `estimateNormal` uses `eps = 0.001`, tuned for a field where coordinates sit in the 0.5–2.0 range. If your SDF coordinates are large (terrain scene, room-scale camera), a 0.001 epsilon becomes sub-pixel in SDF space — normals look noisy/sparkly because you are sampling numerical noise rather than surface geometry. If coordinates are small (sub-unit micro-forms), `eps = 0.001` smears across the whole feature and normals lose detail. Rule: `eps` should be roughly 0.1% of the characteristic feature size in your scene.

3. **No fog or atmospheric falloff — surfaces look pasted on.** Without distance-based attenuation, far-side geometry renders at the same brightness as near-side. The SDF composition is volumetrically ambiguous: the viewer cannot tell which lobe is in front. Always include a fog term in the hit branch: `float fog = 1.0 - smoothstep(near, far, t); color *= fog;`. The recipe above uses `smoothstep(2.0, 8.0, t)` for the two-sphere scene at camera distance 4.0 — adjust near/far to match your actual geometry bounds.

4. **Missing anti-aliasing at the silhouette boundary.** Raymarching produces a hard hit/miss transition at the silhouette — one pixel is a fully-shaded surface sample, the adjacent pixel discards. On high-DPI displays this is less visible, but on 1× screens the silhouette aliases badly, especially on the slowly-rotating form. Two remedies: (a) supersample — render 2× and downsample (doubles fragment cost, cleanest result); (b) `fwidth`-based analytical AA — at the hit pixel, compute `fwidth(sceneSDF(p))` to get the approximate screen-space gradient of the distance field at the surface, then blend `gl_FragColor.a` over that width. The fragment shader above leaves a `fwidth` comment hook where this belongs. For a hero quality level, implement it — the cost is one extra `sceneSDF` call per hit pixel, which is negligible compared to the march itself.

5. **`discard` vs `alpha = 0.0` — compositing mode mismatch.** `discard` skips the fragment entirely: the depth buffer is not written, the color buffer is not touched. This is correct when the SDF quad is composited over a layer that uses depth-based ordering (other geometry in the same scene). However, `discard` interacts badly with certain postprocessing composers that expect every pixel to write an alpha value. If the SDF quad is one pass in a multi-pass composer, replace `discard` with `gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0)` and ensure `transparent: true` is set on the `ShaderMaterial`. Symptom of getting this wrong: the SDF hero silhouette shows as a solid opaque black shape instead of being transparent in the compositor output.

## Reference

See `references.md` → **Resn** entry. A single dark refractive/shattered-glass form floating center-frame against near-black, with the studio name visible through the geometry — type-behind-refractive-object is the hardest version of this pattern because it demands real compositing depth, not a CSS filter. The Resn implementation proves the readability rule: one hero object, one piece of type, near-black field, nothing competing.

The canonical SDF primitive and operator reference is Inigo Quilez's [distfunctions article](https://iquilezles.org/articles/distfunctions/). Read it before authoring any new SDF primitive — most shapes you need are already there with correct, numerically stable implementations.
