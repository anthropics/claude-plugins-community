#!/usr/bin/env bash
set -uo pipefail

# Read stdin JSON to check stop_hook_active (prevents infinite loop)
INPUT="$(cat 2>/dev/null || true)"
if command -v python3 >/dev/null 2>&1; then
  ACTIVE="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active',False))" 2>/dev/null || echo "False")"
  if [ "$ACTIVE" = "True" ]; then
    exit 0
  fi
fi

CONFIG=".ireview.json"
STATE_DIR=".ireview"
STATE_FILE="$STATE_DIR/state.json"

# Not a git repo? Let it go
git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0

# No config? Let it go
[ -f "$CONFIG" ] || exit 0

# Auto review not enabled? Let it go
grep -q '"auto_review"[[:space:]]*:[[:space:]]*true' "$CONFIG" 2>/dev/null || exit 0

# No changes? Let it go
CHANGED="$(git diff HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')"
[ "${CHANGED:-0}" -eq 0 ] && exit 0

# Compute diff hash
if command -v sha256sum >/dev/null 2>&1; then
  DIFF_HASH="$(git diff HEAD 2>/dev/null | sha256sum | awk '{print $1}')"
else
  DIFF_HASH="$(git diff HEAD 2>/dev/null | shasum -a 256 | awk '{print $1}')"
fi

mkdir -p "$STATE_DIR"

# Already reviewed or cancelled this exact diff? Let it go
if [ -f "$STATE_FILE" ]; then
  PREV_HASH="$(grep -o '"diff_hash"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*: *"//; s/"$//')"
  PREV_PHASE="$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*: *"//; s/"$//')"

  if [ "$PREV_HASH" = "$DIFF_HASH" ] && { [ "$PREV_PHASE" = "passed" ] || [ "$PREV_PHASE" = "cancelled" ]; }; then
    exit 0
  fi
fi

# Write state: review requested
TMP="$(mktemp)"
cat > "$TMP" << EOF
{
  "phase": "requested",
  "diff_hash": "$DIFF_HASH",
  "files_changed": $CHANGED,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
mv "$TMP" "$STATE_FILE"

echo "iReview: $CHANGED files changed. Run /ireview:review or /ireview:cancel" >&2
exit 2
