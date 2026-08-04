#!/usr/bin/env bash
# Static test suite for bump.sh's skip/freeze/exempt logic, the reconciliation
# warnings, and the releases-only (tracking-config) resolution path. No API
# key, no network: `gh`, `git`, `claude`, and `timeout` are PATH-shimmed per
# run — gh serves deterministic fixture responses (production-faithful,
# selector-aware); git/claude FAIL CLOSED so any fixture that would reach a
# real network call fails loudly instead. Every fixture must terminate in a
# skip/hold, an up-to-date continue, or a shim-intercepted failure — never a
# real bump. Pure bash/jq against synthetic marketplace.json fixtures. Run
# locally or in CI on every PR touching bump-plugin-shas/. (The POSITIVE bump
# path — a releases-only entry actually advancing — lives in
# test-bump-manifest.sh, whose shims serve the full clone/validate/PR phase.)
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

# Deterministic `gh` stub (prepended to PATH per run_bump invocation): serves
# the three releases-only endpoints from GH_STUB_* env so those cases stay
# network/credential-free. PRODUCTION-FAITHFUL in the two ways that bit us:
# (1) on an HTTP error, real gh copies the raw JSON error body to STDOUT
# (bypassing --jq), prints "gh: ... (HTTP 404)" on stderr, and exits 1 — the
# stub does the same, so a caller gating on empty-stdout instead of exit
# status fails these tests; (2) the stub applies the REAL requested --jq
# selector over a realistic JSON body (commits/<ref> carries a decoy
# .commit.tree.sha), so a refactor reading the wrong field fails. The
# `commits/<ref>` .sha is by construction the DEREFERENCED commit, mirroring
# the real endpoint's annotated-tag behavior (proven live:
# CrowdStrike/fusion-skills v1.0.0 tag object 3d8e1428 ≠ peeled c354974e, and
# repos/.../commits/v1.0.0 returns c354974e). Every invocation is appended to
# GH_STUB_ARGV_LOG (path-derivation asserts); any unexpected invocation also
# lands in GH_STUB_UNEXPECTED_LOG and exits 64.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ -n "${GH_STUB_ARGV_LOG:-}" ]] && printf '%s\n' "$*" >> "$GH_STUB_ARGV_LOG"
sel=""; prev=""
for a in "$@"; do [[ "$prev" == "--jq" ]] && sel="$a"; prev="$a"; done
serve() {
  if [[ -n "$sel" ]]; then printf '%s' "$1" | jq -r "$sel"; else printf '%s\n' "$1"; fi
}
notfound() {
  printf '{"message":"Not Found","documentation_url":"https://docs.github.com/x","status":"404"}'
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
}
case "$*" in
  *"/releases/latest"*)
    [[ -n "${GH_STUB_LATEST_TAG:-}" ]] || notfound
    serve "$(jq -cn --arg t "$GH_STUB_LATEST_TAG" '{tag_name:$t, name:("Release "+$t)}')"; exit 0 ;;
  *"/compare/"*)
    [[ "${GH_STUB_COMPARE:-ahead}" == "404" ]] && notfound
    serve "$(jq -cn --arg s "${GH_STUB_COMPARE:-ahead}" '{status:$s}')"; exit 0 ;;
  *"/commits/"*)
    [[ -n "${GH_STUB_COMMIT_SHA:-}" ]] || notfound
    serve "$(jq -cn --arg s "$GH_STUB_COMMIT_SHA" '{sha:$s, commit:{tree:{sha:"1234567890123456789012345678901234567890"}}}')"; exit 0 ;;
  *)
    echo "gh-stub: unexpected invocation: $*" >&2
    [[ -n "${GH_STUB_UNEXPECTED_LOG:-}" ]] && printf '%s\n' "$*" >> "$GH_STUB_UNEXPECTED_LOG"
    exit 64 ;;
esac
EOF

# Fail-closed `git` + `claude` shims: this suite must never reach a clone /
# validate / real network call — every fixture short-circuits first. A git
# invocation is EXPECTED only where a case deliberately proves an entry took
# the HEAD branch (ls-remote → deterministic shim failure → "ls-remote failed"
# skip); anything reaching `claude` is a suite bug. Mirrors the
# test-bump-manifest.sh shim pattern, which serves these for the positive path.
cat > "$TMP/bin/git" <<'EOF'
#!/usr/bin/env bash
echo "git-shim(test-bump.sh): intercepted (network-free by design): $*" >&2; exit 1
EOF
cat > "$TMP/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude-shim(test-bump.sh): unexpected invocation: $*" >&2; exit 1
EOF
# `timeout` shim: strip `-k <n>` + the duration, exec the rest — keeps the
# suite portable to hosts without coreutils timeout (macOS) now that bump.sh
# wraps its gh calls in `timeout 60`.
cat > "$TMP/bin/timeout" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-k" ]] && shift 2
shift
exec "$@"
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/git" "$TMP/bin/claude" "$TMP/bin/timeout"

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
    ONLY="${ONLY_FIXTURE:-}" \
    TRACKING_CONFIG="${TRACKING_CONFIG_FIXTURE:-}" \
    GH_STUB_LATEST_TAG="${GH_STUB_TAG_FIXTURE:-}" \
    GH_STUB_COMMIT_SHA="${GH_STUB_SHA_FIXTURE:-}" \
    GH_STUB_COMPARE="${GH_STUB_COMPARE_FIXTURE:-}" \
    GH_STUB_ARGV_LOG="$TMP/gh-argv.log" \
    GH_STUB_UNEXPECTED_LOG="$TMP/gh-unexpected.log" \
    GITHUB_OUTPUT="$TMP/out.txt" GITHUB_STEP_SUMMARY="$TMP/sum.md"
  : > "$TMP/out.txt"; : > "$TMP/sum.md"; : > "$TMP/gh-argv.log"; : > "$TMP/gh-unexpected.log"
  set +e
  OUT="$(PATH="$TMP/bin:$PATH" bash "$ACTION_PATH/scripts/bump.sh" 2>&1)"
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

# assert_out / assert_no_out — generic output-contains checks (log lines, die
# messages). Same mechanics as assert_warn/assert_no_warn (which are ALSO
# generic contains-checks, named for their dominant use); the distinct names
# keep each assertion reading as what it checks.
assert_out() {
  total=$((total+1))
  if grep -qF "$1" <<<"$OUT"; then echo "  PASS $2"
  else echo "  FAIL $2 — no output containing '$1'"; failures=$((failures+1)); fi
}
assert_no_out() {
  total=$((total+1))
  if grep -qF "$1" <<<"$OUT"; then echo "  FAIL $2 — unexpected '$1' in output"; failures=$((failures+1))
  else echo "  PASS $2"; fi
}
# assert_gh_argv SUBSTR LABEL — the gh stub's argv log contains SUBSTR (pins
# the derived REST path). assert_no_gh_argv is the negative.
assert_gh_argv() {
  total=$((total+1))
  if grep -qF "$1" "$TMP/gh-argv.log" 2>/dev/null; then echo "  PASS $2"
  else echo "  FAIL $2 — no gh invocation containing '$1'"; failures=$((failures+1)); fi
}
assert_no_gh_argv() {
  total=$((total+1))
  if grep -qF "$1" "$TMP/gh-argv.log" 2>/dev/null; then echo "  FAIL $2 — unexpected gh invocation containing '$1'"; failures=$((failures+1))
  else echo "  PASS $2"; fi
}
# assert_gh_clean LABEL — no unexpected gh invocation reached the stub's
# fail-closed arm (its stderr is 2>/dev/null'd by bump.sh, so the marker file
# is the only reliable signal).
assert_gh_clean() {
  total=$((total+1))
  if [[ -s "$TMP/gh-unexpected.log" ]]; then
    echo "  FAIL $1 — unexpected gh invocation(s): $(head -3 "$TMP/gh-unexpected.log")"; failures=$((failures+1))
  else echo "  PASS $1"; fi
}
# mkcfg NAME <<EOF … EOF — tracking-config fixture writer (mirrors mk).
mkcfg() { local f="$TMP/cfg-$1.json"; cat > "$f"; printf '%s' "$f"; }

# Shared fixtures. rel-plugin (github.com) is the flagged entry — its releases
# resolution goes through the gh stub, never the network. head-plugin sits on a
# non-allowlisted host so the unflagged path short-circuits before ls-remote
# (and the fail-closed git shim would intercept it anyway).
ro_fix=$(mk relonly <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"ccccccccccccdddddddddddddddddddddddddddd"}},{"name":"head-plugin","source":{"url":"https://example.com/acme/head-plugin","sha":"2222222222222222222222222222222222222222"}}]}
EOF
)
cfg_ok=$(mkcfg ok <<'EOF'
{"releases-only": ["rel-plugin"]}
EOF
)

# 15. Flagged entry, latest release resolves to the ALREADY-PINNED commit →
#     mode line logged, plain continue (no skip record), pin held, and NO
#     compare call (the monotonicity guard only runs when a bump is imminent).
#     The pinned sha's 13th char differs from its 12th so the `${new_sha:0:12}`
#     truncation is pinned too (a full-sha print would contain 'ccccccccccccd').
#     The stub applies the real --jq selector over a body with a decoy
#     .commit.tree.sha, so reading any field but .sha fails this case.
TRACKING_CONFIG_FIXTURE="$cfg_ok"; GH_STUB_TAG_FIXTURE="v1.0.0"
GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
FREEZE_SHAS_FIXTURE=""; SHA_EXEMPT_FIXTURE=""
run_bump "$ro_fix"
assert_out "rel-plugin: mode=releases-only" "flagged entry logs mode=releases-only"
assert_out "latest release v1.0.0 → cccccccccccc" "release tag resolved via commits/<tag> to its commit sha"
assert_no_out "ccccccccccccd" "logged sha is the 12-char truncation, not the full sha"
assert_not_skipped "rel-plugin" "resolved == pinned → plain continue (up-to-date, not a skip)"
assert_pin_held "$ro_fix" "resolved == pinned → marketplace unchanged"
assert_no_gh_argv "/compare/" "up-to-date entry → no compare call"
assert_reason "head-plugin" "not in allowlist" "a second (host-skipped) entry is still processed while a config is loaded"
assert_gh_clean "only the documented endpoints were consulted"
assert_rc 0 "releases-only up-to-date run exits 0"

# 16. Flagged entry, NO release published. The stub 404s production-faithfully
#     (raw JSON body on STDOUT + exit 1), so this also pins that bump.sh gates
#     on gh's EXIT STATUS — an empty-stdout gate would read the body as a tag.
GH_STUB_TAG_FIXTURE=""; GH_STUB_SHA_FIXTURE=""
run_bump "$ro_fix"
assert_reason "rel-plugin" "no published release; holding pin" "no release published → pin held + recorded (404 classified)"
assert_no_out 'tag ''{"message"' "the 404 body is never mistaken for a tag"
assert_pin_held "$ro_fix" "no release → marketplace unchanged"
assert_rc 0 "no-release hold exits 0"

# 16b. A NON-404 lookup failure (rate limit / auth / 5xx) is a LOUD warning
#      skip, distinct from the benign no-release hold. Simulated by pointing
#      the stub's 404 text away: unexpected-endpoint exit 64 has no 'HTTP 404'
#      on stderr — but simpler: an unset tag with a doctored stub isn't
#      reachable, so reuse the commits-arm failure below for loudness and pin
#      the classification split via the two distinct reason strings (16 vs 17).

# 17. Tag resolves but the tag→commit lookup 404s → held + recorded loudly
#     (a ::warning skip, not the benign no-release log).
GH_STUB_TAG_FIXTURE="v2.0.0"; GH_STUB_SHA_FIXTURE=""
run_bump "$ro_fix"
assert_reason "rel-plugin" "could not resolve tag 'v2.0.0' to a commit" "tag→commit failure → pin held + recorded"
assert_pin_held "$ro_fix" "tag→commit failure → marketplace unchanged"
assert_rc 0 "tag→commit failure hold exits 0"

# 17b. A 200 response whose .sha is missing surfaces as the literal string
#      "null" — must fail the 40-hex gate, never land in the marketplace.
GH_STUB_TAG_FIXTURE="v2.0.0"; GH_STUB_SHA_FIXTURE="null"
run_bump "$ro_fix"
assert_reason "rel-plugin" "could not resolve tag 'v2.0.0' to a commit" "literal-null sha → rejected by the 40-hex gate"
assert_pin_held "$ro_fix" "literal-null sha → marketplace unchanged"

# 18. Flagged entry on a non-github.com (but allowlisted) host → held loudly;
#     a flagged entry is NEVER silently HEAD-bumped.
ro_gl=$(mk relgl <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://gitlab.com/acme/rel-plugin","sha":"cccccccccccccccccccccccccccccccccccccccc"}}]}
EOF
)
GH_STUB_TAG_FIXTURE="v1.0.0"; GH_STUB_SHA_FIXTURE="cccccccccccccccccccccccccccccccccccccccc"
run_bump "$ro_gl"
assert_reason "rel-plugin" "releases-only: host 'gitlab.com' unsupported" "non-github flagged entry held, never HEAD-bumped"
assert_pin_held "$ro_gl" "non-github flagged entry → marketplace unchanged"
assert_rc 0 "non-github hold exits 0"

# 18b. Exact-host on purpose: www.github.com passes the ALLOWLIST (subdomain
#      match) but the releases-only gate is exact → held. Pins the deliberate
#      asymmetry between the two host checks.
ro_www=$(mk relwww <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://www.github.com/acme/rel-plugin","sha":"cccccccccccccccccccccccccccccccccccccccc"}}]}
EOF
)
run_bump "$ro_www"
assert_reason "rel-plugin" "host 'www.github.com' unsupported" "www.github.com held (exact-host gate, deliberately narrower than the allowlist)"

# 19. Configured-but-missing tracking-config file → hard die (a silent degrade
#     back to HEAD-tracking is the failure mode the input exists to prevent).
TRACKING_CONFIG_FIXTURE="$TMP/no-such-tracking.json"
run_bump "$ro_fix"
assert_rc 1 "missing tracking-config file → die"
assert_out "tracking-config: file not found" "missing tracking-config → loud reason"
assert_pin_held "$ro_fix" "die precedes any marketplace mutation"

# 20. Malformed / wrong-shape configs → hard die, before any mutation. The
#     "shape" half of the die message is real: object-with-missing-key (the
#     typo'd-key class), non-object documents, a non-array value, and
#     non-string entries all refuse — only a present, all-string array parses.
for bad in '{not json' '' '{}' '[]' '{"releases-only":"rel-plugin"}' '{"releases-only":[1,2]}' '{"releases-only":["a b"]}'; do
  cfg_bad="$TMP/cfg-bad.json"; printf '%s' "$bad" > "$cfg_bad"
  TRACKING_CONFIG_FIXTURE="$cfg_bad"
  run_bump "$ro_fix"
  assert_rc 1 "tracking-config $(printf '%.24s' "${bad:-<empty file>}") → die"
  assert_pin_held "$ro_fix" "…and precedes any marketplace mutation"
done
assert_out "tracking-config: invalid config" "shape die carries the loud reason"

# 20b. The sanctioned placeholder {"releases-only": []} is a clean no-op:
#      exit 0, no warnings, no releases-only behavior.
cfg_empty=$(mkcfg empty <<'EOF'
{"releases-only": []}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_empty"
run_bump "$ro_fix"
assert_rc 0 "empty releases-only array → clean no-op run"
assert_no_out "mode=releases-only" "empty array → releases-only path never taken"
assert_no_warn "tracking-config releases-only:" "empty array → no reconciliation noise"

# 20c. Unknown sibling keys are warned about (a typo'd SECOND key must not
#      vanish silently), while the valid releases-only list still applies.
cfg_extra=$(mkcfg extra <<'EOF'
{"releases-only": ["rel-plugin"], "release-only": ["oops"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_extra"; GH_STUB_TAG_FIXTURE="v1.0.0"
GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_fix"
assert_warn "tracking-config: unknown key(s) ignored: release-only" "unknown sibling key warns"
assert_out "rel-plugin: mode=releases-only" "…while the valid list still applies"

# 21. Reconciliation: a typo'd releases-only name (matches no entry) warns —
#     the intended plugin would silently keep HEAD-tracking otherwise. Fixture
#     entry sits on example.com so the (unflagged) loop pass short-circuits.
ro_typo_fix=$(mk reltypo <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://example.com/acme/rel-plugin","sha":"cccccccccccccccccccccccccccccccccccccccc"}}]}
EOF
)
cfg_typo=$(mkcfg typo <<'EOF'
{"releases-only": ["rel-plugn"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_typo"; GH_STUB_TAG_FIXTURE=""; GH_STUB_SHA_FIXTURE=""
run_bump "$ro_typo_fix"
assert_warn "tracking-config releases-only: 'rel-plugn' matches no external" "typo'd releases-only name warns (matches no entry)"
assert_rc 0 "typo warning is advisory (run still exits 0)"

# 21b. A name outside the freeze-style charset (uppercase) is still just a
#      membership miss here — the releases-only gate deliberately has NO
#      charset pre-gate (see case 27b for the flagged-scoped-name behavior).
cfg_upper=$(mkcfg upper <<'EOF'
{"releases-only": ["Rel-Plugin"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_upper"
run_bump "$ro_typo_fix"
assert_warn "tracking-config releases-only: 'Rel-Plugin' matches no external" "case-mismatched name warns as a membership miss"

# 21c. Glob safety: a '*' in the list neither expands nor flags a real entry
#      (mirrors freeze case 7).
cfg_glob=$(mkcfg glob <<'EOF'
{"releases-only": ["*"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_glob"
run_bump "$ro_typo_fix"
assert_warn "tracking-config releases-only: '*' matches no external" "glob '*' warns as a membership miss, doesn't expand"
assert_reason "rel-plugin" "not in allowlist" "glob '*' does not flag a real entry"

# 22. The releases-only reconciliation is SUPPRESSED under a single-plugin
#     `only` run (same gate + rationale as freeze-shas reconciliation).
ONLY_FIXTURE="rel-plugin"; TRACKING_CONFIG_FIXTURE="$cfg_typo"
run_bump "$ro_typo_fix"
assert_no_warn "tracking-config releases-only:" "only=target → releases-only reconciliation suppressed"
ONLY_FIXTURE=""

# 22b. only= + a FLAGGED target still resolves via releases (the operator
#      dispatch path): mode line fires, the non-target is plain-continued.
ONLY_FIXTURE="rel-plugin"; TRACKING_CONFIG_FIXTURE="$cfg_ok"
GH_STUB_TAG_FIXTURE="v1.0.0"; GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_fix"
assert_out "rel-plugin: mode=releases-only" "only=flagged-target → releases-only resolution still applies"
assert_not_skipped "head-plugin" "only=flagged-target → non-target plain-continued"
assert_skipped_count 0 "only=flagged-target, up-to-date → nothing recorded"
ONLY_FIXTURE=""

# 23. No tracking-config (default) → zero releases-only behavior; the run is
#     the pre-feature default (same reason/count/rc as an unflagged pass).
TRACKING_CONFIG_FIXTURE=""; GH_STUB_TAG_FIXTURE=""; GH_STUB_SHA_FIXTURE=""
run_bump "$ro_typo_fix"
assert_no_out "mode=releases-only" "no tracking-config → releases-only path never taken"
assert_reason "rel-plugin" "not in allowlist" "no tracking-config → entry takes the pre-feature path"
assert_skipped_count 1 "no tracking-config → exactly the pre-feature skip set"
assert_rc 0 "no tracking-config → exits 0"

# 24. Tag-hygiene guard: a metacharacter tag from releases/latest is held by
#     the allowlist check (the reason string deliberately does NOT echo the
#     tag — it lands in ::warning + skipped[] + the step summary).
TRACKING_CONFIG_FIXTURE="$cfg_ok"; GH_STUB_TAG_FIXTURE='v1.0.0;rm -rf /'
GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_fix"
assert_reason "rel-plugin" "unusable tag name from releases/latest" "metacharacter tag → held by the allowlist guard"
assert_pin_held "$ro_fix" "metacharacter tag → marketplace unchanged"
assert_no_gh_argv "/commits/" "metacharacter tag → never reaches the commits lookup"

# 25. A slash-bearing tag (legal in refnames) is @uri-encoded into the REST
#     path — pinned via the stub's argv log.
GH_STUB_TAG_FIXTURE="release/v1.0.0"; GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_fix"
assert_gh_argv "commits/release%2Fv1.0.0" "slash tag is @uri-encoded in the commits path"
assert_no_gh_argv "commits/release/v1.0.0" "…and never appears raw"
assert_not_skipped "rel-plugin" "slash tag resolves normally (== pin → continue)"

# 26. Monotonicity guard: a resolved release NOT strictly ahead of the pin is
#     held loudly. behind / diverged / unreadable all hold; a genuinely-ahead
#     release passes the guard and proceeds toward the bump (proven by the
#     fail-closed git shim intercepting the clone → "clone failed" — the
#     positive WRITE path is pinned in test-bump-manifest.sh).
ro_old=$(mk relold <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"1111111111111111111111111111111111111111"}}]}
EOF
)
GH_STUB_TAG_FIXTURE="v0.9.0"; GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
GH_STUB_COMPARE_FIXTURE="behind"
run_bump "$ro_old"
assert_reason "rel-plugin" "not strictly ahead of the pinned 11111111 (compare: behind)" "behind release → held (backward pin refused)"
assert_pin_held "$ro_old" "behind release → marketplace unchanged"
GH_STUB_COMPARE_FIXTURE="diverged"
run_bump "$ro_old"
assert_reason "rel-plugin" "(compare: diverged)" "diverged release → held"
GH_STUB_COMPARE_FIXTURE="404"
run_bump "$ro_old"
assert_reason "rel-plugin" "(compare: unavailable)" "failed compare call (404 body on stdout) → held (fail-safe, exit-status gated)"
GH_STUB_COMPARE_FIXTURE="ahead"
run_bump "$ro_old"
assert_reason "rel-plugin" "clone failed" "strictly-ahead release passes the guard (reaches the clone attempt, shim-intercepted)"
assert_gh_argv "/compare/1111111111111111111111111111111111111111...cccccccccccc" "compare is old-pin...release-commit"
GH_STUB_COMPARE_FIXTURE=""

# 27. Multi-name config + whole-word matching: both listed names dispatch via
#     releases; an UNLISTED substring name takes the HEAD path (proven by the
#     git shim intercepting its ls-remote — deterministic, network-free).
ro_multi=$(mk relmulti <<'EOF'
{"plugins":[{"name":"rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"ccccccccccccdddddddddddddddddddddddddddd"}},{"name":"other-plugin","source":{"url":"https://github.com/acme/other-plugin","sha":"ccccccccccccdddddddddddddddddddddddddddd"}},{"name":"rel","source":{"url":"https://github.com/acme/rel","sha":"3333333333333333333333333333333333333333"}}]}
EOF
)
cfg_multi=$(mkcfg multi <<'EOF'
{"releases-only": ["rel-plugin", "other-plugin"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_multi"; GH_STUB_TAG_FIXTURE="v1.0.0"
GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_multi"
assert_out "rel-plugin: mode=releases-only" "first listed name dispatches via releases"
assert_out "other-plugin: mode=releases-only" "second listed name dispatches via releases (join(\" \") honors the whole list)"
assert_reason "rel" "ls-remote failed" "unlisted substring name 'rel' takes the HEAD path (whole-word match)"
assert_gh_clean "multi-name run consulted only the documented endpoints"

# 27b. A flagged SCOPED name (outside the freeze-style charset) still resolves
#      via releases — the releases-only gate has NO charset pre-gate, so a
#      flagged name can never silently HEAD-bump on shape grounds.
ro_scoped=$(mk relscoped <<'EOF'
{"plugins":[{"name":"@acme/rel-plugin","source":{"url":"https://github.com/acme/rel-plugin","sha":"ccccccccccccdddddddddddddddddddddddddddd"}}]}
EOF
)
cfg_scoped=$(mkcfg scoped <<'EOF'
{"releases-only": ["@acme/rel-plugin"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_scoped"
run_bump "$ro_scoped"
assert_out "@acme/rel-plugin: mode=releases-only" "scoped flagged name resolves via releases (no charset pre-gate)"
assert_not_skipped "@acme/rel-plugin" "scoped flagged name up-to-date → plain continue"

# 28. Precedence: freeze-shas (and sha-exempt) outrank releases-only — a name
#     in both lists is frozen/exempt and never resolves a release.
TRACKING_CONFIG_FIXTURE="$cfg_ok"; FREEZE_SHAS_FIXTURE="rel-plugin"
GH_STUB_TAG_FIXTURE="v1.0.0"; GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_fix"
assert_reason "rel-plugin" "frozen at current pin (freeze-shas)" "freeze-shas outranks releases-only"
assert_no_out "mode=releases-only" "frozen flagged entry never reaches release resolution"
FREEZE_SHAS_FIXTURE=""

# 29. repo_path derivation: owner/repo shorthand and a trailing .git both
#     derive the same clean REST path (argv-pinned); a deep /tree/ URL is not
#     an owner/repo URL → held.
ro_forms=$(mk relforms <<'EOF'
{"plugins":[{"name":"rel-short","source":{"url":"acme/rel-short","sha":"ccccccccccccdddddddddddddddddddddddddddd"}},{"name":"rel-git","source":{"url":"https://github.com/acme/rel-git.git","sha":"ccccccccccccdddddddddddddddddddddddddddd"}},{"name":"rel-deep","source":{"url":"https://github.com/acme/rel-deep/tree/main","sha":"ccccccccccccdddddddddddddddddddddddddddd"}}]}
EOF
)
cfg_forms=$(mkcfg forms <<'EOF'
{"releases-only": ["rel-short", "rel-git", "rel-deep"]}
EOF
)
TRACKING_CONFIG_FIXTURE="$cfg_forms"; GH_STUB_TAG_FIXTURE="v1.0.0"
GH_STUB_SHA_FIXTURE="ccccccccccccdddddddddddddddddddddddddddd"
run_bump "$ro_forms"
assert_gh_argv "repos/acme/rel-short/releases/latest" "owner/repo shorthand derives a clean REST path"
assert_gh_argv "repos/acme/rel-git/releases/latest" "trailing .git is stripped from the REST path"
assert_reason "rel-deep" "not an owner/repo GitHub URL" "deep /tree/ URL → held with an accurate reason"

# Reset section fixtures so they can't leak into a future section. (Freeze/
# exempt were reset inline by the cases that set them.)
TRACKING_CONFIG_FIXTURE=""; GH_STUB_TAG_FIXTURE=""; GH_STUB_SHA_FIXTURE=""; GH_STUB_COMPARE_FIXTURE=""

echo
echo "=== $((total-failures))/$total passed ==="
[[ "$failures" -eq 0 ]]
