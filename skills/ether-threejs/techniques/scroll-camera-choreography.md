# Scroll Camera Choreography (GSAP ScrollTrigger + Lenis)

## When to use

Pages where the 3D scene is the narrative — not a background decoration — and the user's scroll position is the editorial timeline. Camera choreography is the right pattern when: (a) there are 2–5 distinct "beats" the scene must hit as the user reads through the page, (b) those beats need to feel authored (not just zoom in/out), and (c) the user should never be surprised by a cut — the transition between camera positions should always feel proportional to how fast they scroll.

This is the right pattern for: a homepage hero sequence where the product story unfolds over four scroll sections, case-study covers where the 3D object rotates to reveal a back-panel detail as the user scrolls past the fold, any page where the camera path is the user's journey through a product or concept.

This is the wrong pattern for: ambient hero scenes where the camera should orbit slowly on its own and scroll is irrelevant (use a time-driven `requestAnimationFrame` rotation instead), pages with very long bodies of text where pinning the canvas would trap the user in an unresponsive scroll experience, any context where the user expects native scroll momentum behavior and smooth-scroll inertia would feel disorienting (utility pages, article bodies, docs).

**When scroll-driven camera is overkill:** if the "choreography" is just a constant slow dolly-in from z=5 to z=2 while the hero text fades out, a single `ScrollTrigger.to(camera.position, { z: 2 })` without pinning or Lenis is sufficient. The full setup below is for multi-beat authored paths.

## What it gives you

A pinned canvas that stays fixed in the viewport while the user scrolls through 4× viewport heights of content. The camera traces a keyframed spline path — position and `lookAt` target both interpolate through the keyframes — while shader uniforms on materials drive in sync from the same GSAP timeline. Scroll inertia from Lenis makes the progression feel physical rather than mechanical: the camera "catches up" to scroll position rather than snapping. The result reads like a directed camera move in a film: the user is in control of pace, but the framing is authored.

## Required setup

Install:

```bash
npm install gsap lenis
```

`gsap` includes the ScrollTrigger plugin. `lenis` is the official package name as of 2024 — the previous `@studio-freight/lenis` package is deprecated and should not be used.

### 1. Lenis initialization

Lenis adds smooth inertia to native scroll. The browser's actual scroll position follows a lerped curve behind the user's input velocity, which is what makes the camera feel like it has weight.

```js
import Lenis from 'lenis';

const lenis = new Lenis({
  duration: 1.2,          // seconds — controls inertia "weight." 0.6 = snappy; 1.8 = heavy/luxury
  easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)), // expo.out — fast start, long tail
  orientation: 'vertical',
  smoothWheel: true,
  wheelMultiplier: 1.0,   // 1.0 = native wheel velocity. Lower = slower scroll-per-tick
  touchMultiplier: 2.0,   // touch devices need 2× velocity to feel responsive
});
```

### 2. GSAP ticker bridge

Lenis must receive its ticks from GSAP's internal ticker, not from a separate `requestAnimationFrame`. Two RAF loops interfere — see Pitfalls. This is the required integration:

```js
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

gsap.ticker.add((time) => {
  lenis.raf(time * 1000); // GSAP ticker passes seconds; Lenis.raf() expects milliseconds
});

// Disable GSAP's lag smoothing — Lenis handles inertia itself.
// If both are active, GSAP's lag smoothing fights Lenis's easing and produces stutter.
gsap.ticker.lagSmoothing(0);
```

### 3. ScrollTrigger scroller proxy

ScrollTrigger reads scroll position from the DOM's native `scrollTop`. Lenis intercepts native scroll and maintains its own virtual scroll value. Without the proxy, ScrollTrigger reads a scroll position that is always slightly ahead of Lenis's smoothed position — the timeline progress stutters or lags by one frame. The proxy bridges them:

```js
ScrollTrigger.scrollerProxy(document.body, {
  scrollTop(value) {
    if (arguments.length) {
      // ScrollTrigger is setting the scroll position (e.g., on refresh)
      lenis.scrollTo(value, { immediate: true });
    }
    return lenis.scroll; // return Lenis's smoothed virtual position
  },
  getBoundingClientRect() {
    return { top: 0, left: 0, width: window.innerWidth, height: window.innerHeight };
  },
});

// When Lenis updates, tell ScrollTrigger to re-evaluate trigger positions
lenis.on('scroll', ScrollTrigger.update);

// All subsequent ScrollTrigger instances use document.body as the scroller
ScrollTrigger.defaults({ scroller: document.body });
```

### 4. prefers-reduced-motion handling

Lenis smooth scroll is vestibular motion. Disable it when the user has opted out:

```js
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (prefersReduced) {
  lenis.destroy();
  // ScrollTrigger still works — it falls back to native scroll position.
  // Camera animation still plays, but without smooth inertia — it snaps directly
  // to the scroll-proportional position, which is fine for reduced-motion users.
}
```

## Code recipe

### Full wiring — complete setup module

```js
// scroll-setup.js
import Lenis from 'lenis';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

export function initScrollSystem() {
  const lenis = new Lenis({
    duration: 1.2,
    easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
    orientation: 'vertical',
    smoothWheel: true,
    wheelMultiplier: 1.0,
    touchMultiplier: 2.0,
  });

  // Tick Lenis from GSAP — single RAF loop
  gsap.ticker.add((time) => {
    lenis.raf(time * 1000);
  });
  gsap.ticker.lagSmoothing(0);

  // Bridge Lenis virtual scroll to ScrollTrigger
  ScrollTrigger.scrollerProxy(document.body, {
    scrollTop(value) {
      if (arguments.length) {
        lenis.scrollTo(value, { immediate: true });
      }
      return lenis.scroll;
    },
    getBoundingClientRect() {
      return { top: 0, left: 0, width: window.innerWidth, height: window.innerHeight };
    },
  });

  lenis.on('scroll', ScrollTrigger.update);
  ScrollTrigger.defaults({ scroller: document.body });

  // Reduced-motion: destroy Lenis, ScrollTrigger falls back to native scroll
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReduced) {
    lenis.destroy();
  }

  return lenis;
}
```

### Scroll-driven camera timeline — 4-beat path

Four keyframes define the camera's authored positions and `lookAt` targets. GSAP scrubs through them as the user scrolls, driving both `camera.position` and a `lookTarget` vector that feeds `camera.lookAt()` each frame.

```js
// camera-choreography.js
import * as THREE from 'three';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

// Define 4 keyframes — each has a camera position and a lookAt target in world space.
// Edit these first during art direction; the easing and scrub handle the feel.
const cameraPath = [
  { pos: new THREE.Vector3(0, 0, 5),   look: new THREE.Vector3(0, 0, 0)  }, // beat 0: intro
  { pos: new THREE.Vector3(3, 1, 4),   look: new THREE.Vector3(1, 0, 0)  }, // beat 1: reveal
  { pos: new THREE.Vector3(2, -1, 2),  look: new THREE.Vector3(0, 0, -1) }, // beat 2: detail
  { pos: new THREE.Vector3(-2, 0, 3),  look: new THREE.Vector3(0, 1, 0)  }, // beat 3: outro
];

export function buildCameraTimeline(camera, bloomEffect, particleMaterial) {
  const lookTarget = new THREE.Vector3();

  const tl = gsap.timeline({
    scrollTrigger: {
      trigger: '#hero-section',        // the outermost scroll container
      start: 'top top',                // begin when the section hits the top of viewport
      end: '+=400%',                   // 4 viewport heights of pinned scroll travel
      pin: '#canvas-container',        // the element to pin (the WebGL canvas wrapper)
      scrub: 1.0,                      // lerp factor: 0 = instant snap, 1 = 1-second catch-up
      anticipatePin: 1,                // pre-calculate pin position to avoid a one-frame jump
    },
  });

  // Animate through keyframes 1, 2, 3 (keyframe 0 is the starting state)
  cameraPath.forEach((kf, i) => {
    if (i === 0) return; // first keyframe is where the camera already lives

    const prev = cameraPath[i - 1];

    tl.to(camera.position, {
      x: kf.pos.x,
      y: kf.pos.y,
      z: kf.pos.z,
      duration: 1,
      ease: 'none', // linear through each beat — scrub handles the feel
      onUpdate: () => {
        // Interpolate lookAt within this segment.
        // tl.progress() runs 0→1 over the full timeline.
        // Local segment progress = (global progress * numSegments) - segmentIndex
        const segmentProgress = Math.max(0, Math.min(1,
          tl.progress() * (cameraPath.length - 1) - (i - 1)
        ));
        lookTarget.lerpVectors(prev.look, kf.look, segmentProgress);
        camera.lookAt(lookTarget);
      },
    });
  });

  // ── Drive scene-wide shader uniforms from the same timeline ─────────────────

  // Section 2: bloom intensifies as the object is revealed close
  tl.to(bloomEffect, {
    intensity: 0.8,
    duration: 1,
    ease: 'power2.inOut',
  }, 1); // position "1" = start of the second beat segment

  // Section 3: particle field scale expands as camera pulls to detail view
  tl.to(particleMaterial.uniforms.uFieldScale, {
    value: 1.5,
    duration: 1,
    ease: 'none',
  }, 2); // position "2" = start of the third beat segment

  return tl;
}
```

### ScrollTrigger.refresh() — call after layout settles

```js
// After all async content is loaded and fonts are rendered, refresh ScrollTrigger
// so it knows the final section heights. Call once after page load.
window.addEventListener('load', () => {
  // Slight delay to let the browser reflow after load
  setTimeout(() => ScrollTrigger.refresh(), 100);
});

// Also refresh on resize (debounced — avoid firing on every pixel during drag)
let resizeTimer;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => ScrollTrigger.refresh(), 200);
});
```

### Per-frame render loop (with composer)

When using the postprocessing chain, `composer.render()` replaces `renderer.render()`. ScrollTrigger and Lenis update happens inside `gsap.ticker.add()` — no additional RAF needed:

```js
// The GSAP ticker drives both Lenis and the animation timeline.
// Your render loop just needs to produce a frame.
function animate() {
  requestAnimationFrame(animate);
  composer.render(deltaTime); // or renderer.render(scene, camera) if no postprocessing
}

animate();
```

Note: `camera.lookAt()` is called inside the `onUpdate` callback of each timeline tween (above). The `animate()` loop does not need to call `camera.lookAt()` separately — GSAP's scrub handles the timing.

### HTML structure (minimum)

```html
<div id="hero-section">              <!-- ScrollTrigger trigger and end marker -->
  <div id="canvas-container">        <!-- ScrollTrigger pins this element -->
    <canvas id="webgl-canvas"></canvas>
  </div>
  <!-- 4 content sections that live BELOW the pinned canvas in scroll space -->
  <!-- Their combined height drives the pinned scroll travel -->
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

#webgl-canvas {
  display: block;
  width: 100%;
  height: 100%;
}

.scene-section {
  height: 100vh;
  /* Content here is visible after the pin sequence ends */
}
```

## Tunable parameters

| Parameter | Default | Range | Effect |
|---|---|---|---|
| `lenis.duration` | `1.2` | 0.4 – 2.5 s | Inertia weight of smooth scroll. 0.6 reads as responsive/snappy; 1.2 reads as premium/weighted; 2.0 reads as heavy/dramatic. Higher values require more deliberate scroll gestures to reach the end of the sequence — test with real scroll input, not click-drag. |
| `ScrollTrigger.scrub` | `1.0` | 0.1 – 3.0 | Catch-up lag for the camera following scroll progress. 0 = instant snap to scroll position (no GSAP easing applied). 1.0 = camera catches up over 1 second. At 1.0 with Lenis duration 1.2, you get two layers of inertia: Lenis smooths the scroll input, then scrub smooths the timeline response. Together this produces the "luxury" feel. Above 2.0 the camera starts to feel broken — it arrives visibly late to each beat. |
| `end: '+=400%'` | `'+=400%'` | `'+=200%'` – `'+=600%'` | Total pinned scroll travel. 400% = 4 viewport heights to scrub through the 4-beat timeline. Increase to slow the pacing (more scroll per beat), decrease to speed it up. This is the first parameter to adjust when beats feel too fast or too slow to read. |
| `lenis.wheelMultiplier` | `1.0` | 0.5 – 1.5 | Scales physical wheel input before Lenis's easing. Lower values slow the scroll per wheel tick, giving finer grain control over the camera timeline. Do not go below 0.5 — at very low values the sequence feels stuck and users lose confidence the scroll is working. |
| `cameraPath` keyframes | (four authored positions) | any THREE.Vector3 | The actual camera choreography. These are the only values that are pure art direction — position each keyframe in scene space to frame the 3D object at the intended angle for each section. Start with z-axis dolly-in only (vary z, keep x and y fixed), then add lateral and vertical offsets once the basic pacing reads correctly. |
| `anticipatePin` | `1` | 0 or 1 | When set to 1, ScrollTrigger pre-calculates the pin position slightly before it fires. Eliminates the one-frame positional jump that happens when a pinned element snaps to `position: fixed`. Set it to 1 and leave it — the cost is a single extra getBoundingClientRect call at initialization. |

## Common pitfalls

1. **Lenis ticked separately from the GSAP ticker.** If you call `lenis.raf(performance.now())` inside your own `requestAnimationFrame` loop while GSAP also runs its internal ticker, both loops compete for the same scroll state. Lenis may update after GSAP has already sampled scroll position for that frame, so the ScrollTrigger timeline progress lags by exactly one frame — the camera always trails the scroll by a visible amount that does not go away even with scrub tuning. The fix is to tick Lenis exclusively from `gsap.ticker.add()` and not call `requestAnimationFrame` for Lenis anywhere else in your codebase. Search for any calls to `lenis.raf()` outside the GSAP ticker and remove them.

2. **`ScrollTrigger.refresh()` not called after layout changes.** ScrollTrigger measures section heights, trigger positions, and pin durations once at registration. If async content loads after registration — images that shift layout, fonts that reflow text, API responses that inject DOM — the captured measurements are stale. The camera timeline will advance past a beat too early or hold too long because the scroll positions no longer match what ScrollTrigger calculated. Call `ScrollTrigger.refresh()` after layout stabilizes: once 100ms after `window.load` to catch font and image reflow, and once on `resize` (debounced to 200ms to avoid firing on every pixel during a drag resize). If dynamic content loads asynchronously (e.g., after an API call), call `ScrollTrigger.refresh()` in the `.then()` callback after the content is injected.

3. **Pin spacing causes unexpected layout shift downstream.** When ScrollTrigger pins `#canvas-container`, it inserts an invisible spacer `<div>` whose height equals the full pinned scroll travel (4 viewport heights for `end: '+=400%'`). Any content that follows `#hero-section` in the DOM will be pushed down by this spacer. If you lay out the page without accounting for the spacer, the footer and downstream sections jump when ScrollTrigger initializes. Two solutions: (a) accept the spacer and design the page assuming `#hero-section` will be 5× viewport height tall (1× visible + 4× scroll travel), or (b) use `pinSpacing: false` and manually set a `margin-top` on the element that follows the pinned section equal to the scroll travel distance. Option (a) is simpler and less brittle.

4. **`prefers-reduced-motion` not respected — accessibility violation.** Scroll-driven camera animation is continuous viewport motion triggered by user input. For users with vestibular disorders, this produces motion sickness indistinguishable from the same condition triggered by physical motion. Smooth-scroll inertia compounds the problem — the scene keeps moving after the user stops scrolling. Always check `window.matchMedia('(prefers-reduced-motion: reduce)').matches` before initializing Lenis. If set, call `lenis.destroy()` so scroll reverts to native browser behavior. Optionally also reduce the camera animation: replace the camera timeline with a static final position or cut the `end` distance to 0 so the camera jumps once to the authored final state without sweeping through keyframes. Failure to handle this is an accessibility violation under WCAG 2.1 criterion 2.3.3 (Animation from Interactions). It is not optional.

5. **`camera.lookAt()` called in the render loop instead of `onUpdate`.** A common shortcut is to store a `lookAtTarget` vector and call `camera.lookAt(lookAtTarget)` once per frame at the top of the render loop. This works for orbit controls, but when GSAP scrub is driving the camera position, the timeline can update multiple times per frame during a scrub (GSAP interpolates across skipped frames). If `lookAt` runs only once per render cycle, the lookAt target lags behind position updates, producing a frame where the camera has moved but hasn't re-aimed — visible as a directional jitter that is difficult to diagnose because it doesn't appear in every frame. The fix is to call `camera.lookAt()` inside the `onUpdate` callback of the position tween (as shown in the recipe), so it updates in sync with every GSAP interpolation step.

## Reference

See `references.md`:

- **14islands** entry: Homepage hero sets an oversized "Design & Technology" headline against a near-white field, edge-anchored so each word touches a different viewport edge. The annotation specifically calls out that type composition should come first, with the camera path keyed to the type layout — not the reverse. For premium work: art-direct the four `cameraPath` keyframes so each beat frames the 3D object in a way that complements whatever HTML copy sits in that scroll section. The camera serves the message, not the other way around.

- **Ueno** entry: A grid of iPhone mockups at three different angles, where the angle differential per device is what sells physical presence. On scroll, those angles interpolate. What to copy: the principle that authored angle variation (not just zoom or dolly) is what makes scroll-driven camera feel cinematic. Each `cameraPath` keyframe should have a meaningfully different viewing angle — avoid keyframes that differ only in z-position, which produces a tunnel-vision dolly and nothing else.
