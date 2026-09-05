---
description: Scaffold a new phase plan file in docs/plans/ with the canonical structure.
argument-hint: <phase-number> <slug-with-dashes> (e.g. "6 client-scaffold")
---

Create a new phase plan file. Args: $ARGUMENTS (expected format: `<phase-number> <slug-with-dashes>`).

**Step 1 — Parse args.**

Parse `$ARGUMENTS` into:
- `PHASE` — phase number (integer).
- `SLUG` — kebab-case description.

If the args don't parse, abort with: "Usage: /new-plan <phase-number> <slug-with-dashes>. Example: /new-plan 6 client-scaffold."

Determine the date prefix: today's date in `YYYY-MM-DD` format (use `date +%Y-%m-%d` in bash if uncertain).

Compose the path: `docs/plans/<DATE>-phase-<PHASE>-<SLUG>.md`.

**Step 2 — Check for collision.**

If a file at that path already exists, abort. Suggest appending a `-v2` to the slug or picking a different phase number.

**Step 3 — Write the file.**

Write the file with this canonical structure:

```markdown
# Phase <PHASE> — <Human-readable title>

> **For agentic workers:** <One-line orientation. Point at relevant existing skills/conventions to consult before writing.>

**Goal:** <One paragraph. What ships at the end of this phase.>

**Why this now:** <One paragraph. What gap closes. Why this phase before the next.>

**Approach:** <Sketch of the architectural approach. 2-4 sentences.>

Do NOT touch: <files explicitly out of scope>.

---

## File Structure

```
<tree diagram of files this phase touches>
```

---

## <Per-file or per-component outline sections>

<For each new or modified file, an outline of what goes in it.>

---

## Pre-flight

- [ ] <prerequisites before starting tasks>

## Tasks (sequential)

1. <step>
2. <step>
3. ...

## Acceptance

- <verifiable criterion>
- <verifiable criterion>

## Out of scope (deferred)

- <thing not in this phase>
- <thing not in this phase>
```

**Step 4 — Open the file.**

Report the absolute path. Suggest the user fills in the TODO sections and confirms the plan before executing.

Do not pre-fill the TODO sections with guesses. Plans are user-authored decisions; this command just scaffolds the structure.
