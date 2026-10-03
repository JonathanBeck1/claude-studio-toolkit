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
4. **Shaders** — uniforms named meaningfully? Shader loading mixed without a reason (some via `vite-plugin-glsl`, some `?raw`, some inline strings)? Flag accidental mixing; don't enforce one strategy. No magic numbers without comments explaining the intent?
5. **Brand-as-form alignment** — does the 3D work *express the brand*, or is it generic decoration?
6. **Lenis + GSAP integration** — scroll-driven scenes use Lenis for smooth scroll, GSAP for orchestration. No double-driving from `requestAnimationFrame` + scroll listeners colliding.

**Output format**

```
## Three.js Audit: <target>

### Files reviewed
- ...

### [CRITICAL] Blocking issues (must fix before ship)
- ...

### [WARN] Quality issues (should fix)
- ...

### [NOTE] Observations / opportunities
- ...

### Skill recipes that would help here
- [pointers into ether-threejs skill recipes]
```

Do not modify any files. Report only.
