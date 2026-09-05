---
name: ether-shaders
description: Premium shader and postprocessing stack for studio-grade WebGL on the ether engine. Documents the LDR-composer bloom + dither preset, the iridescent fresnel + cheap-noise vertex displacement material pattern, the extruded-word text pipeline, and the engine-vs-site shader boundary. Use this — not ether-threejs — whenever the task is writing or tuning GLSL, a ShaderMaterial, an iridescent fresnel material, vertex displacement, MSDF/extruded 3D text, or the bloom+dither composer (ether-threejs owns scene architecture; this owns the shader and material layer). Triggers on GLSL, fragment shader, vertex shader, custom material, ShaderMaterial, dither, bloom, postprocessing, fresnel, iridescent, displacement, surface noise, extruded text, 3D type, MSDF, premium material, raw GLSL import, sculpture material, ExtrudeGeometry, brand-as-form. Do NOT use when "bloom", "displacement", or "dither" appear outside a GLSL/WebGL material context, or when the existing engine postfx composer already covers the need — reference it, don't rebuild.
---

# ether-shaders

Technique reference for the shader + postprocessing + extruded-text stack in the [ether](https://github.com/JonathanBeck1/ether) engine. Invoke before writing any shader, postprocessing change, or text-as-form work on a site built on it.

## When to use

Any of:
- Writing a new `ShaderMaterial`, vertex shader, or fragment shader.
- Modifying postprocessing (bloom, dither, color grading, new effects).
- Adding or tuning extruded text — hero treatments, chapter heads.
- Diagnosing a banding / glow / type-ghosting / displacement-blur issue.

Invoke alongside `ether-threejs` (the general slop checklist) — this skill specializes, the other generalizes.

## Read first

1. The `ether-threejs` SKILL.md — the general "no AI-slop three.js" checklist applies first.
2. `recipes.md` in this directory — nine numbered recipes.
3. Your studio's taste doc, if the repo has one — what lands vs. what doesn't.

## The engine / site boundary

- **Engine owns** (ether `src/`):
  - `postfx/DitherEffect` — 8×8 Bayer.
  - `postfx/createHeroComposer` — restrained bloom + optional dither (LDR composer); `createNightComposer` — the HDR/ACES variant for emissive-heavy scenes.
  - `primitives/ShaderQuad` — fullscreen backdrop plane with auto-wired `uTime` / `uAspect`.
  - `text/extrudedWord` — opentype → SVGLoader → ExtrudeGeometry pipeline.
- **Your site owns** (`src/shaders/<scene>/`):
  - The hero material shaders — the brand's identity. Site-specific until a second consumer needs them.
  - Backdrop shaders (caustics, gradients, generative fields).

Don't promote site shaders to the engine without a generalization pass (uniform-driven palettes, no hardcoded brand-token vec3s).

## Hard rules

- **GLSL is imported via `?raw`.** Pattern: `import frag from './x.frag.glsl?raw'`. Even if `vite-plugin-glsl` is configured, match the codebase's actual pattern.
- **`optimizeDeps.exclude: ['ether']`** is mandatory in your `astro.config.ts` (or Vite config). Without it, the engine's `?raw` consumers break at build. **Never set `preserveSymlinks: true`** for a `file:` layout — it pins the engine at its node_modules path so edits don't hot-reload.
- **Two composer presets exist — pick one, don't mutate one into the other.** `createHeroComposer` is LDR by design (no `HalfFloatType`; values clip at 1.0 deliberately as bloom containment). `createNightComposer` has an `hdr` option using `HalfFloatType` + ACES `ToneMappingEffect`.
- **Edge AA comes from the composer's `multisampling`, never the context `antialias` flag.** Post-processing renders into textures that bypass the canvas framebuffer, so context MSAA is visually dead the moment a composer runs (the quality profile sets it false and carries `msaaSamples` instead — wire via `createHeroComposer({ multisampling: quality.msaaSamples })`).
- **Dither runs on every tier.** It merges into the SAME fullscreen pass as bloom (a few ALU ops — effectively free) and kills the dark-gradient banding that reads as posterized color on mobile OLED.
- **Bloom intensity `0.06` is the hero-preset ceiling.** Higher = glow-spam. Raise `luminanceThreshold` to gate harder if you need more visible bloom. The night preset ships `0.38` by design — its own ceiling, not a license to raise the hero's.
- **Custom `ShaderMaterial` only on hero elements.** No `MeshBasicMaterial` / `MeshStandardMaterial` for hero content. See `ether-threejs`.
- **Brand tokens through uniforms.** Pull colors from your site's constants module. If tokens are mirrored in CSS, update both when a color changes.
- **Wire `uTime` through the scene tick.** Material uniforms updated from `tick()` or via a wrapper's `tickUniforms`. Never via setInterval.
- **Add `precision highp float;`** at the top of fragment shaders explicitly — three.js prepends it by default, but stating it inline keeps the intent durable across pipeline changes.

## Slop indicators (do not ship)

- Default materials (`MeshBasicMaterial`, `MeshStandardMaterial`) on hero elements.
- Bloom `intensity > 0.1` on the hero preset, or `luminanceThreshold < 0.5` (the night preset ships 0.38 by design).
- Hardcoded `vec3(...)` colors in shaders.
- Ambient particle fields with no narrative function (see `ether-threejs`).
- ShaderMaterial without `uTime` wired through the engine's tick.
- `dat.gui` left in production builds.
- `console.log` inside shader hot paths.
- ExtrudedWord with `curveSegments < 6` on hero treatments.
- Single-color iridescent rim (must be a dual-color mix by normal direction).
- Promoting a site shader to the engine without uniformising the color palette.
- Vertex displacement strong enough to blur bevels on letter-extrusion geometry.

## Procedure for a new ShaderMaterial

1. **Confirm against the `ether-threejs` slop checklist first** — general rules apply before specifics.
2. **Decide ownership** — is the shader reusable across sites (engine) or brand-specific (site)? Default: site, until a second consumer exists.
3. **Place files** — `src/shaders/<scene>/<name>.{vert,frag}.glsl`. Use `?raw` imports.
4. **Wire uniforms through your constants module** — brand colors, displacement amplitudes, fresnel exponents.
5. **Tick uniforms** from the scene's `tick()` (or a wrapping class's `tickUniforms`).
6. **Add `precision highp float;`** to fragment shaders.
7. **Test against the hero composer.** If your material needs HDR values, the LDR composer clips them — rework to 0..1 (preferred) or use the night preset.
8. **Run `premium-review`** before reporting complete.

## After the skill

- Run the `premium-review` subagent on any shader work before reporting complete.
- If the shader is scroll-bound, also invoke `ether-scroll` for the bridge pattern.
- If creating a new dimensional-type treatment, cite the `extrudedWord` options you chose in the commit message — future grep will find the lineage.

## Files

- `SKILL.md` — this file (the script).
- `recipes.md` — nine numbered technique recipes.
- `evals/triggers.json` — should/shouldn't-trigger regression set for the description.
