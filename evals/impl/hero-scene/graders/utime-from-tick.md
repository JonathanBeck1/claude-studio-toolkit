---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

\n([ \t]*)(?:(?:public|private|protected|override)\s+)*tick(?:Uniforms)?\([^)]*\)\s*(?::\s*\w+\s*)?\{(?:(?!\n\1\S)[\s\S])*?(?:uTime(?:['"]\])?\.value\s*\+?=|\.tickUniforms\()
