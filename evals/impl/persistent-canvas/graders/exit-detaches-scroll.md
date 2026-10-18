---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

async\s+exitTransition\(\)[^{]*\{[^}]*(kill|destroy)
