# TakeTwo Scroll — Technique Recipes

Reference Claude reads when `ether-scroll` is invoked. Each recipe cites real `file:line` from the kit + site so it ages with the codebase. If a cite drifts, fix it in the same PR that moved the code.

Line-number citations in this file predate large HomeScene refactors and have drifted — trust symbol names and grep, not line numbers.

**Architecture truth (read first):** the Lenis ↔ ScrollTrigger bridge lives in the engine at `kit/src/scroll/` — `ScrollBridge` (Lenis lifecycle + idempotent `gsap.registerPlugin` + the `ScrollTrigger.update` wiring + seconds→ms raf) and `createScrollProgress` (one scrubbed trigger mapping page progress 0..1 to a callback). `HomeScene.ts` is the canonical consumer: it constructs the bridge with brand-tuned options and uses the factory for its two progress scrubs. Event-style triggers (class/attr toggles) stay inline in site code by design — they're brand-specific DOM hooks, not engine material.

---

## 1. ScrollBridge construction (`HomeScene.ts:144-160`)

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
- **Conditional construction.** `quality.enableSmoothScroll` is `tier !== 'LOW'` (`kit/src/quality/quality.ts`). When the bridge is null (LOW tier), ScrollTrigger falls back to native scroll events. Don't paper over the null with a fake bridge — the fallback works.
- **Options pass through verbatim to `new Lenis(...)`.** Brand tuning (`LENIS_DURATION`, multipliers, `LENIS_TOUCH_INERTIA_EXPONENT`) lives in `site/src/scene/constants.ts`. Tune the feel there, not inline.
- **`syncTouch: true`** is the fix for choppy mobile scroll-to-3D. The old advice ("syncTouch fights iOS, leave it false") was wrong for OUR use: native iOS scroll arrives in coarse stepped compositor bursts, so binding the 3D to it reads as choppy. `syncTouch` (Lenis 1.3+) smooths ON TOP of native momentum — it does not hijack scroll — giving touch the same rAF-synced position desktop has. `touchInertiaExponent` shapes the post-flick glide decay (Lenis default 1.7); the per-frame interpolation that smooths iOS's stepped input is `syncTouchLerp` (left at its 0.075 default). With Lenis live on touch, `TOUCH_SCRUB_FACTOR` drops to 1.0 — the heavier scrub was only masking this missing inertial layer.

---

## 2. The Lenis → ScrollTrigger wiring (`kit/src/scroll/scrollBridge.ts:38`)

```ts
this.lenis.on('scroll', ScrollTrigger.update);
```

One line, owned by the `ScrollBridge` constructor — site code never writes it. Without it, ScrollTrigger reads un-smoothed native scrollY and scrub progress jumps in 16ms increments instead of the Lenis-eased curve. The constructor also registers the ScrollTrigger plugin idempotently (`scrollBridge.ts:10-14`), so no bare `gsap.registerPlugin(ScrollTrigger)` belongs in site code either.

Do NOT bind `ScrollTrigger.update` to `window.scroll` events yourself, and do not pipe a manual `ScrollTrigger.refresh` through onScroll.

---

## 3. Shared rAF tick (`HomeScene.ts:508`)

```ts
tick(time: number, deltaTime: number): void {
  this.scroll?.raf(time);          // bridge converts seconds → ms internally
  // ... rest of per-frame work
}
```

The kit's `SceneManager.tick` (`kit/src/core/SceneManager.ts:135`) calls `activeScene.tick(now / 1000, deltaTime)` — seconds. `ScrollBridge.raf` does the ×1000 Lenis expects (`scrollBridge.ts:43-45`). **Never multiply at the call site** — double-scaling makes Lenis run 1000× fast, which reads as scroll teleporting in one frame.

**Why one loop matters:** if you give Lenis its own rAF (the library's default if you call `lenis.start()`), scroll position is read on Lenis's clock while 3D updates run on the renderer's clock — they desynchronize by a frame on slow tabs and the eye catches it.

**Hard rule:** the bridge is ticked from `tick()`. Never call `lenis.start()`.

---

## 4. Progress scrub — `createScrollProgress` (drift `HomeScene.ts:357`, camera `:362`)

The canonical "scroll position drives a per-frame value" shape, exported by `ether/scroll` (`kit/src/scroll/scrollProgress.ts:36`):

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
- `scrub` is in seconds, from constants: `DRIFT_SCRUB = 0.5`, `CAMERA_SCRUB = 0.8`. Raise for sluggish, lower for snappy. Never `scrub: true` (= instant, defeats the smoothing).

---

## 5. Class-toggle on threshold (canvas dim `HomeScene.ts:383`, projects reveal `:415`)

The "DOM state changes at a scroll position" shape — stays inline via `ScrollTrigger.create` (brand-specific anchors, not engine material):

```ts
this.canvasDimTrigger = ScrollTrigger.create({
  trigger: '.projects',
  start: 'top bottom',                  // section's top hits viewport bottom = 0
  end: 'top top',                       // section's top hits viewport top    = 1
  scrub: 0.6,
  onUpdate: (self) => {
    this.sculpture.setAlpha(1 - self.progress);
  },
});

this.projectsRevealTrigger = ScrollTrigger.create({
  trigger: '.projects',
  start: 'top 72%',
  onEnter: () => document.querySelector('.projects')?.classList.add('is-visible'),
  onLeaveBack: () => document.querySelector('.projects')?.classList.remove('is-visible'),
});
```

Apply to: any reveal that drives CSS rather than 3D.

**Tips:**
- Use `onEnter` / `onLeaveBack` (not `onToggle`) when you want explicit enter/exit behavior.
- The `top 72%` threshold was tuned from `top 50%` to fire earlier. Set it from the section's actual hero-margin context, not a default.
- CSS handles cascade timing (per-card stagger via `--reveal-delay`). ScrollTrigger just flips the parent flag.

---

## 6. Body data-flag (scroll cue `HomeScene.ts:401`)

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

## 7. Scroll-restoration must be inline-head (`Layout.astro:41-43`)

```html
<script is:inline>
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
</script>
```

**Why:** on a mid-scroll reload the browser restores scrollY before the scene boots; ScrollTrigger then fires `onUpdate(>0)` the instant `setupScrollTrigger()` runs — drift, camera Z, and scrub-bound uniforms snap to mid-scroll before the user touches anything. `manual` keeps the page at 0. Pair with `window.scrollTo(0, 0)` + `this.scroll?.scrollTo(0, { immediate: true })` in `preload()` (`HomeScene.ts:189-191`) as belt-and-braces.

Never move this to a module script. Never remove it.

---

## 8. Teardown (`HomeScene.ts:528-533`)

```ts
dispose(): void {
  this.driftTrigger?.kill();
  this.cameraTrigger?.kill();
  this.canvasDimTrigger?.kill();
  this.projectsRevealTrigger?.kill();
  this.scrollCueTrigger?.kill();
  this.scroll?.destroy();
  // ... rest of disposables
}
```

Factory handles get `.kill()` (the `ScrollProgressTrigger` wraps the underlying instance); inline triggers get `.kill()`; the bridge gets `.destroy()` (tears down Lenis + its scroll listener). Without this, view transitions (`transition:persist`) ghost — old triggers fire on the new scene.

The kit's `astro/router.ts:98-111` listens on `astro:before-swap` + `beforeunload` and calls `manager.destroy()` → scene `dispose()`. As long as dispose covers every trigger the scene created, view transitions stay clean.

**Adding a trigger? You also add the `.kill()` to dispose. Same commit. Always paired.**

---

## 9. Setup order

ScrollTriggers are created inside `setupScrollTrigger()` (`HomeScene.ts:347`), called **after the intro completes** — not in the constructor and not in `preload()`. Triggers measure layout at construction; created before the intro finishes mutating layout, they latch onto wrong dimensions.

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
5. Pull thresholds and scrub values from `constants.ts` if reusable, else inline with a one-line comment.
6. Test the no-bridge fallback (LOW tier: bridge null, native scroll). Scrub feels less buttery but values must still drive correctly. Touch is NOT a fallback case anymore — it runs the bridge.

---

## Pitfalls (read before debugging scroll issues)

- **Trigger fires `onUpdate(>0)` on intro complete.** Scroll restoration — see §7.
- **Scrub looks janky.** Two render loops — confirm `scroll?.raf(time)` is called from `tick()` and nothing ever called `lenis.start()`. See §3.
- **Scroll teleports in one frame.** Someone multiplied at the raf call site (`raf(time * 1000)`) — the bridge already converts. See §3.
- **Trigger latches onto wrong dimensions.** Created before intro completion. See §9.
- **Ghost double-update after view transition.** Missing `.kill()` in dispose. See §8.
- **`Multiple instances of three.js` or triggers not driven by smoothed scroll.** Dedupe broken — `gsap`/`lenis` must resolve to single instances (`site/astro.config.ts` `resolve.dedupe`).

---

## File-line citation index

For grep-friendly verification:

- `clients/taketwo-media/kit/src/scroll/scrollBridge.ts:32-58` — ScrollBridge (ctor wiring at 38, raf s→ms at 43-45)
- `clients/taketwo-media/kit/src/scroll/scrollProgress.ts:36` — createScrollProgress factory
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:144-160` — bridge construction (brand options)
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:189-191` — preload scroll-to-top
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:347` — setupScrollTrigger()
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:357,362` — the two progress scrubs (drift, camera)
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:383,401,415` — inline event triggers (canvas-dim, scroll-cue, projects-reveal)
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:508` — bridge tick from scene tick
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:528-533` — dispose teardown
- `clients/taketwo-media/site/src/layouts/Layout.astro:41-43` — inline-head scrollRestoration
- `clients/taketwo-media/kit/src/quality/quality.ts:120` — enableSmoothScroll definition
- `clients/taketwo-media/kit/src/core/SceneManager.ts:135` — manager tick → scene tick (seconds)
- `clients/taketwo-media/kit/src/astro/router.ts:98-111` — view-transition cleanup hooks
- `clients/taketwo-media/kit/README.md:60` — ether/scroll API table row
