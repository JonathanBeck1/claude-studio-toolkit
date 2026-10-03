---
description: Review three.js / WebGL / shader code in this project against the ether-threejs skill's slop checklist.
argument-hint: [file path or directory — defaults to the build CLAUDE.md names]
---

Audit the target three.js code for premium-quality issues. Target: $ARGUMENTS. With no argument, resolve the scope from `CLAUDE.md` — the path it names as the active build — and scan that path's `src/` for `.ts`, `.js`, `.glsl`, `.vert`, `.frag` files that import three.js.

**Mandatory first step:** invoke the `ether-threejs` skill (`claude-studio-toolkit:ether-threejs` as a plugin). The skill contains the slop checklist, vetted recipes, performance budgets, and reusable GLSL snippets. Do not audit from memory or generic three.js knowledge.

**Audit categories** (use the skill's checklist as canonical — these are the headline checks):

1. **Slop checklist** — default-quality giveaways: stock geometry, basic Lambert/Phong with no postprocessing, default rotation/orbit animation, no DPR clamping, particles for the sake of particles.
2. **Performance budget** — DPR clamped? Frame budget reasonable? Texture sizes power-of-two and reasonable? Geometry instanced where appropriate?
3. **Postprocessing** — using the `postprocessing` package? Sensible passes only, no kitchen-sink stacks?
4. **Shaders** — uniforms named meaningfully? GLSL imported by one consistent convention across the project — if a GLSL build plugin is configured, imports should go through it rather than `?raw`, and mixing both is the thing to flag. No magic numbers without comments explaining the intent?
5. **Brand-as-form alignment** — does the 3D work *express the brand*, or is it generic decoration?
6. **Lenis + GSAP integration** — scroll-driven scenes use Lenis for smooth scroll, GSAP for orchestration. No double-driving from `requestAnimationFrame` + scroll listeners colliding.

**Layers.** The categories above are the source layer. Report every layer, each either run or `not collected — <reason>`.
- **source**: always.
- **runtime**: when the project uses ether 1.2+ and you can drive a browser against a running build. Prefer a production preview for any number you cite. Follow the collection recipe and evidence rules in the `ether-threejs` skill's `performance.md` (Runtime diagnostics).
- **visual**: page screenshots of the settled scene at the viewports the project's CLAUDE.md names; otherwise the slop-checklist self-review viewport plus one phone-sized viewport.

Utility routes (parked behind opaque DOM, or no scene) need no runtime or visual layer beyond `failures` 0. Performance claims on any scene follow `performance.md`'s evidence rules.

**Output format**

```
## Three.js Audit: <target>

### Files reviewed
- ...

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
