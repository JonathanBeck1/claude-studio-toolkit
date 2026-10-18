---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

This is the home page hero scene. The project's slop checklist rejects a hero whose content uses "default geometries (`TorusKnotGeometry`, `DodecahedronGeometry`, `BoxGeometry`, `SphereGeometry` as the visible subject)".

PASS if the visible centerpiece is built from something other than those four geometries, for example a procedural geometry, an imported model, a raymarched surface or another three.js geometry. Using one of the four for something that is not the visible subject (instanced particles, a bounding or helper volume, a full-screen quad) still passes.

FAIL if the visible centerpiece mesh uses `TorusKnotGeometry`, `DodecahedronGeometry`, `BoxGeometry` or `SphereGeometry`, or if the file builds no visible subject at all.
