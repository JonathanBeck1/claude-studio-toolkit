---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

track\([^;]*(TextureLoader|loadAsync|this\.noise)|this\.noise\??\.dispose\(\)
