---
description: Scaffold a written phase plan for work too large to hold in one session.
argument-hint: <phase-number> <slug-with-dashes> (e.g. "6 search-rewrite")
---

Create a phase plan file. Args: $ARGUMENTS (expected format: `<phase-number> <slug-with-dashes>`).

A written plan is the exception, not the routine. Most work is better planned in the session and executed — reach for this only when the work spans multiple sessions or collaborators, or when someone has to approve the approach before code is written. If the task does not clear that bar, say so and skip the file.

**Step 1 — Parse args.**

Parse `$ARGUMENTS` into:
- `PHASE` — phase number (integer).
- `SLUG` — kebab-case description.

If the args don't parse, abort with: "Usage: /new-plan <phase-number> <slug-with-dashes>. Example: /new-plan 6 search-rewrite."

Determine the date prefix: today's date in `YYYY-MM-DD` format (use `date +%Y-%m-%d` in bash if uncertain).

Compose the path as `<PLANS_DIR>/<DATE>-phase-<PHASE>-<SLUG>.md`. Resolve `<PLANS_DIR>` from the repo, in this order: the plans directory `CLAUDE.md` names; else an existing plans directory already in the repo; else ask where plans belong. Do not invent a directory the repo does not use.

**Step 2 — Check for collision.**

If a file at that path already exists, abort. Suggest appending a `-v2` to the slug or picking a different phase number.

**Step 3 — Write the file.**

Write the file with this structure:

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

Report the absolute path. Suggest the user fills in the placeholder sections and confirms the plan before executing.

Do not pre-fill the placeholder sections with guesses. Plans are user-authored decisions; this command only scaffolds the structure.
