---
name: aether-onboard
description: First-session onboarding ritual for a new collaborator on TakeTwo Studio work. Walks through environment verification, context reading, and a structured briefing. Triggers on "I'm new", "onboard me", "where do I start", "first time here", "just joined", "getting set up", "new collaborator", "new engineer", any variation of "help me get oriented", "what is this repo", or signals that the user has never worked in this repo before. Do NOT use for returning collaborators, mid-session re-orientation, or quick "where is X" lookups — this is the full first-session ritual only.
---

# aether-onboard

Deterministic first-session ritual for a new contributor. Replaces ad-hoc orientation with a structured walk-through: environment check, context reading, briefing, first-day prompt.

## When to use

Invoke EXCLUSIVELY on the first session for a new contributor. For a returning person who wants a quick refresher, point them at `/CLAUDE.md` instead and do not run the full ritual.

## The ritual

1. **Greet.** Read the Opening section of `tour.md` to the user.

2. **Verify environment.** In order:
   - Run `git rev-parse --show-toplevel` — confirm we're at the monorepo root.
   - Run `node --version` — require `>=22.12.0` (matches `clients/taketwo-media/site/package.json` engines field).
   - Check `clients/taketwo-media/site/node_modules/` exists. If missing, ask the user "Run `npm install` now?" — do NOT run it unilaterally.

3. **Anchor context.** Read these files in order:
   - `/CLAUDE.md` (auto-loaded but re-read to prime the conversation)
   - `/README.md`
   - `/brain/README.md`, `/brain/studio-standards.md`, `/brain/design-taste.md`
   - `/clients/taketwo-media/brand-assets.md`

4. **Survey recent plans.** Run `ls -t docs/superpowers/plans/ | head -2` and read the two most recent plan files in full. These ARE the current trajectory.

5. **Brief the human.** Read sections 2–7 of `tour.md` to the user, in order. Paraphrase naturally to match their apparent experience level. Do not skip sections. Do not inject personal opinions.

6. **First-day prompt.** Read section 8 of `tour.md` (the First-day prompt). Wait for the user's answer. Route them to the matching skill / subagent / file using the tour's routing guide.

## What not to do

- Do NOT pre-install dependencies, start the dev server, or modify any files during the ritual. Ask first.
- Do NOT commit during onboarding. The session is read-only.
- Do NOT shorten the ritual because the user seems experienced. The full ritual is what makes the first session deterministic.
- Do NOT inject personal opinions about the codebase or studio direction. Stick to what the files say.

## After the ritual

Point the user at `/CLAUDE.md` as their ongoing reference and at `/docs/superpowers/plans/` for the build spine. Make it clear: next time they sit down, no ritual — just work.

## Files

- `SKILL.md` — this file (the script)
- `tour.md` — the briefing language Claude reads to the human during steps 1, 5, and 6
