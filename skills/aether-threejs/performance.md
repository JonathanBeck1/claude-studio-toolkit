# Performance Budgets & Profiling

Premium three.js sites die when they ship laggy mobile. These numbers are non-negotiable; if a scene blows them, redesign rather than patch.

## Budgets

| Metric | Target | Hard limit |
|---|---|---|
| First Contentful Paint (4G) | < 1.0s | < 1.5s |
| Hero scene rendering on mid-tier laptop | < 2.0s | < 3.0s |
| Mobile FPS (2-year-old iPhone, sustained) | 60 | 30 |
| Per-page client JS gzip (excluding three.js) | 200 KB | 250 KB |
| three.js itself | ~150 KB gzip | (fixed, the library cost) |
| Per-page asset payload (models + textures combined) | 1.0 MB | 1.5 MB |
| Single texture max | 512 KB compressed (KTX2) | 1 MB |
| Single model max | 300 KB compressed (DRACO + Meshopt) | 500 KB |
| Draw calls per frame | < 50 | < 100 |
| Triangles per scene | < 200k | < 500k |

## Profiling — desktop

1. Open Chrome DevTools → Performance tab.
2. Click record, interact with the scene for 10 seconds, stop recording.
3. Look at the FPS meter overlay (Rendering tab → Frame Rendering Stats). Confirm sustained 60 FPS.
4. Open the bottom panel summary. Frame time should average < 16ms. If > 16ms, identify the long task in the flame graph.
5. Open Memory tab → take a heap snapshot. Confirm < 100 MB used after page settles.

## Profiling — mobile

1. Connect a 2-year-old iPhone via USB or use BrowserStack.
2. Open the deployed (not localhost) URL on the device.
3. Use Safari → Develop menu → device → page to open Web Inspector.
4. In Web Inspector, open the Timelines tab and record 10 seconds of interaction.
5. Confirm sustained 30+ FPS. If lower, common causes:
   - Texture sizes too large (compress with KTX2)
   - Too many draw calls (use instanced rendering)
   - Postprocessing too heavy (reduce passes on mobile via media query or device-pixel-ratio check)
   - Custom shader has expensive operations in fragment shader (move to vertex where possible)

## Required optimizations from day one

- [ ] All textures compressed to KTX2 / Basis Universal before commit
- [ ] All glTF models run through `gltf-transform` with DRACO + MeshOpt
- [ ] `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))` — never blindly use device pixel ratio
- [ ] Particle systems > 1000 particles use `InstancedMesh` or `Points` with custom buffer geometry, never individual meshes
- [ ] Postprocessing passes that are heavy on mobile (e.g., `DepthOfField`) gated by viewport width or device-pixel-ratio
- [ ] Static geometries marked `geometry.computeBoundingSphere()` once and frustum-culled
- [ ] `renderer.shadowMap` disabled unless shadows are deliberately part of the art direction
- [ ] Lazy-load assets per route — don't bundle every page's models into the initial chunk

## Symptom → fix table

| Symptom | Likely cause | Fix |
|---|---|---|
| Mobile FPS < 30 | Pixel ratio too high | Cap at 2.0 |
| Mobile FPS < 30, low draw calls | Fragment shader too expensive | Profile via Spector.js, simplify |
| Long initial paint | Hero model too large | Compress with `gltf-transform` |
| Memory grows over time | Geometries or textures not disposed on route change | Audit `SceneManager` cleanup |
| Frame drops during scroll | Postprocessing chain re-runs every frame | Confirm `composer.render()` not duplicated |
| Choppy camera animation | RAF callback doing layout work | Move DOM reads outside RAF |

## Tooling

- **Spector.js** — browser extension. Captures a single WebGL frame. Inspect every draw call, every shader, every uniform. Indispensable for debugging custom shaders.
- **stats.js** — drop-in FPS / MS / MB overlay. Add behind a `?stats` query param.
- **Chrome DevTools Coverage tab** — finds unused JS / CSS that's bloating the bundle.
- **Lighthouse** — periodic checks for FCP / LCP. Run from CI in Phase 6.
