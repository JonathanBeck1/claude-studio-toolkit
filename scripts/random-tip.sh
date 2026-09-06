#!/usr/bin/env bash
# SessionStart hook: one rotating Claude Code habit per session. Output lands in
# the conversation context, so keep each tip to one line.

tips=(
  "Plan mode (Shift+Tab -> Plan) prevents most bad outputs on non-trivial work. Use it for anything beyond a one-liner."
  "/clear between unrelated tasks. Context drift quietly degrades quality."
  "/compact when the thread is long but still relevant. Frees tokens without losing the plot."
  "'From now on...' belongs in CLAUDE.md or memory, not the transcript."
  "Review before commits; a deeper review before merging premium work."
  "Worktrees for risky or experimental work keep the main checkout clean and allow parallel sessions."
  "Check the skill library before reasoning from scratch."
  "Three.js: invoke the ether-threejs skill first. Default three.js output is slop."
  "Wrong model wastes money and quality: the strongest model for taste and review, a cheaper one for mechanical work."
  "When you catch Claude being wrong, that is a memory signal. Save the correction."
  "Slash commands codify repeated workflows. This plugin ships /ship, /audit, /brand-check, /threejs-audit, /handoff — under the claude-studio-toolkit: prefix when installed as a plugin."
  "/agents lists installed subagents: minimal-diff for surgical changes, repo-orientation for an unfamiliar codebase, premium-review before shipping."
)

echo "TIP — ${tips[$RANDOM % ${#tips[@]}]}"
