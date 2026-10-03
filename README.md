# claude-studio-toolkit

A Claude Code plugin for premium three.js / WebGL web work: the toolkit a
small studio used to keep an AI pair from shipping "default three.js" on a
production site. Skills that load before 3D code is written, slash commands
that audit against a written bar, remind-only hooks that fire at the right
moment, and a read-only review agent that defaults to NEEDS WORK.

## What it teaches Claude

Left alone, an AI pair writes plausible three.js fast and calls it done:
stock geometry, Lambert materials with no postprocessing, a default orbit
spin, "smooth" with no measurement behind it. The toolkit replaces those
defaults with habits written where Claude reads them:

- Load the technique reference before writing 3D code, and audit against the
  written slop checklist, never from general three.js knowledge.
- Treat ether as the authority: cite it by symbol, defer to its source where a
  skill disagrees, and read live numbers from `getDiagnostics()` instead of
  inferring them from code.
- Claim nothing unmeasured. Frame rates need a production build on named, real
  hardware; rendered work needs visual evidence before it is called READY.
- Read before asserting: brand checks use the repo's brand document,
  orientation reports only files it opened, onboarding fills its tour from the
  repo's own `CLAUDE.md` and README.
- Change as little as the task needs, and ask before committing or opening a
  PR.

## ether and this toolkit

[ether](https://github.com/JonathanBeck1/ether) is the engine: it renders,
routes scenes and reports what its runtime is doing. This toolkit is the
judgment on top: the slop bar, the recipes, the audits and the review agent.
Ether provides truth; the toolkit provides judgment.

The coupling runs one way. The toolkit knows ether deeply (its module map,
composer presets, scene contract and diagnostics snapshot) and cites it by
symbol. Ether knows nothing about the toolkit: its snapshot is the same JSON
for a developer in devtools, a CI job or a Playwright test. There is no shared
code. The toolkit reads ether's documented contract, so a project installs
nothing extra.

**Compatibility.** Toolkit 0.2 supports ether 1.2+. The `/threejs-audit`
runtime layer reads `SceneManager.getDiagnostics()`, which is listed under
Unreleased in ether's CHANGELOG until 1.2 is tagged; the audit detects it by
the method's presence, not by version. Against an ether build without it the
source layer runs unchanged and the runtime layer reports `not collected`.

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
| `/ship` | premium-review → triage → commit → push → offer a PR; steps below. Commit bodies carry no attribution trailers. |
| `/audit` | Detects what's in the diff (scene, styling, logic, docs) and runs the matching audits, on the same scope rule `premium-review` defines. Report only. |
| `/threejs-audit` | Reviews three.js code in three layers: source, runtime and visual; see [Auditing an ether project](#auditing-an-ether-project). Report only. |
| `/brand-check` | Audits a page against the brand reference your `CLAUDE.md` names — colors, type, logo, voice. Refuses to audit from remembered colors. |
| `/handoff` | Writes a structured session-handoff file so a cold session resumes without the transcript. |
| `/new-plan` | Scaffolds a phase plan for work that spans sessions — the exception, not the routine. Doesn't pre-fill decisions, and writes into the plans directory your repo already uses. |
| `/onboard` | Runs the `studio-onboard` ritual. |

`/ship`, in order:

1. Snapshot `git status` and the diff; a clean tree stops with "Nothing to ship."
2. Run `premium-review` on the diff, passing any evidence from the session verbatim (Evidence blocks, snapshot JSON, CI logs, your visual confirmation).
3. Triage: Critical aborts; Should fix and NEEDS VISUAL VERIFICATION continue only on your explicit yes.
4. Draft a conventional commit, show it with the diff summary, and commit only after you confirm. It stages named paths, lets hooks run, and passes `--no-verify` only if you explicitly ask.
5. Push (setting upstream if needed; never to the default branch without instruction), then offer a PR via `gh pr create` and open it only on confirmation.

### Agents (`agents/`)

| Agent | Role |
|---|---|
| `premium-review` | End-of-build auditor. Routes changed files to the right checklists, applies a ship-readiness pass, and returns a punch list with file:line refs. Default verdict is NEEDS WORK; a clean static audit on rendered work is NEEDS VISUAL VERIFICATION, never READY without the visual (and, for ether 1.2+ scenes, runtime) evidence it needs. It cites runtime numbers only from evidence handed to it (a `/threejs-audit` Evidence block, CI output, a snapshot) and says plainly when that evidence is missing. Read-only. |
| `repo-orientation` | Maps an unfamiliar codebase: the real entry point, one traced path end to end, long-lived state, and the seams. States only what it read in files it opened, and reports what it skipped. Read-only. |
| `minimal-diff` | Writes the fewest lines that solve the stated problem. Declares a line budget up front, tests every line against the request, and reports what it noticed but deliberately left alone. |

The shape of a `premium-review` result (illustrative):

```
# Premium Review

Verdict: NEEDS VISUAL VERIFICATION
Branch: feat/hero-rim  •  Files audited: 3

## Should fix (before it ships)
- src/scene/HeroScene.ts:212 — bloom intensity raised to 0.14; the hero preset's ceiling is 0.06
  Why: above ~0.1 the whole bright area halos. Raise luminanceThreshold to gate harder instead.

## Passed
- threejs-audit: HeroSculpture.ts — custom ShaderMaterial, DPR cap present, composer MSAA wired
- brand-check: colors resolve to tokens, display face matches the brand reference
- ship-readiness: no stray logs, no secrets, diff scoped to the task

## Evidence
- runtime: not provided
- visual: not provided

## Before READY
- View / at 1440×900 and 390×844: confirm the rim reads as an edge, not a second glyph
- Capture `getDiagnostics()` on / once settled; confirm `failures` 0 and textures flat across three in-page / → /work → / hops
```

### Hooks (`hooks/hooks.json`)

Remind-only — they print, never block.

| Hook | Event | Fires when |
|---|---|---|
| `threejs-reminder.sh` | PostToolUse (Edit/Write) | A scene file is touched → invoke `ether-threejs`, run `premium-review` before reporting complete |
| `kit-drift-reminder.sh` | PostToolUse (Edit/Write) | Engine source is touched → sync the engine README and the matching skill in the same PR |
| `premium-review-reminder.sh` | PreToolUse (Bash) | The command is a `git commit` and staged files include deliverable paths → confirm `premium-review` ran |
| `plan-mode-nudge.sh` | PostToolUse (Edit/Write) | Fourth edit of a session → one-shot nudge toward Plan mode and a worktree |
| `random-tip.sh` (in `scripts/`) | SessionStart | One rotating Claude Code habit per session |

Path patterns are environment-overridable: `STUDIO_SCENE_GLOB`
(default `*/src/scene/*`), `STUDIO_ENGINE_GLOB` (default `*/ether/src/*`),
`STUDIO_DELIVERABLE_RE` (default `(^|/)src/(scene|components|styles)/`).

## Auditing an ether project

`/threejs-audit` reports three layers, each either run or
`not collected — <reason>`:

- **source**, always: the target files against the `ether-threejs` slop
  checklist, performance budgets and shader conventions.
- **runtime**, when ether has `getDiagnostics()` and there is a running
  build (preferably a production preview for any number cited): Claude
  drives a browser, finds the
  `SceneManager` on the canvas, polls `getDiagnostics()` until the expected
  route settles, and keeps the raw JSON with its provenance (commit plus a
  dirty-tree fingerprint, URL, build, browser, GPU string, viewport). Leak
  checks hop routes in-page and compare geometry, texture and program counts
  against the first visit.
- **visual**: page screenshots of the settled scene at the viewports the
  project's `CLAUDE.md` names.

The collection recipe, evidence rules and snapshot reading table live in
`skills/ether-threejs/performance.md`. `premium-review` runs no browser, and
treats evidence whose commit or fingerprint no longer matches the tree as not
provided.

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

Run them:

```bash
scripts/run_evals.py --out evals/RESULTS.md
```

Each query starts a fresh headless session with the plugin loaded, isolated
from user-level skills (`--setting-sources project`), working inside a copy
of `evals/fixture/` — a small Astro + three.js project, so "walk me through
this repo" has a repo to walk through. The first `Skill` call within two
turns is the verdict. Stdlib Python; needs the `claude` CLI on `PATH`.

Measured 2026-09-05 with `sonnet` ([full report](./evals/RESULTS.md)):

| Skill | should fire | fired | should not | fired anyway |
|---|---|---|---|---|
| `ether-threejs` | 8 | 6 | 12 | 0 |
| `ether-shaders` | 10 | 10 | 10 | 0 |
| `ether-scroll` | 10 | 9 | 10 | 0 |
| `studio-onboard` | 10 | 10 | 10 | 0 |

Zero false positives across 42 should-not queries; the three misses fired
nothing rather than the wrong skill. Results move a little between runs — a
single flip is noise, a pattern is a description problem. Run with
`--no-isolate` on a machine with a broad personal skill library and a few
queries go to adjacent third-party skills instead; that is real behaviour on
that machine, not a description fault, and the report counts it separately.
The descriptions were hand-tuned with explicit negative scope; the suites
exist so that any later edit is checked rather than trusted on read.

## Provenance

Extracted from the `.claude/` directory of a private studio monorepo, where
it was built in phases between April and September 2026 (skill → hooks →
technique skills → commands → hardening → evals) and used daily on the
production site that [ether](https://github.com/JonathanBeck1/ether) powers.
The commit history is the real one, filtered to this directory; the private
studio's paths and brand values were generalized on top of it.

## License

MIT — see [LICENSE](./LICENSE).
