---
name: ether-scroll
description: Lenis + GSAP ScrollTrigger bridge for Astro + three.js sites built on the ether engine (ether/scroll exports ScrollBridge + createScrollProgress). Documents the rAF-shared loop, conditional smooth-scroll by quality tier, the canonical trigger patterns (scroll-progress via the engine factory; class-toggle and body-flag inline), and the scroll-progress-to-3D handoff. Triggers on Lenis, ScrollTrigger, smooth scroll, scroll-driven animation, scroll progress, scroll-bound camera, scroll-bound shader uniform, parallax, scroll pinning, scrollytelling, scroll restoration, scroll cue, scroll cascade, persistent canvas + scroll, scroll-driven shader uniform. Do NOT use for non-scroll GSAP timelines, CSS scroll-snap, or basic anchor-link smooth scrolling.
---

# ether-scroll

Technique reference for the Lenis + GSAP ScrollTrigger stack in the [ether](https://github.com/JonathanBeck1/ether) engine. Invoke before writing scroll-driven motion on a site built on it.

Symbol names are the durable references. Paths cited here are ether repo paths (`src/...`); your site's consumer scene is referred to by role.

## When to use

Any of:
- Adding a new section that binds visual state to scroll position.
- Modifying an existing ScrollTrigger in a scene's `setupScrollTrigger()`.
- Wiring a shader uniform, camera transform, or DOM class to scroll progress.
- Diagnosing scroll feel — jank, mis-firing triggers, ghost updates after view transitions.

Do NOT invoke for:
- Pure CSS scroll-snap or `scroll-timeline()` work (those don't need ScrollTrigger).
- Sites that don't use `ether/scroll` (this skill encodes its bridge architecture).

## Read first

1. `recipes.md` in this directory — ten numbered recipes.
2. The engine bridge at `src/scroll/` — `ScrollBridge` (Lenis lifecycle, idempotent plugin registration, seconds→ms raf) and `createScrollProgress` (page progress 0..1 → callback, raw and unsmoothed).
3. Your site's scene `setupScrollTrigger()` — the consumer.

## Hard rules

- **The bridge is ticked from the engine's render loop, not its own.** Your scene's `tick(time)` calls `this.scroll?.raf(time)` — `ScrollBridge` converts seconds→ms internally; never multiply at the call site. Never call `lenis.start()`. Two rAF loops produce one-frame lag between scroll and 3D.
- **The `ScrollBridge` is conditional on `quality.enableSmoothScroll`.** Null on LOW tier and under prefers-reduced-motion — touch gets the bridge (Lenis `syncTouch` smooths on top of native iOS momentum, the fix for choppy mobile scroll-to-3D; it does NOT hijack scroll). When null, ScrollTrigger falls back to native scroll automatically — don't paper over the null with a fake bridge. Progress triggers still work without it: `createScrollProgress` registers the plugin itself.
- **Construct the bridge at `enterTransition` START, never the scene constructor.** Lenis intercepts wheel from the moment it exists but only moves the page when its raf is pumped — and `tick()` only runs once the scene is the manager's activeScene, after preload. A constructor-built bridge eats every wheel event for the whole preload window, then lurches when ticking starts. Native scroll covers input until enter.
- **Triggers born mid-range deliver RAW progress at creation.** If the user scrolled during the intro, every trigger writes its full progress into the scene's `*Target` fields the instant `setupScrollTrigger()` runs — while the live values still sit at their construction-time rest states. `tick()`'s smoothing then eases the world from rest to the live scroll state through the exact same path as normal scrolling. No separate catch-up tween is needed: the target/live split *is* the catch-up.
- **Progress triggers come from `createScrollProgress` (ether/scroll), not hand-rolled `ScrollTrigger.create`.** Call it with no `scrub`. Event-style triggers (class/attr toggles) stay inline — site-specific DOM hooks.
- **ScrollTriggers go through `setupScrollTrigger()`,** called from intro `onComplete`, not from the constructor and not from `preload()`. Triggers measure layout at construction time; create them after the intro has finished modifying layout.
- **`history.scrollRestoration = 'manual'` lives inline in your layout's `<head>`.** Do not move it to a module script. Do not remove it. Without it, mid-scroll reloads cause `onUpdate(>0)` to fire on first render and snap state mid-animation.
- **Every trigger you create has a paired `.kill()` in the scene's teardown helper** (and the bridge a `.destroy()`). Same commit. Centralize the kills in one private `killTriggers()` and call it from every exit path — `exitTransition()` above all, which runs synchronously inside `astro:before-swap`, ahead of Astro's DOM swap — plus `dispose()` as the backstop. View transitions (`transition:persist`) ghost old triggers if the exit path skips this.
- **Pull thresholds and smoothing settle times from your constants module when reusable.** Inline only with a one-line comment explaining the value (e.g. a `top 72%` reveal threshold tuned to a section's margin).

## Slop indicators (do not ship)

- A second `requestAnimationFrame` loop driving scroll updates.
- `lenis.start()` called anywhere.
- `ScrollTrigger.update` bound directly to `window.scroll` events.
- `new Lenis(...)` or a bare page-progress `ScrollTrigger.create` in site code — `ether/scroll` owns those primitives.
- `raf(time * 1000)` at a call site — the bridge converts; double-scaling teleports the scroll.
- ScrollTriggers created in module scope or in the scene constructor.
- Mutating three.js objects directly from `onUpdate` (bypasses `tick()`'s deltaTime-aware path).
- Passing `scrub` to `createScrollProgress` and expecting eased motion — it is inert on an onUpdate-only trigger (GSAP builds a scrub tween only for an attached `animation`; the callback always receives raw progress). Smooth in `tick()` instead.
- `onToggle` collapsing enter + exit into one callback when the intent is asymmetric.
- A ScrollTrigger created without a matching `.kill()` in the scene's teardown helper.
- `history.scrollRestoration` set in a module script instead of inline-head.

## Procedure for a new scroll-driven section

1. **Pick the pattern.** Scroll-progress via `createScrollProgress` (§4 in recipes), class-toggle on threshold (§5), or body data-flag (§6). Often you need two — a progress trigger for 3D, class-toggle for CSS reveals.
2. **Create the trigger inside `setupScrollTrigger()`** — not in the constructor. Store the instance on the scene (`this.fooTrigger`).
3. **Write the RAW value into a `*Target` field in `onUpdate`,** and ease the live value toward it in `tick()`. Never mutate three.js objects from `onUpdate`, and never reach for `scrub` to do the easing.
4. **Add the `.kill()` to `killTriggers()`** in the same commit. Always paired.
5. **Test the LOW-tier fallback** — Lenis null, native scroll. Scrub feel changes but values must still drive correctly.

After implementing, run `premium-review`.

## After the skill

- Point Claude at `ether-threejs` if the scroll-bound value is a shader uniform.
- Point at `ether-shaders` if the value drives material parameters.
- Recipes in `recipes.md` show the copy-paste skeletons.

## Files

- `SKILL.md` — this file (the script).
- `recipes.md` — ten numbered technique recipes.
- `evals/triggers.json` — should/shouldn't-trigger regression set for the description.
