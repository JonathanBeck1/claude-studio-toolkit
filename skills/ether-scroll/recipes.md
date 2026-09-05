# Scroll — Technique Recipes

Reference Claude reads when `ether-scroll` is invoked. Engine cites are ether repo paths (`src/...`). Consumer-side snippets are illustrative — adapt the names to your scene.

**Architecture truth (read first):** the Lenis ↔ ScrollTrigger bridge lives in the engine at `src/scroll/` — `ScrollBridge` (Lenis lifecycle + idempotent `gsap.registerPlugin` + the `ScrollTrigger.update` wiring + seconds→ms raf) and `createScrollProgress` (one scrubbed trigger mapping page progress 0..1 to a callback). Your hero scene is the consumer: it constructs the bridge with its own feel options and uses the factory for its progress scrubs. Event-style triggers (class/attr toggles) stay inline in site code by design — they're site-specific DOM hooks, not engine material.

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
- **`syncTouch: true`** is the fix for choppy mobile scroll-to-3D. The folk advice ("syncTouch fights iOS, leave it false") is wrong for scroll-driven 3D: native iOS scroll arrives in coarse stepped compositor bursts, so binding the 3D to it reads as choppy. `syncTouch` (Lenis 1.3+) smooths ON TOP of native momentum — it does not hijack scroll — giving touch the same rAF-synced position desktop has. `touchInertiaExponent` shapes the post-flick glide decay (Lenis default 1.7); the per-frame interpolation that smooths iOS's stepped input is `syncTouchLerp` (leave it at its default). With Lenis live on touch, a heavier touch scrub factor is no longer needed — it was only masking the missing inertial layer.

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

## 4. Progress scrub — `createScrollProgress` (`src/scroll/scrollProgress.ts`)

The canonical "scroll position drives a per-frame value" shape:

```ts
this.driftTrigger = createScrollProgress(
  (progress) => this.drift?.setScrollProgress(progress),
  { end: DRIFT_TRIGGER_END, scrub: DRIFT_SCRUB },
);

this.cameraTrigger = createScrollProgress(
  (progress) => {
    this.cameraScrollProgress = progress;
    this.applyCameraZ(progress);
  },
  { end: 'bottom bottom', scrub: CAMERA_SCRUB },
);
```

Apply to: any value that reads from scroll continuously — camera transforms, shader uniforms, displacement amplitudes. Defaults: `trigger: 'body'`, `start: 'top top'` (override for section-anchored progress).

**Slop avoidance:**
- Don't hand-roll `ScrollTrigger.create` for this shape — the factory registers the plugin on first use, so it also works on the native-scroll path (no bridge required).
- Write the value into per-frame scene state inside the callback; read it from `tick()`. Don't mutate three.js objects directly from the callback — that bypasses deltaTime-aware work in `tick()`.
- `scrub` is in seconds, from constants (e.g. `0.5` for a drift scrub, `0.8` for a camera scrub). Raise for sluggish, lower for snappy. Never `scrub: true` (= instant, defeats the smoothing).

---

## 5. Class-toggle on threshold (examples: canvas dim, section reveal)

The "DOM state changes at a scroll position" shape — stays inline via `ScrollTrigger.create` (site-specific anchors, not engine material):

```ts
this.canvasDimTrigger = ScrollTrigger.create({
  trigger: '.work',
  start: 'top bottom',                  // section's top hits viewport bottom = 0
  end: 'top top',                       // section's top hits viewport top    = 1
  scrub: 0.6,
  onUpdate: (self) => {
    this.sculpture.setAlpha(1 - self.progress);
  },
});

this.workRevealTrigger = ScrollTrigger.create({
  trigger: '.work',
  start: 'top 72%',
  onEnter: () => document.querySelector('.work')?.classList.add('is-visible'),
  onLeaveBack: () => document.querySelector('.work')?.classList.remove('is-visible'),
});
```

Apply to: any reveal that drives CSS rather than 3D.

**Tips:**
- Use `onEnter` / `onLeaveBack` (not `onToggle`) when you want explicit enter/exit behavior.
- Set thresholds from the section's actual margin context, not a default (`top 72%` fired earlier than `top 50%` on a section that follows a tall hero).
- CSS handles cascade timing (per-card stagger via `--reveal-delay`). ScrollTrigger just flips the parent flag.

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

**Why:** on a mid-scroll reload the browser restores scrollY before the scene boots; ScrollTrigger then fires `onUpdate(>0)` the instant `setupScrollTrigger()` runs — drift, camera Z, and scrub-bound uniforms snap to mid-scroll before the user touches anything. `manual` keeps the page at 0. Pair with `window.scrollTo(0, 0)` + `this.scroll?.scrollTo(0, { immediate: true })` in `preload()` as belt-and-braces.

Never move this to a module script. Never remove it.

---

## 8. Teardown (consumer scene `dispose()`)

```ts
dispose(): void {
  this.driftTrigger?.kill();
  this.cameraTrigger?.kill();
  this.canvasDimTrigger?.kill();
  this.workRevealTrigger?.kill();
  this.scrollCueTrigger?.kill();
  this.scroll?.destroy();
  // ... rest of disposables
}
```

Factory handles get `.kill()` (the `ScrollProgressTrigger` wraps the underlying instance); inline triggers get `.kill()`; the bridge gets `.destroy()` (tears down Lenis + its scroll listener). Without this, view transitions (`transition:persist`) ghost — old triggers fire on the new scene.

The engine's `src/astro/router.ts` listens on `astro:before-swap` + `beforeunload` and drives scene `exitTransition()` → `dispose()`. As long as dispose covers every trigger the scene created, view transitions stay clean.

**Adding a trigger? You also add the `.kill()` to dispose. Same commit. Always paired.**

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

1. Pick the pattern: §4 progress-scrub (use `createScrollProgress`), §5 class-toggle, §6 body-flag. Often two — scrub for 3D state, class-toggle for CSS reveals. Don't merge them into one trigger.
2. Create it inside `setupScrollTrigger()`. Don't scatter triggers across files.
3. Store the handle on the scene (`this.fooTrigger`).
4. Add the `.kill()` to `dispose()` in the same commit.
5. Pull thresholds and scrub values from your constants module if reusable, else inline with a one-line comment.
6. Test the no-bridge fallback (LOW tier: bridge null, native scroll). Scrub feels less buttery but values must still drive correctly. Touch is NOT a fallback case — it runs the bridge.

---

## Pitfalls (read before debugging scroll issues)

- **Trigger fires `onUpdate(>0)` on intro complete.** Scroll restoration — see §7.
- **Scrub looks janky.** Two render loops — confirm `scroll?.raf(time)` is called from `tick()` and nothing ever called `lenis.start()`. See §3.
- **Scroll teleports in one frame.** Someone multiplied at the raf call site (`raf(time * 1000)`) — the bridge already converts. See §3.
- **Trigger latches onto wrong dimensions.** Created before intro completion. See §9.
- **Ghost double-update after view transition.** Missing `.kill()` in dispose. See §8.
- **`Multiple instances of three.js` or triggers not driven by smoothed scroll.** Dedupe broken — `gsap`/`lenis` must resolve to single instances (your `astro.config.ts` `resolve.dedupe`).

---

## Engine citation index

- `src/scroll/scrollBridge.ts` — `ScrollBridge` (ctor wiring, raf s→ms, `scrollTo`, `destroy`)
- `src/scroll/scrollProgress.ts` — `createScrollProgress` factory
- `src/quality/quality.ts` — `enableSmoothScroll` definition
- `src/core/SceneManager.ts` — manager tick → scene tick (seconds)
- `src/astro/router.ts` — view-transition cleanup hooks
