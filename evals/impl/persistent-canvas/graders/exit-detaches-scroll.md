---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

async\s+exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\(|^(?=[\s\S]*async\s+exitTransition\(\)[^{]*\{(?:[^{}]|\{[^{}]*\})*\bthis\.(\w+)\()[\s\S]*\b\2\(\)[^{;]*\{(?:[^{}]|\{[^{}]*\})*\.(kill|destroy)\(
