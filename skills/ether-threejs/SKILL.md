---
name: ether-threejs
description: Premium three.js technique reference for studio-grade WebGL. Use this skill BEFORE writing any three.js code on a premium-tier deliverable. Contains reference work, technique recipes, GLSL snippets, and a slop checklist. Triggers on writing three.js code, building WebGL scenes, designing 3D web experiences, scene architecture, geometry strategy, instancing, camera and render-loop setup, performance budgets, scroll-driven 3D, multi-beat camera moves across a scroll story, a canvas or scene persisting across pages and route changes, scene lifecycle between pages, premium agency-grade WebGL. Do NOT use for non-3D TypeScript, plain DOM/CSS animation, or review-only passes — use the threejs-audit command to critique existing 3D code. For GLSL, fragment/vertex shaders, ShaderMaterial, the iridescent material, vertex displacement, MSDF/extruded 3D text, or the bloom+dither postprocessing composer, use ether-shaders instead. For the Lenis/ScrollTrigger bridge or a single scroll-progress value, use ether-scroll.
---

# ether-threejs

Persistent technique reference and slop-prevention library for premium three.js work. Built for a studio site redesign and reusable across premium projects.

## When to use

Invoke this skill before any three.js work on premium-tier deliverables. The skill exists because Claude's default three.js output is generic — torus knots, default materials, no postprocessing — and that output is unacceptable for a studio that sells against AI-generated work.

## How to use

1. Read `slop-checklist.md` first and classify the scene's tier (1 utility, 2 branded, 3 hero) from its tier table. If your planned approach trips a check for that tier, change the plan before coding. On an existing scene, make the smallest change that clears the check.
2. Build scenes on ether's Scene contract, usually by extending `BaseScene` from `ether/core`: `enterTransition`, `exitTransition`, `tick(time, deltaTime)` (seconds) and `dispose`, with every geometry, material, texture and render target registered through `this.track()`. SceneManager owns the renderer and the one render loop, so a scene never creates a `WebGLRenderer` or its own `requestAnimationFrame`. Hop order, the per-scene contract and lifecycle pitfalls (interrupted intros, teardown before the first `await`) are in `techniques/persistent-canvas-routing.md`.
3. Read `references.md` to find a studio working in the relevant aesthetic. Open its live site for ground truth.
4. Read the relevant `techniques/` file for a code recipe and required tuning parameters.
5. Pull GLSL snippets from `shaders/` and import them by the project's configured convention (see the ether-shaders hard rule); don't mix strategies without a reason. The samples use `?raw`, which returns the file verbatim. If the project registers `vite-plugin-glsl`, a `?raw` import bypasses the plugin and gets no `#include` expansion.
6. After writing code, re-run the slop checklist for the tier. Capture a screenshot. Have the user review before committing the rendered scene.

## Index

- **`references.md`** — annotated list of premium agencies and what each does well
- **`slop-checklist.md`** — tier table and concrete anti-patterns. Classify, then run before commit.
- **`performance.md`** — budgets, profiling techniques, mobile checklist
- **`techniques/`** — one file per reusable technique with code recipes
- **`shaders/`** — `.glsl` snippets (e.g. imported via `?raw`). `fresnel.glsl`, `curl-noise.glsl` and `color-grade.glsl` are standalone reference snippets the engine does not ship (the engine grades through `loadLUT` and `LUT3DEffect`). The 8×8 Bayer dither chunk is not copied here; import the engine's: `import { dither } from 'ether/shaders'` (string) or `import dither from 'ether/shaders/dither.glsl?raw'` (file). Those are the specifiers for a git or `file:` install; an npm install (not yet published) uses `@jonathanbeck1/ether/shaders` and `@jonathanbeck1/ether/shaders/dither.glsl?raw`.

## Maintenance

Add new techniques here as you encounter them in the wild. Re-verify the reference annotations periodically; agency sites change. When you find yourself doing the same shader trick twice, pull it into `shaders/` and add a `techniques/` file describing when to use it.
