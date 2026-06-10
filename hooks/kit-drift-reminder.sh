#!/usr/bin/env bash
# PostToolUse hook for Edit|Write|MultiEdit.
# When a kit source file is touched, remind Claude that the toolkit
# documents the engine — skills and READMEs silently drift unless
# synced in the same PR as the API change.
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
  */clients/taketwo-media/kit/src/*)
    cat <<'EOF'
[hook:kit-drift-reminder] Kit source touched. If the public surface changed
(exports, signatures, files moved), sync the docs in the SAME PR:
  - kit/README.md (API table + config examples)
  - the matching aether-* skill (SKILL.md + recipes.md file:line cites)
EOF
    ;;
esac

exit 0
