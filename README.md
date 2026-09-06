# claude-studio-toolkit

A Claude Code plugin for premium three.js / WebGL web work: the toolkit a
small studio used to keep an AI pair from shipping "default three.js" on a
production site. Skills that load before 3D code is written, slash commands
that audit against a written bar, remind-only hooks that fire at the right
moment, and a read-only review agent that defaults to NEEDS WORK.

Built alongside the [ether](https://github.com/JonathanBeck1/ether) engine;
the `ether-*` skills document that engine's shader, postprocessing, and scroll
architecture.

## Install

Load it for a session:

```bash
claude --plugin-dir /path/to/claude-studio-toolkit
```

Or drop it in your skills directory so it loads automatically:

```bash
git clone https://github.com/JonathanBeck1/claude-studio-toolkit ~/.claude/skills/claude-studio-toolkit
```

Everything registers under the `claude-studio-toolkit:` prefix —
`/claude-studio-toolkit:ship`, the `claude-studio-toolkit:premium-review`
agent, the `claude-studio-toolkit:ether-threejs` skill (skills also fire on
their triggers without being named). Hooks arm on load.
`claude plugin validate .` passes.

## What's inside

### Skills (`skills/`)

| Skill | Loads when | What it holds |
|---|---|---|
| `ether-threejs` | Any three.js / WebGL scene work | The slop checklist (reject + required), an annotated reference list of premium studios with per-studio copy/skip notes, seven technique recipes (curl-noise particles, fresnel iridescence, MSDF typography, persistent-canvas routing, postprocessing chain, raymarched SDF hero, scroll camera choreography), reusable GLSL snippets, and performance budgets |
| `ether-shaders` | GLSL, `ShaderMaterial`, bloom/dither, extruded 3D type | Engine-vs-site shader boundary, the LDR bloom + dither preset and its ceilings, iridescent-rim and cheap-noise displacement patterns, the `extrudedWord` pipeline, pitfalls |
| `ether-scroll` | Lenis, ScrollTrigger, scroll-driven 3D | The one-rAF-loop rule, conditional smooth scroll by GPU tier, progress-scrub vs class-toggle vs body-flag patterns, scroll-restoration, paired teardown |
| `studio-onboard` | "I'm new", "where do I start" | A deterministic first-session ritual whose tour is a template filled from the repo's own CLAUDE.md and README |

Every skill ships `evals/triggers.json`: ~20 realistic prompts labeled
should/shouldn't trigger, weighted toward near-misses. They are regression
suites for the skill descriptions — see [Evals](#evals).

### Commands (`commands/`)

| Command | Does |
|---|---|
| `/ship` | premium-review → triage → conventional commit → push → offer a PR. Never commits before you confirm the message. |
| `/audit` | Detects what's in the diff (scene, styling, logic, docs) and runs the matching audits. Report only. |
| `/threejs-audit` | Reviews three.js code against the `ether-threejs` slop checklist. Report only. |
| `/brand-check` | Audits a page against your repo's brand document — colors, type, logo, voice. Refuses to audit from remembered colors. |
| `/handoff` | Writes a structured session-handoff file so a cold session resumes without the transcript. |
| `/new-plan` | Scaffolds a plan file with the canonical structure. Doesn't pre-fill decisions. |
| `/onboard` | Runs the `studio-onboard` ritual. |

### Agents (`agents/`)

| Agent | Role |
|---|---|
| `premium-review` | End-of-build auditor. Routes changed files to the right checklists, applies a ship-readiness pass, and returns a punch list with file:line refs. Default verdict is NEEDS WORK; a clean static audit on rendered work is NEEDS VISUAL VERIFICATION, never READY. Read-only. |
| `repo-orientation` | Maps an unfamiliar codebase: the real entry point, one traced path end to end, long-lived state, and the seams. States only what it read in files it opened, and reports what it skipped. Read-only. |
| `minimal-diff` | Writes the fewest lines that solve the stated problem. Declares a line budget up front, tests every line against the request, and reports what it noticed but deliberately left alone. |

The shape of a `premium-review` result (illustrative):

```
# Premium Review

Verdict: NEEDS VISUAL VERIFICATION
Branch: feat/hero-rim  •  Files audited: 3

## Should fix (before client-facing)
- src/scene/HeroScene.ts:212 — bloom intensity raised to 0.14; the hero preset's ceiling is 0.06
  Why: above ~0.1 the whole bright area halos. Raise luminanceThreshold to gate harder instead.

## Passed
- threejs-audit: HeroSculpture.ts — custom ShaderMaterial, DPR cap present, composer MSAA wired
- brand-check: colors resolve to tokens, display face matches the brand doc
- ship-readiness: no stray logs, no secrets, diff scoped to the task

## Before READY
- View / at 1440×900 and 390×844: confirm the rim reads as an edge, not a second glyph
```

### Hooks (`hooks/hooks.json`)

Remind-only — they print, never block.

| Hook | Event | Fires when |
|---|---|---|
| `threejs-reminder.sh` | PostToolUse (Edit/Write) | A scene file is touched → invoke `ether-threejs`, run `premium-review` before reporting complete |
| `kit-drift-reminder.sh` | PostToolUse (Edit/Write) | Engine source is touched → sync the engine README and the matching skill in the same PR |
| `premium-review-reminder.sh` | PreToolUse (`git commit`) | Staged files include client-deliverable paths → confirm `premium-review` ran |
| `plan-mode-nudge.sh` | PostToolUse (Edit/Write) | Fourth edit of a session → one-shot nudge toward Plan mode and a worktree |
| `random-tip.sh` | SessionStart | One rotating Claude Code habit per session |

Path patterns are environment-overridable: `STUDIO_SCENE_GLOB`
(default `*/src/scene/*`), `STUDIO_ENGINE_GLOB` (default `*/ether/src/*`),
`STUDIO_DELIVERABLE_RE` (default `(^|/)src/(scene|components|styles)/`).

## Evals

A skill is only as good as its description — it decides whether the skill
loads at the right moment. Each skill ships `evals/triggers.json`: about
twenty realistic prompts, roughly half labeled `should_trigger: true` and
half `false`, weighted toward near-misses that share vocabulary but need a
different skill ("add a bloom glow to this photo" must not load a WebGL
shader skill).

```json
[
  {"query": "Add a postprocessing chain with bloom and grain to the three.js scene", "should_trigger": true},
  {"query": "Animate this DOM heading with a GSAP fade-up on page load",             "should_trigger": false}
]
```

The format is runner-agnostic: anything that can start a session per query
and watch whether the skill loads will score them. The descriptions were
hand-tuned with explicit negative scope; the suites exist so that any later
edit can be checked against them rather than trusted on read — a description
that reads well can still fire on the wrong half of these.

## Provenance

Extracted from the `.claude/` directory of a private studio monorepo, where
it was built in phases between April and September 2026 (skill → hooks →
technique skills → commands → hardening → evals) and used daily on the
production site that [ether](https://github.com/JonathanBeck1/ether) powers.
The commit history is the real one, filtered to this directory; the private
studio's paths and brand values were generalized on top of it.

## License

MIT — see [LICENSE](./LICENSE).
