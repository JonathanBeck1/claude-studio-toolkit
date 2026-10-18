---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

PASS if no requestAnimationFrame loop the scene starts can keep running after exitTransition() or dispose(). The loop may be removed, cancelled with cancelAnimationFrame using the id of the most recently scheduled frame, or made to stop re-scheduling itself once the scene is torn down.

FAIL if a loop the scene starts can keep re-scheduling itself after teardown. This includes calling cancelAnimationFrame on an id stored only for the first frame while the callback re-schedules itself without updating that id.
