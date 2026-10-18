---
type: regex
target:
  source: file
  path: src/scene/boot.ts
---

^(?![\s\S]*(new\s+(THREE\.)?WebGLRenderer\b|new\s+SceneManager\b|addEventListener\(\s*['"](astro:after-swap|beforeunload)['"]|requestAnimationFrame\())[\s\S]*initSceneRouter\(
