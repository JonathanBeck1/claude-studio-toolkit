# Slop Checklist

Classify the scene's tier first, then run that tier's checks before committing. A ticked Reject box means fix that item; redesign only if the approach itself is the cause.

## Classify first

State the tier and a one-line reason. The tier follows the scene's role on the page, not the effort spent or the GPU quality tier. When unsure between two tiers, take the higher one.

| Tier | What it is | Apply |
|---|---|---|
| 1 Utility | 3D that supports the page rather than carrying it: a loader, an icon-scale object, a data view, an ambient backdrop behind content | The palette, mobile-profiling and reduced-motion lines in Required, and the Reject items for OrbitControls outside a product-viewer or data-exploration context, purposeless particles and unmeasured mobile FPS |
| 2 Branded | 3D that carries brand identity but is not the lead moment: a section accent, a case-study viewer, a secondary scene | Tier 1's lines, plus every other Reject and Required line, one by one: meet it, or state in the review why it does not fit this moment |
| 3 Hero / cinematic | The page's lead 3D moment or a choreographed sequence: a homepage hero, a scroll-driven chapter, brand-as-form | Everything in this file |

## Reject (slop tells)

- [ ] Hero content uses default geometries (`TorusKnotGeometry`, `DodecahedronGeometry`, `BoxGeometry`, `SphereGeometry` as the visible subject)
- [ ] Any visible material is `MeshStandardMaterial` or `MeshBasicMaterial` with no custom shader uniforms or onBeforeCompile
- [ ] Lighting is only `AmbientLight` + `DirectionalLight` with default colors and untuned intensity
- [ ] Scene uses `OrbitControls` outside a product-viewer or data-exploration context
- [ ] Particle field has no narrative function (does not respond to scroll, pointer, or scene state)
- [ ] No postprocessing pipeline (no bloom, no color grading, no grain/dither)
- [ ] 3D content sits next to flat HTML in unrelated layout (3D is decoration, not integrated with typography)
- [ ] The scene could be on any other website (no brand-specific palette, motion, or composition)
- [ ] Camera is static or only OrbitControls — no choreographed movement
- [ ] Mobile FPS not measured

## Required

Every Tier 3 moment must demonstrate ALL of these:

- [ ] At least one custom GLSL shader (vertex, fragment, or both) giving a material identity
- [ ] Postprocessing chain — one of the kit's three composer presets: `createHeroComposer` (restrained LDR bloom + dither), `createNightComposer` (hotter bloom, for scenes whose light is emissive geometry), or `createLightComposer` (dither only — on a pale ground bloom lifts the whole field and the accent disappears). ACES tone mapping is the `hdr` option on `createComposer`; of the three presets only `createNightComposer` exposes it. Library is vanruesc `postprocessing`, never `UnrealBloomPass`.
- [ ] Camera choreography driven by GSAP timeline OR scroll position via Lenis — never `OrbitControls` outside product-viewer or data-exploration contexts
- [ ] Geometry is one of: hand-modeled in Blender, procedurally generated (e.g., particle system, raymarched SDF), or a non-primitive imported asset
- [ ] The brand palette is applied deliberately (one accent dominant, another as counterpoint, muted values on the dark field) — never three.js default colors
- [ ] Mobile profiling completed — sustained 30+ FPS on a 2-year-old iPhone
- [ ] Renders correctly with `prefers-reduced-motion` (motion reduced or disabled, not just muted)

## Self-review process

Before committing any scene-touching code:

1. Take a screenshot of the rendered scene (1920x1080, default viewport).
2. Tier 3: open the screenshot next to the closest reference studio's live page (URLs in `references.md`). If the gap is obvious, redesign.
3. Run through the Reject checklist as the tier applies it. If an applicable box ticks, fix before commit (Tier 2, beyond Tier 1's lines: or state why it does not fit).
4. Run through the Required checklist as the tier applies it. If a required box does NOT tick, fix before commit (Tier 2, beyond Tier 1's lines: or state why it does not fit).
5. Profile on the Chrome DevTools Performance tab (ether's runtime snapshot `fps` can corroborate it per `performance.md`'s evidence rules). Confirm 60 FPS on a mid-tier laptop.
6. If a real device is available, profile on a 2-year-old iPhone. Confirm sustained 30+ FPS.
7. Push the screenshot to the brainstorming visual companion (or share with the user) for art-direction review BEFORE committing the underlying scene code.

## Common rationalizations to reject

- *"It's just a placeholder, I'll polish later."* → Placeholders shipped to main are how slop ends up in production. Polish before commit.
- *"OrbitControls makes it feel interactive."* → Interactivity ≠ choreography. Choreography is harder, and Tier 3 requires it.
- *"I added a bloom pass, that's enough postprocessing."* → Bloom alone is the AI-slop signature look. Tier 3 requires the full chain.
- *"Mobile is a stretch goal."* → Mobile is a hard requirement (see `performance.md`).
- *"The user will give feedback after they see it."* → User reviews are the LAST gate, not the only gate. Apply the checklist first.
