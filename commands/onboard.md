---
description: Run the first-session onboarding ritual for a new collaborator.
argument-hint: [no args — fires the full ritual]
---

This ritual is a template. Every step reads the project's own files rather than any particular project's layout — adapt the steps to what this repo actually has, and drop the ones it has no file for.

Invoke the `studio-onboard` skill (`claude-studio-toolkit:studio-onboard` when installed as a plugin). Run the full ritual end-to-end:

1. Greet (read `tour.md` Opening).
2. Verify environment (`git rev-parse --show-toplevel`, `node --version` against the repo's `engines` field, `node_modules/` present where the app lives).
3. Anchor context (read `/CLAUDE.md`, `/README.md`, and the standards / brand docs they point at).
4. Read whichever section of `/CLAUDE.md` states the current direction, if it has one — that is the live trajectory; archived plans are history only.
5. Brief the human (read `tour.md` sections 2–7).
6. First-day prompt — ask "what's the first thing you want to build or fix?" and route per the tour's routing guide.

Do not shorten the ritual because the user seems experienced. Do not modify any files during the ritual. Do not commit during onboarding.
