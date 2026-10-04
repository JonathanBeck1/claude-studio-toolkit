# Persistent Canvas Routing (Astro ClientRouter + SceneManager)

## When to use

Sites where the WebGL canvas is the continuous ambient field the page lives inside — not a section-level decoration that gets mounted and unmounted per route. Use this when: (a) the hero scene should survive navigation (logo, ambient field, or background cloth), (b) route transitions need to feel like a camera move between two spaces rather than a reload, or (c) the GPU scene state — loaded textures, compiled shaders, preloaded audio — is expensive enough that re-initializing it per page visit would produce a visible 200–800ms black frame.

This is the right pattern for: a studio site (one canvas, several route scenes sharing the same renderer), any portfolio site where project pages fly into from the home grid, experience-type sites where the "room" persists and the "content" changes.

This is the wrong pattern for: sites where each page has genuinely different renderer configurations (e.g., one page uses WebXR, another needs a 2D canvas), sites where individual pages are authored by different teams and cannot share a scene contract, cases where the route content is so heavy (large GLTF per page) that the GPU memory benefit of a shared renderer is outweighed by the complexity of scene disposal and re-initialization.

**When a simpler approach is better:** if you only have two routes and the "transition" is just a crossfade, a CSS opacity transition on the canvas wrapper is sufficient. SceneManager is for 3+ routes with authored camera transitions between scenes that share a renderer.

## What it gives you

A WebGL renderer that never tears down across navigation. Route changes become authored transitions from the exiting scene into the entering scene. The hop order is **exit old → dispose old → construct + preload next → enter** — exit first, so that scene resource lifetimes are strictly disjoint: the Lenis bridge, ScrollTriggers and pointer listeners a scene creates in its constructor are guaranteed torn down before the next scene creates its own. The cost of that ordering is a gap the outgoing scene has to cover, which is why `exitTransition` leaves the framebuffer dark: the last rendered frame holds until the incoming scene's first render, so the seam reads as a fade rather than a stall. The browser tab never goes black between pages. GPU-resident textures and compiled shaders from the shared renderer persist: a 4-page site that would cost 800ms of initialization per visit costs that once.

The visual outcome: the site feels like one continuous space. Navigation is movement, not replacement.

## Required setup

Astro's client router turns navigation into a DOM swap instead of a page load, and emits the `astro:before-swap` / `astro:after-swap` events around it. The `transition:persist` attribute on the canvas tells Astro to keep that DOM node alive across swaps — the renderer attached to it survives because the canvas element itself never leaves the document.

**The component is `<ClientRouter />`.** It was `<ViewTransitions />` through Astro 4 and was renamed in Astro 5. On Astro 6 — what the kit is used against — `ViewTransitions` is gone from `astro:transitions` entirely, so an older snippet fails at build on a missing export rather than on anything that points at the cause.

In the root layout (`src/layouts/Layout.astro`):

```astro
---
import { ClientRouter } from 'astro:transitions';
---
<html lang="en">
  <head>
    <ClientRouter />
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

### The manager is shipped — you attach it, you don't write it

`SceneManager` owns the renderer, the rAF loop, and per-route `Scene`
instances. Its constructor is `(canvas: HTMLCanvasElement, quality:
QualityProfile)` — quality is resolved BEFORE the renderer is built,
because antialias and DPR cannot be changed on a live WebGL context, and
the profile then drives `antialias`, `powerPreference` (`'low-power'` on
the LOW tier, for thermal headroom on devices that throttle anyway) and
the DPR cap.

You almost never construct it directly. `attachSceneManager(canvas,
routes, options)` is the framework-agnostic half of the pattern, and it
is what guarantees the invariant that matters: **exactly one manager per
canvas, for the lifetime of the tab.** It detects quality, tears down any
prior manager on that canvas, registers the route table, starts the loop,
resolves the initial route from the address bar, and returns an
`Attachment`:

```ts
interface Attachment {
  readonly manager: SceneManager;
  readonly quality: QualityProfile;
  /** False once a later attach displaced this one (HMR, double boot). */
  isCurrent(): boolean;
  /** Normalizes the pathname, drives the manager, logs a failure. */
  transitionTo(pathname: string, options?: { force?: boolean }): Promise<void>;
  /** Unbinds, destroys the manager if still current, frees the canvas. */
  detach(): void;
}
```

Three details of that guarantee are worth knowing, because they are the
bugs you would otherwise write:

- **The manager is tagged on the canvas element, not module scope.** HMR
  churns module instances; the DOM node survives.
- **There is a single-flight init guard.** Attaching is async (it awaits
  quality detection), so two overlapping boots would both pass a
  module-scope check before either tagged a manager — leaving two render
  loops on one canvas, which presents as ghost-doubled geometry and
  frame-to-frame jitter. An in-flight attach hands back the same
  attachment; a *settled* one is displaced rather than reused, so a new
  route table takes effect.
- **Routes are trailing-slash insensitive.** `normalizeRoute` folds
  `/work/` and `/work` together, because static hosts serve one and dev
  servers the other. Root stays `/`.

### `bind` — how your framework's navigation reaches the manager

`attachSceneManager` deliberately does not know how navigation is
announced. That is the `bind` option: it runs once the manager is live,
and returns an unbind that runs on detach. Both shipped adapters are a
dozen lines of it.

```ts
import { attachSceneManager, type SceneRoutes } from 'ether/core';

const attachment = await attachSceneManager(canvas, routes, {
  bind(attached) {
    const onPop = () => {
      // A defensive teardown may have displaced this manager; its
      // listener must not drive transitions on the corpse.
      if (!attached.isCurrent()) return;
      attached.transitionTo(location.pathname);
    };
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  },
});
```

### Route resolution and the `'*'` fallback

The route table is `Record<string, SceneFactory>`, and a factory is
`(renderer, quality, route?) => Scene`. `SceneManager.runTransition`
looks up the exact normalized pathname, then falls back to the key `'*'`
— register it and unmatched routes (404s, pages you have not built yet)
get a backdrop instead of a black canvas. With neither, the manager warns
and keeps whatever is rendering.

Two behaviors follow from *factory identity*, so they only work if the
routes that should share a world reference the same function object:

- **`transitionTo` is a latest-wins queue.** Rapid A→B→A converges on the
  last URL Astro settled on. Same-route calls are no-ops unless `force`
  is set — which the Astro adapter always sets, because Astro full-swaps
  the body even for a same-path link click, detaching every node the live
  scene's ScrollTriggers hold.
- **Same-world navigation skips the rebuild.** When the destination
  resolves to the *same factory* as the active scene, the route actually
  changed, and the scene implements `retarget`, the manager calls
  `retarget(route)` instead of exit → dispose → construct. The scene
  stays alive across the DOM swap and plays its own continuous
  transition. `attachSceneManager` de-duplicates wrappers by factory
  identity precisely so this comparison can match; two routes that inline
  two separate arrow functions can never take this path.

Hop order otherwise: exit old → dispose old → construct next → size to
the canvas box → preload → activate → enter. Exit runs first so scene
resource lifetimes are strictly disjoint. **`enterTransition` is not
awaited by the queue** — a navigation during a long intro interrupts it
via `dispose`.

### Per-scene contract — every scene must implement this interface

Six members are required — `scene`, `camera`, `enterTransition`,
`exitTransition`, `tick`, `dispose` — and five are optional, each
covering a case the required six cannot:

| Member | Required | What it is for |
|---|---|---|
| `preload?(): Promise<void>` | no | Load textures, compile shaders, parse glTFs. Awaited before the scene is activated, while the previous one is already gone. |
| `composer?: EffectComposer` | no | If set, `composer.render(deltaTime)` replaces `renderer.render(scene, camera)`. |
| `renders?: boolean` | no | Set `false` for a **park scene** — a route where an opaque DOM page covers the canvas. `tick` still runs, but no GPU render is issued; a full-DPR framebuffer behind an opaque page is pure waste. |
| `onResize?(w, h)` | no | Called by the manager with the canvas's CSS box whenever it changes, after the camera aspect and composer size are already updated. Put your own responsive tuning here. |
| `retarget?(route)` | no | Same-world navigation — see the `'*'` section above. Runs inside the `astro:before-swap` dispatch, so the new DOM is not in yet; defer DOM-coupled wiring to `astro:page-load`. |

`BaseScene` implements the boilerplate: it builds the `THREE.Scene` and a
`PerspectiveCamera` (defaults fov 50, near 0.1, far 100, z 4 — all
overridable through `super({...})`), gives you `track()` for disposables,
and drains them in `dispose()`.

```ts
// your site: src/scene/scenes/home/HomeScene.ts
import * as THREE from 'three';
import gsap from 'gsap';
import { BaseScene } from 'ether/core';
import type { QualityProfile } from 'ether/quality';

export class HomeScene extends BaseScene {
  private intro: gsap.core.Tween | null = null;

  constructor(
    private renderer: THREE.WebGLRenderer,
    private quality: QualityProfile,
    private route?: string,
  ) {
    super({ fov: 50, cameraZ: 5 });
  }

  override async preload(): Promise<void> {
    // Awaited before this scene is activated, so nothing half-loaded renders.
    // track() returns what you give it and disposes it later.
    const map = this.track(await new THREE.TextureLoader().loadAsync('/textures/hero.webp'));
    map.colorSpace = THREE.SRGBColorSpace;
  }

  async enterTransition(): Promise<void> {
    // NOT awaited by the transition queue — a navigation during this
    // interrupts it via dispose(), which is why the tween is held.
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      this.camera.position.set(0, 0, 5);
      return;
    }
    await new Promise<void>((resolve) => {
      this.intro = gsap.fromTo(
        this.camera.position,
        { z: 20 },
        { z: 5, duration: 0.8, ease: 'expo.out', onComplete: () => resolve() },
      );
    });
  }

  async exitTransition(): Promise<void> {
    // Everything BEFORE the first await runs inside the before-swap
    // dispatch, ahead of the DOM mutation and Astro's scroll reset.
    // Detach ScrollTriggers and the Lenis bridge here, synchronously.
    this.intro?.kill();

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    await new Promise<void>((resolve) => {
      gsap.to(this.camera.position, { z: 20, duration: 0.6, ease: 'expo.in', onComplete: () => resolve() });
    });
  }

  tick(time: number, deltaTime: number): void {
    // time = seconds since start (monotonic). deltaTime = seconds since last frame.
  }

  onResize(width: number, height: number): void {
    // Camera aspect and composer size are already handled. Yours goes here:
    // portrait tuning, uniform updates that depend on viewport shape.
  }

  override dispose(): void {
    // Kill intro timelines here: dispose() is how an interrupted
    // enterTransition gets stopped, and GSAP's kill() suppresses
    // onComplete so nothing fires against a dead scene.
    this.intro?.kill();
    super.dispose();
  }
}
```

A park scene is the whole contract in a dozen lines:

```ts
import * as THREE from 'three';
import type { Scene } from 'ether/core';

export class ParkScene implements Scene {
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(50, 1, 0.1, 100);
  readonly renders = false;   // ticks, never draws
  async enterTransition(): Promise<void> {}
  async exitTransition(): Promise<void> {}
  tick(): void {}
  dispose(): void {}
}
```

**What belongs in `track()`:** `BufferGeometry`, `Material` (and all subclasses), `Texture`, `WebGLRenderTarget`, `EffectComposer` — anything with a `dispose()`. Meshes and Groups do not hold GPU memory; the geometry and material they reference do.

### Routing through the kit — `initSceneRouter` (the shipped pattern)

`initSceneRouter` is `attachSceneManager` plus one `bind` that listens
for `astro:before-swap`. It owns all of the wiring — route-table
registration, route normalization, initial-route resolution from the
address bar, the navigation listener, the single-flight guard, and
teardown (real teardown only on `beforeunload`; the manager survives
every swap). It **returns the `SceneManager`**, so site code can reach
`manager.activeScene` afterwards — for a dev panel, a stats overlay,
anything that needs to bind to whatever is currently live. For what the
runtime is actually doing (hop phase, draw counts, applied DPR, the composer
running), read `manager.getDiagnostics()` (ether 1.2+; see `performance.md`).

```ts
// your site: src/scene/boot.ts
import { initSceneRouter, type SceneRoutes } from 'ether/astro';

export async function boot(canvas: HTMLCanvasElement) {
  // ONE factory object shared by '/' and '*': the wrapper de-dup is by
  // factory identity, so 404 <-> home hits the retarget path and the
  // scene survives the swap instead of rebuilding.
  const home: SceneRoutes[string] = (renderer, quality, route) =>
    new HomeScene(renderer, quality, route);

  const routes: SceneRoutes = {
    '/': home,
    '/work': (renderer, quality) => new WorkScene(renderer, quality),
    // A full paper document with no 3D of its own — park the canvas.
    '/services': () => new ParkScene(),
    '*': home,
  };

  const manager = await initSceneRouter(canvas, routes);
  return manager;
}
```

All routes register up front in `boot.ts` — a new page's own scripts
execute after the swap, which is too late to register the factory the
transition needs. Case-study routes and other generated pages get looped
into the same table before the call.

Two properties of the shipped design that a hand-rolled router
consistently gets wrong:

- **`astro:before-swap`, not `after-swap`, drives the transition.**
  The event dispatch runs the outgoing scene's `exitTransition`
  synchronously up to its first `await`, so scroll- and DOM-coupled
  state (ScrollTriggers, the Lenis bridge) detaches BEFORE Astro
  mutates the DOM and resets scroll. After-swap is too late — the old
  triggers would fire `onUpdate` against the new DOM. The event's
  `e.to.pathname` carries the destination; `location.pathname` is
  still the OLD route at dispatch time. The adapter also re-stamps
  `data-gpu-tier` onto the incoming document's `<body>`, because Astro
  swaps the body wholesale and wipes attributes set at init.
- **Every navigation is forced.** The adapter calls
  `transitionTo(pathname, { force: true })`, because Astro full-swaps
  even a same-path click — the logo while already on home — which
  detaches every node the live scene's triggers hold. Without `force`
  the same-route call is a no-op and the scene is left holding detached
  nodes.

### prefers-reduced-motion

The motion concern is camera animation between scenes — a rapid dolly from z=20 to z=5. For users with vestibular sensitivity, skip the interpolation and set the camera to its final position directly. The scene contract above handles this inside `enterTransition` and `exitTransition`. No SceneManager change is needed — each scene applies the check independently, which allows different scenes to make different motion decisions (e.g., a service page might have no camera animation at all, and the check is a no-op).

```ts
// Pattern used inside every scene's enterTransition / exitTransition:
if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  this.camera.position.set(0, 0, 5); // final pose directly
  return;                            // no GSAP, no await
}

await new Promise<void>((resolve) => {
  this.intro = gsap.fromTo(
    this.camera.position,
    { z: 20 },
    { z: 5, duration: 0.8, ease: 'expo.out', onComplete: () => resolve() },
  );
});
```

## Tunable parameters

| Parameter | Default | Range | Effect |
|---|---|---|---|
| `enterTransition` duration | `0.8 s` | 0.3 – 2.0 s | How long the camera takes to arrive at the scene's intro pose. 0.8 s is the minimum that reads as "moved there"; below 0.4 s it reads as a pop. Above 1.5 s the user is waiting for the site to respond. |
| `exitTransition` duration | `0.6 s` | 0.2 – 1.0 s | Exit should always be shorter than enter — the user has already decided to leave; don't detain them. A 0.6/0.8 ratio (exit/enter) gives a snappy leave and a weighted arrival. |
| `ease: 'expo.out'` on enter | `expo.out` | `power2.out`, `expo.out`, `circ.out` | Controls the deceleration curve of the camera arrival. `expo.out` reads as physical (fast then drift to rest). `power2.out` is softer. `circ.out` is sharper and slightly mechanical. |
| `quality.dprCap` | per tier | 1 – 3 | The manager applies `min(devicePixelRatio, quality.dprCap)`. Not yours to set directly — it comes from the detected GPU tier, and can be overridden wholesale with `initSceneRouter`'s `quality` option (useful to force LOW for QA). On a 3× display, rendering at 3× produces 2.25× the fragments of 2× for no visible gain at normal viewing distance. |
| `powerPreference` | tier-derived | `'low-power'`, `'high-performance'` | Also from the quality profile: `'low-power'` on the LOW tier, `'high-performance'` everywhere else. On dual-GPU machines this is what asks for the discrete GPU; on a throttling phone, low-power buys thermal headroom in a session that was going to be throttled anyway. |
| `quality.antialias` | `false` | — | Context MSAA is dead weight whenever a composer runs — passes render into textures that bypass the canvas framebuffer. Real edge AA comes from the composer's `msaaSamples`. Pass `multisampling: quality.msaaSamples` to `createComposer`. |

## Common pitfalls

1. **Geometries, materials, and textures not disposed on scene change.** WebGL keeps GPU buffers alive until JavaScript releases them via `.dispose()`. After 5–10 route navigations without disposal, GPU memory fills and the browser either kills the tab or drops to a software renderer. The symptom arrives late and is hard to attribute — the site "worked fine" during development because no one navigated more than 3 times. Register every GPU-allocating object with `BaseScene`'s `track()`, which drains them in `dispose()`. The types that need it: `BufferGeometry`, `Material`, `Texture`, `WebGLRenderTarget`, `EffectComposer`. Meshes themselves do not — only what they reference does, and `scene.remove(mesh)` frees neither.

2. **A browser without View Transitions degrades to full page loads.** Astro's client router falls back to a normal navigation where the API is missing: fresh document, fresh boot, fresh manager. That is correct rather than broken — the architecture degrades to "what you would have had anyway" — but the benefits go with it: initialization cost returns on every hop and the first frame after each navigation is black. No special handling is needed in scene code; what is needed is not *assuming* persistence when you reason about cost. If a route's design depends on state carried across the swap, that route needs a fallback the fallback path can render.

3. **Stale ScrollTriggers across navigation — solved structurally, not with `ScrollTrigger.refresh()`.** In the shipped design no trigger ever outlives its scene: the outgoing scene kills its own triggers synchronously in `exitTransition` (inside the before-swap dispatch, ahead of the DOM mutation and scroll reset), and the incoming scene creates its triggers only AFTER its intro completes, measuring the already-settled new DOM (the ether-scroll triggers-after-intro rule). There is never a stale trigger to refresh. A global `refresh()` on navigation is only needed if a trigger outlives its scene — which is itself the bug to fix.

4. **Resizing mid-transition — already handled, and not by a `window.resize` listener.** A naive handler fires on every `resize` event and reaches for `activeScene.camera`, which mid-swap is either disposed or not yet active. The shipped manager avoids the whole class of problem: a `ResizeObserver` watches the **canvas's CSS box** (not `window.inner*`, which diverges from it whenever mobile browser chrome is in play), the callback is debounced 150ms so an iOS URL-bar collapse coalesces into one resize instead of eight, and identical dimensions short-circuit. When it lands it calls `sizeScene` — camera aspect, `composer.setSize(w, h, false)`, then the scene's own `onResize(w, h)` hook. And `runTransition` sizes each new scene to the canvas box *before* `preload()` (which is where scenes render their warm-up frame), then re-checks afterwards in case a resize landed while there was no active scene to receive it. Your part is `onResize` for scene-specific responsive tuning. Note the `updateStyle: false` everywhere: the stylesheet owns the canvas box, and letting three.js write inline pixel heights is what pins a boot-sized canvas under a growing iOS viewport, leaving a permanent black band.

5. **Multiple navigation listeners accumulate.** If a navigation `addEventListener` call lives inside a component `<script>` re-evaluated after each swap, each navigation adds one more listener and scene transitions multiply per hop — race condition, GPU memory leak, or runtime error depending on timing. `initSceneRouter` handles this: the single-flight guard means one manager per canvas, the adapter's `bind` registers exactly one persistent `astro:before-swap` listener, its returned unbind removes it, and `beforeunload` is the only thing that triggers real teardown. The listener also guards itself with `attached.isCurrent()`, so a displaced manager's listener cannot drive transitions on the corpse. Only hand-rolled routers need module-scope or body-dataset guard patterns.

6. **The WebGL context can be lost, and nothing tells you.** iOS Safari drops contexts under memory pressure — multiple tabs, an app switch, OS pressure — and without a handler the canvas becomes a permanent white rectangle until reload. `SceneManager` catches `webglcontextlost`, calls `preventDefault()` (required, or the browser treats the context as permanently dead and never fires `webglcontextrestored`), and sets `data-webgl-lost` on `<body>` so CSS can show a fallback poster. Note what it keeps running: `tick` still executes on every frame, because it is CPU-side math *and* it pumps the scene's scroll bridge — skipping it turns a blank canvas into an unscrollable page. Only the GPU render calls are skipped.

## Reference

See `references.md`:

- **Hello Monday** entry: The dark sliding panel that sits over the right edge of the hero is a navigation surface sitting above a single WebGL canvas that persists between the hero and project tiles below. The project tile color fields stay live on the same WebGL context as the hero. This is the architectural choice this technique implements — one canvas under all HTML overlays, scenes swapped via camera transitions, never a page reload. What to copy: the architecture. What to skip: Hello Monday's illustration style is a studio signature; borrow the persistent-canvas structure, not the artwork.

- **Bonhomme** entry: Bonhomme Paris is cited publicly for narrative scrollytelling case studies with persistent canvas state across route changes, but the entry's screenshot capture landed on `bonhomme.lol` (Maxime Bonhomme's personal portfolio), not Bonhomme Paris (`bonhommeparis.com`). Do not cite this entry as verified evidence until the site is re-captured against the correct URL. The technique recipe above does not depend on that capture — it is grounded in the Hello Monday entry and in Active Theory's navigation behavior (project-to-project transitions with no renderer reset).
