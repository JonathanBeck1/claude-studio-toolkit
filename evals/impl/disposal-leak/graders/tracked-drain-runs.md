---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
weight: 2
---

super\.dispose\(\)|^(?![\s\S]*\bdispose\(\)\s*(?::\s*\w+\s*)?\{)[\s\S]*class\s+HomeScene
