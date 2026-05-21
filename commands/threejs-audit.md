---
description: Review three.js / WebGL / shader code in this project against the taketwo-threejs skill's slop checklist.
argument-hint: [file path or directory — defaults to scanning the active site]
---

Audit the target three.js code for TakeTwo-quality issues. Target: $ARGUMENTS (default to scanning `clients/taketwo-media/site/src/` for `.ts`, `.js`, `.glsl`, `.vert`, `.frag` files using three.js).

**Mandatory first step:** invoke the `taketwo-threejs` skill. The skill contains the slop checklist, vetted recipes, performance budgets, and reusable GLSL snippets. Do not audit from memory or generic three.js knowledge.

**Audit categories** (use the skill's checklist as canonical — these are the headline checks):

1. **Slop checklist** — default-quality giveaways: stock geometry, basic Lambert/Phong with no postprocessing, default rotation/orbit animation, no DPR clamping, particles for the sake of particles.
2. **Performance budget** — DPR clamped? Frame budget reasonable? Texture sizes power-of-two and reasonable? Geometry instanced where appropriate?
3. **Postprocessing** — using the `postprocessing` package (already in dependencies)? Sensible passes only, no kitchen-sink stacks?
4. **Shaders** — uniforms named meaningfully? `vite-plugin-glsl` includes used cleanly? No magic numbers without comments explaining the intent?
5. **Brand-as-form alignment** — does the 3D work *express the brand* (per design-taste memory), or is it generic decoration?
6. **Lenis + GSAP integration** — scroll-driven scenes use Lenis for smooth scroll, GSAP for orchestration. No double-driving from `requestAnimationFrame` + scroll listeners colliding.

**Output format**

```
## Three.js Audit: <target>

### Files reviewed
- ...

### 🔴 Blocking issues (must fix before ship)
- ...

### 🟡 Quality issues (should fix)
- ...

### 💭 Observations / opportunities
- ...

### Skill recipes that would help here
- [pointers into taketwo-threejs skill recipes]
```

Do not modify any files. Report only.
