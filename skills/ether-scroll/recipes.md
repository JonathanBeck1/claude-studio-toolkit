# Scroll — Technique Recipes

Reference Claude reads when `ether-scroll` is invoked. Engine cites are ether repo paths (`src/...`). Consumer-side snippets are illustrative — adapt the names to your scene.

**Architecture truth (read first):** the Lenis ↔ ScrollTrigger bridge lives in the engine at `src/scroll/` — `ScrollBridge` (Lenis lifecycle + idempotent `gsap.registerPlugin` + the `ScrollTrigger.update` wiring + seconds→ms raf) and `createScrollProgress` (one trigger mapping page progress 0..1 to a callback — raw; smoothing is the consumer's job in `tick()`). Your hero scene is the consumer: it constructs the bridge with its own feel options and uses the factory for its progress triggers. Event-style triggers (class/attr toggles) stay inline in site code by design — they're site-specific DOM hooks, not engine material.

---

## 1. ScrollBridge construction (consumer scene, at `enterTransition` start)

```ts
this.scroll = quality.enableSmoothScroll
  ? new ScrollBridge({
      duration: LENIS_DURATION,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
      wheelMultiplier: LENIS_WHEEL_MULTIPLIER,
      touchMultiplier: LENIS_TOUCH_MULTIPLIER,
      syncTouch: true,                                  // smooth scroll-to-3D on touch
      touchInertiaExponent: LENIS_TOUCH_INERTIA_EXPONENT, // glide decay; Lenis default 1.7
    })
  : null;
```

Key points:
- **Conditional construction.** `quality.enableSmoothScroll` is `tier !== 'LOW'` (`src/quality/quality.ts`). When the bridge is null, ScrollTrigger falls back to native scroll events. Don't paper over the null with a fake bridge — the fallback works.
- **Options pass through verbatim to `new Lenis(...)`.** Feel tuning (duration, multipliers, inertia exponent) lives in your site's constants module. Tune the feel there, not inline.
- **`syncTouch: true`** is the fix for choppy mobile scroll-to-3D. The folk advice ("syncTouch fights iOS, leave it false") is wrong for scroll-driven 3D: native iOS scroll arrives in coarse stepped compositor bursts, so binding the 3D to it reads as choppy. `syncTouch` (Lenis 1.3+) smooths ON TOP of native momentum — it does not hijack scroll — giving touch the same rAF-synced position desktop has. `touchInertiaExponent` shapes the post-flick glide decay (Lenis default 1.7); the per-frame interpolation that smooths iOS's stepped input is `syncTouchLerp` (leave it at its default). With Lenis live on touch, the old touch-only damping compensation is no longer needed — it was only masking the missing inertial layer.

---

## 2. The Lenis → ScrollTrigger wiring (`src/scroll/scrollBridge.ts`)

```ts
this.lenis.on('scroll', ScrollTrigger.update);
```

One line, owned by the `ScrollBridge` constructor — site code never writes it. Without it, ScrollTrigger reads un-smoothed native scrollY and scrub progress jumps in 16ms increments instead of the Lenis-eased curve. The constructor also registers the ScrollTrigger plugin idempotently, so no bare `gsap.registerPlugin(ScrollTrigger)` belongs in site code either.

Do NOT bind `ScrollTrigger.update` to `window.scroll` events yourself, and do not pipe a manual `ScrollTrigger.refresh` through onScroll.

---

## 3. Shared rAF tick (consumer scene)

```ts
tick(time: number, deltaTime: number): void {
  this.scroll?.raf(time);          // bridge converts seconds → ms internally
  // ... rest of per-frame work
}
```

The engine's `SceneManager.tick` (`src/core/SceneManager.ts`) calls `activeScene.tick(seconds, deltaTime)`. `ScrollBridge.raf` does the ×1000 Lenis expects. **Never multiply at the call site** — double-scaling makes Lenis run 1000× fast, which reads as scroll teleporting in one frame.

**Why one loop matters:** if you give Lenis its own rAF (the library's default if you call `lenis.start()`), scroll position is read on Lenis's clock while 3D updates run on the renderer's clock — they desynchronize by a frame on slow tabs and the eye catches it.

**Hard rule:** the bridge is ticked from `tick()`. Never call `lenis.start()`.

---

## 4. Scroll progress — `createScrollProgress` (`src/scroll/scrollProgress.ts`)

The canonical "scroll position drives a per-frame value" shape. A full hero scene runs three of them — drift, reform, camera. Every callback writes a RAW target; `tick()` eases the live value toward it:

```ts
this.driftTrigger = createScrollProgress(
  (progress) => {
    this.driftTarget = progress;
  },
  { end: DRIFT_TRIGGER_END },
);

// Section-anchored progress — override trigger/start/end.
this.reformTrigger = createScrollProgress(
  (progress) => {
    this.reformProgress = Math.min(progress / this.reformPeak(), 1);
    this.driftTarget = 1 - this.reformProgress;
  },
  { trigger: '.approach', start: 'top bottom', end: 'bottom top' },
);

this.cameraTrigger = createScrollProgress(
  (progress) => {
    this.cameraTarget = progress;
  },
  { end: 'bottom bottom' },
);
```

Apply to: any value that reads from scroll continuously — camera transforms, shader uniforms, displacement amplitudes. Defaults: `trigger: 'body'`, `start: 'top top'` (override for section-anchored progress, as `reformTrigger` does).

**Slop avoidance:**
- Don't hand-roll `ScrollTrigger.create` for this shape — the factory registers the plugin on first use, so it also works on the native-scroll path (no bridge required).
- **Don't pass `scrub`.** `ScrollProgressOptions` still accepts it, but it is inert here: GSAP builds its scrub tween only for an attached `animation`, and an onUpdate-only trigger's callback always receives raw progress. Passing a number buys nothing and reads in review as smoothing that isn't there. Omit it.
- **Smooth in `tick()` instead.** The callback writes `fooTarget`; `tick(time, deltaTime)` eases `fooCurrent` toward it with a frame-rate-independent exponential, settle times from your constants module (e.g. `DRIFT_SMOOTHING`, `CAMERA_SMOOTHING`). That also keeps the work deltaTime-aware.
- Leave a value RAW only when it must track scroll pixel-for-pixel (e.g. a page-anchored formation offset); smoothing one of those makes it swim against the page.
- Don't mutate three.js objects directly from the callback; it bypasses `tick()`.

---

## 5. Threshold triggers (examples: canvas dim, section reveals)

The "state changes at a scroll position" shape — stays inline via `ScrollTrigger.create` (site-specific anchors, not engine material):

```ts
// Fade the sculpture back as the FIRST content section arrives. No scrub
// (§4's rule applies to inline triggers too): raw target, tick() smooths.
this.canvasDimTrigger = ScrollTrigger.create({
  trigger: '.services',
  start: 'top bottom',                  // section's top hits viewport bottom = 0
  end: 'top top',                       // section's top hits viewport top    = 1
  onUpdate: (self) => {
    this.dimAlphaTarget = 1 - self.progress * (1 - SCULPTURE_ALPHA_FLOOR);
  },
});

// One reveal trigger per content section, collected so teardown is one loop.
for (const selector of revealSections) {
  this.revealTriggers.push(
    ScrollTrigger.create({
      trigger: selector,
      start: 'top 72%',
      // Reveal once and stick — no onLeaveBack re-hide; re-running the fade
      // on the way back up reads as flicker.
      onEnter: () => document.querySelector(selector)?.classList.add('is-visible'),
    }),
  );
}
```

Apply to: canvas/sculpture alpha, and any reveal that drives CSS rather than 3D.

**Tips:**
- Reveals fire once (`onEnter` only). Reach for `onEnter` + `onLeaveBack` (never `onToggle`) only when the exit genuinely has to undo something — the body flag in §6 does.
- Several sections sharing one pattern? Loop a selector list into a `revealTriggers[]` array — one create site, one kill site.
- Set thresholds from the section's actual margin context, not a default (`top 72%` fired earlier than `top 50%` on a section that follows a tall hero).
- CSS handles cascade timing (per-card stagger via `--reveal-delay`). ScrollTrigger just flips the parent flag.
- Two writers on one visual property (a dim fade and a reform swell both driving sculpture alpha) need a single apply function combining them — otherwise whichever trigger fires last wins.

---

## 6. Body data-flag (scroll cue)

```ts
this.scrollCueTrigger = ScrollTrigger.create({
  trigger: 'body',
  start: 'top top-=40',
  onEnter: () => document.body.setAttribute('data-scrolled', ''),
  onLeaveBack: () => document.body.removeAttribute('data-scrolled'),
});
```

Apply to: tiny one-bit state changes that CSS reads — scroll-cue, header swap, back-to-top. The `-=40` start offset means "intent detected, not micro-jitter."

---

## 7. Scroll-restoration must be inline-head (your layout's `<head>`)

```html
<script is:inline>
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
</script>
```

**Why:** on a mid-scroll reload the browser restores scrollY before the scene boots; ScrollTrigger then fires `onUpdate(>0)` the instant `setupScrollTrigger()` runs — drift, camera Z, and scroll-bound uniforms snap to mid-scroll before the user touches anything. `manual` keeps the page at 0. Pair with `window.scrollTo(0, 0)` + `this.scroll?.scrollTo(0, { immediate: true })` in `preload()` as belt-and-braces.

Never move this to a module script. Never remove it.

---

## 8. Teardown (one `killTriggers()` helper, called from every exit path)

```ts
private killTriggers(): void {
  this.driftTrigger?.kill();
  this.driftTrigger = null;
  this.reformTrigger?.kill();
  this.reformTrigger = null;
  this.cameraTrigger?.kill();
  this.cameraTrigger = null;
  this.canvasDimTrigger?.kill();
  this.canvasDimTrigger = null;
  for (const trigger of this.revealTriggers) trigger.kill();
  this.revealTriggers.length = 0;
  this.scrollCueTrigger?.kill();
  this.scrollCueTrigger = null;
}
```

Centralize the kills in one private helper rather than spelling them out in `dispose()`, and call it from every exit path — `exitTransition()`, `dispose()`, and any in-session reset — each followed by `this.scroll?.destroy(); this.scroll = null;`. Factory handles get `.kill()` (the `ScrollProgressTrigger` wraps the underlying instance); inline triggers get `.kill()`; the bridge gets `.destroy()` (tears down Lenis + its scroll listener). Null the fields as you go so a second call is a no-op.

**`exitTransition()` is the path that matters for view transitions.** The engine's `src/astro/router.ts` binds `astro:before-swap` (and only that) and calls `SceneManager.transitionTo()` from it; the dispatch runs the outgoing scene's `exitTransition()` synchronously up to its first `await`, so triggers and Lenis detach BEFORE Astro mutates the DOM and resets scroll. `dispose()` calling the same helper is the backstop, not the primary. The router binds no `beforeunload` and calls no `manager.destroy()` — tab teardown is the browser's problem. Skip the kill on the exit path and `transition:persist` ghosts the old triggers: they keep firing against the new scene.

**Adding a trigger? You also add the `.kill()` to `killTriggers()`. Same commit. Always paired.**

---

## 9. Setup order

ScrollTriggers are created inside `setupScrollTrigger()`, called **after the intro completes** — not in the constructor and not in `preload()`. Triggers measure layout at construction; created before the intro finishes mutating layout, they latch onto wrong dimensions.

Order:
1. `preload()` — assemble all DOM the page needs, including hidden future content
2. Intro animation runs
3. `setupScrollTrigger()` from the intro's `onComplete`
4. `ScrollTrigger.refresh()` if layout changed between 2 and 3

---

## 10. New scroll-driven section — recipe

1. Pick the pattern: §4 scroll progress (use `createScrollProgress`), §5 threshold trigger, §6 body-flag. Often two — a progress trigger for 3D state, a threshold trigger for CSS reveals. Don't merge them into one trigger.
2. Create it inside `setupScrollTrigger()`. Don't scatter triggers across files.
3. Store the handle on the scene (`this.fooTrigger`).
4. Add the `.kill()` to `killTriggers()` in the same commit.
5. Pull thresholds and smoothing settle times from your constants module if reusable, else inline with a one-line comment.
6. Test the no-bridge fallback (LOW tier: bridge null, native scroll). Scroll feel is less buttery but values must still drive correctly. Touch is NOT a fallback case — it runs the bridge.

---

## Pitfalls (read before debugging scroll issues)

- **Trigger fires `onUpdate(>0)` on intro complete.** Scroll restoration — see §7.
- **Motion looks janky.** Two render loops — confirm `scroll?.raf(time)` is called from `tick()` and nothing ever called `lenis.start()`. See §3.
- **Scroll teleports in one frame.** Someone multiplied at the raf call site (`raf(time * 1000)`) — the bridge already converts. See §3.
- **Trigger latches onto wrong dimensions.** Created before intro completion. See §9.
- **Ghost double-update after view transition.** An exit path that never called `killTriggers()`, or a trigger missing from it. See §8.
- **`Multiple instances of three.js` or triggers not driven by smoothed scroll.** Dedupe broken — `gsap`/`lenis` must resolve to single instances (your `astro.config.ts` `resolve.dedupe`).

---

## Engine citation index

- `src/scroll/scrollBridge.ts` — `ScrollBridge` (ctor wiring, raf s→ms, `scrollTo`, `destroy`)
- `src/scroll/scrollProgress.ts` — `createScrollProgress` factory
- `src/quality/quality.ts` — `enableSmoothScroll` definition
- `src/core/SceneManager.ts` — manager tick → scene tick (seconds)
- `src/astro/router.ts` — `astro:before-swap` → `SceneManager.transitionTo` (the only listener it binds)
