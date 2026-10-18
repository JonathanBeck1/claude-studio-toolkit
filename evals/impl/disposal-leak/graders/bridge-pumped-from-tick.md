---
type: llm
focus:
  source: file
  path: src/scene/scenes/home/HomeScene.ts
---

ether drives every scene from one render loop: SceneManager calls scene.tick(time, deltaTime) every frame, with time in seconds. ScrollBridge.raf(seconds) converts to the milliseconds Lenis expects. ScrollBridge.lenis is the raw Lenis instance, and its raf() takes milliseconds.

PASS if the scene no longer runs its own requestAnimationFrame loop and tick() advances the bridge once per frame with correctly scaled time, as this.scroll?.raf(time) or this.scroll?.lenis.raf(time * 1000).

FAIL if any requestAnimationFrame loop remains in the scene (even one cancelled on teardown), if the bridge is advanced from more than one place, or if the time is mis-scaled (this.scroll.raf(time * 1000), or lenis.raf() given seconds).
