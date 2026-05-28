#!/usr/bin/env bash
# PreToolUse hook for Bash.
# When the command is `git commit` and staged changes include client-deliverable
# paths (src/scene, src/components, src/styles), remind that premium-review
# should have run. Non-blocking.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("tool_input", {}).get("command", ""))
' 2>/dev/null || true)

case "$cmd" in
  *"git commit"*)
    staged=$(git -C "${CLAUDE_PROJECT_DIR:-.}" diff --cached --name-only 2>/dev/null || true)
    if printf '%s\n' "$staged" | grep -qE '^clients/taketwo-media/site/src/(scene|components|styles)/'; then
      cat <<'EOF'
[hook:premium-review-reminder] Staged changes touch client deliverable paths.
Confirm `premium-review` has run since the last code change. If not, abort the
commit and run it now — `premium-review` chains threejs-audit + brand-check +
ship pre-commit checklist. This hook does not block; it relies on you to do
the right thing.
EOF
    fi
    ;;
esac

exit 0
