---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit]
---

Memory keeps climbing on the home page. Every / -> /work -> / hop leaves more geometries and textures behind, the JS heap grows too, and after a dozen hops scrolling on / gets choppy and the tab feels sluggish. It's worst when I click through to /work before the home intro has finished. Find and fix what's leaking in src/scene/scenes/home/HomeScene.ts. Nothing is installed in this checkout and you can't run it, so fix it from the source, then tell me what you changed.
