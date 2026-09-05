#!/usr/bin/env bash
# PostToolUse hook for Edit|Write|MultiEdit.
# Increments a per-session edit counter. On the 4th edit, prints a one-shot
# nudge toward Plan mode and worktrees. Does not re-fire after the trigger.
set -euo pipefail

session_id="${CLAUDE_SESSION_ID:-fallback-$PPID}"
state_dir="${TMPDIR:-/tmp}/claude-studio-toolkit"
mkdir -p "$state_dir"
state_file="$state_dir/edits-${session_id}.count"

count=$(cat "$state_file" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$state_file"

if [ "$count" = "4" ]; then
  cat <<'EOF'
[hook:plan-mode-nudge] You've edited 4 files this session. If this is a
multi-file change, consider:
  - Plan mode — write a plan in docs/plans/, get approval, execute.
  - A git worktree for risky work, so the main checkout stays clean.
This nudge fires once per session.
EOF
fi

exit 0
