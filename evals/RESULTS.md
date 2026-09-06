# Trigger eval results

Model `sonnet`, 80 queries, 2026-09-05. Verdict = first `Skill` call within 2 turn(s) of a headless session with the plugin loaded, cwd = a copy of `evals/fixture/`, isolated from user-level settings and skills.

| Skill | should fire | fired (recall) | absorbed by other skill | should not | fired anyway (FP) |
|---|---|---|---|---|---|
| `ether-scroll` | 10 | 9 (90%) | 0 | 10 | 0 |
| `ether-shaders` | 10 | 10 (100%) | 0 | 10 | 0 |
| `ether-threejs` | 8 | 6 (75%) | 0 | 12 | 0 |
| `studio-onboard` | 10 | 10 (100%) | 0 | 10 | 0 |

## Misses

| Skill under test | Expected | Got | Query |
|---|---|---|---|
| `ether-scroll` | fire | `(nothing fired)` | Add a scroll cue that fades out once the user starts scrolling |
| `ether-threejs` | fire | `(nothing fired)` | Wire up the persistent WebGL canvas so it survives route changes between pages |
| `ether-threejs` | fire | `(nothing fired)` | Add scroll-driven camera movement to the three.js hero (the 3D camera choreography side of it) |
