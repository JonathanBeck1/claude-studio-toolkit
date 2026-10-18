---
type: regex
target:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

CAMERA_Z_START[\s\S]*CAMERA_Z_END|CAMERA_Z_END[\s\S]*CAMERA_Z_START
