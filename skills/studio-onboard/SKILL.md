---
name: studio-onboard
description: First-session onboarding ritual for a new collaborator on a studio repo that uses this toolkit. Walks through environment verification, context reading, and a structured briefing filled from the repo's own CLAUDE.md and README. Triggers on "I'm new", "onboard me", "where do I start", "first time here", "just joined", "getting set up", "new collaborator", "new engineer", any variation of "help me get oriented", "what is this repo", or signals that the user has never worked in this repo before. Do NOT use for returning collaborators, mid-session re-orientation, or quick "where is X" lookups — this is the full first-session ritual only.
---

# studio-onboard

Deterministic first-session ritual for a new contributor. Replaces ad-hoc orientation with a structured walk-through: environment check, context reading, briefing, first-day prompt. Everything Claude says comes from the repo's own documents — the tour is a template, not a script about any particular studio.

## When to use

Invoke EXCLUSIVELY on the first session for a new contributor. For a returning person who wants a quick refresher, point them at `/CLAUDE.md` instead and do not run the full ritual.

## The ritual

1. **Greet.** Read the Opening section of `tour.md` to the user, with the studio name filled from `CLAUDE.md` / `README.md`.

2. **Verify environment.** In order:
   - Run `git rev-parse --show-toplevel` — confirm we're at the repo root.
   - Run `node --version` — compare against the `engines` field of the app's `package.json`.
   - Check that `node_modules/` exists where the app lives.
   - Most repo checklists make install + a dev-server smoke test the first thing a new collaborator does. If this one does, OFFER it: "Run `npm install` and start the dev server to confirm the app boots?" Run it only on an explicit yes, report the URL it serves, and stop the server once the check passes. Never run either unilaterally, and never substitute your own command for the one the checklist names.

3. **Anchor context.** Read these in order:
   - `/CLAUDE.md` (auto-loaded but re-read to prime the conversation)
   - `/README.md`
   - The standards, taste, and brand documents those two files point at.

4. **Survey current direction.** Read the "Current direction" section of `CLAUDE.md` if it has one — that is the live trajectory. Archived plans and retired docs are history only; never build from them.

5. **Brief the human.** Read sections 2–7 of `tour.md` to the user, in order, filling every bracketed prompt from what you just read. Paraphrase naturally to match their apparent experience level. Do not skip sections. Do not inject personal opinions.

6. **First-day prompt.** Read section 8 of `tour.md`. Wait for the user's answer. Route them to the matching skill / subagent / file using the tour's routing guide.

7. **Confirm the context actually loads.** Most repo checklists close by having the new collaborator verify that `CLAUDE.md` is being auto-loaded — typically by asking the repo's own bar question ("what's the bar?" in the studio's vocabulary) and checking the answer comes back in the repo's own terms, unprompted. Run that check: put the question to the user to ask, and if the answer does not land in the repo's language, `CLAUDE.md` is not loading. Say so plainly and tell them to fix that before trusting any later session — do not paper over it by quoting the file you read manually in step 3.

## What not to do

- Do NOT install dependencies, start the dev server, or modify any files WITHOUT asking. Install and the dev-server smoke test are an offered step (step 2) when the repo's checklist calls for them — offer, wait for a yes, then run. Everything else stays hands-off.
- Do NOT commit, push, or branch during onboarding. Apart from the offered install / dev-server check, the session changes nothing.
- Do NOT shorten the ritual because the user seems experienced. The full ritual is what makes the first session deterministic.
- Do NOT inject personal opinions about the codebase or studio direction. Stick to what the files say.
- Do NOT fill a bracketed prompt from memory or guesswork. If the repo doesn't document it, say so.

## After the ritual

Point the user at `/CLAUDE.md` (and its "Current direction" section, if any) as their ongoing reference. Make it clear: next time they sit down, no ritual — just work.

## Files

- `SKILL.md` — this file (the script)
- `tour.md` — the briefing template Claude fills and reads during steps 1, 5, and 6
- `evals/triggers.json` — should/shouldn't-trigger regression set for the description
