#!/usr/bin/env bash
# PostToolUse hook for Edit|Write|MultiEdit.
# When an engine source file is touched (STUDIO_ENGINE_GLOB, default
# */ether/src/*), remind Claude that the toolkit documents the engine —
# skills and READMEs silently drift unless synced in the same PR.
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
  ${STUDIO_ENGINE_GLOB:-*/ether/src/*})
    cat <<'EOF'
[hook:kit-drift-reminder] Engine source touched. If the public surface changed
(exports, signatures, files moved), sync the docs in the SAME PR:
  - the engine README (API table + config examples)
  - the matching ether-* skill (SKILL.md + recipes.md cites)
If the engine is mirrored publicly, publish after the change lands.
EOF
    ;;
esac

exit 0
