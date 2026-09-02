# TakeTwo Studio Onboarding Tour

Briefing content for the `aether-onboard` ritual. Claude reads these sections aloud during steps 1, 5, and 6 of the ritual. Paraphrase naturally to match the user's experience level; do not skip sections.

## 1. Opening

Welcome to TakeTwo Studio. This is your orientation session — future sessions skip this and jump straight to work.

## 2. What this repo is

Personal monorepo and command center for TakeTwo Media. The active build is `clients/taketwo-media/site/` — an Astro 6 site running a persistent three.js + GSAP + Lenis canvas. Six routes build today — home, `/work`, `/work/[slug]`, `/contact`, 404 (service pages archived; old URLs redirect home). The rest of the repo is supporting machinery: planning docs (`docs/`), studio brain (`brain/`), reference screenshots (`references/`), and Claude skills (`.claude/skills/`). Full layout in `/README.md`.

## 3. The bar

TakeTwo positions against Active Theory, Lusion, and Resn. The studio sells against work that AI assistants produce by default — so "Claude default" actively damages the brand. The bar is "would the studio owner stop and stare," not "is this technically not slop." Concrete example: the hero is the brand mark itself extruded as dimensional 3D type with iridescent material — not a particle field or a generic torus. Read `brain/studio-standards.md` and `brain/design-taste.md` for the full taste calibration.

## 4. How to work here

- Invoke the `aether-threejs` skill BEFORE writing any 3D code. It has the slop checklist and technique recipes. Mandatory, not optional.
- For non-trivial work (multi-file change, new feature, refactor), use Plan mode — plan in conversation, get owner approval, execute. (`docs/archive/` holds retired plans — history only.)
- For risky changes, use a git worktree. The `using-git-worktrees` skill handles this.
- Before reporting "done" on any premium-component or WebGL work, run the `premium-review` subagent. It chains threejs-audit + brand-check + the ship checklist.
- Brand tokens (colors, fonts) are mirrored in `clients/taketwo-media/site/src/scene/constants.ts` and `.../src/styles/global.css`. Update both when either changes.

## 5. What's currently happening

The production site is three pages — home, `/work`, `/contact` — in one centered poster grammar; six routes build today (home, `/work`, `/work/[slug]`, `/contact`, 404), with service pages archived and their old URLs redirecting home. Active work is the site itself. Current direction lives in repo `CLAUDE.md` ("Current direction") and the closing section of `brain/design-taste.md`.

## 6. Files to actually read this week

1. `clients/taketwo-media/site/README.md` — full site architecture
2. `brain/studio-standards.md` + `brain/design-taste.md` — the bar
3. `clients/taketwo-media/brand-assets.md` — brand reference (colors, fonts, voice, logo usage)

## 7. Conventions you'll bump into

- **Constants over magic numbers.** `src/scene/constants.ts` is the single source of truth for scene values. Anything hardcoded in `scene/` should be promoted up.
- **No new files unless required, no new docs unless asked.** Default to editing what exists.
- **`.claude/settings.local.json` is per-machine permissions, not shared.** Your version stays yours; don't expect to inherit Jonathan's allow-list.

## 8. First-day prompt

End the ritual by asking the user: "What's the first thing you want to build or fix?" Route their answer:

- **WebGL / 3D / animation work** → start with the `aether-threejs` skill
- **Brand styling / typography / component change** → start with the `brand-check` command
- **Bug fix** → `minimal-change-engineer` subagent
- **Codebase orientation** → `codebase-onboarding-engineer` subagent
- **"I don't know yet"** → suggest reading `clients/taketwo-media/site/README.md` and the two most recent plan files first

After routing, end the session. Next time the user sits down, no ritual — just work.
