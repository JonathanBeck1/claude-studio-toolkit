---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit]
---

The canvas in src/layouts/Layout.astro isn't wired to any scene yet. Hook it up so / shows HomeScene and the 3D background stays alive when I navigate between / and /work instead of restarting on every page. /work has no scene of its own yet. Put the boot code in src/scene/boot.ts. Nothing is installed in this checkout, so write the code without running it, then tell me what you changed.
