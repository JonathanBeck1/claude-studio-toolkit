# Trigger eval results

Model `sonnet`, 89 queries, 2026-10-18. Verdict = first `Skill` call within 2 turn(s) of a headless session with the plugin loaded, cwd = a copy of `evals/fixture/`, isolated from user-level settings and skills.

| Skill | should fire | fired (recall) | absorbed by other skill | should not | fired anyway (FP) |
|---|---|---|---|---|---|
| `ether-scroll` | 10 | 10 (100%) | 0 | 10 | 0 |
| `ether-shaders` | 10 | 10 (100%) | 0 | 10 | 0 |
| `ether-threejs` | 14 | 14 (100%) | 0 | 15 | 0 |
| `studio-onboard` | 10 | 10 (100%) | 0 | 10 | 0 |
