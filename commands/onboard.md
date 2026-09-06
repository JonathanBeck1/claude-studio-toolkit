---
description: Run the first-session onboarding ritual for a new collaborator.
argument-hint: [no args — fires the full ritual]
---

Invoke the `studio-onboard` skill (`claude-studio-toolkit:studio-onboard` when installed as a plugin). Run the full ritual end-to-end:

1. Greet (read `tour.md` Opening).
2. Verify environment (`git rev-parse --show-toplevel`, `node --version` against the repo's `engines` field, `node_modules/` present where the app lives).
3. Anchor context (read `/CLAUDE.md`, `/README.md`, and the standards / brand docs they point at).
4. Read the "Current direction" section of `/CLAUDE.md` if it has one — that is the live trajectory; archived plans are history only.
5. Brief the human (read `tour.md` sections 2–7).
6. First-day prompt — ask "what's the first thing you want to build or fix?" and route per the tour's routing guide.

Do not shorten the ritual because the user seems experienced. Do not modify any files during the ritual. Do not commit during onboarding.
