---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

track\(\s*(new\s+THREE\.IcosahedronGeometry|this\.geometry)|this\.geometry\??\.dispose\(\)
