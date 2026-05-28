---
description: Write a structured session-handoff file so a cold session (or a new collaborator) can resume without the transcript.
argument-hint: [optional slug — otherwise derived from the branch name]
---

Write a session handoff. Slug: $ARGUMENTS (if empty, derive a short kebab-case slug from the current branch name, dropping any `claude/` prefix).

**Step 1 — Gather state.** Run these in parallel and read the results:
- `git rev-parse --abbrev-ref HEAD` — current branch.
- `git status --short` — uncommitted work.
- `git log --oneline -8` — recent commits.
- `git diff --stat origin/master...HEAD` (fall back to `main` if there's no `master`) — what this branch changed vs base.

Determine today's date in `YYYY-MM-DD` (use `date +%Y-%m-%d`).

**Step 2 — Compose the path.** `.claude/handoffs/<SLUG>-<DATE>.md`. If that file already exists, append `-2` (then `-3`, …) to the slug until it's unique — never overwrite an existing handoff.

**Step 3 — Write the file** with the structure below. Fill every section from what actually happened this session; do not invent. Keep it tight — a handoff is a runway, not a transcript.

```markdown
# Handoff — <human-readable title>

**Date:** <DATE> · **Branch:** <branch>

## Resume here
<The single most important thing the next session should do first. One or two sentences.>

## Goal
<What this line of work is trying to achieve. The why.>

## Key findings
- <Decisions made, facts discovered, dead ends ruled out — with file paths / line refs where relevant.>

## Gotchas
- <Traps, surprises, environment quirks — anything that cost time and would cost it again.>

## How to test / verify
- <Exact commands or steps to confirm the work, and what "correct" looks like.>

## Repo state
- <Branch vs base, committed vs uncommitted, any PR link, anything mid-flight.>

## Open threads
- [ ] <Unfinished work, deferred decisions, follow-ups — most important first.>
```

**Step 4 — Report** the absolute path written.

Handoffs are committed — the point is to survive context loss across sessions and machines. Do not put secrets in them. Do not pad sections to look thorough; an honest short handoff beats a padded one.
