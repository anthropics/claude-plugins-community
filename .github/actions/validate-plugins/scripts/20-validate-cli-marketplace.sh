#!/usr/bin/env bash
# Run `claude plugin validate` on the full assembled marketplace.json.
# This is the canonical schema check — always current with the CLI.

source "$ACTION_PATH/lib/common.sh"

: "${VALIDATE_TMP:?}"
MP="$VALIDATE_TMP/marketplace.json"

group_start "CLI: claude plugin validate (marketplace)"

command -v claude >/dev/null 2>&1 || die "claude CLI not found on PATH"

# With SCOPE_ERRORS_TO_CHANGED, errors about entries this change does not touch
# are warnings, if the base marketplace already has them (see known-errors.py).
# Any other failure is an error, as is every failure when the base is unknown.
BASE_MP="$VALIDATE_TMP/marketplace.base.json"
if [[ "${SCOPE_ERRORS_TO_CHANGED:-false}" == "true" && "${FAIL_ON_WARNINGS:-false}" != "true" && -f "$BASE_MP" ]] \
   && ! claude plugin validate "$MP" > "$VALIDATE_TMP/cli-head.txt" 2>&1; then
  mkdir -p "$VALIDATE_TMP/base/.claude-plugin" "$VALIDATE_TMP/rest/.claude-plugin"
  cp -- "$BASE_MP" "$VALIDATE_TMP/base/.claude-plugin/marketplace.json"
  claude plugin validate "$VALIDATE_TMP/base/.claude-plugin/marketplace.json" > "$VALIDATE_TMP/cli-base.txt" 2>&1 || true
  if python3 -I "$ACTION_PATH/scripts/known-errors.py" \
       "$MP" "$VALIDATE_TMP/cli-head.txt" "$BASE_MP" "$VALIDATE_TMP/cli-base.txt" \
       "$VALIDATE_TMP/rest/.claude-plugin/marketplace.json"; then
    log "$(cat "$VALIDATE_TMP/cli-head.txt")"
    warn "marketplace.json: claude plugin validate fails only on entries this change does not touch, as on the base"
    record_result "cli-marketplace" "warn" "marketplace.json" "errors only on unchanged entries"
    cli_validate "cli-marketplace" "the other entries" "$VALIDATE_TMP/rest/.claude-plugin/marketplace.json" || exit 1
    group_end
    exit 0
  fi
fi

cli_validate "cli-marketplace" "marketplace.json" "$MP" || exit 1

group_end
