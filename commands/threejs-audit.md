---
description: Review three.js / WebGL / shader code in this project against the ether-threejs skill's slop checklist.
argument-hint: [file path or directory — defaults to the build CLAUDE.md names]
---

Audit the target three.js code for premium-quality issues. Target: $ARGUMENTS. With no argument, resolve the scope from `CLAUDE.md` — the path it names as the active build — and scan that path's `src/` for `.ts`, `.js`, `.glsl`, `.vert`, `.frag` files that import three.js.

**Mandatory first step:** invoke the `ether-threejs` skill (`studio-toolkit:ether-threejs` as a plugin). The skill contains the slop checklist, vetted recipes, performance budgets, and reusable GLSL snippets. Do not audit from memory or generic three.js knowledge.

**Classify first.** For each scene in scope, state its tier from the tier table in the skill's `slop-checklist.md`, with a one-line reason. Apply that tier's requirements: a Tier 3 item missing from a Tier 1 scene is not a finding, and a Tier 2 scene passes an item beyond Tier 1's lines that it meets or gives a stated reason to skip. The tier scopes only the slop-checklist lines behind categories 1, 3 and 5; the other categories apply to every scene. When unsure, audit at the higher tier.

**Audit categories** (use the skill's checklist as canonical — these are the headline checks):

1. **Slop checklist** — default-quality giveaways: stock geometry, basic Lambert/Phong, default rotation/orbit animation, no DPR clamping, particles for the sake of particles.
2. **Performance budget** — DPR clamped? Frame budget reasonable? Texture sizes power-of-two and reasonable? Geometry instanced where appropriate?
3. **Postprocessing** — where the tier requires a chain or one exists: using the `postprocessing` package? Sensible passes only, no kitchen-sink stacks?
4. **Shaders** — uniforms named meaningfully? Shader loading mixed without a reason (some via `vite-plugin-glsl`, some `?raw`, some inline strings)? Flag accidental mixing; don't enforce one strategy. No magic numbers without comments explaining the intent?
5. **Brand-as-form alignment** — from Tier 2 up: does the 3D work *express the brand*, or is it generic decoration?
6. **Scroll** — a `ScrollBridge` exists only when `QualityProfile.enableSmoothScroll` is true; otherwise ScrollTrigger reads native scroll. Progress triggers come from `createScrollProgress`, created after the intro settles layout (ether-scroll skill, Setup order). Teardown and loop ownership are category 7.
7. **Lifecycle and ownership** (ether README, Routing and scene lifecycle; Disposal) — in a `BaseScene` subclass every GPU resource goes through `BaseScene.track()` or is the scene's `this.composer`, and everything else the scene starts (DOM and window listeners, GSAP tweens and timelines, the intro included since `enterTransition()` is not awaited) is released in an overridden `dispose()` that calls `super.dispose()`; a direct `Scene` implementation releases the same things in its own `dispose()`. ScrollTriggers and the `ScrollBridge` are killed or destroyed in `exitTransition()` before its first `await`, `dispose()` as backstop. The bridge is built at the start of `enterTransition()`, never in the constructor. Nothing drives the scene or Lenis from its own rAF: `SceneManager`'s loop calls `tick`, and the bridge advances through `ScrollBridge.raf(time)` there. Routes meant to share one world share one factory object and the scene implements `retarget(route)`; it re-couples DOM-bound state itself, deferred to `astro:page-load`. Nothing is allocated per frame in `tick` (vectors, arrays, closures).

**Layers.** The categories above are the source layer. Report every layer, each either run or `not collected — <reason>`.
- **source**: always.
- **runtime**: when the project uses ether 1.2+ and you can drive a browser against a running build. Prefer a production preview for any number you cite. Follow the collection recipe and evidence rules in the `ether-threejs` skill's `performance.md` (Runtime diagnostics); the recipe reaches the manager through the canvas's `__sceneManager` tag, which ether documents as a tooling hook stable across 1.x.
- **visual**: page screenshots of the settled scene at the viewports the project's CLAUDE.md names; otherwise the slop-checklist self-review viewport plus one phone-sized viewport.

Utility routes (parked behind opaque DOM, or no scene; a Tier 1 scene is not one) need no runtime or visual layer beyond `failures` 0. Performance claims on any scene follow `performance.md`'s evidence rules.

**Output format**

```
## Three.js Audit: <target>

### Files reviewed
- ...

### Tiers
- <scene>: Tier <1|2|3> — <reason>

### Evidence
- source: <files read>
- runtime: <commit (git rev-parse --short HEAD; on a dirty tree append +dirty:<`git diff HEAD | git hash-object --stdin | cut -c1-7`>) · URL · build (dev/preview/deploy id) · browser · GPU renderer string or software GL · viewport> — <phase, route, failures, skipped, renderCalls/drawCalls/triangles, geometries/textures/programs per route, dpr, postFX, fps/cpuMs only if real hardware> | not collected — <reason>
- visual: <commit · viewports · screenshot paths> | not collected — <reason>

### [CRITICAL] Blocking issues (must fix before ship)
- ...

### [WARN] Quality issues (should fix)
- ...

### [NOTE] Observations / opportunities
- ...

### Skill recipes that would help here
- [pointers into ether-threejs skill recipes]
```

Do not modify project files. Starting a dev server or preview and driving a browser read-only is allowed; stop anything you started.
