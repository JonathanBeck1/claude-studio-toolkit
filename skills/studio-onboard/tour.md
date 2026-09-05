# Studio Onboarding Tour

Briefing template for the `studio-onboard` ritual. Claude reads these sections aloud during steps 1, 5, and 6, filling every [bracketed prompt] from the repo's `CLAUDE.md` and `README.md` — never from memory. Paraphrase naturally to match the user's experience level; do not skip sections.

## 1. Opening

Welcome to [studio name]. This is your orientation session — future sessions skip this and jump straight to work.

## 2. What this repo is

[One paragraph from the README: what the repo holds, where the active build lives and what it runs on, and what the supporting machinery is — docs, standards, skills, engine.]

## 3. The bar

[The studio's positioning and quality bar, from CLAUDE.md and the standards doc. Name the reference studios it measures itself against, state the bar in the studio's own words, and give one concrete example from this repo of work that meets it.]

## 4. How to work here

- Invoke the `ether-threejs` skill BEFORE writing any 3D code. It has the slop checklist and technique recipes. Mandatory, not optional.
- For non-trivial work (multi-file change, new feature, refactor), use Plan mode — plan in conversation, get owner approval, execute.
- For risky changes, work in a git worktree so the main checkout stays clean.
- Before reporting "done" on any premium-component or WebGL work, run the `premium-review` subagent. It chains threejs-audit + brand-check + the ship checklist.
- [Where the brand tokens live and whether they are mirrored anywhere — from CLAUDE.md.]

## 5. What's currently happening

[The "Current direction" section of CLAUDE.md in two or three sentences. If there is none, say so and point at the most recent commits instead.]

## 6. Files to actually read this week

1. [The app's README — architecture]
2. [The standards / taste documents — the bar]
3. [The brand reference — colors, fonts, voice, logo usage]

## 7. Conventions you'll bump into

- **Constants over magic numbers.** [Name the constants module.] Anything hardcoded in scene code should be promoted up.
- **No new files unless required, no new docs unless asked.** Default to editing what exists.
- **`.claude/settings.local.json` is per-machine permissions, not shared.** Your version stays yours.
- [Any further repo-specific conventions from CLAUDE.md.]

## 8. First-day prompt

End the ritual by asking the user: "What's the first thing you want to build or fix?" Route their answer:

- **WebGL / 3D / animation work** → start with the `ether-threejs` skill
- **Brand styling / typography / component change** → start with the `brand-check` command
- **Bug fix** → `minimal-diff` subagent
- **Codebase orientation** → `repo-orientation` subagent
- **"I don't know yet"** → suggest reading the app's README and the "Current direction" section first

After routing, end the session. Next time the user sits down, no ritual — just work.
