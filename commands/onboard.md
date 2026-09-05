---
description: Run the TakeTwo first-session onboarding ritual for a new collaborator.
argument-hint: [no args — fires the full ritual]
---

Invoke the `ether-onboard` skill. Run the full ritual end-to-end:

1. Greet (read `tour.md` Opening).
2. Verify environment (`git rev-parse --show-toplevel`, `node --version >=22.12.0`, `clients/taketwo-media/site/node_modules/` check).
3. Anchor context (read `/CLAUDE.md`, `/README.md`, `/brain/*`, `/clients/taketwo-media/brand-assets.md`).
4. Read the "Current direction" section of `/CLAUDE.md` and the closing section of `brain/design-taste.md` — that is the live trajectory; `docs/archive/` is history only.
5. Brief the human (read `tour.md` sections 2–7).
6. First-day prompt — ask "what's the first thing you want to build or fix?" and route per the tour's routing guide.

Do not shorten the ritual because the user seems experienced. Do not modify any files during the ritual. Do not commit during onboarding.
