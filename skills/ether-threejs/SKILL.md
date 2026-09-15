---
name: ether-threejs
description: Premium three.js technique reference for studio-grade WebGL. Use this skill BEFORE writing any three.js code on a premium-tier deliverable. Contains annotated reference work, vetted technique recipes, reusable GLSL shader snippets, performance budgets, and a slop checklist for self-review. Triggers on writing three.js code, building WebGL scenes, designing 3D web experiences, scene architecture, geometry strategy, instancing, camera and render-loop setup, performance budgets, scroll-driven 3D, persistent-canvas routing, premium agency-grade WebGL. Do NOT use for non-3D TypeScript, plain DOM/CSS animation, or review-only passes — use the threejs-audit command to critique existing 3D code. For GLSL, fragment/vertex shaders, ShaderMaterial, the iridescent material, vertex displacement, MSDF/extruded 3D text, or the bloom+dither postprocessing composer, use ether-shaders instead.
---

# ether-threejs

Persistent technique reference and slop-prevention library for premium three.js work. Built for a studio site redesign and reusable across premium projects.

## When to use

Invoke this skill before any three.js work on premium-tier deliverables. The skill exists because Claude's default three.js output is generic — torus knots, default materials, no postprocessing — and that output is unacceptable for a studio that sells against AI-generated work.

## How to use

1. Read `slop-checklist.md` first. If your planned approach trips any checkbox, redesign before coding.
2. Read `references.md` to find a studio working in the relevant aesthetic. Open its live site for ground truth.
3. Read the relevant `techniques/` file for a code recipe and required tuning parameters.
4. Pull GLSL snippets from `shaders/` and import them via `?raw`. `vite-plugin-glsl` is registered and active in the Vite config, but `?raw` returns the file verbatim and bypasses it — every GLSL import in the reference codebase uses `?raw`, so none of them get `#include` expansion. Drop the `?raw` on an import when you do want the plugin to resolve includes.
5. After writing code, re-run the slop checklist. Capture a screenshot. Have the user review before committing the rendered scene.

## Index

- **`references.md`** — annotated list of premium agencies and what each does well
- **`slop-checklist.md`** — concrete anti-patterns. Run before commit.
- **`performance.md`** — budgets, profiling techniques, mobile checklist
- **`techniques/`** — one file per reusable technique with code recipes
- **`shaders/`** — `.glsl` snippets, imported via `?raw`. `dither.glsl` is the chunk the engine ships as `ether/shaders`; `fresnel.glsl`, `curl-noise.glsl` and `color-grade.glsl` are standalone reference snippets the engine does not ship (the engine grades through `loadLUT` and `LUT3DEffect`).

## Maintenance

Add new techniques here as you encounter them in the wild. Re-verify the reference annotations periodically; agency sites change. When you find yourself doing the same shader trick twice, pull it into `shaders/` and add a `techniques/` file describing when to use it.
