#!/usr/bin/env python3
"""Trigger evals for the plugin's skills.

For every skills/<name>/evals/triggers.json, each query is sent to a fresh
headless Claude Code session with this plugin loaded, working inside a copy of
the small fixture project in evals/fixture/ (so "walk me through this repo"
has a repo to walk through). The first `Skill` tool call within the turn
budget is the verdict: which skill, if any, the description made Claude reach
for.

Scored per skill:
  recall   — should-trigger queries that fired this skill
  FP       — should-not queries that fired it anyway
  absorbed — should-trigger queries taken by a skill that is NOT part of this
             plugin. Only possible with --no-isolate (the default isolates the
             session from user-level skills); it is real behaviour on that
             machine, but not a fault in this plugin's description.

Results vary a little run to run against a real model; treat a single flip as
noise and a pattern as a description problem.

Usage:
  scripts/run_evals.py [--model sonnet] [--jobs 4] [--max-turns 2] [--no-fixture]
                       [--no-isolate] [--extra-args "..."] [--out evals/RESULTS.md] [skill ...]

Requires the `claude` CLI on PATH. Stdlib only.
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import json
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PREFIX = json.loads((ROOT / '.claude-plugin/plugin.json').read_text())['name'] + ':'
FIXTURE = ROOT / 'evals/fixture'
SKILL_RE = re.compile(r'"name":"Skill".{0,300}?"skill":"([^"]+)"', re.S)


def fired_skill(query: str, model: str, cwd: str, timeout: int, max_turns: int, extra: list[str]) -> str | None:
    """Run one query; return the first skill that fired ('' for none, None on error/timeout).
    Plugin skills come back without the prefix; foreign skills keep their name."""
    cmd = ['claude', '--plugin-dir', str(ROOT), '--model', model, '--max-turns', str(max_turns),
           '--output-format', 'stream-json', '--verbose', *extra, '-p', query]
    try:
        out = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired:
        return None
    m = SKILL_RE.search(out)
    if not m:
        return ''
    name = m.group(1)
    return name[len(PREFIX):] if name.startswith(PREFIX) else name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('skills', nargs='*', help='skill names to run (default: all with evals)')
    ap.add_argument('--model', default='sonnet')
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--timeout', type=int, default=240, help='seconds per query')
    ap.add_argument('--max-turns', type=int, default=2, help='assistant turns allowed before reading the verdict')
    ap.add_argument('--no-fixture', action='store_true', help='run in an empty directory instead of a copy of evals/fixture')
    ap.add_argument('--no-isolate', action='store_true',
                    help='also load user-level settings and skills (default isolates via --setting-sources project so other installed skills cannot absorb a query)')
    ap.add_argument('--extra-args', default='', help='extra arguments passed to `claude` verbatim')
    ap.add_argument('--out', help='also write a markdown report here (relative to repo root)')
    args = ap.parse_args()
    extra = shlex.split(args.extra_args)
    if not args.no_isolate:
        extra = ['--setting-sources', 'project', *extra]

    suites = {p.parent.parent.name: p for p in sorted((ROOT / 'skills').glob('*/evals/triggers.json'))}
    if args.skills:
        suites = {k: v for k, v in suites.items() if k in args.skills}
    if not suites:
        print('no eval suites found', file=sys.stderr)
        return 2
    plugin_skills = {p.name for p in (ROOT / 'skills').iterdir() if (p / 'SKILL.md').exists()}

    cases = [(skill, c['query'], bool(c['should_trigger']))
             for skill, path in suites.items() for c in json.loads(path.read_text())]
    use_fixture = FIXTURE.is_dir() and not args.no_fixture
    print(f'{len(cases)} queries across {len(suites)} skills, model={args.model}, turns={args.max_turns}, '
          f'fixture={"yes" if use_fixture else "no"}, jobs={args.jobs}', flush=True)

    with tempfile.TemporaryDirectory() as scratch:
        cwd = scratch
        if use_fixture:
            cwd = str(Path(scratch) / 'studio-site')
            shutil.copytree(FIXTURE, cwd)
        with cf.ThreadPoolExecutor(args.jobs) as pool:
            futures = {pool.submit(fired_skill, q, args.model, cwd, args.timeout, args.max_turns, extra): (s, q, exp)
                       for s, q, exp in cases}
            results = []
            for i, fut in enumerate(cf.as_completed(futures), 1):
                s, q, exp = futures[fut]
                results.append((s, q, exp, fut.result()))
                print(f'  [{i}/{len(cases)}]', end='\r', flush=True)
    print()

    env = (f'Model `{args.model}`, {len(cases)} queries, {dt.date.today().isoformat()}. Verdict = first `Skill` call '
           f'within {args.max_turns} turn(s) of a headless session with the plugin loaded, '
           f'{"cwd = a copy of `evals/fixture/`" if use_fixture else "empty cwd"}, '
           f'{"isolated from user-level settings and skills" if not args.no_isolate else "with the machine`s user-level skills loaded"}'
           + (f', extra args `{args.extra_args}`' if args.extra_args else '') + '.')
    lines = ['# Trigger eval results', '', env, '',
             '| Skill | should fire | fired (recall) | absorbed by other skill | should not | fired anyway (FP) |',
             '|---|---|---|---|---|---|']
    misses = []
    for skill in suites:
        rows = [r for r in results if r[0] == skill]
        pos = [r for r in rows if r[2]]
        neg = [r for r in rows if not r[2]]
        tp = sum(1 for r in pos if r[3] == skill)
        absorbed = sum(1 for r in pos if r[3] and r[3] not in plugin_skills)
        fp = sum(1 for r in neg if r[3] == skill)
        err = sum(1 for r in rows if r[3] is None)
        lines.append(f'| `{skill}` | {len(pos)} | {tp} ({tp / len(pos):.0%}) | {absorbed} | {len(neg)} | {fp}'
                     + (f' ({err} errors)' if err else '') + ' |')
        for s, q, exp, got in rows:
            if got is None:
                misses.append((s, q, exp, 'ERROR/timeout'))
            elif exp and got != skill:
                misses.append((s, q, exp, (got + (' (other skill)' if got not in plugin_skills else '')) if got else '(nothing fired)'))
            elif not exp and got == skill:
                misses.append((s, q, exp, got))
    if misses:
        lines += ['', '## Misses', '', '| Skill under test | Expected | Got | Query |', '|---|---|---|---|']
        for s, q, exp, got in misses:
            lines.append(f'| `{s}` | {"fire" if exp else "stay quiet"} | `{got}` | {q} |')
    report = '\n'.join(lines) + '\n'
    print(report)
    if args.out:
        (ROOT / args.out).parent.mkdir(parents=True, exist_ok=True)
        (ROOT / args.out).write_text(report)
        print(f'wrote {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
