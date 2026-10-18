---
type: regex
target:
  source: file
  path: src/scene/boot.ts
---

^(?![\s\S]*(new\s+(THREE\.)?WebGLRenderer|new\s+SceneManager|astro:after-swap|beforeunload|requestAnimationFrame))[\s\S]*initSceneRouter\(
