---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

\btick\([^)]*\)\s*(?::\s*\w+\s*)?\{(?:[^{}]|\{[^{}]*\})*uTime\.value\s*\+?=
