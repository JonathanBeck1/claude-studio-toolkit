---
name: aether-scroll
description: Lenis + GSAP ScrollTrigger bridge for the TakeTwo studio site — now an engine module (aether/scroll exports ScrollBridge + createScrollProgress). Documents the rAF-shared loop, conditional smooth-scroll by quality tier, the canonical trigger patterns (progress-scrub via the kit factory; class-toggle and body-flag inline), and the scroll-progress-to-3D handoff. Triggers on Lenis, ScrollTrigger, smooth scroll, scroll-driven animation, scroll progress, scroll-bound camera, scroll-bound shader uniform, parallax, scroll pinning, scrollytelling, scroll restoration, scroll cue, scroll cascade, persistent canvas + scroll, scroll-driven shader uniform. Do NOT use for non-scroll GSAP timelines, CSS scroll-snap, or basic anchor-link smooth scrolling.
---

# aether-scroll

Technique reference for the Lenis + GSAP ScrollTrigger stack used on TakeTwo Media. Invoke before writing scroll-driven motion on any TakeTwo client deliverable.

## When to use

Any of:
- Adding a new section that binds visual state to scroll position.
- Modifying an existing ScrollTrigger in `HomeScene.ts`.
- Wiring a shader uniform, camera transform, or DOM class to scroll progress.
- Diagnosing scroll feel — jank, mis-firing triggers, ghost updates after view transitions.

Do NOT invoke for:
- Pure CSS scroll-snap or `scroll-timeline()` work (those don't need ScrollTrigger).
- Non-TakeTwo client work (this skill encodes TakeTwo's specific kit + bridge architecture).

## Read first

1. `recipes.md` in this directory — ten numbered recipes, each citing `file:line`.
2. The engine bridge at `clients/taketwo-media/kit/src/scroll/` — `ScrollBridge` (Lenis lifecycle, idempotent plugin registration, seconds→ms raf) and `createScrollProgress` (page progress 0..1 → callback).
3. The canonical consumer at `clients/taketwo-media/site/src/scene/scenes/home/HomeScene.ts` (`setupScrollTrigger()` at line 347).

## Hard rules

- **The bridge is ticked from `SceneManager.tick`, not its own loop.** `HomeScene.ts:508` calls `this.scroll?.raf(time)` from inside `tick()` — `ScrollBridge` converts seconds→ms internally; never multiply at the call site. Never call `lenis.start()`. Two rAF loops produce one-frame lag between scroll and 3D.
- **The `ScrollBridge` is conditional on `quality.enableSmoothScroll`.** Null on LOW tier and touch devices. ScrollTrigger falls back to native scroll automatically — don't paper over the null with a fake bridge. Progress scrubs still work without it: `createScrollProgress` registers the plugin itself.
- **Construct the bridge at `enterTransition` START, never the scene constructor.** Lenis intercepts wheel from the moment it exists but only moves the page when its raf is pumped — and `tick()` only runs once the scene is the manager's activeScene, after preload. A constructor-built bridge eats every wheel event for the whole preload window, then lurches when ticking starts. Native scroll covers input until enter (see `initScrollBridge` in both scenes).
- **Triggers born mid-range teleport.** Creation-time `onUpdate` fires with RAW progress — scrub smooths linked animations, not creation. If the user can be scrolled when `setupScrollTrigger` runs (they scrolled during the intro), reset consumers to rest and ease to the live state with a one-shot catch-up tween (`HomeScene.setupScrollTrigger`'s `catchupTween`).
- **Progress scrubs come from `createScrollProgress` (aether/scroll), not hand-rolled `ScrollTrigger.create`.** Drift and camera both use it (`HomeScene.ts:357`, `:362`). Event-style triggers (class/attr toggles) stay inline — brand-specific DOM hooks.
- **ScrollTriggers go through `setupScrollTrigger()`,** called from intro `onComplete`, not from the constructor and not from `preload()`. Triggers measure layout at construction time; create them after the intro has finished modifying layout.
- **`history.scrollRestoration = 'manual'` lives inline-head** in `Layout.astro:41-43`. Do not move it to a module script. Do not remove it. Without it, mid-scroll reloads cause `onUpdate(>0)` to fire on first render and snap state mid-animation.
- **Every trigger you create has a paired `.kill()` in dispose** (and the bridge a `.destroy()`). Same commit. View transitions (`transition:persist`) ghost old triggers if you skip this.
- **Pull thresholds and scrub values from `constants.ts` when reusable.** Inline only with a one-line comment explaining the value (see `HomeScene.ts:415` for the `top 72%` example).

## Slop indicators (do not ship)

- A second `requestAnimationFrame` loop driving scroll updates.
- `lenis.start()` called anywhere.
- `ScrollTrigger.update` bound directly to `window.scroll` events.
- `new Lenis(...)` or a bare progress-scrub `ScrollTrigger.create` in site code — `aether/scroll` owns those primitives.
- `raf(time * 1000)` at a call site — the bridge converts; double-scaling teleports the scroll.
- ScrollTriggers created in module scope or in the scene constructor.
- Mutating three.js objects directly from `onUpdate` (bypasses `tick()`'s deltaTime-aware path).
- `scrub: true` — defeats the smoothing the bridge exists to provide.
- `onToggle` collapsing enter + exit into one callback when the intent is asymmetric.
- A ScrollTrigger created without a matching `.kill()` in `dispose()`.
- `history.scrollRestoration` set in a module script instead of inline-head.

## Procedure for a new scroll-driven section

1. **Pick the pattern.** Progress-scrub via `createScrollProgress` (§4 in recipes), class-toggle on threshold (§5), or body data-flag (§6). Often you need two — scrub for 3D, class-toggle for CSS reveals.
2. **Create the trigger inside `setupScrollTrigger()`** — not in the constructor. Store the instance on the scene (`this.fooTrigger`).
3. **Write per-frame state in `onUpdate`,** read it from `tick()`. Never mutate three.js objects from `onUpdate`.
4. **Add the `.kill()` to `dispose()`** in the same commit. Always paired.
5. **Test the LOW-tier fallback** — Lenis null, native scroll. Scrub feel changes but values must still drive correctly.

After implementing, run `premium-review` per the studio bar.

## After the skill

- Point Claude at `aether-threejs` if the scroll-bound value is a shader uniform.
- Point at `aether-shaders` if the value drives material parameters.
- Recipes in `recipes.md` show the copy-paste skeletons. Cite `file:line` in commit messages so future grep finds the lineage.

## Files

- `SKILL.md` — this file (the script).
- `recipes.md` — ten numbered technique recipes with `file:line` citations.
