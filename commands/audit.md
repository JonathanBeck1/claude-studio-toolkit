---
description: Broad audit pass — chains threejs-audit, brand-check, and code review based on what's in the diff or path.
argument-hint: [optional path — defaults to current diff vs origin/master]
---

Run a comprehensive audit. Target: $ARGUMENTS (default to the current diff vs `origin/master` — staged + unstaged + untracked files in the change set).

**Step 1 — Detect file types in scope.**

Categorize the target files:
- **WebGL / 3D / shader** — `.ts`/`.js` under `src/scene/`, any `.glsl`/`.vert`/`.frag`. Triggers `threejs-audit`.
- **Styling / components / typography** — `.astro` files, `.tsx`/`.jsx` components, `.css` files, anything under `src/components/` or `src/styles/`. Triggers `brand-check`.
- **TypeScript logic (non-3D)** — `.ts`/`.js` outside `src/scene/`. Triggers general code review.
- **Docs / skills** — `.md` under `docs/`, `.claude/skills/`. No automated audit — sanity-check the writing matches the studio voice.

**Step 2 — Run the right audits.**

For each category in scope:
- Scene/shader → run `/threejs-audit $ARGUMENTS` (or invoke the underlying skill manually).
- Component/styling → run `/brand-check $ARGUMENTS`.
- TypeScript logic → invoke the `code-review` skill or do a careful read-pass yourself; surface correctness bugs and slop indicators specific to this project (defensive code for impossible cases, premature abstractions, three similar lines becoming a function, missing verification of feature completion).
- Markdown → spot-check tone against the repo's standards (CLAUDE.md). Flag emoji usage, AI-listicle phrasing, multi-paragraph docstrings.

**Step 3 — Consolidate.**

Produce a single punch list in this format:

```
## Audit: <target description>

### Files reviewed
- <path> — <category>

### [CRITICAL] (must fix before ship)
- <finding> · <file:line> · <quick fix>

### [WARN] Should fix
- ...

### [NOTE] Observations / opportunities
- ...

### Passed
- <category>: no issues

### Recommended next step
- <e.g. "run /ship", "fix critical findings first">
```

Do not modify any files. Report only. If no files are in scope, abort with "Nothing to audit — working tree is clean and no path was provided."
