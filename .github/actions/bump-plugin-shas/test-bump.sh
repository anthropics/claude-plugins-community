#!/usr/bin/env bash
# Static test suite for bump.sh, in TWO network-free regimes:
#   - Cases 1-14 (skip/freeze/exempt/only): every fixture entry resolves to a
#     skip BEFORE any git ls-remote / clone / claude / gh call — no shims.
#   - The releases-only (tracking-config) cases: resolution itself runs, against
#     gh/git/timeout/claude PATH shims in $TMP/bin (run_bump_shimmed). The gh
#     shim is faithful to real gh: on an HTTP error it prints the JSON error
#     BODY to stdout and exits 1 (verified gh 2.96.0). Any un-modeled stub call
#     appends a STUB-UNEXPECTED/STUB-MISCONFIGURED sentinel that the per-case
#     drift guard turns into a FAILURE (bump.sh itself converts unexpected
#     non-zero exits into normal-looking skips, so the sentinel is the only
#     loud signal).
# Pure bash/jq against synthetic marketplace.json fixtures. Run locally or in
# CI on every PR touching bump-plugin-shas/.
#
# Fixtures use heredocs (not quoted args) so the suite runs identically on
# macOS bash 3.2 and Linux bash 5.x.

set -euo pipefail
cd "$(dirname "$0")"
export ACTION_PATH="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
failures=0; total=0

# A stub validate-lib providing exactly the helpers bump.sh sources. Faithful
# to validate-plugins/lib/common.sh for the functions the skip paths touch.
cat > "$TMP/lib.sh" <<'EOF'
log()   { printf '%s\n' "$*"; }
info()  { printf '::notice::%s\n' "$*"; }
warn()  { printf '::warning::%s\n' "$*"; }
error() { printf '::error::%s\n' "$*"; }
die()   { error "$*"; exit 1; }
group_start() { printf '::group::%s\n' "$*"; }
group_end()   { printf '::endgroup::\n'; }
has_unsafe_chars() {
  case "$1" in
    *'$'*|*'`'*|*';'*|*'&'*|*'|'*|*'('*|*')'*|*'<'*|*'>'*|*' '*|*'	'*|*'"'*|*"'"*|*'\'*) return 0 ;;
  esac
  return 1
}
EOF

mk() { local f="$TMP/$1.json"; cat > "$f"; printf '%s' "$f"; }

# Run the real bump.sh against fixture $1, with FREEZE_SHAS_FIXTURE /
# SHA_EXEMPT_FIXTURE supplying the two lists. Captures combined output in OUT,
# the parsed `skipped` output array in SKIPPED_JSON, and the exit code in RC.
# bump.sh mutates MARKETPLACE_PATH in place, so it operates on a copy ($work)
# and the caller compares $work against $1 to assert "pin held".
work=""
run_bump() {
  work="$TMP/work.json"; cp "$1" "$work"
  export VALIDATE_LIB="$TMP/lib.sh" MARKETPLACE_PATH="$work" \
    MAX_BUMPS=20 ALLOWED_HOSTS="github.com gitlab.com bitbucket.org" \
    PR_BRANCH="bump/plugin-shas" BASE_BRANCH="main" GH_TOKEN="dummy" \
    SHA_EXEMPT="${SHA_EXEMPT_FIXTURE:-}" FREEZE_SHAS="${FREEZE_SHAS_FIXTURE:-}" \
    ONLY="${ONLY_FIXTURE:-}" TRACKING_CONFIG="${TRACKING_CONFIG_FIXTURE:-}" \
    OWNER_BASELINE="${OWNER_BASELINE_FIXTURE:-}" \
    PR_MODE="${PR_MODE_FIXTURE:-batch}" \
    GITHUB_OUTPUT="$TMP/out.txt" GITHUB_STEP_SUMMARY="$TMP/sum.md"
  : > "$TMP/out.txt"; : > "$TMP/sum.md"
  set +e
  OUT="$(bash "$ACTION_PATH/scripts/bump.sh" 2>&1)"
  RC=$?
  set -e
  SKIPPED_JSON="$(sed -n 's/^skipped=//p' "$TMP/out.txt")"
  [[ -n "$SKIPPED_JSON" ]] || SKIPPED_JSON='[]'
}

# assert_reason NAME EXPECTED_SUBSTR LABEL — entry NAME was skipped with a
# reason containing EXPECTED_SUBSTR.
assert_reason() {
  total=$((total+1))
  local got; got="$(jq -r --arg n "$1" '.[]|select(.name==$n)|.reason' <<<"$SKIPPED_JSON")"
  if [[ "$got" == *"$2"* ]]; then echo "  PASS $3"
  else echo "  FAIL $3 — '$1' reason='$got' expected to contain '$2'"; failures=$((failures+1)); fi
}

# assert_warn SUBSTR LABEL — a workflow ::warning containing SUBSTR was emitted.
assert_warn() {
  total=$((total+1))
  if grep -qF "$1" <<<"$OUT"; then echo "  PASS $2"
  else echo "  FAIL $2 — no warning containing '$1'"; failures=$((failures+1)); fi
}

# assert_no_warn SUBSTR LABEL — no output line contains SUBSTR.
assert_no_warn() {
  total=$((total+1))
  if grep -qF "$1" <<<"$OUT"; then echo "  FAIL $2 — unexpected '$1' in output"; failures=$((failures+1))
  else echo "  PASS $2"; fi
}

# assert_pin_held FIXTURE LABEL — bump.sh left the marketplace byte-identical.
assert_pin_held() {
  total=$((total+1))
  if diff -q "$1" "$work" >/dev/null; then echo "  PASS $2"
  else echo "  FAIL $2 — marketplace.json changed (pin advanced)"; failures=$((failures+1)); fi
}

# assert_rc EXPECTED LABEL
assert_rc() {
  total=$((total+1))
  if [[ "$RC" == "$1" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — exit $RC, expected $1"; failures=$((failures+1)); fi
}

# assert_not_skipped NAME LABEL — entry NAME does NOT appear in skipped[] (it was
# plain-continued by the `only` guard, not recorded as a skip).
assert_not_skipped() {
  total=$((total+1))
  local got; got="$(jq -r --arg n "$1" '[.[]|select(.name==$n)]|length' <<<"$SKIPPED_JSON")"
  if [[ "$got" == "0" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — '$1' unexpectedly recorded in skipped[]"; failures=$((failures+1)); fi
}

# assert_skipped_count N LABEL — exactly N entries in skipped[].
assert_skipped_count() {
  total=$((total+1))
  local got; got="$(jq -r 'length' <<<"$SKIPPED_JSON")"
  if [[ "$got" == "$1" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — skipped[] has $got, expected $1"; failures=$((failures+1)); fi
}

echo "=== stub fidelity: has_unsafe_chars matches the real common.sh ==="
# The stub lib above hand-copies has_unsafe_chars from validate-plugins/lib/common.sh
# so this suite can stay network-free. That copy is the SAME guard the `only`
# validation cases below assert against — if the real charset ever changes (e.g.
# adds * or ?), the copy would silently keep testing stale behavior and the
# injection-guard cases would pass against a definition that no longer ships. Pin
# the two together: run both implementations over a probe battery and require they
# agree on every input. (Each is sourced in its own subshell so neither clobbers
# the other; the real common.sh is pure function defs + a safe set/RESULTS_FILE top.)
REAL_COMMON="$ACTION_PATH/../validate-plugins/lib/common.sh"
total=$((total+1))
if [[ ! -f "$REAL_COMMON" ]]; then
  echo "  FAIL has_unsafe_chars stub-vs-real — real common.sh not found at $REAL_COMMON"; failures=$((failures+1))
else
  _drift=""
  for _p in "plain-name" "@scope/plugin" "Foo.Bar" "UPPER" "a b" "a	b" 'a$b' 'a`b' 'a;b' 'a&b' 'a|b' 'a(b' 'a)b' 'a<b' 'a>b' 'a"b' "a'b" 'a\b' "a*b" "a?b" "a[b]" ""; do
    _s=0; ( source "$TMP/lib.sh";    has_unsafe_chars "$_p" ) >/dev/null 2>&1 || _s=$?
    _r=0; ( source "$REAL_COMMON";    has_unsafe_chars "$_p" ) >/dev/null 2>&1 || _r=$?
    [[ "$_s" == "$_r" ]] || _drift="$_drift [$_p: stub=$_s real=$_r]"
  done
  if [[ -z "$_drift" ]]; then echo "  PASS has_unsafe_chars stub agrees with real common.sh across the probe battery"
  else echo "  FAIL has_unsafe_chars stub DRIFTED from real common.sh:$_drift"; failures=$((failures+1)); fi
fi

echo "=== bump-plugin-shas freeze/exempt tests ==="

# 1. A frozen, pinned entry is held and recorded — even though its host IS
#    allowlisted, the freeze check fires before any ls-remote (network-free).
f=$(mk freeze <<'EOF'
{"plugins":[{"name":"frozen-plugin","source":{"url":"https://github.com/acme/frozen-plugin","sha":"1111111111111111111111111111111111111111"}}]}
EOF
)
FREEZE_SHAS_FIXTURE="frozen-plugin"; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_reason "frozen-plugin" "frozen at current pin (freeze-shas)" "freeze fires + recorded in skipped[]"
assert_pin_held "$f" "frozen pin held (marketplace unchanged)"
assert_rc 0 "skip-only run exits 0 (Nothing to bump)"

# 2. Freeze match is whole-word: a 'frozen' entry is NOT frozen by the list
#    'frozen-plugin'. It passes the freeze gate and skips for a different
#    reason (host not allowlisted → still network-free).
f=$(mk wholeword <<'EOF'
{"plugins":[{"name":"frozen-plugin","source":{"url":"https://github.com/acme/frozen-plugin","sha":"1111111111111111111111111111111111111111"}},{"name":"frozen","source":{"url":"https://example.com/acme/frozen","sha":"2222222222222222222222222222222222222222"}}]}
EOF
)
FREEZE_SHAS_FIXTURE="frozen-plugin"; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_reason "frozen"        "not in allowlist"                  "substring 'frozen' is NOT frozen (whole-word match)"
assert_reason "frozen-plugin" "frozen at current pin (freeze-shas)" "whole-word entry still frozen"

# 3. sha-exempt path still works (no regression).
f=$(mk exempt <<'EOF'
{"plugins":[{"name":"exempt-plugin","source":{"url":"https://github.com/acme/exempt-plugin"}}]}
EOF
)
FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE="exempt-plugin"
run_bump "$f"
assert_reason "exempt-plugin" "unpinned by policy (sha-exempt)" "sha-exempt still skips (no regression)"

# 4. Name in BOTH lists → sha-exempt wins (checked first).
f=$(mk both <<'EOF'
{"plugins":[{"name":"dual","source":{"url":"https://github.com/acme/dual"}}]}
EOF
)
FREEZE_SHAS_FIXTURE="dual"; SHA_EXEMPT_FIXTURE="dual"
run_bump "$f"
assert_reason "dual" "unpinned by policy (sha-exempt)" "both-lists precedence: sha-exempt first"

# 5. Reconciliation: a typo'd freeze name (no matching entry) warns loudly.
f=$(mk typo <<'EOF'
{"plugins":[{"name":"frozen-plugin","source":{"url":"https://example.com/acme/frozen-plugin","sha":"1111111111111111111111111111111111111111"}}]}
EOF
)
FREEZE_SHAS_FIXTURE="frozn-plugin"; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_warn "freeze-shas: 'frozn-plugin' matches no external" "typo'd freeze name warns (matches no entry)"

# 6. Reconciliation: a freeze name outside the guard charset (uppercase) warns
#    as invalid — this is the silent-no-op case the warning exists to catch.
f=$(mk badname <<'EOF'
{"plugins":[{"name":"Frozen-Plugin","source":{"url":"https://example.com/acme/frozen-plugin","sha":"1111111111111111111111111111111111111111"}}]}
EOF
)
FREEZE_SHAS_FIXTURE="Frozen-Plugin"; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_warn "freeze-shas: 'Frozen-Plugin' is not a valid plugin name" "charset-excluded freeze name warns as invalid"

# 7. Reconciliation is glob-safe: a '*' in the list must not expand against the
#    filesystem nor freeze a real entry; it warns as invalid and 'abc' is left
#    to normal processing (skips on host).
f=$(mk glob <<'EOF'
{"plugins":[{"name":"abc","source":{"url":"https://example.com/acme/abc","sha":"3333333333333333333333333333333333333333"}}]}
EOF
)
FREEZE_SHAS_FIXTURE="*"; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_warn   "is not a valid plugin name" "glob '*' in freeze list warns, doesn't expand"
assert_reason "abc" "not in allowlist"      "glob '*' does not freeze a real entry"

# 8. No freeze list → no freeze-shas reconciliation noise.
f=$(mk none <<'EOF'
{"plugins":[{"name":"abc","source":{"url":"https://example.com/acme/abc","sha":"3333333333333333333333333333333333333333"}}]}
EOF
)
FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_no_warn "freeze-shas:" "empty freeze list → no freeze-shas warning"

# 8b. Traversal-shaped source.path (subdir) is rejected up front: `..` and
#     absolute paths could otherwise escape the throwaway clone at
#     target="$dest/$subdir", so they must skip BEFORE any ls-remote/clone
#     (network-free — the guard sits ahead of resolution), matching scan.sh's
#     subdir guard and validate-plugins' assert_safe_path. Three shapes:
#     leading ../, embedded /../, absolute /. The safe-subdir counterparts
#     (guard must NOT over-fire) are case 24b below and test-bump-manifest.sh's
#     subdir-present case.
f=$(mk travsub <<'EOF'
{"plugins":[{"name":"trav-up","source":{"url":"https://github.com/acme/trav-up","sha":"1111111111111111111111111111111111111111","path":"../../../../tmp/x"}},{"name":"trav-embed","source":{"url":"https://github.com/acme/trav-embed","sha":"2222222222222222222222222222222222222222","path":"docs/../../x"}},{"name":"trav-abs","source":{"url":"https://github.com/acme/trav-abs","sha":"3333333333333333333333333333333333333333","path":"/tmp/x"}}]}
EOF
)
FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""
run_bump "$f"
assert_reason "trav-up"    "unsafe subdir" "leading ../ subdir rejected"
assert_reason "trav-embed" "unsafe subdir" "embedded .. subdir rejected"
assert_reason "trav-abs"   "unsafe subdir" "absolute subdir rejected"
assert_skipped_count 3     "all three traversal-shaped subdirs skipped"
assert_pin_held "$f"       "traversal subdirs → pins held, nothing bumped"
assert_rc 0                "traversal-subdir run exits 0 (skip, not die)"

echo
echo "=== bump-plugin-shas single-plugin (only) target tests ==="

# Shared 2-entry fixture for the `only` cases. Both entries short-circuit BEFORE
# `git ls-remote` (alpha via the freeze gate; beta via a non-allowlisted host), so
# these stay network/gh/claude-free like the rest of this suite. alpha is on
# github.com so that — absent the freeze — it WOULD reach ls-remote; the freeze
# proves the target falls through to its real skip reason rather than the only
# guard swallowing it.
only_fix=$(mk onlytgt <<'EOF'
{"plugins":[{"name":"alpha","source":{"url":"https://github.com/acme/alpha","sha":"1111111111111111111111111111111111111111"}},{"name":"beta","source":{"url":"https://example.com/acme/beta","sha":"2222222222222222222222222222222222222222"}}]}
EOF
)

# 9. only=alpha (a frozen target): alpha still reports its freeze reason; beta is
#    plain-continued (NOT recorded in skipped[]). Proves the target falls through
#    to its real skip reason AND a non-target is silently plain-continued. (NOTE:
#    this case does NOT pin the guard's POSITION relative to the freeze gate — a
#    frozen target reports "frozen" with the guard either before or after freeze.
#    The guard-before-everything ordering invariant is pinned by case 11, which
#    relies on a non-matching target producing ZERO skip records.)
ONLY_FIXTURE="alpha"; FREEZE_SHAS_FIXTURE="alpha"; SHA_EXEMPT_FIXTURE=""
run_bump "$only_fix"
assert_reason      "alpha" "frozen at current pin (freeze-shas)" "only=target still reports its real skip reason"
assert_not_skipped "beta"                                        "only=target → non-target plain-continued (not in skipped[])"
assert_skipped_count 1                                           "only=target → exactly one entry recorded"
assert_pin_held    "$only_fix"                                   "only=target → marketplace unchanged"

# 10. only="" (default): every entry processed exactly as today — alpha frozen,
#     beta host-skipped → both recorded. Proves the empty-ONLY no-op.
ONLY_FIXTURE=""; FREEZE_SHAS_FIXTURE="alpha"; SHA_EXEMPT_FIXTURE=""
run_bump "$only_fix"
assert_reason        "alpha" "frozen at current pin (freeze-shas)" "only='' → alpha still frozen"
assert_reason        "beta"  "not in allowlist"                    "only='' → beta still host-skipped"
assert_skipped_count 2                                             "only='' → both entries processed (byte-identical default)"

# 11. only=<missing>: no entry matches → all plain-continued → Nothing to bump.
ONLY_FIXTURE="ghost"; FREEZE_SHAS_FIXTURE="alpha"; SHA_EXEMPT_FIXTURE=""
run_bump "$only_fix"
assert_skipped_count 0   "only=missing → no entry recorded (all plain-continued)"
assert_rc 0              "only=missing → exits 0 (Nothing to bump)"
assert_pin_held "$only_fix" "only=missing → marketplace unchanged"

# 12. only='bad name' (whitespace): rejected up front via has_unsafe_chars → die.
#     run_bump captures RC via its own `set +e` wrapper — no errexit-suppressing
#     `( … ) || rc=$?` around the command under test.
ONLY_FIXTURE="bad name"; FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""
run_bump "$only_fix"
assert_rc 1 "only='bad name' (whitespace) → die (RC 1)"
assert_warn "contains unsafe characters" "only='bad name' → unsafe-char die message"

# 13. has_unsafe_chars ALLOWS a scoped/dotted name (the whole reason `only` uses it
#     instead of the narrow freeze charset). A scoped target must NOT die — it
#     passes validation and reaches normal processing (here: host-skip, network-free,
#     since the freeze gate's [a-z0-9-] regex doesn't match a scoped name anyway).
scoped_fix=$(mk scoped <<'EOF'
{"plugins":[{"name":"@acme/scoped","source":{"url":"https://example.com/acme/scoped","sha":"4444444444444444444444444444444444444444"}},{"name":"alpha","source":{"url":"https://github.com/acme/alpha","sha":"1111111111111111111111111111111111111111"}}]}
EOF
)
ONLY_FIXTURE="@acme/scoped"; FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""
run_bump "$scoped_fix"
assert_rc 0 "only=@acme/scoped → scoped/dotted name ALLOWED (no die)"
assert_reason "@acme/scoped" "not in allowlist" "scoped target reached processing (host-skip), proving it was allowed past validation"
assert_not_skipped "alpha" "only=@acme/scoped → non-target alpha plain-continued"

# 13b. A non-whitespace shell metacharacter is still rejected (rejection coverage
#      isn't whitespace-only).
ONLY_FIXTURE="a;b"; FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""
run_bump "$scoped_fix"
assert_rc 1 "only='a;b' (metachar) → die"
assert_warn "contains unsafe characters" "only='a;b' → unsafe-char die message"

# 14. The freeze-reconciliation warning block is SKIPPED under a single-plugin run
#     (the `[[ -z "$ONLY" ]]` gate). Two-sided so the gate is load-bearing: a typo'd
#     freeze name warns when ONLY is empty, and is suppressed when ONLY is set.
ONLY_FIXTURE=""; FREEZE_SHAS_FIXTURE="frozn-typo"; SHA_EXEMPT_FIXTURE=""
run_bump "$only_fix"
assert_warn "freeze-shas:" "only='' → freeze-reconciliation warning fires (typo'd name)"
ONLY_FIXTURE="alpha"; FREEZE_SHAS_FIXTURE="frozn-typo"; SHA_EXEMPT_FIXTURE=""
run_bump "$only_fix"
assert_no_warn "freeze-shas:" "only=alpha → freeze-reconciliation warning SUPPRESSED (targeted run)"

ONLY_FIXTURE=""  # reset so it can't leak into any later case

echo
echo "=== bump-plugin-shas releases-only (tracking-config) tests ==="

# These cases exercise the RESOLUTION branch itself, so — unlike the skip-path
# cases above — they need `gh api`, `git ls-remote`, and (for the stale-entry
# case) the clone path to run. Stay network-free via PATH shims in $TMP/bin:
#   - The gh stub is FAITHFUL to real gh: on an HTTP error it prints the JSON
#     error body to STDOUT and exits 1 (verified gh 2.96.0) — modeling failure
#     as empty-stdout would certify behavior real gh does not have.
#   - The git stub answers ls-remote and REFUSES clone (exit 1) so a stale
#     entry's bump attempt terminates as "clone failed" without any network.
#   - timeout execs its wrapped command (PATH-resolving into the stubs);
#     claude is fail-closed (never legitimately reachable here).
#   - Any un-modeled call (or a route whose STUB_* input a case forgot to set)
#     appends a STUB-UNEXPECTED / STUB-MISCONFIGURED sentinel line; the
#     per-case drift guard in run_bump_shimmed turns sentinels into FAILURES —
#     bump.sh converts unexpected non-zero exits into normal-looking skips, so
#     the sentinel is the only loud signal.
# Every case sets the STUB_* inputs it needs; run_bump_shimmed unsets them all
# afterwards, so no case can silently inherit a neighbor's fixture.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "${STUB_CALL_LOG:-/dev/null}"
need() { if [[ -z "${!1+x}" ]]; then echo "STUB-MISCONFIGURED $1 unset" >> "${STUB_CALL_LOG:-/dev/null}"; exit 9; fi; }
case "$*" in
  "api repos/"*"/releases/latest")
    need STUB_RELEASES_HTTP
    case "$STUB_RELEASES_HTTP" in
      200) need STUB_LATEST_TAG; printf '{"tag_name":"%s"}\n' "$STUB_LATEST_TAG" ;;
      404) printf '{"message":"Not Found","status":"404"}\n'; exit 1 ;;
      *)   printf '{"message":"API rate limit exceeded","status":"%s"}\n' "$STUB_RELEASES_HTTP"; exit 1 ;;
    esac ;;
  "api repos/"*"/compare/"*)
    printf '{"status":"%s"}\n' "${STUB_COMPARE_STATUS:-ahead}" ;;
  "api repos/"*"/commits/"*)
    need STUB_TAG_COMMIT_SHA; printf '{"sha":"%s"}\n' "$STUB_TAG_COMMIT_SHA" ;;
  "api repos/"*"/git/ref/tags/"*)
    # The WRONG answer, deliberately available: a tag-object implementation
    # would consume this dddd… sha — assertions prove it is never used.
    printf '{"object":{"type":"tag","sha":"dddddddddddddddddddddddddddddddddddddddd"}}\n' ;;
  "api repos/"*)
    # Plain repos/<owner>/<repo> — the source-owner verification gate. Must
    # stay BELOW the more specific repos/ routes above (case is first-match).
    need STUB_SOURCE_HTTP
    case "$STUB_SOURCE_HTTP" in
      200)
        # STUB_SOURCE_OWNER_ID: numeric → owner.id in the body (identity-leg
        # cases); "none" or unset → full_name only (the leg is inactive without
        # a baseline, or the cannot-verify case when one is present).
        need STUB_SOURCE_FULL_NAME
        if [[ -n "${STUB_SOURCE_OWNER_ID:-}" && "$STUB_SOURCE_OWNER_ID" != "none" ]]; then
          printf '{"full_name":"%s","owner":{"id":%s}}\n' "$STUB_SOURCE_FULL_NAME" "$STUB_SOURCE_OWNER_ID"
        else
          printf '{"full_name":"%s"}\n' "$STUB_SOURCE_FULL_NAME"
        fi ;;
      404) printf '{"message":"Not Found","status":"404"}\n'; exit 1 ;;
      *)   printf '{"message":"API rate limit exceeded","status":"%s"}\n' "$STUB_SOURCE_HTTP"; exit 1 ;;
    esac ;;
  "pr list --head "*)
    printf '%s\n' "${STUB_OPEN_PR_URL:-}" ;;
  *) echo "STUB-UNEXPECTED gh $*" >> "${STUB_CALL_LOG:-/dev/null}"; echo "gh-stub: unexpected call: $*" >&2; exit 12 ;;
esac
EOF
cat > "$TMP/bin/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "${STUB_CALL_LOG:-/dev/null}"
need() { if [[ -z "${!1+x}" ]]; then echo "STUB-MISCONFIGURED $1 unset" >> "${STUB_CALL_LOG:-/dev/null}"; exit 9; fi; }
case "$*" in
  "ls-remote -- "*" HEAD") need STUB_HEAD_SHA; printf '%s\tHEAD\n' "$STUB_HEAD_SHA" ;;
  "clone "*) echo "git-stub: clone refused (network-free suite)" >&2; exit 1 ;;
  *) echo "STUB-UNEXPECTED git $*" >> "${STUB_CALL_LOG:-/dev/null}"; echo "git-stub: unexpected call: $*" >&2; exit 12 ;;
esac
EOF
cat > "$TMP/bin/timeout" <<'EOF'
#!/usr/bin/env bash
echo "timeout $*" >> "${STUB_CALL_LOG:-/dev/null}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -k) shift 2 ;;
    [0-9]*) shift; break ;;
    *) break ;;
  esac
done
exec "$@"
EOF
cat > "$TMP/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude $*" >> "${STUB_CALL_LOG:-/dev/null}"
echo "STUB-UNEXPECTED claude $*" >> "${STUB_CALL_LOG:-/dev/null}"
exit 1
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/git" "$TMP/bin/timeout" "$TMP/bin/claude"
export STUB_CALL_LOG="$TMP/stub-calls.log"

# run_bump with the shims first on PATH; PATH restored unconditionally, the
# drift guard runs per-case, and ALL STUB_* inputs are unset afterwards (each
# case must set its own — silent leak-forward is a pass-shaped failure mode).
run_bump_shimmed() {
  local oldpath="$PATH" rc=0
  : > "$STUB_CALL_LOG"
  export STUB_HEAD_SHA STUB_LATEST_TAG STUB_TAG_COMMIT_SHA STUB_RELEASES_HTTP STUB_COMPARE_STATUS STUB_OPEN_PR_URL \
    STUB_SOURCE_HTTP STUB_SOURCE_FULL_NAME STUB_SOURCE_OWNER_ID
  PATH="$TMP/bin:$PATH"
  run_bump "$1" || rc=$?
  PATH="$oldpath"
  total=$((total+1))
  if grep -q '^STUB-' "$STUB_CALL_LOG"; then
    echo "  FAIL stub-drift guard — $(grep '^STUB-' "$STUB_CALL_LOG" | head -1)"; failures=$((failures+1))
  else
    echo "  PASS stub-drift guard (no unexpected/misconfigured stub calls)"
  fi
  unset STUB_HEAD_SHA STUB_LATEST_TAG STUB_TAG_COMMIT_SHA STUB_RELEASES_HTTP STUB_COMPARE_STATUS STUB_OPEN_PR_URL \
    STUB_SOURCE_HTTP STUB_SOURCE_FULL_NAME STUB_SOURCE_OWNER_ID
  return "$rc"
}

# assert_call SUBSTR LABEL — the stub call log records a matching invocation.
assert_call() {
  total=$((total+1))
  if grep -qF "$1" "$STUB_CALL_LOG"; then echo "  PASS $2"
  else echo "  FAIL $2 — no stub call containing '$1'"; failures=$((failures+1)); fi
}

# assert_no_call SUBSTR LABEL
assert_no_call() {
  total=$((total+1))
  if grep -qF "$1" "$STUB_CALL_LOG"; then echo "  FAIL $2 — unexpected stub call '$1'"; failures=$((failures+1))
  else echo "  PASS $2"; fi
}

# assert_summary SUBSTR LABEL — the step summary (the operator-facing surface
# for a releases-only hold) contains SUBSTR.
assert_summary() {
  total=$((total+1))
  if grep -qF "$1" "$TMP/sum.md"; then echo "  PASS $2"
  else echo "  FAIL $2 — no step-summary line containing '$1'"; failures=$((failures+1)); fi
}

mk_tc() { local f="$TMP/$1"; cat > "$f"; printf '%s' "$f"; }

# Shared fixtures. SHA roles: aaaa…=release commit · bbbb…=upstream HEAD ·
# cccc…=annotated-tag commit · dddd…=tag-OBJECT sha (stub-served, must never
# be consumed) · 9999…=stale old pin · eeee…=alt HEAD · ffff…=gitlab pin.
# ro_fix: rel-plugin (flagged) + head-plugin (unflagged control) + rel — the
# whole-word control: `rel` is a prefix of the flagged `rel-plugin`, so a
# padding-dropped match (*"$name"* instead of *" $name "*) would wrongly flag it.
ro_fix=$(mk relonly <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},{"name":"head-plugin","source":{"url":"https://github.com/acme/head-plugin","sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},{"name":"rel","source":{"url":"https://github.com/acme/rel","sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}]}
EOF
)
stale_fix=$(mk relstale <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"9999999999999999999999999999999999999999"}}]}
EOF
)
anno_fix=$(mk annofix <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"cccccccccccccccccccccccccccccccccccccccc"}}]}
EOF
)
tc_rel=$(mk_tc tracking.json <<'EOF'
{"releases-only": ["rel-plugin"]}
EOF
)

# 15. At-pin resolution, both paths + whole-word: the flagged entry resolves via
#     releases/latest→commits/<tag>; the unflagged entries resolve via ls-remote
#     HEAD; the `rel` prefix-name is NOT captured by the `rel-plugin` flag.
TRACKING_CONFIG_FIXTURE="$tc_rel"; FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""; ONLY_FIXTURE=""
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG="v1.0.0"
STUB_TAG_COMMIT_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
run_bump_shimmed "$ro_fix"
assert_rc 0 "releases-only: mixed at-pin fixture exits 0 (Nothing to bump)"
assert_warn "rel-plugin: mode=releases-only — releases/latest=v1.0.0 → aaaaaaaa" "flagged entry logs the releases-only resolution line"
assert_call "gh api repos/acme/rel-plugin/releases/latest" "flagged entry queried releases/latest"
assert_call "gh api repos/acme/rel-plugin/commits/v1.0.0" "flagged entry dereferenced the tag via commits/<tag>"
assert_call "git ls-remote -- https://github.com/acme/head-plugin HEAD" "unflagged entry still resolved via ls-remote HEAD"
assert_call "git ls-remote -- https://github.com/acme/rel HEAD" "whole-word: prefix-name 'rel' is NOT captured by the 'rel-plugin' flag"
assert_no_call "gh api repos/acme/head-plugin" "unflagged entry never touched the releases API"
assert_no_call "gh api repos/acme/rel/" "whole-word: 'rel' never routed to the releases API"
assert_no_call "git ls-remote -- https://github.com/acme/rel-plugin" "flagged entry never fell back to ls-remote"
assert_skipped_count 0 "all entries at-pin → no skips, no clone attempted"
assert_pin_held "$ro_fix" "all pins held (marketplace unchanged)"

# 16. STALE flagged entry: the resolved release COMMIT becomes the BUMP TARGET
#     (the headline behavior — a resolve-log-discard implementation fails here).
#     The run proceeds to clone, which the git stub refuses → "clone failed"
#     skip, still network-free. HEAD (bbbb…) differs from the release commit:
#     a HEAD-fallback implementation would render "-> bbbb…" and fail.
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG="v3.1.0"
STUB_TAG_COMMIT_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_COMPARE_STATUS="ahead"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/rel-plugin"
run_bump_shimmed "$stale_fix"
assert_warn "rel-plugin: 9999999999999999999999999999999999999999 -> aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "stale flagged entry ADOPTS the release commit as the bump target"
assert_call "compare/9999999999999999999999999999999999999999...aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "forward-only guard consulted compare before bumping"
assert_reason "rel-plugin" "clone failed" "…and proceeded to clone at that sha (stub refuses → network-free)"
assert_no_warn "-> bbbbbbbbbb" "no HEAD-fallback: upstream HEAD never became the target"
assert_pin_held "$stale_fix" "pin unchanged (clone refused before any write)"

# 17. Backward/divergent release REFUSED: releases/latest is chronological, so
#     a back-patch (compare=behind) must hold the pin loudly, never bump.
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG="v0.9.1"
STUB_TAG_COMMIT_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
STUB_COMPARE_STATUS="behind"
run_bump_shimmed "$stale_fix"
assert_reason "rel-plugin" "not ahead of the current pin (compare=behind) — refusing a backward/divergent bump" "backward release → loud refusal"
assert_no_call "clone" "backward release → no clone attempted"
assert_pin_held "$stale_fix" "backward release → pin held"

# 18. Annotated-tag semantics: commits/<tag> returns the COMMIT sha. The stub
#     SERVES the wrong answer too (git/ref/tags → dddd…), so a tag-object
#     implementation has a route to be wrong through — and is observably not.
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG="v2.0.0-annotated"
STUB_TAG_COMMIT_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_warn "mode=releases-only — releases/latest=v2.0.0-annotated → cccccccc" "annotated tag resolves to the commit sha"
assert_no_warn "dddddddd" "tag-object sha never surfaces (stub serves it; code must not consume it)"
assert_no_call "/git/ref" "no raw tag-ref lookup (commits endpoint only)"
assert_no_call "ls-remote --tags" "no ls-remote tag enumeration"
assert_skipped_count 0 "at-pin → no skips"
assert_pin_held "$anno_fix" "annotated-tag pin held at the commit"

# 19. NO published release (HTTP 404 — real gh prints the JSON error body to
#     STDOUT and exits 1): the QUIET policy hold, recorded in skipped[] AND in
#     the step summary, never a fallback to HEAD.
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=404
run_bump_shimmed "$anno_fix"
assert_rc 0 "no-releases 404: run exits 0"
assert_reason "rel-plugin" "releases-only: no published releases (pin held)" "404 → visible pin-hold skip record"
assert_summary "**rel-plugin** — releases-only: no published releases (pin held)" "the hold is visible in the step summary"
assert_no_call "git ls-remote -- https://github.com/acme/rel-plugin" "404 → never falls back to ls-remote HEAD"
assert_no_call "commits/" "404 → no tag resolution attempted"
assert_pin_held "$anno_fix" "404 → pin held"

# 20. TRANSIENT failure (403 rate limit) is NOT "no published releases" — it is
#     a loud skip naming the real cause (the error-attribution split).
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=403
run_bump_shimmed "$anno_fix"
assert_reason "rel-plugin" "releases/latest lookup failed (HTTP 403)" "403 → loud lookup-failure skip with the HTTP status"
assert_no_warn "no published releases" "403 is never misreported as the developer not releasing"
assert_pin_held "$anno_fix" "403 → pin held"

# 21. freeze-shas PRECEDENCE: a frozen-and-flagged entry stays frozen and never
#     consults the releases API (the ordering is the security property).
TRACKING_CONFIG_FIXTURE="$tc_rel"; FREEZE_SHAS_FIXTURE="rel-plugin"
run_bump_shimmed "$anno_fix"
assert_reason "rel-plugin" "frozen at current pin (freeze-shas)" "freeze WINS over releases-only"
assert_no_call "gh api repos/acme/rel-plugin" "frozen entry never consults the releases API (ordering pinned)"
assert_pin_held "$anno_fix" "frozen pin held"
FREEZE_SHAS_FIXTURE=""

# 22. sha-exempt PRECEDENCE: an exempt (deliberately unpinned) entry is not
#     re-pinned by a releases-only flag.
exempt_ro_fix=$(mk exemptro <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin"}}]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_rel"; SHA_EXEMPT_FIXTURE="rel-plugin"
run_bump_shimmed "$exempt_ro_fix"
assert_reason "rel-plugin" "unpinned by policy (sha-exempt)" "sha-exempt WINS over releases-only"
assert_no_call "gh api" "exempt entry never consults the releases API"
SHA_EXEMPT_FIXTURE=""

# 23. PER-ENTRY mode (the -official/KWP production mode): a stale flagged entry
#     with an open bump PR is skipped AFTER resolution, before any clone.
TRACKING_CONFIG_FIXTURE="$tc_rel"; PR_MODE_FIXTURE="per-entry"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG="v3.1.0"
STUB_TAG_COMMIT_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
STUB_COMPARE_STATUS="ahead"
STUB_OPEN_PR_URL="https://github.com/acme/marketplace/pull/1"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/rel-plugin"
run_bump_shimmed "$stale_fix"
assert_reason "rel-plugin" "open bump PR already exists at bump/rel-plugin" "per-entry: open-PR skip still applies to a releases-only bump"
assert_call "pr list --head bump/rel-plugin" "per-entry: open-PR probe ran"
assert_no_call "clone" "per-entry open-PR skip → no clone"
assert_pin_held "$stale_fix" "per-entry open-PR skip → pin held"
PR_MODE_FIXTURE=""

# 24. Hostile release tags: a tag outside the charset allowlist (or carrying a
#     '..' segment) is skipped BEFORE any commits/<tag> API route is built.
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG='v1.0.0#frag'
run_bump_shimmed "$anno_fix"
assert_reason "rel-plugin" "has characters outside" "hostile tag charset → visible skip"
assert_no_call "commits/v1.0.0#frag" "rejected tag never reaches the API route"
TRACKING_CONFIG_FIXTURE="$tc_rel"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG='../../../repos/evil/evil'
run_bump_shimmed "$anno_fix"
assert_reason "rel-plugin" "has characters outside" "traversal-shaped tag → visible skip"
assert_no_call "repos/evil" "'..' tag can never rewrite the API route"

# 24b. Safe MULTI-SEGMENT subdir stays allowed: the traversal guard (case 8b)
#      rejects `..`/absolute but must keep interior `/` legal — git-subdir
#      entries declare paths like plugins/foo. At-pin (stub HEAD == pinned sha)
#      so the run stays network-free and stops before the subtree probe; the
#      ls-remote call proves the entry PASSED the subdir guard.
subdir_ok_fix=$(mk subdirok <<'EOF'
{"plugins":[{"name":"subdir-ok","source":{"url":"https://github.com/acme/subdir-ok","sha":"cccccccccccccccccccccccccccccccccccccccc","path":"plugins/foo"}}]}
EOF
)
TRACKING_CONFIG_FIXTURE=""
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$subdir_ok_fix"
assert_rc 0 "multi-segment subdir: run exits 0"
assert_call "git ls-remote -- https://github.com/acme/subdir-ok HEAD" "safe multi-segment subdir passes the guard (reaches resolution)"
assert_skipped_count 0 "safe subdir not skipped (guard does not over-fire on interior /)"
assert_pin_held "$subdir_ok_fix" "at-pin multi-segment entry → pin held"

# 25. Reconcile warning: a flagged name matching no marketplace entry warns
#     (typo or not-yet-live add-PR) when ONLY is empty, suppressed under a
#     targeted run — two-sided, mirroring the freeze-shas gate (case 14).
#     The real entry is AT-PIN (HEAD=cccc…) so the run stays on the intended
#     Nothing-to-bump path — pinned by the skipped-count/pin asserts.
tc_ghost=$(mk_tc tracking-ghost.json <<'EOF'
{"releases-only": ["ghost-plugin"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_ghost"; ONLY_FIXTURE=""
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_warn "tracking-config releases-only: 'ghost-plugin' matches no external" "unmatched releases-only name warns (only='')"
assert_skipped_count 0 "ghost-warn run stays on the Nothing-to-bump path"
assert_pin_held "$anno_fix" "ghost-warn run leaves the pin held"
ONLY_FIXTURE="rel-plugin"
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_no_warn "tracking-config releases-only: 'ghost-plugin'" "reconcile warning suppressed under only=<target>"
ONLY_FIXTURE=""

# 26. Reconcile invalid-name + glob-safety (mirrors freeze cases 6-7): an
#     out-of-charset name warns as invalid; a '*' must not glob-expand nor
#     flag a real entry.
tc_upper=$(mk_tc tracking-upper.json <<'EOF'
{"releases-only": ["Rel-Plugin"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_upper"
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_warn "tracking-config releases-only: 'Rel-Plugin' is not a valid plugin name" "charset-excluded releases-only name warns as invalid"
assert_no_call "gh api" "invalid-charset flag never routes to the releases API"
tc_glob=$(mk_tc tracking-glob.json <<'EOF'
{"releases-only": ["*"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_glob"
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_warn "is not a valid plugin name" "glob '*' in releases-only warns, doesn't expand"
assert_no_call "gh api" "glob '*' does not flag a real entry"
assert_skipped_count 0 "glob run stays clean (entry HEAD-tracks at-pin)"

# 27. A marketplace ENTRY named outside the charset gate cannot be releases-only
#     tracked even when listed — it HEAD-tracks, and the reconcile warns. This
#     pins the documented limitation as tested behavior, not an accident.
upper_fix=$(mk upperfix <<'EOF'
{"plugins":[{"name":"Rel-Plugin","source":{"url":"https://github.com/acme/Rel-Plugin","sha":"cccccccccccccccccccccccccccccccccccccccc"}}]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_upper"
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$upper_fix"
assert_call "git ls-remote -- https://github.com/acme/Rel-Plugin HEAD" "out-of-charset flagged ENTRY falls back to HEAD-tracking"
assert_no_call "gh api" "out-of-charset entry never routes to the releases API"
assert_warn "'Rel-Plugin' is not a valid plugin name" "…and the reconcile surfaces why"
assert_pin_held "$upper_fix" "out-of-charset entry pin held (at HEAD)"

# 28. Config schema is STRICT — every silent-fallback shape dies loudly; the
#     empty list is the one benign shape.
TRACKING_CONFIG_FIXTURE="$TMP/nonexistent-tracking.json"
run_bump_shimmed "$anno_fix"
assert_rc 1 "missing tracking-config file → die"
assert_warn "tracking-config not found" "missing-file die message"
tc_notjson=$(mk_tc tracking-notjson.json <<'EOF'
not json at all
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_notjson"
run_bump_shimmed "$anno_fix"
assert_rc 1 "unparseable tracking-config → die"
assert_warn "tracking-config is invalid" "unparseable-config die message"
tc_badkey=$(mk_tc tracking-badkey.json <<'EOF'
{"releases_only": ["rel-plugin"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_badkey"
run_bump_shimmed "$anno_fix"
assert_rc 1 "typo'd KEY (releases_only) → die, never a silent empty policy"
assert_warn "unknown key(s)" "unknown-key die message"
tc_ws=$(mk_tc tracking-ws.json <<'EOF'
{"releases-only": ["foo bar"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_ws"
run_bump_shimmed "$anno_fix"
assert_rc 1 "whitespace-bearing name → die (would word-split into two flags)"
assert_warn "must not contain whitespace" "whitespace-name die message"
tc_mixed=$(mk_tc tracking-mixed.json <<'EOF'
{"releases-only": ["rel-plugin", 5]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_mixed"
run_bump_shimmed "$anno_fix"
assert_rc 1 "non-string member → die (matches the error message's claim)"
assert_warn "must contain only strings" "mixed-type die message"
tc_empty=$(mk_tc tracking-empty.json <<'EOF'
{"releases-only": []}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_empty"
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_rc 0 "empty releases-only list → clean no-op run"
assert_no_warn "tracking-config" "empty list → no reconcile noise"
assert_call "git ls-remote -- https://github.com/acme/rel-plugin HEAD" "empty list → entry HEAD-tracks as before"

# 28b. owner/repo derivation: a `.git`-suffixed URL must route to the BARE
#      repo (acme/rel-plugin, not acme/rel-plugin.git → a silent 404-hold);
#      a deep URL (extra path segments) hits the derive-failure skip branch.
derive_fix=$(mk derivefix <<'EOF'
{"plugins":[{"name":"relgit","source":{"url":"https://github.com/acme/rel-plugin.git","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},{"name":"reldeep","source":{"url":"https://github.com/acme/rel-plugin/tree/main","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]}
EOF
)
tc_derive=$(mk_tc tracking-derive.json <<'EOF'
{"releases-only": ["relgit", "reldeep"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_derive"
STUB_RELEASES_HTTP=200 STUB_LATEST_TAG="v1.0.0"
STUB_TAG_COMMIT_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
run_bump_shimmed "$derive_fix"
assert_call "gh api repos/acme/rel-plugin/releases/latest" ".git-suffixed URL derives the BARE owner/repo"
assert_no_call "rel-plugin.git/releases" ".git suffix never leaks into the API route (a silent 404-hold shape)"
assert_reason "reldeep" "could not derive owner/repo" "deep URL hits the derive-failure skip branch"
assert_pin_held "$derive_fix" "derivation case pins held"

# 29. Flagged entry on a non-github host: releases/latest is a GitHub concept —
#     visible skip, no silent HEAD-tracking, no API call against a foreign host.
gl_fix=$(mk glfix <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://gitlab.com/acme/rel-plugin","sha":"ffffffffffffffffffffffffffffffffffffffff"}}]}
EOF
)
TRACKING_CONFIG_FIXTURE="$tc_rel"
run_bump_shimmed "$gl_fix"
assert_reason "rel-plugin" "releases-only tracking requires a github.com source" "non-github flagged entry → visible skip, not HEAD-fallback"
assert_no_call "gh api" "non-github flagged entry → no API call"
assert_pin_held "$gl_fix" "non-github flagged entry → pin held"

# 30. No tracking-config (the default): the flagged-in-nothing github entry
#     resolves via ls-remote exactly as before — byte-identical default proof
#     on the resolution path itself (cases 1-14 prove it on the skip paths).
TRACKING_CONFIG_FIXTURE=""
STUB_HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
run_bump_shimmed "$anno_fix"
assert_rc 0 "no config: exits 0"
assert_call "git ls-remote -- https://github.com/acme/rel-plugin HEAD" "no config → ls-remote HEAD resolution"
assert_no_call "gh api" "no config → releases API never consulted"
assert_no_warn "mode=releases-only" "no config → no releases-only mode line"
assert_pin_held "$anno_fix" "no config → pin held at HEAD"

TRACKING_CONFIG_FIXTURE=""  # reset

echo
echo "=== bump-plugin-shas source-owner verification tests ==="

# The verification gate sits AFTER the staleness check and BEFORE any bump
# work (subtree probe / open-PR probe / clone): a stale github.com entry's
# listed owner/repo is resolved via `gh api repos/<owner>/<repo>` and the
# canonical full_name must still match the listed owner (case-insensitive).
# 404 / owner-change / lookup-failure all hold the pin as a visible skip.
# SHA roles: 9999…=stale pin · bbbb…=upstream HEAD (stale trigger).
sv_fix=$(mk svfix <<'EOF'
{"plugins":[{"name":"sv-plugin","source":{"url":"https://github.com/acme/sv-plugin","sha":"9999999999999999999999999999999999999999"}}]}
EOF
)

# 31. Verified source (canonical owner matches, case-insensitively): the gate
#     passes through to the normal bump path (clone — refused by the git stub,
#     so the case stays network-free). Canonical case differs (Acme vs acme):
#     a case-SENSITIVE comparison would wrongly hold this pin.
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="Acme/sv-plugin"
run_bump_shimmed "$sv_fix"
assert_call "gh api repos/acme/sv-plugin" "stale entry consulted the source-verification lookup"
assert_reason "sv-plugin" "clone failed" "verified source passes the gate (reached the clone path)"
assert_no_warn "owner changed" "case-only difference is NOT an owner change"
assert_pin_held "$sv_fix" "verified-source case: pin unchanged (clone refused)"

# 32. Source repo 404: definitive unavailability — visible hold, no clone.
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=404
run_bump_shimmed "$sv_fix"
assert_rc 0 "404 source: run exits 0 (per-entry hold, not a run failure)"
assert_reason "sv-plugin" "not found (HTTP 404) — source unavailable; pin held" "404 → visible source-unavailable hold"
assert_no_call "git clone" "404 → no clone attempted"
assert_pin_held "$sv_fix" "404 → pin held"

# 33. Owner changed upstream (the redirect case): canonical full_name resolves
#     under a DIFFERENT owner → the pin must hold, naming both sides.
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="newowner/sv-plugin"
run_bump_shimmed "$sv_fix"
assert_reason "sv-plugin" "owner changed upstream" "owner change → pin held"
assert_reason "sv-plugin" "newowner/sv-plugin" "hold reason names the canonical location"
assert_no_call "git clone" "owner change → no clone attempted"
assert_pin_held "$sv_fix" "owner change → pin held"

# 34. Transient lookup failure (403 rate limit): FAIL CLOSED — cannot verify,
#     do not advance; the reason names the real cause (never misreported as
#     an unavailable source).
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=403
run_bump_shimmed "$sv_fix"
assert_reason "sv-plugin" "lookup failed (HTTP 403) — cannot verify source; pin held" "transient failure → fail-closed hold with the HTTP status"
assert_no_warn "source unavailable" "403 is never misreported as an unavailable source"
assert_no_call "git clone" "unverifiable source → no clone"
assert_pin_held "$sv_fix" "unverifiable source → pin held"

# 35. Repo renamed WITHIN the same owner: same namespace, same publisher —
#     the bump PROCEEDS (reaches clone) with a loud refresh-the-URL warning.
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/sv-plugin-renamed"
run_bump_shimmed "$sv_fix"
assert_warn "renamed within the same owner" "same-owner rename warns (URL refresh nudge)"
assert_reason "sv-plugin" "clone failed" "same-owner rename does NOT hold the pin (reached the clone path)"
assert_pin_held "$sv_fix" "same-owner rename: pin unchanged (clone refused)"

# 36. Non-github host: the gate is github.com-scoped — a stale gitlab entry
#     goes straight to the normal bump path with NO repos/ lookup. STUB_SOURCE_*
#     stay deliberately unset: a lookup would trip the stub's need-guard and
#     the drift check would fail this case loudly.
gl_sv_fix=$(mk glsvfix <<'EOF'
{"plugins":[{"name":"gl-plugin","source":{"url":"https://gitlab.com/acme/gl-plugin","sha":"9999999999999999999999999999999999999999"}}]}
EOF
)
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
run_bump_shimmed "$gl_sv_fix"
assert_no_call "gh api repos/" "non-github host → verification lookup not consulted"
assert_reason "gl-plugin" "clone failed" "non-github entry proceeds on the normal path"

# 37. At-pin entry: the gate costs ZERO api calls when there is nothing to
#     bump (placement after the staleness check is the api-budget bound).
STUB_HEAD_SHA="9999999999999999999999999999999999999999"
run_bump_shimmed "$sv_fix"
assert_rc 0 "at-pin: exits 0 (Nothing to bump)"
assert_no_call "gh api repos/" "at-pin → no verification lookup (post-staleness placement)"
assert_skipped_count 0 "at-pin → no skips"

echo
echo "=== bump-plugin-shas owner-identity (baseline) tests ==="

# The identity leg: with an owner baseline committed, the gate ALSO compares the
# live owner's account id (from the same repos/ response) against the recorded
# one. full_name alone cannot see a RE-REGISTERED owner — the login is freed and
# re-taken and a repo is created at the listed path, so the location checks all
# pass; the account id is the discriminator. No baseline file (cases 31-37 above)
# → the leg is inactive, pinning the callers-without-a-baseline default.
sv_baseline=$(mk_tc owner-baseline.json <<'EOF'
{"schema": 1, "owners": {"acme": {"id": 1010, "type": "Organization"}}}
EOF
)

# 38. Identity verified (recorded id == live id) → the gate passes through to
#     the normal bump path (clone, refused by the git stub), no baseline noise.
OWNER_BASELINE_FIXTURE="$sv_baseline"
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/sv-plugin" STUB_SOURCE_OWNER_ID=1010
run_bump_shimmed "$sv_fix"
assert_reason "sv-plugin" "clone failed" "matching account id passes the identity leg (reached the clone path)"
assert_no_warn "not in the owner baseline" "baselined owner → no unbaselined warning"
assert_pin_held "$sv_fix" "identity-verified case: pin unchanged (clone refused)"

# 39. Identity CHANGED (recorded 1010, live 2020 — the re-registered-owner
#     class): hold the pin loudly, no clone. This is the race the location
#     checks cannot see (no redirect; the repo genuinely sits at the listed path).
OWNER_BASELINE_FIXTURE="$sv_baseline"
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/sv-plugin" STUB_SOURCE_OWNER_ID=2020
run_bump_shimmed "$sv_fix"
assert_reason "sv-plugin" "different account id (recorded 1010, live 2020)" "id mismatch → identity hold naming both ids"
assert_no_call "git clone" "id mismatch → no clone attempted"
assert_pin_held "$sv_fix" "id mismatch → pin held"

# 40. Owner ABSENT from the baseline → warn-and-proceed: the entry was
#     human-reviewed when added; holding would false-hold every new entry until
#     the next baseline refresh merges. The warning keeps the not-yet-pinned
#     state observable.
sv_baseline_other=$(mk_tc owner-baseline-other.json <<'EOF'
{"schema": 1, "owners": {"otherorg": {"id": 42, "type": "User"}}}
EOF
)
OWNER_BASELINE_FIXTURE="$sv_baseline_other"
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/sv-plugin" STUB_SOURCE_OWNER_ID=1010
run_bump_shimmed "$sv_fix"
assert_warn "not in the owner baseline" "unbaselined owner warns (identity pin not yet active)"
assert_reason "sv-plugin" "clone failed" "unbaselined owner still proceeds (reached the clone path)"

# 41. Recorded id present but the response carries NO usable owner id →
#     FAIL CLOSED (cannot verify the identity the baseline pins).
OWNER_BASELINE_FIXTURE="$sv_baseline"
STUB_HEAD_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
STUB_SOURCE_HTTP=200 STUB_SOURCE_FULL_NAME="acme/sv-plugin" STUB_SOURCE_OWNER_ID=none
run_bump_shimmed "$sv_fix"
assert_reason "sv-plugin" "identity could not be verified" "recorded id + missing live id → fail-closed hold"
assert_no_call "git clone" "unverifiable identity → no clone"
assert_pin_held "$sv_fix" "unverifiable identity → pin held"

OWNER_BASELINE_FIXTURE=""  # reset

echo
echo "=== $((total-failures))/$total passed ==="
[[ "$failures" -eq 0 ]]
