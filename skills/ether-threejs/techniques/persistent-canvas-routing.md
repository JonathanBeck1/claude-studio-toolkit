# Persistent Canvas Routing (Astro View Transitions + SceneManager)

## When to use

Sites where the WebGL canvas is the continuous ambient field the page lives inside — not a section-level decoration that gets mounted and unmounted per route. Use this when: (a) the hero scene should survive navigation (logo, ambient field, or background cloth), (b) route transitions need to feel like a camera move between two spaces rather than a reload, or (c) the GPU scene state — loaded textures, compiled shaders, preloaded audio — is expensive enough that re-initializing it per page visit would produce a visible 200–800ms black frame.

This is the right pattern for: the TakeTwo site itself (one canvas, four route scenes sharing the same renderer), any portfolio site where project pages fly into from the home grid, experience-type sites where the "room" persists and the "content" changes.

This is the wrong pattern for: sites where each page has genuinely different renderer configurations (e.g., one page uses WebXR, another needs a 2D canvas), sites where individual pages are authored by different teams and cannot share a scene contract, cases where the route content is so heavy (large GLTF per page) that the GPU memory benefit of a shared renderer is outweighed by the complexity of scene disposal and re-initialization.

**When a simpler approach is better:** if you only have two routes and the "transition" is just a crossfade, a CSS opacity transition on the canvas wrapper is sufficient. SceneManager is for 3+ routes with authored camera transitions between scenes that share a renderer.

## What it gives you

A WebGL renderer that never tears down across navigation. Route changes become GSAP camera transitions from the exiting scene into the entering scene — the new scene is preloaded (textures, shader compilation) before the old scene exits, so the camera move reveals a fully ready scene rather than a still-loading one. The browser tab never goes black between pages. GPU-resident textures and compiled shaders from the shared renderer persist: a 4-page site that would cost 800ms of initialization per visit costs that once.

The visual outcome: the site feels like one continuous space. Navigation is movement, not replacement.

## Required setup

Astro's `<ViewTransitions />` component enables the browser-native View Transitions API and provides the `astro:after-swap` event that signals when the DOM has been swapped for the next route. The `transition:persist` attribute on the canvas tells Astro to keep that DOM node alive across swaps — the renderer attached to it survives because the canvas element itself never leaves the document.

In the root layout (`src/layouts/Layout.astro`):

```astro
---
import { ViewTransitions } from 'astro:transitions';
---
<html lang="en">
  <head>
    <ViewTransitions />
  </head>
  <body>
    <canvas id="scene-canvas" transition:persist />
    <slot />
  </body>
</html>
```

Install GSAP if not already present:

```bash
npm install gsap
```

## Code recipe

### SceneManager — owns the renderer, manages per-route scene swaps

```js
// kit/src/core/SceneManager.ts
import * as THREE from 'three';
import gsap from 'gsap';

export class SceneManager {
  constructor(canvas) {
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
    });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(window.innerWidth, window.innerHeight);

    this.scenes = new Map();        // routeName -> () => Scene instance
    this.activeScene = null;
    this.lastTime = 0;
    this.running = false;

    window.addEventListener('resize', () => this.handleResize());
  }

  registerScene(routeName, sceneFactory) {
    this.scenes.set(routeName, sceneFactory);
  }

  async transitionTo(routeName) {
    const factory = this.scenes.get(routeName);
    if (!factory) {
      console.warn(`No scene registered for route: ${routeName}`);
      return;
    }

    const next = factory(this.renderer);

    // Preload the next scene before tearing down the current one.
    // Textures and shaders compile during this await — the renderer
    // is still drawing the current scene while preload runs.
    if (next.preload) await next.preload();

    if (this.activeScene) {
      await this.activeScene.exitTransition();
      this.activeScene.dispose();
    }

    this.activeScene = next;
    await this.activeScene.enterTransition();
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.lastTime = performance.now();
    this.tick = this.tick.bind(this);
    requestAnimationFrame(this.tick);
  }

  tick(now) {
    if (!this.running) return;
    const deltaTime = (now - this.lastTime) / 1000;
    this.lastTime = now;

    if (this.activeScene) {
      this.activeScene.tick(now / 1000, deltaTime);

      // If the scene has an EffectComposer, it replaces renderer.render().
      if (this.activeScene.composer) {
        this.activeScene.composer.render(deltaTime);
      } else {
        this.renderer.render(this.activeScene.scene, this.activeScene.camera);
      }
    }

    requestAnimationFrame(this.tick);
  }

  handleResize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.renderer.setSize(w, h);

    if (this.activeScene?.camera) {
      this.activeScene.camera.aspect = w / h;
      this.activeScene.camera.updateProjectionMatrix();
    }

    if (this.activeScene?.composer) {
      this.activeScene.composer.setSize(w, h);
    }
  }

  destroy() {
    this.running = false;
    this.activeScene?.dispose();
    this.renderer.dispose();
  }
}
```

### Per-scene contract — every scene must implement this interface

`SceneManager` calls `preload`, `enterTransition`, `exitTransition`, `tick`, and `dispose` in that order across a scene's lifetime. All transitions return Promises so `transitionTo` can `await` them in sequence.

```js
// site/src/scene/scenes/home/HomeScene.ts
import * as THREE from 'three';
import gsap from 'gsap';

export class HomeScene {
  constructor(renderer) {
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(
      50,
      window.innerWidth / window.innerHeight,
      0.1,
      100
    );
    this.composer = null;       // optional: EffectComposer instance. If set, replaces renderer.render().
    this.disposables = [];      // every BufferGeometry, Material, Texture, RenderTarget added to this scene.
  }

  async preload() {
    // Optional. Load textures, compile shaders, parse GLTFs.
    // SceneManager awaits this before calling exitTransition on the previous scene,
    // so the old scene stays visible while the new one loads.
    //
    // Example:
    // const loader = new THREE.TextureLoader();
    // this.map = await loader.loadAsync('/textures/hero.webp');
    // this.disposables.push(this.map);
  }

  async enterTransition() {
    // Animate the camera from an "off" pose into the scene's authored intro pose.
    // Returned Promise resolves when the animation completes.
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (prefersReduced) {
      // Skip animation — place camera at the final pose immediately.
      this.camera.position.set(0, 0, 5);
      return;
    }

    return new Promise((resolve) => {
      gsap.fromTo(
        this.camera.position,
        { x: 0, y: 0, z: 20 },
        { x: 0, y: 0, z: 5, duration: 0.8, ease: 'expo.out', onComplete: resolve }
      );
    });
  }

  async exitTransition() {
    // Animate the camera back to the "off" pose before dispose() is called.
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (prefersReduced) {
      this.camera.position.set(0, 0, 20);
      return;
    }

    return new Promise((resolve) => {
      gsap.to(this.camera.position, {
        z: 20,
        duration: 0.6,
        ease: 'expo.in',
        onComplete: resolve,
      });
    });
  }

  tick(time, deltaTime) {
    // Per-frame updates. Update shader uniforms, rotate objects, step particle systems.
    // time = seconds since start (monotonic). deltaTime = seconds since last frame.
  }

  dispose() {
    // Release every GPU resource this scene allocated.
    // Geometries, materials, and textures each hold GPU buffers independently.
    // Meshes themselves do not need .dispose() — only what they reference does.
    this.disposables.forEach((d) => d.dispose());
    if (this.composer) this.composer.dispose();
  }
}
```

**What belongs in `this.disposables`:** `BufferGeometry`, `Material` (and all subclasses), `Texture`, `WebGLRenderTarget`, `EffectComposer`. Meshes and Groups do not hold GPU memory — the geometry and material they reference do.

### Routing through the kit — `initSceneRouter` (the shipped pattern)

As built, `ether/astro → initSceneRouter` owns ALL of this wiring —
route-table registration, route normalization (prod serves `/web/`,
dev `/web`), initial-route resolution from the address bar, the
navigation listener, single-flight init guarding against double-boot,
and teardown (real teardown only on `beforeunload`; the manager
survives every swap). Site code passes a routes map once and never
touches navigation events:

```ts
// site/src/scene/boot.ts — the real consumer
import { initSceneRouter } from 'ether/astro';

await initSceneRouter(canvas, {
  '/': (renderer, quality) => new HomeScene(renderer, quality),
  '/web': (renderer, quality) => new WebScene(renderer, quality),
});
```

All routes register up front in `boot.ts` — a new page's own scripts
execute after the swap, which is too late to register the factory the
transition needs.

Two deliberate corrections in the shipped design vs this file's
original sketch:

- **`astro:before-swap`, not `after-swap`, drives the transition.**
  The event dispatch runs the outgoing scene's `exitTransition`
  synchronously up to its first `await`, so scroll- and DOM-coupled
  state (ScrollTriggers, the Lenis bridge) detaches BEFORE Astro
  mutates the DOM and resets scroll. After-swap is too late — the old
  triggers would fire `onUpdate` against the new DOM. The event's
  `e.to.pathname` carries the destination; `location.pathname` is
  still the OLD route at dispatch time.
- **`SceneManager.transitionTo` is a latest-wins queue.** Rapid
  A→B→A converges on the last URL Astro settled on; same-route calls
  are no-ops; `enterTransition` is NOT awaited by the queue, so a
  navigation during a long intro interrupts it via `dispose` — scenes
  must kill their intro timelines there (GSAP `kill()` suppresses
  `onComplete`, closing the triggers-after-dispose leak).

### prefers-reduced-motion

The motion concern is camera animation between scenes — a rapid dolly from z=20 to z=5. For users with vestibular sensitivity, skip the interpolation and set the camera to its final position directly. The scene contract above handles this inside `enterTransition` and `exitTransition`. No SceneManager change is needed — each scene applies the check independently, which allows different scenes to make different motion decisions (e.g., a service page might have no camera animation at all, and the check is a no-op).

```js
// Pattern used inside every scene's enterTransition / exitTransition:
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (prefersReduced) {
  this.camera.position.set(0, 0, 5); // final pose directly
  return;                             // no GSAP, no await
}

return new Promise((resolve) => {
  gsap.fromTo(this.camera.position, { z: 20 }, { z: 5, duration: 0.8, ease: 'expo.out', onComplete: resolve });
});
```

## Tunable parameters

| Parameter | Default | Range | Effect |
|---|---|---|---|
| `enterTransition` duration | `0.8 s` | 0.3 – 2.0 s | How long the camera takes to arrive at the scene's intro pose. 0.8 s is the minimum that reads as "moved there"; below 0.4 s it reads as a pop. Above 1.5 s the user is waiting for the site to respond. |
| `exitTransition` duration | `0.6 s` | 0.2 – 1.0 s | Exit should always be shorter than enter — the user has already decided to leave; don't detain them. A 0.6/0.8 ratio (exit/enter) gives a snappy leave and a weighted arrival. |
| `ease: 'expo.out'` on enter | `expo.out` | `power2.out`, `expo.out`, `circ.out` | Controls the deceleration curve of the camera arrival. `expo.out` reads as physical (fast then drift to rest). `power2.out` is softer. `circ.out` is sharper and slightly mechanical. |
| `renderer.setPixelRatio` cap | `2` | 1 – 3 | Capped at 2 to protect mobile GPUs. On a 3× retina display, rendering at 3× pixel ratio produces 2.25× more fragments than 2× — measurable cost for no visible improvement at normal viewing distance. Cap at 1.5 for GPU-heavy scenes. |
| `powerPreference: 'high-performance'` | `'high-performance'` | `'default'`, `'low-power'`, `'high-performance'` | On dual-GPU machines (MacBooks with discrete + integrated), tells the browser to prefer the discrete GPU. `'default'` often selects the integrated GPU on AC power, halving fill rate. Use `'high-performance'` for TakeTwo hero scenes; only drop to `'low-power'` for ambient backgrounds that don't need full framerate. |

## Common pitfalls

1. **Geometries, materials, and textures not disposed on scene change.** WebGL keeps GPU buffers alive until JavaScript releases them via `.dispose()`. After 5–10 route navigations without disposal, GPU memory fills and the browser either kills the tab or drops to a software renderer. The symptom arrives late and is hard to attribute — the site "worked fine" during development because no one navigated more than 3 times. Track every GPU-allocating object in `this.disposables` and call `.dispose()` on each inside `dispose()`. The types that need disposal: `BufferGeometry`, `Material`, `Texture`, `WebGLRenderTarget`, `EffectComposer`. Meshes themselves do not need disposal — only what they reference does. A mesh removed from the scene with `scene.remove(mesh)` does not free its geometry or material.

2. **View Transitions API needs a fallback for older browsers.** Safari before version 18 did not support the View Transitions API. When Astro's `<ViewTransitions />` detects no support, it falls back to a full page navigation — the canvas DOM node is replaced and the renderer loses its context. The persistent-canvas architecture silently breaks: the renderer is initialized from scratch, initialization cost returns, and the first frame after each navigation is black. Detect support before relying on the architecture: `if (!document.startViewTransition) { /* fallback: no transition, full reload */ }`. For TakeTwo's audience (premium-targeting, B2B/creative), requiring modern browsers is acceptable. Do not paper over the fallback by pretending it doesn't exist — a black flash is worse than a plain navigation.

3. **Stale ScrollTriggers across navigation — solved structurally, not with `ScrollTrigger.refresh()`.** In the shipped design no trigger ever outlives its scene: the outgoing scene kills its own triggers synchronously in `exitTransition` (inside the before-swap dispatch, ahead of the DOM mutation and scroll reset), and the incoming scene creates its triggers only AFTER its intro completes, measuring the already-settled new DOM (the ether-scroll triggers-after-intro rule). There is never a stale trigger to refresh. A global `refresh()` on navigation is only needed if a trigger outlives its scene — which is itself the bug to fix.

4. **Canvas does not resize correctly when viewport changes during a transition.** The `handleResize` handler fires immediately on `resize`, but if a scene swap is in progress — `exitTransition` is awaited, `dispose` runs, `preload` runs, `enterTransition` starts — the `activeScene` is in an intermediate state. Calling `this.activeScene.camera.aspect = w / h` mid-swap may set the aspect on a scene that is already disposed or not yet the active one. Two options: (a) queue the resize event and apply it after `transitionTo` resolves (cleaner for hero scenes), or (b) apply immediately and accept a single-frame glitch if the user happens to resize during the 800ms transition window. For TakeTwo's hero scenes, option (a) is preferred — add a `this.pendingResize` flag and flush it at the end of `transitionTo`.

5. **Multiple navigation listeners accumulate.** If a navigation `addEventListener` call lives inside a component `<script>` re-evaluated after each swap, each navigation adds one more listener and scene transitions multiply per hop — race condition, GPU memory leak, or runtime error depending on timing. The shipped kit handles this inside `initSceneRouter`: the single-flight init guard means one manager per canvas, the manager registers exactly one persistent `astro:before-swap` listener, and `beforeunload` cleanup removes it. Only hand-rolled routers need the module-scope / body-dataset guard patterns.

## Reference

See `references.md`:

- **Hello Monday** entry: The dark sliding panel that sits over the right edge of the hero is a navigation surface sitting above a single WebGL canvas that persists between the hero and project tiles below. The project tile color fields stay live on the same WebGL context as the hero. This is the architectural choice this technique implements — one canvas under all HTML overlays, scenes swapped via camera transitions, never a page reload. What to copy: the architecture. What to skip: Hello Monday's illustration style is a studio signature; borrow the persistent-canvas structure, not the artwork.

- **Bonhomme** entry: Bonhomme Paris is cited publicly for narrative scrollytelling case studies with persistent canvas state across route changes, but the `references/screenshots/bonhomme.png` capture landed on `bonhomme.lol` (Maxime Bonhomme's personal portfolio), not Bonhomme Paris (`bonhommeparis.com`). Do not cite this entry as verified evidence until the screenshot is re-captured against the correct URL. The technique recipe above does not depend on that capture — it is grounded in the Hello Monday entry and in Active Theory's navigation behavior (project-to-project transitions with no renderer reset).
