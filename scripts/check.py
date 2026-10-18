#!/usr/bin/env python3
"""Deterministic CI checks: manifests, trigger files, frontmatter, links (needs PyYAML)."""
import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
# Agent Skills spec limit; `claude plugin validate` does not enforce it, so it only warns.
SKILL_DESCRIPTION_LIMIT = 1024
errors = []


def rel(p):
    return p.relative_to(ROOT).as_posix()


def error(p, msg):
    msg = ' '.join(msg.split())
    errors.append(f'{rel(p)}: {msg}')
    print(f'::error file={rel(p)}::{msg}')


def load_json(p):
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        error(p, f'invalid JSON: {e}')


def check_json():
    for p in [*sorted(ROOT.glob('.claude-plugin/*.json')), ROOT / 'hooks/hooks.json']:
        load_json(p)
    for p in sorted(ROOT.glob('skills/*/evals/triggers.json')):
        data = load_json(p)
        if data is None:
            continue
        if not isinstance(data, list) or not data:
            error(p, 'expected a non-empty array')
            continue
        for i, case in enumerate(data):
            if not (isinstance(case, dict) and set(case) == {'query', 'should_trigger'}
                    and isinstance(case['query'], str) and case['query'].strip()
                    and isinstance(case['should_trigger'], bool)):
                error(p, f'entry {i} must be {{"query": non-empty string, "should_trigger": bool}}')


def check_frontmatter():
    groups = [('skills/*/SKILL.md', ('name', 'description')),
              ('agents/*.md', ('name', 'description')),
              ('commands/*.md', ('description',))]
    for pattern, required in groups:
        for p in sorted(ROOT.glob(pattern)):
            m = re.match(r'---\n(.*?)\n---\n', p.read_text(), re.S)
            if not m:
                error(p, 'no YAML frontmatter block')
                continue
            try:
                fm = yaml.safe_load(m.group(1))
            except yaml.YAMLError as e:
                error(p, f'frontmatter does not parse: {e}')
                continue
            if not isinstance(fm, dict):
                error(p, 'frontmatter is not a mapping')
                continue
            for key in required:
                if not isinstance(fm.get(key), str) or not fm[key].strip():
                    error(p, f'missing required field "{key}"')
            desc = fm.get('description')
            if pattern.startswith('skills') and isinstance(desc, str) and len(desc) > SKILL_DESCRIPTION_LIMIT:
                print(f'::warning file={rel(p)}::description is {len(desc)} chars, over the '
                      f'{SKILL_DESCRIPTION_LIMIT}-char Agent Skills limit')


FENCE_RE = re.compile(r'^[ \t]*(`{3,}|~{3,}).*?^[ \t]*\1', re.S | re.M)
LINK_RE = re.compile(r'\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)|^\[(?!\^)[^\]]+\]:\s*(\S+)', re.M)


def strip_code(text):
    return re.sub(r'(`+)[^`\n]*?\1', '', FENCE_RE.sub('', text))


def anchors(p):
    slugs = set()
    for line in FENCE_RE.sub('', p.read_text()).splitlines():
        m = re.match(r'#{1,6}\s+(.*?)\s*#*\s*$', line)
        if m:
            heading = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', m.group(1))
            slug = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
            n = 0
            while (slug if n == 0 else f'{slug}-{n}') in slugs:
                n += 1
            slugs.add(slug if n == 0 else f'{slug}-{n}')
    return slugs


def check_links():
    for p in sorted(ROOT.rglob('*.md')):
        if '.git' in p.relative_to(ROOT).parts:
            continue
        for m in LINK_RE.finditer(strip_code(p.read_text())):
            target = m.group(1) or m.group(2)
            if re.match(r'[a-z][a-z0-9+.-]*:', target, re.I):
                continue
            path, _, frag = target.partition('#')
            dest = (p.parent / path).resolve() if path else p
            if not dest.exists():
                error(p, f'broken link: {target}')
            elif frag and dest.suffix == '.md' and frag not in anchors(dest):
                error(p, f'broken anchor: {target}')


check_json()
check_frontmatter()
check_links()
if errors:
    sys.exit(f'{len(errors)} check(s) failed')
print('All checks passed')
