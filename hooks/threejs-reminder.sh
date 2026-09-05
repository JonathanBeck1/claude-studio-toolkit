#!/usr/bin/env bash
# PostToolUse hook for Edit|Write|MultiEdit.
# When a file under clients/taketwo-media/site/src/scene/ is touched, remind
# Claude to invoke the ether-threejs slop checklist and run premium-review
# before reporting complete.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("tool_input", {}).get("file_path", ""))
' 2>/dev/null || true)

case "$file_path" in
  */clients/taketwo-media/site/src/scene/*)
    cat <<'EOF'
[hook:threejs-reminder] Scene file touched. Before reporting complete:
  1. Invoke the `ether-threejs` skill — confirm against the slop checklist.
  2. Run the `premium-review` subagent.
See /CLAUDE.md for the studio bar.
EOF
    ;;
esac

exit 0
