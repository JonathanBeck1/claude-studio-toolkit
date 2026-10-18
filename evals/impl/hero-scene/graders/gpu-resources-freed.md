---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

Judge only whether the GPU resources this file creates are freed by the class's `dispose()`. Do not judge the architecture or whether the class should extend a base class.

Facts: ether's `BaseScene.dispose()` frees everything passed to `this.track(...)` and `this.composer`, and nothing else; it does not walk the scene graph. postprocessing's `EffectComposer.dispose()` disposes its passes, and an `EffectPass` disposes its effects, so effects added to a composer are freed with it. ether's `create*Composer` returns `{ composer, ... }`, and disposing `.composer` frees the chain. Mesh, Group, Scene, cameras, Color and Vector objects hold no GPU memory.

PASS if every BufferGeometry, Material, Texture, WebGLRenderTarget, EffectComposer and WebGLRenderer the file creates is freed: disposed directly in `dispose()`, passed to `this.track(...)`, or, on a `BaseScene` subclass, assigned to `this.composer` and freed by `BaseScene.dispose()`.

FAIL if any of those is never freed, or if a `BaseScene` subclass overrides `dispose()` without calling `super.dispose()`.
