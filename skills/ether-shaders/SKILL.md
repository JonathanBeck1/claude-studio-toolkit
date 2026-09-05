---
name: ether-shaders
description: Premium shader and postprocessing stack for TakeTwo studio work. Documents the LDR-composer bloom + dither preset, the iridescent fresnel + cheap-noise vertex displacement material, the extruded-word text pipeline, and the kit-vs-site shader boundary. Use this — not ether-threejs — whenever the task is writing or tuning GLSL, a ShaderMaterial, the iridescent fresnel material, vertex displacement, MSDF/extruded 3D text, or the bloom+dither composer (ether-threejs owns scene architecture; this owns the shader and material layer). Triggers on GLSL, fragment shader, vertex shader, custom material, ShaderMaterial, dither, bloom, postprocessing, fresnel, iridescent, displacement, surface noise, extruded text, 3D type, MSDF, premium material, raw GLSL import, sculpture material, ExtrudeGeometry, brand-as-form. Do NOT use when "bloom", "displacement", or "dither" appear outside a GLSL/WebGL material context, or when the existing kit postfx composer already covers the need — reference it, don't rebuild.
---

# ether-shaders

Technique reference for the shader + postprocessing + extruded-text stack used on TakeTwo Media. Invoke before writing any shader, postprocessing change, or text-as-form work on TakeTwo client deliverables.

## When to use

Any of:
- Writing a new `ShaderMaterial`, vertex shader, or fragment shader.
- Modifying postprocessing (bloom, dither, color grading, new effects).
- Adding or tuning extruded text — hero treatments, chapter heads, service-as-form.
- Diagnosing a banding / glow / type-ghosting / displacement-blur issue.

Invoke alongside `ether-threejs` (the general slop checklist) — this skill specializes, the other generalizes.

## Read first

1. The `ether-threejs` SKILL.md — the general "no AI-slop three.js" checklist applies first.
2. `recipes.md` in this directory — nine numbered recipes with `file:line` citations.
3. `brain/design-taste.md` — what lands vs. what doesn't (brand-as-form, premium dimensional craft).

## The kit / site boundary

- **Kit owns** (`clients/taketwo-media/kit/src/`):
  - `postfx/DitherEffect` — 8×8 Bayer.
  - `postfx/createHeroComposer` — canonical bloom + optional-dither preset (LDR composer).
  - `primitives/ShaderQuad` — fullscreen backdrop plane with auto-wired `uTime` / `uAspect`.
  - `text/extrudedWord` — opentype → SVGLoader → ExtrudeGeometry pipeline.
- **Site owns** (`clients/taketwo-media/site/src/shaders/hero/`):
  - `sculpture.{vert,frag}.glsl` — iridescent fresnel + cheap-noise displacement. Brand-specific to TakeTwo until a second client needs it.
  - `caustics.{vert,frag}.glsl` — backdrop caustics. Site-specific.

Don't promote site shaders to kit without a generalization pass (uniform-driven palettes, no hardcoded brand-token vec3s).

## Hard rules

- **GLSL is imported via `?raw`.** Pattern: `import frag from './x.frag.glsl?raw'`. `vite-plugin-glsl` is configured but unused in practice — match the actual codebase, not the config.
- **`optimizeDeps.exclude: ['ether']`** is mandatory in `site/astro.config.ts`. Without it, kit's `?raw` consumers break at build. **NEVER set `preserveSymlinks: true`** — it pins the kit at its node_modules path so kit edits don't hot-reload; `astro.config.ts:26-32` documents the bug.
- **Two composer presets exist — pick one, don't mutate one into the other.** `createHeroComposer` is LDR by design (no `HalfFloatType`; values clip at 1.0 deliberately as bloom containment). `createNightComposer` (`heroComposer.ts:88`) has an `hdr` option using `HalfFloatType` + ACES `ToneMappingEffect`.
- **Edge AA comes from the composer's `multisampling`, never the context `antialias` flag.** Post-processing renders into textures that bypass the canvas framebuffer, so context MSAA is visually dead the moment a composer runs (the quality profile sets it false and carries `msaaSamples` instead — wire via `createHeroComposer({ multisampling: quality.msaaSamples })`).
- **Dither runs on every tier.** It merges into the SAME fullscreen pass as bloom (a few ALU ops — effectively free) and kills the dark-gradient banding that reads as posterized color on mobile OLED. The old "most expensive pass after bloom" claim was measured wrong; don't resurrect it.
- **Bloom intensity `0.06` is the hero-preset ceiling.** Higher = glow-spam. Raise `luminanceThreshold` to gate harder if you need more visible bloom. The night preset ships `0.38` by design — its own ceiling, not a license to raise the hero's.
- **Custom `ShaderMaterial` only on hero elements.** No `MeshBasicMaterial` / `MeshStandardMaterial` for hero content. See `ether-threejs` and `brain/studio-standards.md`.
- **Brand tokens through uniforms.** Pull colors from `scene/constants.ts`. Update both `constants.ts` AND `styles/global.css` when a brand color changes (mirrored).
- **Wire `uTime` through scene tick.** Material uniforms updated from `tick()` or via a wrapper's `tickUniforms`. Never via setInterval.
- **Add `precision highp float;`** at the top of fragment shaders explicitly (`sculpture.frag.glsl:23` is the example).

## Slop indicators (do not ship)

- Default materials (`MeshBasicMaterial`, `MeshStandardMaterial`) on hero elements.
- Bloom `intensity > 0.1` on the hero preset, or `luminanceThreshold < 0.5` (the night preset ships 0.38 by design).
- Hardcoded `vec3(...)` colors in shaders.
- Ambient particle fields (covered by `ether-threejs` + `brain/design-taste.md`).
- ShaderMaterial without `uTime` wired through the manager's tick.
- `dat.gui` left in production builds.
- `console.log` inside shader hot paths.
- ExtrudedWord with `curveSegments < 6` on hero treatments.
- Single-color iridescent rim (must be dual-color mix by normal Y).
- Promoting `sculpture.{vert,frag}.glsl` to kit without uniformising the color palette.
- Vertex displacement multiplier above `0.14` on letter-extrusion geometry.

## Procedure for a new ShaderMaterial

1. **Confirm against the `ether-threejs` slop checklist first** — general rules apply before specifics.
2. **Decide ownership** — is the shader reusable across future clients (kit) or brand-specific (site)? Default: site, until a second consumer exists.
3. **Place files** — `site/src/shaders/<scene>/<name>.{vert,frag}.glsl`. Use `?raw` imports.
4. **Wire uniforms through `scene/constants.ts`** — brand colors, displacement amplitudes, fresnel exponents.
5. **Tick uniforms** from the scene's `tick()` (or a wrapping class's `tickUniforms`).
6. **Add `precision highp float;`** to fragment shaders.
7. **Test against the hero composer.** If your material needs HDR values, the LDR composer clips them — rework to 0..1 (preferred) or skip the composer for this scene.
8. **Run `premium-review`** per the studio bar before reporting complete.

## After the skill

- Run `premium-review` subagent on any shader work before reporting complete.
- If the shader is scroll-bound, also invoke `ether-scroll` for the bridge pattern.
- If creating a new dimensional-type treatment, cite `extrudedWord` defaults in commit message — future grep will find the lineage.

## Files

- `SKILL.md` — this file (the script).
- `recipes.md` — nine numbered technique recipes with `file:line` citations.
