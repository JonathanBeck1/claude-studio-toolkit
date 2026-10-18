---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

^(?![\s\S]*(?:new\s+(?:\w+\.)?(?:OrbitControls|UnrealBloomPass)\b|from\s+['"][^'"]*(?:OrbitControls|UnrealBloomPass|(?:jsm|addons)/postprocessing)))[\s\S]*class\s+HomeScene
