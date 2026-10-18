---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

This scene class extends ether's `BaseScene`, whose `dispose()` frees everything passed to `this.track(...)` and the scene's composer, and nothing else; it does not walk the scene graph.

PASS if every geometry, material, texture and render target the class creates is either passed to `this.track(...)` or disposed explicitly in a `dispose()` override that also calls `super.dispose()`.

FAIL if any geometry, material, texture or render target the class creates is neither tracked nor disposed, or if a `dispose()` override skips `super.dispose()`.
