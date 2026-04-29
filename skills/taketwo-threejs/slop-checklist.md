# Slop Checklist

Run this checklist on every three.js scene before committing. If you tick any box in "Reject," the work needs to be redone, not patched.

## Reject (slop tells)

- [ ] Hero content uses default geometries (`TorusKnotGeometry`, `DodecahedronGeometry`, `BoxGeometry`, `SphereGeometry` as the visible subject)
- [ ] Any visible material is `MeshStandardMaterial` or `MeshBasicMaterial` with no custom shader uniforms or onBeforeCompile
- [ ] Lighting is only `AmbientLight` + `DirectionalLight` with default colors and untuned intensity
- [ ] Scene uses `OrbitControls` outside a product-viewer context
- [ ] Particle field has no narrative function (does not respond to scroll, pointer, or scene state)
- [ ] No postprocessing pipeline (no bloom, no color grading, no grain/dither)
- [ ] 3D content sits next to flat HTML in unrelated layout (3D is decoration, not integrated with typography)
- [ ] The scene could be on any other website (no brand-specific palette, motion, or composition)
- [ ] Camera is static or only OrbitControls — no choreographed movement
- [ ] Mobile FPS not measured

## Required

Every shipped 3D moment must demonstrate ALL of these:

- [ ] At least one custom GLSL shader (vertex, fragment, or both) giving a material identity
- [ ] Postprocessing chain with at minimum: tone mapping + dither/grain. Recommended additions: `UnrealBloomPass`, custom color grading via LUT, chromatic aberration on bright edges.
- [ ] Camera choreography driven by GSAP timeline OR scroll position via Lenis — never `OrbitControls` for non-product contexts
- [ ] Geometry is one of: hand-modeled in Blender, procedurally generated (e.g., particle system, raymarched SDF), or a non-primitive imported asset
- [ ] Brand palette is applied deliberately (one of `#e66cff`, `#59ffe2`, `#ff7d4e` is dominant; another is accent; muted on `#0a0e1a → #161b2f` background)
- [ ] Mobile profiling completed — sustained 30+ FPS on a 2-year-old iPhone
- [ ] Renders correctly with `prefers-reduced-motion` (motion reduced or disabled, not just muted)

## Self-review process

Before committing any scene-touching code:

1. Take a screenshot of the rendered scene (1920x1080, default viewport).
2. Open the screenshot next to a reference screenshot from `references/screenshots/`. If the gap is obvious, redesign.
3. Run through the Reject checklist. If any box ticks, fix before commit.
4. Run through the Required checklist. If any box does NOT tick, fix before commit.
5. Profile on Chrome DevTools Performance tab. Confirm 60 FPS on a mid-tier laptop, frame budget under 16ms.
6. If a real device is available, profile on a 2-year-old iPhone. Confirm sustained 30+ FPS.
7. Push the screenshot to the brainstorming visual companion (or share with the user) for art-direction review BEFORE committing the underlying scene code.

## Common rationalizations to reject

- *"It's just a placeholder, I'll polish later."* → Placeholders shipped to main are how slop ends up in production. Polish before commit.
- *"OrbitControls makes it feel interactive."* → Interactivity ≠ choreography. Choreography is harder and required.
- *"I added a bloom pass, that's enough postprocessing."* → Bloom alone is the AI-slop signature look. The full chain matters.
- *"Mobile is a stretch goal."* → Mobile is a hard requirement (see `performance.md`).
- *"The user will give feedback after they see it."* → User reviews are the LAST gate, not the only gate. Apply the checklist first.
