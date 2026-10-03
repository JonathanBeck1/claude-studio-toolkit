# Performance Budgets & Profiling

Reference targets for a premium site on mid-tier hardware. A project's own budgets (its CLAUDE.md or docs) override them, and on their own they are not pass/fail. If a scene blows them, redesign rather than patch.

## Budgets

| Metric | Target | Ceiling |
|---|---|---|
| First Contentful Paint (4G) | < 1.0s | < 1.5s |
| Hero scene rendering on mid-tier laptop | < 2.0s | < 3.0s |
| Mobile FPS (2-year-old iPhone, sustained) | 60 | 30 |
| Per-page client JS gzip (excluding three.js) | 200 KB | 250 KB |
| three.js itself | ~150 KB gzip | (fixed, the library cost) |
| Per-page asset payload (models + textures combined) | 1.0 MB | 1.5 MB |
| Single texture max | 512 KB compressed (KTX2) | 1 MB |
| Single model max | 300 KB compressed (DRACO) | 500 KB |
| Draw calls per frame | < 50 | < 100 |
| Triangles per scene | < 200k | < 500k |

For draw calls, read the runtime snapshot (below). On a kit composer, scene draws ≈ `drawCalls − (renderCalls − 1)`.

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
   - Postprocessing too heavy (branch on the tier from `detectQuality()` in `ether/quality` — not a media query)
   - Custom shader has expensive operations in fragment shader (move to vertex where possible)

## Required optimizations from day one

- [ ] All textures compressed to KTX2 / Basis Universal before commit
- [ ] All glTF models run through `gltf-transform` with DRACO for geometry and KTX2 for textures — `loadGLTF` registers `DRACOLoader` and `KTX2Loader` only, so a MeshOpt-compressed file will not decode at runtime
- [ ] `renderer.setPixelRatio(Math.min(window.devicePixelRatio, quality.dprCap))` — never blindly use device pixel ratio, and never hard-code the cap. `dprCap` is 1.5 on LOW and MID, 2 on HIGH; `SceneManager` already applies it on attach
- [ ] Particle systems > 1000 particles use `InstancedMesh` or `Points` with custom buffer geometry, never individual meshes
- [ ] Postprocessing passes that are heavy on mobile (e.g., `DepthOfField`) gated on the quality tier, not on viewport width
- [ ] Static geometries marked `geometry.computeBoundingSphere()` once and frustum-culled
- [ ] `renderer.shadowMap` disabled unless shadows are deliberately part of the art direction
- [ ] Lazy-load assets per route — don't bundle every page's models into the initial chunk

## Symptom → fix table

| Symptom | Likely cause | Fix |
|---|---|---|
| Mobile FPS < 30 | Pixel ratio too high | Confirm `quality.dprCap` is applied (1.5 below HIGH) |
| Mobile FPS < 30, low draw calls | Fragment shader too expensive | Profile via Spector.js, simplify |
| Long initial paint | Hero model too large | Compress with `gltf-transform` |
| Memory grows over time | Geometries or textures not disposed on route change; the snapshot's `geometries/textures/programs` climb across repeated in-page A→B→A hops | Audit `SceneManager` cleanup |
| Frame drops during scroll | Postprocessing chain re-runs every frame | Confirm `composer.render()` not duplicated |
| Choppy camera animation | RAF callback doing layout work | Move DOM reads outside RAF |

## Tooling

- **Spector.js** — browser extension. Captures a single WebGL frame. Inspect every draw call, every shader, every uniform. Indispensable for debugging custom shaders.
- **`Stats` (`ether/dev`)** — the engine's own overlay: FPS, frame ms, GPU tier, DPR, composer state, viewport. No memory readout — use the DevTools Memory tab for that. Mount it behind a `?stats` query param and import it dynamically so it ships zero bytes when the param is absent.
- **Runtime snapshot (`manager.getDiagnostics()`, ether 1.2+)**: JSON from the live engine. See below.
- **Chrome DevTools Coverage tab** — finds unused JS / CSS that's bloating the bundle.
- **Lighthouse** — periodic checks for FCP / LCP. Run from CI.

## Runtime diagnostics (ether 1.2+)

`SceneManager.getDiagnostics()` returns a JSON snapshot of what the live engine is doing.

### Fields

- `scene` {phase, route, fallback, target, id, entered, failures, lastError}
- `performance` {frames, fps, cpuMs}
- `rendering` {skipped, renderCalls, drawCalls, triangles, geometries, textures, programs, dpr, contextLost}
- `postFX` {enabled, msaa, passes}
- `quality`

`quality` is what the profile asked for; everything else is observed. Per-field meaning is on ether's `RuntimeDiagnostics` type.

### Collecting

One recipe, for Playwright's `page.evaluate(fn, expected)` or any browser tool's evaluate (there, invoke it inline: `((expected) => { ... })('/')`). Run it every ~100 ms until `state` is `'settled'` or `'pre-1.2'`, or a ~15 s timeout. `expected` is the normalized route you are waiting on: no trailing slash, root stays `/`.

```js
(expected) => {
  const m = [...document.querySelectorAll('canvas')].find((c) => c.__sceneManager)?.__sceneManager;
  if (!m) return { state: 'no-manager' };
  if (!m.getDiagnostics) return { state: 'pre-1.2' };
  const d = m.getDiagnostics();
  const gl = m.renderer.getContext();
  const ext = gl.getExtension('WEBGL_debug_renderer_info');
  const gpu = ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'unknown';
  return { state: d.scene.phase === 'active' && d.scene.entered && d.scene.route === expected ? 'settled' : 'pending', d, gpu };
}
```

- Decide "ether < 1.2" only when a manager is found without `getDiagnostics`.
- Decide "manager not reachable" only at timeout. Causes: the app doesn't use `attachSceneManager`/`initSceneRouter`, boot never completed (the tag is set only after quality detection), or the engine detached (where ether still binds `beforeunload` to detach, a mailto or download click destroys the engine and deletes the tag). Report it as a finding, not a version mismatch.
- On timeout with a manager present, the last snapshot is the finding.
- Once settled, wait at least 600 ms so an fps window closes, then keep the raw JSON.
- **Software GL:** a `gpu` matching `/SwiftShader|llvmpipe|Software|Mesa offscreen/i`, or `'unknown'`, is not real hardware.

### Hops for leak checks

Hop by clicking in-page links or calling the app's own router, never `page.goto` or URL navigation, which reloads and gives a fresh manager.

- Prove continuity on every settled visit: `frames` keeps increasing and `id` never decreases (it rises on every rebuild and stays the same on a retarget). A drop back to `id` 1 means a full page load.
- If continuity fails (`id` back to 1 or `frames` restarting means the page fully reloaded, e.g. an Astro `<ClientRouter fallback="none">` in a browser without View Transitions), write `runtime: hop flatness not collected — full page loads`.
- Compare `geometries/textures/programs` at each A visit with the first A visit.

### Screenshots and provenance

- Take the page screenshot, never `canvas.toDataURL` (the drawing buffer is not preserved).
- Every number carries its provenance: commit (short SHA, plus `+dirty:<fingerprint>` on a dirty tree, where the fingerprint is `git diff HEAD | git hash-object --stdin | cut -c1-7`), URL, build, browser, GPU string, viewport. The fingerprint changes with any later edit, so stale evidence is detectable.

### Evidence rules

- Structural fields hold under any GL and can back a finding or a pass: phase, route, fallback, failures/lastError, skipped, renderCalls, drawCalls/triangles (whole-frame, so judge scene draws through the formula under Budgets), postFX, dpr, contextLost, memory counts and their flatness.
- `fps`/`cpuMs` count only from a real browser on named, real hardware, in a production build. Never write "60 fps", "smooth", "performant" or "within budget" without such a measurement. The mobile requirement stays open until measured on a device.
- `fps` excludes gaps over 1 s, so it does not capture hop or shader-compile hitches over 1 s; use the Performance tab for those.
- Budgets: judge against the project's own; if it has none, report the numbers and cite the Budgets table above as reference.

### Reading the snapshot

| Reading | Meaning | Severity |
|---|---|---|
| `frames` frozen while visible and active | Loop died | CRITICAL |
| `failures` > 0 | A hop or enter threw; `lastError` has route and message | CRITICAL on a shipped route |
| `phase` stuck at `exiting`/`loading` | Exit or preload never settles | CRITICAL |
| `active` but `entered` false long after load | `enterTransition` never settled | WARN |
| `fallback` true on a real page | No registration for that route | WARN unless it is the 404 |
| `skipped` `'zero-size'` | Canvas CSS-hidden | WARN if unintended |
| `skipped` `'renders-false'` with `drawCalls` > 0 | Park scene renders offscreen | NOTE |
| `contextLost` true | Context lost | CRITICAL unless induced |
| `postFX.enabled` disagrees with source | Composer not assigned, or a composer on a park route | WARN |
| `postFX.enabled` and `postFX.msaa` ≠ `quality.msaaSamples` | Composer not fed the profile (`msaa` is the requested count; the GPU may clamp it) | WARN |
| `dpr` ≠ `Math.min(devicePixelRatio, quality.dprCap)` read in-page | The cap is not the one applied; `dpr` is fixed at boot | WARN |
| Memory counts climbing across continuous hops | Disposal leak | CRITICAL |

### Caveats

- `renderCalls` is one per composer pass. With default bloom settings in postprocessing 6.39 the kit presets read 18 (hero/night), 2 (light) and 1 (direct render); a site that changes bloom levels or the luminance pass changes the count. It corroborates the preset the source layer found; it never identifies it.
- `textures` include composer render targets (17 on the bloom presets at defaults).
- `passes` shows structure, not the preset.
- `quality.enablePostFX`/`enableDither`/`antialias` are constants.
- `cpuMs` is main-thread only, about 0.1 ms resolution, and can be 0.
- Scroll state is not reported.
- Before 1.2, a raw `renderer.info.render.calls` read after a composed frame shows 1; never cite it.
