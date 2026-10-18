---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
weight: 2
---

^(?=[\s\S]*(ShaderMaterial|onBeforeCompile))(?:(?=[\s\S]*onBeforeCompile)|(?![\s\S]*Mesh(Standard|Basic|Lambert|Phong)Material))[\s\S]*class\s+HomeScene
