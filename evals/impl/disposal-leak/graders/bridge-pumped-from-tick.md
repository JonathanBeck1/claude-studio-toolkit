---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

ether drives every scene from one render loop: SceneManager calls scene.tick(time, deltaTime) every frame, with time in seconds. ScrollBridge.raf(seconds) converts to the milliseconds Lenis expects. ScrollBridge.lenis is the raw Lenis instance, and its raf() takes milliseconds.

PASS if the scene no longer runs its own requestAnimationFrame loop and tick() advances the bridge once per frame as this.scroll?.raf(time).

FAIL if any requestAnimationFrame loop remains in the scene (even one cancelled on teardown), if the bridge is advanced from more than one place, if the time is mis-scaled (this.scroll.raf(time * 1000)), or if Lenis is pumped directly with lenis.raf(), whatever its argument, since the bridge owns the seconds-to-milliseconds conversion.
