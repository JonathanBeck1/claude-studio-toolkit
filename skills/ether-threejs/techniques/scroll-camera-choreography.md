# Scroll Camera Choreography (`ether/scroll` over GSAP ScrollTrigger + Lenis)

## When to use

Pages where the 3D scene is the narrative — not a background decoration — and the user's scroll position is the editorial timeline. Camera choreography is the right pattern when: (a) there are 2–5 distinct "beats" the scene must hit as the user reads through the page, (b) those beats need to feel authored (not just zoom in/out), and (c) the user should never be surprised by a cut — the transition between camera positions should always feel proportional to how fast they scroll.

This is the right pattern for: a homepage hero sequence where the story unfolds over several scroll sections, case-study covers where the 3D object rotates to reveal a back-panel detail as the user scrolls past the fold, any page where the camera path is the user's journey through a product or concept.

This is the wrong pattern for: ambient hero scenes where the camera should orbit slowly on its own and scroll is irrelevant (use a time-driven rotation in the scene's tick), pages with very long bodies of text where pinning the canvas would trap the user in an unresponsive scroll experience, any context where the user expects native scroll momentum and smooth-scroll inertia would feel disorienting (utility pages, article bodies, docs).

**When scroll-driven camera is overkill:** if the "choreography" is a constant slow dolly-in while the hero text fades out, one `createScrollProgress` feeding a lerped camera z in the scene's tick is sufficient. Reach for a pinned, scrubbed GSAP timeline only for multi-beat authored paths.

## Use the engine's bridge, not a hand-rolled one

`ether/scroll` owns the Lenis ↔ ScrollTrigger integration. Two exports carry the whole pattern:

- **`ScrollBridge`** wraps a Lenis instance and owns the three things site code keeps getting wrong: registering the ScrollTrigger plugin (idempotently, so HMR and repeated scene construction don't churn it), wiring `lenis.on('scroll', ScrollTrigger.update)` so ScrollTrigger reads the smoothed position, and converting the monotonic **seconds** a scene tick receives into the **milliseconds** Lenis expects. Methods: `raf(timeSeconds)`, `scrollTo(target, opts)`, `destroy()`.
- **`createScrollProgress(onProgress, options)`** makes one scrubbed ScrollTrigger that maps scroll progress `0..1` to a callback — the reusable "scroll drives a 3D value" shape. It registers the plugin on first use, so it also works with no bridge at all (the native-scroll path). Returns `{ trigger, kill() }`; call `kill()` in `Scene.dispose`.

Event-style triggers — class and attribute toggles on enter/leave, section reveals — stay in site code. They are site-specific and not worth abstracting.

### Smooth scroll is optional, and tier-gated

Construct `ScrollBridge` only when the quality tier enables smooth scroll. Low-end tiers and reduced-motion users run native scroll, which ScrollTrigger reads by default — nothing else has to change, because `createScrollProgress` registers the plugin itself. Touch is *not* excluded: Lenis `syncTouch` smooths on top of native iOS momentum rather than hijacking it, so touch feeds ScrollTrigger the same rAF-synced position desktop does.

```ts
import { ScrollBridge, createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';

private scroll: ScrollBridge | null = null;

private initScrollBridge(): void {
  this.scroll = this.quality.enableSmoothScroll
    ? new ScrollBridge({
        duration: LENIS_DURATION,
        easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
        smoothWheel: true,
        wheelMultiplier: LENIS_WHEEL_MULTIPLIER,
        touchMultiplier: LENIS_TOUCH_MULTIPLIER,
        syncTouch: true,
        touchInertiaExponent: LENIS_TOUCH_INERTIA_EXPONENT,
      })
    : null;
}
```

Options are forwarded verbatim to `new Lenis(...)`. Feel tuning (duration, easing, multipliers) belongs in the consuming site's constants, not in the engine.

### Lifecycle: build the bridge at enter, not in the constructor

This is the trap. Lenis intercepts wheel input from the moment it exists, but it only moves the page when its `raf` is pumped — and a scene's tick only runs once it is the manager's active scene, *after* preload. A bridge built in the scene constructor therefore eats every wheel event for the whole preload window and then dumps the accumulated delta as a lurch when ticking starts. Build it at the start of `enterTransition`, pump it in `tick`, tear it down in exit/dispose. Until enter, native scroll handles input perfectly well.

```ts
tick(elapsedSeconds: number): void {
  this.scroll?.raf(elapsedSeconds); // seconds in — the bridge converts to ms
  // ...camera / uniform updates
}

exit(): void {
  this.scroll?.destroy();
  this.scroll = null;
}
```

There is one RAF loop: the render loop that ticks the scene. Do not add a second `requestAnimationFrame` for Lenis, and do not call `lenis.raf()` anywhere else.

### Disable GSAP lag smoothing at the site level

GSAP clamps its ticker delta to 33 ms after any frame longer than 500 ms, which turns scrubbed tweens into slow motion on a slow renderer while the rest of the scene eases on raw frame time. `ScrollBridge` does **not** do this for you — it is a site-level decision, one line in the module that owns the scene:

```ts
gsap.ticker.lagSmoothing(0);
```

### No `scrollerProxy` — you do not need one

`ScrollTrigger.scrollerProxy` exists for scroll that never reaches the document: a transform-based custom wrapper, a scroll container that isn't the window. Lenis in its default configuration moves the real document scroll position, so ScrollTrigger's native reads are already correct; the only wiring needed is `lenis.on('scroll', ScrollTrigger.update)`, which `ScrollBridge` does in its constructor. Adding a proxy on top of that is a second source of truth for scroll position and a reliable way to produce the one-frame lag it claims to fix.

## Code recipe

### Scroll progress driving 3D values

The engine shape: one trigger per value, each writing a *target* that the scene's tick lerps toward. Smoothing happens in your tick, not in the trigger.

```ts
import * as THREE from 'three';
import { createScrollProgress, type ScrollProgressTrigger } from 'ether/scroll';

private cameraTrigger: ScrollProgressTrigger | null = null;
private cameraTarget = 0;
private cameraProgress = 0;

private setupScrollTriggers(): void {
  // Full-page progress: trigger defaults to 'body', start to 'top top'.
  this.cameraTrigger = createScrollProgress(
    (progress) => { this.cameraTarget = progress; },
    { end: 'bottom bottom' },
  );

  // Scoped to a section — pass trigger/start/end explicitly.
  this.revealTrigger = createScrollProgress(
    (progress) => { this.revealTarget = progress; },
    { trigger: '.approach', start: 'top bottom', end: 'bottom top' },
  );
}

tick(elapsedSeconds: number, dt: number): void {
  this.scroll?.raf(elapsedSeconds);

  // The easing lives here. Frame-rate independent lerp.
  this.cameraProgress += (this.cameraTarget - this.cameraProgress) * (1 - Math.exp(-6 * dt));
  this.camera.position.z = THREE.MathUtils.lerp(CAMERA_Z_START, CAMERA_Z_END, this.cameraProgress);
}

dispose(): void {
  this.cameraTrigger?.kill();
}
```

**Do not expect `scrub` to smooth this.** `createScrollProgress` builds an `onUpdate`-only trigger, and GSAP only constructs its scrub tween for a trigger with an attached `animation` — `onProgress` always receives raw progress. Omit `scrub` and smooth in your own tick, as above. Some values *want* raw progress: anything page-anchored (an element that must track the scroll pixel-for-pixel) will visibly swim against the page if you smooth it.

### Reduced motion

Smooth scroll and camera motion are vestibular motion; opacity is not. The split that works: skip the bridge and the motion triggers, keep the alpha/reveal ones, and snap section reveals on.

```ts
if (REDUCED_MOTION) {
  // createScrollProgress normally registers the plugin. On this path it is
  // skipped, so any raw ScrollTrigger.create calls below need it explicitly.
  gsap.registerPlugin(ScrollTrigger);
  for (const selector of revealSections) {
    document.querySelector(selector)?.classList.add('is-visible');
  }
} else {
  // drift / camera / reveal triggers
}
```

Failing to handle `prefers-reduced-motion` on scroll-driven camera work is an accessibility violation under WCAG 2.1 criterion 2.3.3 (Animation from Interactions). It is not optional.

### Pinned, scrubbed multi-beat timeline (raw GSAP)

The engine does not wrap this — a pinned timeline is page choreography, not a reusable 3D primitive. Use it when you genuinely have authored beats rather than one monotonic progress value. `ScrollBridge` still supplies the smooth scroll underneath; nothing here needs a proxy.

```js
import * as THREE from 'three';
import gsap from 'gsap';

const cameraPath = [
  { pos: new THREE.Vector3(0, 0, 5),  look: new THREE.Vector3(0, 0, 0)  }, // beat 0: intro
  { pos: new THREE.Vector3(3, 1, 4),  look: new THREE.Vector3(1, 0, 0)  }, // beat 1: reveal
  { pos: new THREE.Vector3(2, -1, 2), look: new THREE.Vector3(0, 0, -1) }, // beat 2: detail
  { pos: new THREE.Vector3(-2, 0, 3), look: new THREE.Vector3(0, 1, 0)  }, // beat 3: outro
];

export function buildCameraTimeline(camera, bloom) {
  const lookTarget = new THREE.Vector3();

  const tl = gsap.timeline({
    scrollTrigger: {
      trigger: '#hero-section',
      start: 'top top',
      end: '+=400%',            // 4 viewport heights of pinned travel
      pin: '#canvas-container',
      scrub: 1.0,               // real smoothing here — the timeline HAS an animation
      anticipatePin: 1,
    },
  });

  cameraPath.forEach((kf, i) => {
    if (i === 0) return; // first keyframe is where the camera already lives
    const prev = cameraPath[i - 1];

    tl.to(camera.position, {
      x: kf.pos.x, y: kf.pos.y, z: kf.pos.z,
      duration: 1,
      ease: 'none', // linear through each beat — scrub handles the feel
      onUpdate: () => {
        const segmentProgress = Math.max(0, Math.min(1,
          tl.progress() * (cameraPath.length - 1) - (i - 1)
        ));
        lookTarget.lerpVectors(prev.look, kf.look, segmentProgress);
        camera.lookAt(lookTarget);
      },
    });
  });

  // Drive an effect handle from the same timeline. createHeroComposer returns
  // `bloom` alongside `composer` — keep it rather than only `.composer`.
  tl.to(bloom.luminanceMaterial, { threshold: 0.55, duration: 1, ease: 'power2.inOut' }, 1);

  return tl;
}
```

Note the bloom lever: the hero preset's `0.06` intensity is a restraint ceiling, so the swell leaves intensity alone and lowers the luminance threshold (preset `0.65`) to let more of the accent bloom. Stay inside its `0.55 – 0.8` safe range. See `techniques/postprocessing-chain.md`.

### `ScrollTrigger.refresh()` after layout settles

```js
window.addEventListener('load', () => {
  setTimeout(() => ScrollTrigger.refresh(), 100); // let fonts and images reflow
});

let resizeTimer;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => ScrollTrigger.refresh(), 200);
});
```

### HTML structure (pinned pattern only)

```html
<div id="hero-section">              <!-- ScrollTrigger trigger and end marker -->
  <div id="canvas-container">        <!-- ScrollTrigger pins this element -->
    <canvas id="webgl-canvas"></canvas>
  </div>
  <section class="scene-section">Section A content</section>
  <section class="scene-section">Section B content</section>
  <section class="scene-section">Section C content</section>
  <section class="scene-section">Section D content</section>
</div>
```

```css
#canvas-container {
  position: relative; /* ScrollTrigger requires this to be non-static */
  width: 100%;
  height: 100vh;
}

#webgl-canvas { display: block; width: 100%; height: 100%; }

.scene-section { height: 100vh; }
```

## Tunable parameters

| Parameter | Where | Default | Range | Effect |
|---|---|---|---|---|
| Lenis `duration` | `ScrollBridge` options | site constant | 0.4 – 2.5 s | Inertia weight of smooth scroll. 0.6 reads responsive; ~1.2 reads weighted; 2.0 reads heavy. Higher values need more deliberate gestures to reach the end of a sequence — test with real scroll input, not click-drag. |
| Lenis `wheelMultiplier` | `ScrollBridge` options | site constant | 0.5 – 1.5 | Scales wheel input before Lenis's easing. Lower gives finer grain over the camera timeline. Below 0.5 the sequence feels stuck and users lose confidence the scroll is working. |
| Lenis `syncTouch` | `ScrollBridge` options | `true` on the smooth path | `true / false` | Smooths on top of native touch momentum instead of replacing it. This is the fix for choppy mobile scroll-to-3D; `touchInertiaExponent` shapes the post-flick glide and should be dialled on-device. |
| Tick lerp rate | your `tick` | — | 4 – 12 | The real smoothing knob for `createScrollProgress` values. `1 - exp(-rate * dt)` keeps it frame-rate independent. Higher = tighter tracking; lower = more float. |
| `createScrollProgress` `end` | trigger options | — | `'+=60%'` – `'bottom bottom'` | Scroll distance the 0..1 progress spans. First thing to adjust when a beat reads too fast or too slow. |
| `ScrollTrigger.scrub` | pinned timeline only | `1.0` | 0.1 – 3.0 | Catch-up lag for a timeline that has an attached animation. With Lenis underneath you get two layers of inertia. Above 2.0 the camera arrives visibly late to each beat. **No effect on `createScrollProgress`.** |
| `end: '+=400%'` | pinned timeline | `'+=400%'` | `'+=200%'` – `'+=600%'` | Total pinned travel. 400% = 4 viewport heights across a 4-beat timeline. |
| `cameraPath` keyframes | pinned timeline | four authored positions | any `Vector3` | Pure art direction. Start with z-only dolly, then add lateral and vertical offsets once pacing reads. |
| `anticipatePin` | pinned timeline | `1` | 0 or 1 | Pre-calculates the pin position, eliminating the one-frame jump when the element snaps to `position: fixed`. Set it and leave it. |

## Common pitfalls

1. **Building the bridge in the scene constructor.** Lenis eats wheel events from the moment it exists but only moves the page when `raf` is pumped, and the tick doesn't run until the scene is active — after preload. The accumulated delta lands as a lurch on the first ticked frame. Build at `enterTransition` start. (This once presented as a blank canvas *and* an unscrollable page: a scene whose tick is skipped also stops pumping the bridge.)

2. **A second RAF loop for Lenis.** If `lenis.raf(performance.now())` runs in its own `requestAnimationFrame` while the scene tick also pumps the bridge, both loops fight over the same scroll state and ScrollTrigger samples a position that is a frame stale — the camera trails scroll by an amount no scrub tuning removes. Pump the bridge from exactly one place: `Scene.tick`, in seconds.

3. **Expecting `scrub` to smooth a `createScrollProgress` callback.** It does not — GSAP builds the scrub tween only for a trigger with an attached animation, and `onProgress` always gets raw progress. Symptom: the value snaps per scroll event and no `scrub` number changes it. Smooth in your tick.

4. **Reaching for `scrollerProxy`.** Lenis moves the real document scroll, so ScrollTrigger's native reads are correct and `lenis.on('scroll', ScrollTrigger.update)` — already done by `ScrollBridge` — is the whole integration. A proxy adds a second source of truth for scroll position and causes the stutter it is meant to fix. It belongs to transform-based or custom-container scrolling only.

5. **`ScrollTrigger.refresh()` not called after layout changes.** ScrollTrigger measures section heights, trigger positions, and pin durations once at registration. Async content that shifts layout — images, fonts, API-injected DOM — invalidates those measurements, and beats then fire early or hold too long. Refresh 100 ms after `window.load`, on debounced resize, and in the `.then()` of any content injection.

6. **Pin spacing pushing downstream content.** Pinning inserts an invisible spacer whose height equals the full pinned travel, so everything after the pinned section moves down when ScrollTrigger initializes. Either design the page assuming the hero section is 5× viewport height (1 visible + 4 travel), or use `pinSpacing: false` and set a matching `margin-top` on the next element. The first option is simpler and less brittle.

7. **`camera.lookAt()` in the render loop instead of `onUpdate`.** On the pinned-timeline path GSAP can interpolate the timeline more than once per rendered frame during a scrub. A `lookAt` that runs once per render cycle lags the position updates, producing intermittent directional jitter that is hard to diagnose because it isn't in every frame. Call it inside the position tween's `onUpdate`. On the `createScrollProgress` path this doesn't arise — you own both writes in the same tick.

## Reference

See `references.md`:

- **14islands** entry: Homepage hero sets an oversized "Design & Technology" headline against a near-white field, edge-anchored so each word touches a different viewport edge. The annotation calls out that type composition should come first, with the camera path keyed to the type layout — not the reverse. For premium work: art-direct each beat so it frames the 3D object in a way that complements whatever copy sits in that scroll section. The camera serves the message, not the other way around.

- **Ueno** entry: A grid of device mockups at three different angles, where the angle differential per device is what sells physical presence. On scroll, those angles interpolate. What to copy: authored angle variation — not just zoom or dolly — is what makes scroll-driven camera feel cinematic. Each keyframe should have a meaningfully different viewing angle; keyframes that differ only in z produce a tunnel-vision dolly and nothing else.
