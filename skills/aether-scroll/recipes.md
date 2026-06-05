# TakeTwo Scroll — Technique Recipes

Reference Claude reads when `aether-scroll` is invoked. Each recipe cites real `file:line` from the kit + site so it ages with the codebase.

**Architecture truth (read first):** `kit/src/scroll/` is empty by design today. The Lenis ↔ ScrollTrigger bridge currently lives inline in `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts`. The kit README earmarks the lift for "next site." Until then, the home scene is the canonical implementation and what every new scroll-driven section should mirror.

---

## 1. Lenis construction (`HomeScene.ts:153-168`)

```ts
if (quality.enableSmoothScroll) {
  this.lenis = new Lenis({
    duration: LENIS_DURATION,
    easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
    smoothWheel: true,
    wheelMultiplier: LENIS_WHEEL_MULTIPLIER,
    touchMultiplier: LENIS_TOUCH_MULTIPLIER,
    syncTouch: false,           // belt-and-braces: never fight iOS
  });
  this.lenis.on('scroll', ScrollTrigger.update);
} else {
  this.lenis = null;
}
```

Key points:
- **Conditional construction.** `quality.enableSmoothScroll` is set to `tier !== 'LOW' && !isTouch` in `kit/src/quality/quality.ts:120`. When Lenis is null, ScrollTrigger falls back to its default behavior of listening on native scroll events. Don't paper over the null with a fake Lenis — the fallback works.
- **Constants pulled from `site/src/scene/constants.ts`.** `LENIS_DURATION`, `LENIS_WHEEL_MULTIPLIER`, `LENIS_TOUCH_MULTIPLIER`. Tune the feel there, not inline. Brand consistency.
- **`syncTouch: false`** is non-negotiable. Touch sync fights iOS's native momentum and produces visible jitter.

---

## 2. The Lenis → ScrollTrigger bridge (`HomeScene.ts:165`)

```ts
this.lenis.on('scroll', ScrollTrigger.update);
```

One line. Without it, ScrollTrigger reads the un-smoothed native scrollY and your scrub progress jumps in 16ms increments instead of the Lenis-eased curve. With it, ScrollTrigger reads the smoothed value Lenis writes to the document on every frame.

Do NOT pipe through a manual ScrollTrigger.refresh in onScroll — Lenis already updates on its own rAF tick (next recipe) and the bridge call fires every frame Lenis emits.

---

## 3. Shared rAF tick (`HomeScene.ts:525-541`)

```ts
tick(time: number, deltaTime: number): void {
  this.lenis?.raf(time * 1000);          // Lenis expects ms
  // ... rest of per-frame work
}
```

The kit's `SceneManager.tick` (`kit/src/core/SceneManager.ts:135`) calls `activeScene.tick(now / 1000, deltaTime)`. Lenis gets its rAF from the same loop that drives the renderer.

**Why this matters:** if you give Lenis its own rAF (the library's default if you call `lenis.start()`), you get two render loops drifting against each other. Scroll position is read on Lenis's clock; 3D updates run on the renderer's clock; they desynchronize by a frame or more on slow tabs. Result: ScrollTrigger-driven uniforms lag the visible scroll by one frame and the eye catches it.

**Hard rule:** any scene that uses Lenis must tick it from `tick()`. Never call `lenis.start()`.

---

## 4. ScrollTrigger pattern — Scrub + onUpdate (drift, camera Z)

The canonical "scroll position drives a per-frame value" shape. Used for the drift rotation (`HomeScene.ts:367-375`) and the camera-Z parallax (`HomeScene.ts:377-386`):

```ts
this.scrollTriggerInstance = ScrollTrigger.create({
  trigger: 'body',
  start: 'top top',
  end: DRIFT_TRIGGER_END,
  scrub: DRIFT_SCRUB,                            // 0..1 lag in seconds; 0.6 ≈ buttery
  onUpdate: (self) => {
    if (this.drift) this.drift.setScrollProgress(self.progress);
  },
});
```

Apply to: any value that reads from scroll continuously — camera transforms, shader uniforms, displacement amplitudes.

**Slop avoidance:**
- Write the value into per-frame scene state inside `onUpdate`. Read it from `tick()`. Don't mutate three.js objects directly from `onUpdate` — that bypasses any deltaTime-aware work in `tick()` and causes the gimbal-lock snaps we already fixed (see `HeroDrift.ts` history).
- `scrub` is in seconds. `DRIFT_SCRUB = 0.6` is the brand-feel default; raise for sluggish, lower for snappy. Never `scrub: true` (= instant, defeats the smoothing).
- `trigger: 'body'` for whole-page scrub. Use a section selector for section-bound scrub.

---

## 5. ScrollTrigger pattern — Class-toggle on threshold (canvas dim, projects reveal)

The "DOM state changes at a scroll position" shape. Used for sculpture fade as projects enters (`HomeScene.ts:401-412`) and projects-reveal cascade (`HomeScene.ts:433-440`):

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
  start: 'top 72%',                     // fires when section top hits 72% from viewport top
  onEnter: () => document.querySelector('.projects')?.classList.add('is-visible'),
  onLeaveBack: () => document.querySelector('.projects')?.classList.remove('is-visible'),
});
```

Apply to: any reveal that drives CSS rather than 3D.

**Tips:**
- Use `onEnter` / `onLeaveBack` (not `onToggle`) when you want explicit enter/exit behavior. `onToggle` collapses both into one callback and obscures intent.
- The `top 72%` threshold was tuned from `top 50%` (viewport center, scrollY ≈ 480) to fire earlier — section already arriving as user starts scrolling. Use the actual section's hero-margin context to set this, not a default.
- CSS handles the cascade timing (per-card stagger via `--reveal-delay`). ScrollTrigger just flips the parent flag.

---

## 6. ScrollTrigger pattern — Body data-flag (scroll cue)

The "tiny state machine on `<body>`" shape. Used for the scroll-cue indicator (`HomeScene.ts:419-424`):

```ts
this.scrollCueTrigger = ScrollTrigger.create({
  trigger: 'body',
  start: 'top top-=40',
  onEnter: () => document.body.setAttribute('data-scrolled', ''),
  onLeaveBack: () => document.body.removeAttribute('data-scrolled'),
});
```

Apply to: tiny one-bit state changes that CSS reads — show/hide a scroll-cue, swap a header style, toggle a back-to-top button.

The `-=40` offset on the start means "fire after scrolling 40px past the natural trigger point." Small threshold = intent detected, not just micro-jitter.

---

## 7. Scroll-restoration must be inline-head (`Layout.astro:36-42`)

```html
<script is:inline>
  // Inline-head — runs before any module script. If we wait for the
  // scene module to disable scroll restoration, the browser has
  // already jumped to last scrollY by the time we listen.
  if ('scrollRestoration' in history) {
    history.scrollRestoration = 'manual';
  }
</script>
```

**Why this matters:** if the page reloads mid-scroll, the browser restores scrollY before the scene boots. ScrollTrigger then fires `onUpdate(progress > 0)` the instant `setupScrollTrigger()` runs — meaning the drift, camera Z, and any scrub-bound shader uniforms snap to their mid-scroll position before the user sees the hero. Looks like a glitch.

`history.scrollRestoration = 'manual'` keeps the page at scrollY=0 on reload. Pair with `window.scrollTo(0, 0)` + `lenis.scrollTo(0, { immediate: true })` in `preload()` (`HomeScene.ts:199-201`) as belt-and-braces.

Never move this to a module script. Never remove it.

---

## 8. Teardown (`HomeScene.ts:544-551`)

```ts
dispose(): void {
  this.scrollTriggerInstance?.kill();
  this.cameraScrollTrigger?.kill();
  this.canvasDimTrigger?.kill();
  this.projectsRevealTrigger?.kill();
  this.scrollCueTrigger?.kill();
  this.lenis?.destroy();
  // ... rest of disposables
}
```

Every ScrollTrigger gets `.kill()`. Lenis gets `.destroy()`. Without this, view transitions (Astro `transition:persist`) ghost — old triggers fire on the new scene, and you see double-update jitter.

The kit's `astro/router.ts:80-91` listens on `astro:before-swap` + `beforeunload` and calls `manager.destroy()` which calls scene `dispose()`. So as long as the scene's dispose covers every ScrollTrigger it created, view transitions work cleanly.

**Adding a new ScrollTrigger? You also add the `.kill()` to dispose. Always paired.**

---

## 9. Setup order

ScrollTriggers are created inside `setupScrollTrigger()` (`HomeScene.ts:357`), which is called **after the intro animation completes** — not in the constructor and not in `preload()`. Reason: triggers created against `body` measure `body.scrollHeight` at construction time. If your intro animates content into the page (or the intro itself adds height), triggers created before intro completion latch onto the wrong dimensions.

Order:
1. `preload()` — assemble all DOM the page needs, including hidden future content
2. Intro animation runs
3. `setupScrollTrigger()` called from intro's `onComplete`
4. `ScrollTrigger.refresh()` if any layout changed between step 2 and step 3

For pure-CSS sections (no JS-driven layout changes), triggers can be created in `preload()`. But the home scene's intro animates content layout, so it waits.

---

## 10. New section that binds to scroll — recipe

When adding a new scroll-driven section to a TakeTwo scene:

1. Decide which of the three patterns (§4 scrub-onUpdate, §5 class-toggle, §6 body-flag) the section needs. Often two: scrub for 3D state, class-toggle for CSS reveals. Don't mix into one trigger.
2. Add the trigger creation inside `setupScrollTrigger()`. Don't scatter triggers across multiple files.
3. Store the returned instance on the scene (`this.fooTrigger`). Killing it later requires the reference.
4. Add the `.kill()` to `dispose()` in the same commit.
5. Pull thresholds and scrub values from `constants.ts` if reusable, else inline with a one-line comment explaining the value.
6. Test the LOW-tier fallback path (Lenis null, native scroll). The scrub feels less buttery but should still drive the value correctly.

---

## Pitfalls (read before debugging scroll issues)

- **Trigger fires `onUpdate(>0)` on intro complete.** You forgot to set `history.scrollRestoration = 'manual'` inline-head, OR the page reloaded mid-scroll. See §7.
- **Scrub looks janky.** Two render loops — Lenis is on its own rAF. Confirm `lenis.raf()` is called from `tick()` and `lenis.start()` was never called. See §3.
- **ScrollTrigger doesn't fire on touch.** Lenis is null on touch (quality.enableSmoothScroll). ScrollTrigger falls back to native scroll, which works — but if your trigger relies on the Lenis bridge, it won't fire. Use scroll listeners that work both ways.
- **Trigger latches onto wrong dimensions.** Created before intro completion. Move to `setupScrollTrigger()` and call it from `onComplete`. See §9.
- **Ghost double-update after view transition.** Forgot `.kill()` in dispose. See §8.

---

## File-line citation index

For grep-friendly verification:

- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:153-168` — Lenis construction
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:165` — bridge call
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:357-441` — setupScrollTrigger()
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:526` — Lenis tick from scene tick
- `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts:544-551` — dispose teardown
- `clients/taketwo-media/site/src/layouts/Layout.astro:36-42` — inline-head scrollRestoration
- `clients/taketwo-media/kit/src/quality/quality.ts:120` — enableSmoothScroll definition
- `clients/taketwo-media/kit/src/core/SceneManager.ts:135` — manager tick → scene tick
- `clients/taketwo-media/kit/src/scroll/index.ts` — empty by design today
- `clients/taketwo-media/kit/README.md:60` — bridge lift roadmap
