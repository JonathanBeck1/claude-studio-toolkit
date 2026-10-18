---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

This is a scene class for a persistent-canvas site where scenes are entered, exited and disposed on every navigation.

PASS only if all of these hold:
- Any smooth-scroll bridge (ScrollBridge) is constructed in enterTransition or a helper it calls, never in the constructor or at module scope.
- Every scroll trigger the scene creates is created after construction (in enterTransition, an intro completion callback, or a helper they call), and is killed on a path reached from exitTransition, with dispose also killing it.
- The bridge, if present, is destroyed on the same exit path.
- The scroll callback only stores a value; the camera position is updated in tick.

FAIL if any of these is missing, or if the file has no scroll wiring at all.
