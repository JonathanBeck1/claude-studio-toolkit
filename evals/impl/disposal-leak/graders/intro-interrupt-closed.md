---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
weight: 2
---

This class is an ether scene. On a route hop, ether's SceneManager awaits the outgoing scene's exitTransition() and then calls dispose(). It does not await enterTransition(), so a hop while the intro is still playing runs exitTransition() and dispose() while enterTransition() is still waiting on its intro tween. GSAP's kill() stops a tween without firing its onComplete. The workspace is on ether 1.3, where BaseScene.dispose() kills every tween passed to `this.track(...)`.

PASS if a hop during the intro can no longer leave behind anything created after teardown. Any of these counts: the intro tween is stored and killed in exitTransition() or dispose(); the intro tween is passed to `this.track(...)` and BaseScene.dispose() runs (the class has no dispose() override, or its override calls super.dispose()); the intro's tweens are killed with gsap.killTweensOf on the tweened object during teardown; enterTransition() checks a flag that exitTransition() or dispose() sets, after the intro, and returns before setupScrollTrigger().

FAIL if the code after the intro's await (setupScrollTrigger() / createScrollProgress) can still run after exitTransition() or dispose(), leaving a trigger that nothing kills. Moving trigger creation ahead of the intro changes when triggers measure the page and is not a fix.
