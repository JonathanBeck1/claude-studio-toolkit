---
name: ether-threejs
description: Premium three.js technique reference for TakeTwo Media work. Use this skill BEFORE writing any three.js code on TakeTwo Media projects (or any premium-tier deliverable). Contains annotated reference work, vetted technique recipes, reusable GLSL shader snippets, performance budgets, and a slop checklist for self-review. Triggers on: writing three.js code, building WebGL scenes, designing 3D web experiences, scene architecture, geometry strategy, instancing, camera and render-loop setup, performance budgets, scroll-driven 3D, persistent-canvas routing, premium agency-grade WebGL. Do NOT use for non-3D TypeScript, plain DOM/CSS animation, or review-only passes — use the threejs-audit command to critique existing 3D code. For GLSL, fragment/vertex shaders, ShaderMaterial, the iridescent material, vertex displacement, MSDF/extruded 3D text, or the bloom+dither postprocessing composer, use ether-shaders instead.
---

# ether-threejs

Persistent technique reference and slop-prevention library for premium three.js work. Built during Phase 0 of the TakeTwo Media site redesign and reusable across all future premium projects.

## When to use

Invoke this skill before any three.js work on premium-tier deliverables. The skill exists because Claude's default three.js output is generic — torus knots, default materials, no postprocessing — and that output is unacceptable for TakeTwo's positioning. See `brain/studio-standards.md`.

## How to use

1. Read `slop-checklist.md` first. If your planned approach trips any checkbox, redesign before coding.
2. Read `references.md` to find a studio working in the relevant aesthetic. Open the local screenshot for ground truth.
3. Read the relevant `techniques/` file for a code recipe and required tuning parameters.
4. Pull GLSL snippets from `shaders/` and import them via `?raw` (`vite-plugin-glsl` is configured but unused — every GLSL import in the codebase uses `?raw`).
5. After writing code, re-run the slop checklist. Capture a screenshot. Have the user review before committing the rendered scene.

## Index

- **`references.md`** — annotated list of premium agencies and what each does well
- **`slop-checklist.md`** — concrete anti-patterns. Run before commit.
- **`performance.md`** — budgets, profiling techniques, mobile checklist
- **`techniques/`** — one file per reusable technique with code recipes
- **`shaders/`** — `.glsl` snippets imported by Phase 2+ project code
- **`references/screenshots/`** — local PNGs of reference work (survives upstream changes)

## Maintenance

Add new techniques here as you encounter them in the wild. Update screenshots periodically; agency sites change. When you find yourself doing the same shader trick twice, pull it into `shaders/` and add a `techniques/` file describing when to use it.
