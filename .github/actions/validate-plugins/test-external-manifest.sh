#!/usr/bin/env bash
# Static test for resolve_external_manifest() in lib/common.sh — the manifest
# resolution + strict:false synthesis used by 30-validate-cli-external.sh.
# Pure bash/jq, no network, no CLI. Same conventions as test-invariants.sh.
set -euo pipefail
cd "$(dirname "$0")"
export ACTION_PATH="$PWD"
VALIDATE_TMP="$(mktemp -d)"; export VALIDATE_TMP   # common.sh derives RESULTS_FILE from this
# shellcheck disable=SC1091
source "$ACTION_PATH/lib/common.sh"
TMP="$VALIDATE_TMP"; trap 'rm -rf "$TMP"' EXIT
failures=0; total=0

mkdir_target() { mktemp -d "$TMP/tgt.XXXXXX"; }

# assert_resolves <desc> <expected-path-suffix> <target> <name> <strict> [expected-rc=0]
# expected-rc distinguishes an existing manifest (0) from a synthesized one (2).
assert_resolves() {
  total=$((total+1))
  local got rc=0 want_rc="${6:-0}"
  got="$(resolve_external_manifest "$3" "$4" "$5")" || rc=$?
  if [[ "$rc" -eq "$want_rc" && "$got" == *"$2" ]]; then echo "  PASS $1"
  else echo "  FAIL $1 — rc=$rc (want $want_rc) got='$got' (expected suffix '$2')"; failures=$((failures+1)); fi
}

# assert_no_manifest <desc> <target> <name> <strict>  (expects rc 1)
assert_no_manifest() {
  total=$((total+1))
  local rc=0
  resolve_external_manifest "$2" "$3" "$4" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 1 ]]; then echo "  PASS $1"
  else echo "  FAIL $1 — expected rc 1, got rc=$rc"; failures=$((failures+1)); fi
}

echo "=== resolve_external_manifest tests ==="

# 1. existing .claude-plugin/plugin.json is used
t="$(mkdir_target)"; mkdir -p "$t/.claude-plugin"; echo '{"name":"x"}' > "$t/.claude-plugin/plugin.json"
assert_resolves "real .claude-plugin/plugin.json is used" "/.claude-plugin/plugin.json" "$t" "x" "true"

# 2. root plugin.json is used when no .claude-plugin/  (exact path — the suffix
#    "$t/plugin.json" can't also match a ".claude-plugin/plugin.json" return)
t="$(mkdir_target)"; echo '{"name":"x"}' > "$t/plugin.json"
assert_resolves "root plugin.json is used" "$t/plugin.json" "$t" "x" "true"

# 3. precedence: .claude-plugin/plugin.json wins over root plugin.json
t="$(mkdir_target)"; mkdir -p "$t/.claude-plugin"
echo '{"name":"x"}' > "$t/.claude-plugin/plugin.json"; echo '{"name":"y"}' > "$t/plugin.json"
assert_resolves "prefers .claude-plugin/ over root plugin.json" "/.claude-plugin/plugin.json" "$t" "x" "true"

# 3b. strict:false MUST NOT synthesize over a real .claude-plugin/plugin.json
#     (rc 0 = existing, not 2 = synthesized) — guards the last-resort ordering.
t="$(mkdir_target)"; mkdir -p "$t/.claude-plugin"; echo '{"name":"real"}' > "$t/.claude-plugin/plugin.json"
assert_resolves "strict:false defers to a real .claude-plugin/plugin.json" "/.claude-plugin/plugin.json" "$t" "ignored" "false" 0
total=$((total+1))
if [[ "$(jq -r .name "$t/.claude-plugin/plugin.json")" == "real" ]]; then
  echo "  PASS strict:false did NOT overwrite the real manifest"
else echo "  FAIL strict:false clobbered a real manifest"; failures=$((failures+1)); fi

# 3c. strict:false MUST NOT synthesize over a real root plugin.json either.
t="$(mkdir_target)"; echo '{"name":"real-root"}' > "$t/plugin.json"
assert_resolves "strict:false defers to a real root plugin.json" "$t/plugin.json" "$t" "ignored" "false" 0

# 4. strict:false + no manifest -> synthesize a minimal one (rc 2) carrying the name
t="$(mkdir_target)"
assert_resolves "strict:false synthesizes a manifest (rc 2)" "/.claude-plugin/plugin.json" "$t" "netsuite-suitecloud" "false" 2
total=$((total+1))
if [[ -f "$t/.claude-plugin/plugin.json" ]] \
   && [[ "$(jq -r .name "$t/.claude-plugin/plugin.json")" == "netsuite-suitecloud" ]]; then
  echo "  PASS synthesized manifest exists and carries the entry name"
else echo "  FAIL synthesized manifest missing or wrong name"; failures=$((failures+1)); fi

# 5. strict:true + no manifest -> rc 1 (genuine failure, unchanged behavior)
t="$(mkdir_target)"
assert_no_manifest "strict:true with no manifest fails" "$t" "x" "true"

# 6. strict unset (defaults to strict) + no manifest -> rc 1
t="$(mkdir_target)"
assert_no_manifest "strict default (empty arg) with no manifest fails" "$t" "x" ""

# 7. remove_escaping_symlinks: links out of the clone (or into .git) go, the rest stay
t="$(mkdir_target)"; outside="$(mkdir_target)"; echo secret > "$outside/plugin.json"
mkdir -p "$t/sub" "$t/.git"; echo '{"name":"x"}' > "$t/sub/plugin.json"; echo cfg > "$t/.git/config"
ln -s sub "$t/kept-dir"; ln -s sub/plugin.json "$t/kept-file"
ln -s "$outside" "$t/out-dir"; ln -s "../${outside##*/}/plugin.json" "$t/out-file"
ln -s out-file "$t/out-chain"; ln -s "$outside/not-yet" "$t/out-dangling"; ln -s ../.git/config "$t/sub/into-git"
ln -s "$outside" "$t/.claude-plugin"
total=$((total+1))
if remove_escaping_symlinks "$t" \
   && [[ -L "$t/kept-dir" && -f "$t/kept-file" && -f "$t/.git/config" ]] \
   && [[ ! -L "$t/out-dir" && ! -L "$t/out-file" && ! -L "$t/out-chain" ]] \
   && [[ ! -L "$t/out-dangling" && ! -L "$t/sub/into-git" && ! -L "$t/.claude-plugin" ]] \
   && [[ "$(cat "$outside/plugin.json")" == "secret" ]]; then
  echo "  PASS removes escaping symlinks, keeps inside ones"
else echo "  FAIL symlink containment"; failures=$((failures+1)); fi
assert_no_manifest "a manifest reached through an escaping link is not used" "$t" "x" "true"

# 8. a directory that cannot be walked fails closed
total=$((total+1))
if remove_escaping_symlinks "$t/no-such-dir" 2>/dev/null; then
  echo "  FAIL missing clone should not pass"; failures=$((failures+1))
else echo "  PASS missing clone is rejected"; fi

echo
echo "=== $((total-failures))/$total passed ==="
[[ "$failures" -eq 0 ]]
