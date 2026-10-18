---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
weight: 2
---

^(?![\s\S]*(new\s+Lenis|ScrollTrigger\.create|requestAnimationFrame|lenis\.start\(|raf\([^)]*\*\s*1000|addEventListener\(\s*['"]scroll['"]))[\s\S]*createScrollProgress\(
