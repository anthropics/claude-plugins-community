#!/usr/bin/env bash
# Hermetic test suite for sweep.sh. Network-free: `gh` is a PATH shim answering
# the two batched GraphQL shapes from per-case fixture files. Any un-modeled
# call appends a STUB-UNEXPECTED sentinel that the per-case drift guard turns
# into a failure. Pure bash/jq against synthetic marketplace fixtures — run
# locally or in CI on every PR touching this action.

set -euo pipefail
cd "$(dirname "$0")"
ACTION_PATH="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
failures=0; total=0

# ── gh shim ──────────────────────────────────────────────────────────────────
# `gh api graphql --input <file>`: discriminated on the query body —
# repositoryOwner( → $STUB_OWNERS_RESP, else repository( → $STUB_REPOS_RESP.
# (Order matters: "repository(" is a substring of "repositoryOwner(".)
# Payloads are logged for query-content assertions.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "${STUB_CALL_LOG:-/dev/null}"
if [[ "${1:-}" == "api" && "${2:-}" == "graphql" && "${3:-}" == "--input" ]]; then
  q="$(cat "${4:-/dev/null}" 2>/dev/null || true)"
  printf '%s\n' "$q" >> "${STUB_PAYLOAD_LOG:-/dev/null}"
  if grep -qF "repositoryOwner(" <<<"$q"; then
    cat "${STUB_OWNERS_RESP:?}"
  elif grep -qF "repository(" <<<"$q"; then
    cat "${STUB_REPOS_RESP:?}"
  else
    echo "STUB-UNEXPECTED graphql query" >> "${STUB_CALL_LOG:-/dev/null}"; exit 12
  fi
  exit 0
fi
echo "STUB-UNEXPECTED gh $*" >> "${STUB_CALL_LOG:-/dev/null}"; exit 12
EOF
chmod +x "$TMP/bin/gh"
export STUB_CALL_LOG="$TMP/calls.log" STUB_PAYLOAD_LOG="$TMP/payloads.log"

# ── fixtures ─────────────────────────────────────────────────────────────────
# alpha+beta under owner acme (listed spelling "Acme"/"acme"), gamma under
# otherorg; a gitlab entry, a local ./ entry, and a deep github URL that must
# land in unparseable — never silently vanish.
cat > "$TMP/marketplace.json" <<'EOF'
{"plugins":[
 {"name":"alpha","source":{"url":"https://github.com/Acme/alpha.git","sha":"1111111111111111111111111111111111111111"}},
 {"name":"beta","source":{"url":"https://github.com/acme/beta","sha":"2222222222222222222222222222222222222222"}},
 {"name":"gamma","source":{"url":"https://github.com/OtherOrg/gamma","sha":"3333333333333333333333333333333333333333"}},
 {"name":"gl","source":{"url":"https://gitlab.com/acme/gl","sha":"4444444444444444444444444444444444444444"}},
 {"name":"vendored","source":"./vendored"},
 {"name":"deep","source":{"url":"https://github.com/acme/alpha/tree/main","sha":"5555555555555555555555555555555555555555"}}
]}
EOF

# Owner aliases follow owners.json order (group_by(owner_lc): acme, otherorg);
# repo aliases follow repos.json order (acme/alpha, acme/beta, otherorg/gamma).
owners_live() { cat > "$TMP/owners.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4999},
 "o0":{"__typename":"Organization","login":"Acme","databaseId":111},
 "o1":{"__typename":"User","login":"OtherOrg","databaseId":222}}}
EOF
}
repos_clean() { cat > "$TMP/repos.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4998},
 "r0":{"nameWithOwner":"Acme/alpha"},
 "r1":{"nameWithOwner":"Acme/beta"},
 "r2":{"nameWithOwner":"OtherOrg/gamma"}}}
EOF
}
export STUB_OWNERS_RESP="$TMP/owners.resp" STUB_REPOS_RESP="$TMP/repos.resp"

# run_sweep MODE BASELINE — runs sweep.sh with the shim first on PATH; captures
# OUT/RC, findings JSON path in FIND, and runs the stub-drift guard.
FIND="$TMP/findings.json"
run_sweep() {
  local mode="$1" baseline="$2" rc=0
  : > "$STUB_CALL_LOG"; : > "$STUB_PAYLOAD_LOG"
  set +e
  OUT="$(PATH="$TMP/bin:$PATH" \
    MARKETPLACE_PATH="$TMP/marketplace.json" BASELINE_PATH="$baseline" \
    MODE="$mode" FINDINGS_PATH="$FIND" GITHUB_STEP_SUMMARY="$TMP/sum.md" \
    GITHUB_OUTPUT="$TMP/out.txt" \
    bash "$ACTION_PATH/scripts/sweep.sh" 2>&1)"
  RC=$?
  set -e
  total=$((total+1))
  if grep -q '^STUB-' "$STUB_CALL_LOG" 2>/dev/null; then
    echo "  FAIL stub-drift guard — $(grep '^STUB-' "$STUB_CALL_LOG" | head -1)"; failures=$((failures+1))
  else
    echo "  PASS stub-drift guard"
  fi
}

assert_eq() {  # got expected label
  total=$((total+1))
  if [[ "$1" == "$2" ]]; then echo "  PASS $3"
  else echo "  FAIL $3 — got '$1', expected '$2'"; failures=$((failures+1)); fi
}
assert_contains() {  # haystack needle label
  total=$((total+1))
  if grep -qF "$2" <<<"$1"; then echo "  PASS $3"
  else echo "  FAIL $3 — output missing '$2'"; failures=$((failures+1)); fi
}
count() { jq --arg s "$1" '.findings[$s] | length' "$FIND"; }

mp_md5() { md5sum "$TMP/marketplace.json" 2>/dev/null || md5 -q "$TMP/marketplace.json"; }
MP_BEFORE="$(mp_md5)"

echo "=== owner-liveness-sweep: seed ==="
owners_live; repos_clean
B="$TMP/baseline.json"
run_sweep seed "$B"
assert_eq "$RC" 0 "seed exits 0"
assert_eq "$(jq '.owners | length' "$B")" 2 "baseline has 2 owners"
assert_eq "$(jq -r '.owners.acme.id' "$B")" 111 "acme id recorded (lowercased key)"
assert_eq "$(jq -r '.owners.otherorg.type' "$B")" "User" "otherorg type recorded"
assert_eq "$(count unparseable)" 1 "deep github URL lands in unparseable (not silently dropped)"
assert_contains "$(jq -r '.findings.unparseable[0].name' "$FIND")" "deep" "unparseable names the entry"
assert_eq "$(count identity_changed)" 0 "seed: no identity findings"
# Payload files hold the {query: "..."} envelope, so the login arg's quotes
# are JSON-escaped in the logged payload.
assert_contains "$(cat "$STUB_PAYLOAD_LOG")" 'repositoryOwner(login: \"Acme\")' "owner lookup uses the first-seen listed spelling"

echo "=== report: clean corpus ==="
run_sweep report "$B"
assert_eq "$RC" 0 "clean report exits 0"
for s in identity_changed owner_missing repo_moved repo_missing unbaselined baseline_orphans; do
  assert_eq "$(count $s)" 0 "clean: $s == 0"
done

echo "=== report: identity change fails the run ==="
cat > "$TMP/owners.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4999},
 "o0":{"__typename":"Organization","login":"Acme","databaseId":999},
 "o1":{"__typename":"User","login":"OtherOrg","databaseId":222}}}
EOF
run_sweep report "$B"
assert_eq "$RC" 1 "identity change → exit 1"
assert_eq "$(count identity_changed)" 1 "one identity_changed finding"
assert_eq "$(jq -r '.findings.identity_changed[0].recorded_id' "$FIND")" 111 "finding carries the recorded id"
assert_eq "$(jq -r '.findings.identity_changed[0].live_id' "$FIND")" 999 "finding carries the live id"
assert_contains "$OUT" "different account id" "error names the drift class"
assert_contains "$(jq -rc '.findings.identity_changed[0].entries' "$FIND")" "alpha" "finding lists the affected entries"

echo "=== report: fail-on-identity-change=false reports without failing ==="
FAIL_ON_IDENTITY_CHANGE=false run_sweep report "$B" || true
# (env leaks into run_sweep's child via its environment)
set +e
OUT="$(PATH="$TMP/bin:$PATH" MARKETPLACE_PATH="$TMP/marketplace.json" BASELINE_PATH="$B" \
  MODE=report FINDINGS_PATH="$FIND" FAIL_ON_IDENTITY_CHANGE=false \
  GITHUB_STEP_SUMMARY="$TMP/sum.md" GITHUB_OUTPUT="$TMP/out.txt" \
  bash "$ACTION_PATH/scripts/sweep.sh" 2>&1)"
RC=$?
set -e
assert_eq "$RC" 0 "fail-on-identity-change=false → exit 0"
assert_eq "$(count identity_changed)" 1 "finding still reported"

echo "=== refresh refuses over an identity change ==="
B_SAVED="$(cat "$B")"
run_sweep refresh "$B"
assert_eq "$RC" 1 "refresh over identity change → exit 1"
assert_contains "$OUT" "refresh refused" "refusal message"
assert_eq "$(cat "$B")" "$B_SAVED" "baseline untouched by the refused refresh"

echo "=== report: owner missing + repo moved ==="
owners_live
cat > "$TMP/owners.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4999},
 "o0":{"__typename":"Organization","login":"Acme","databaseId":111},
 "o1":null}}
EOF
cat > "$TMP/repos.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4998},
 "r0":{"nameWithOwner":"Acme/alpha"},
 "r1":{"nameWithOwner":"Acme/beta"},
 "r2":{"nameWithOwner":"NewHome/gamma"}}}
EOF
run_sweep report "$B"
assert_eq "$RC" 0 "owner-missing/repo-moved are reported, not run-failing"
assert_eq "$(count owner_missing)" 1 "owner_missing == 1"
assert_eq "$(jq -r '.findings.owner_missing[0].owner' "$FIND")" "OtherOrg" "owner_missing names the login"
assert_eq "$(count repo_moved)" 1 "repo_moved == 1"
assert_eq "$(jq -r '.findings.repo_moved[0].canonical' "$FIND")" "NewHome/gamma" "repo_moved carries the canonical location"
# Disposition split — this is the publisher-rebrand shape (owner login gone but
# the repo resolves at a canonical successor): must carry the successor and the
# verify-successor disposition, NOT the review-the-entries one.
assert_eq "$(jq -r '.findings.owner_missing[0].disposition' "$FIND")" "verify-successor" "missing owner WITH a resolving successor → verify-successor disposition"
assert_eq "$(jq -rc '.findings.owner_missing[0].successors' "$FIND")" '["NewHome/gamma"]' "successor location carried on the finding"

echo "=== report: owner missing with NO resolving repo → review disposition ==="
cat > "$TMP/repos.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4998},
 "r0":{"nameWithOwner":"Acme/alpha"},
 "r1":{"nameWithOwner":"Acme/beta"},
 "r2":null}}
EOF
run_sweep report "$B"
assert_eq "$(count owner_missing)" 1 "owner_missing == 1"
assert_eq "$(jq -r '.findings.owner_missing[0].disposition' "$FIND")" "review" "missing owner with NO resolving repo → review disposition"
assert_eq "$(jq -r '.findings.owner_missing[0].successors | length' "$FIND")" 0 "no successor recorded"
assert_eq "$(count repo_missing)" 1 "the vanished repo also lands in repo_missing"

echo "=== report: repo missing ==="
owners_live
cat > "$TMP/repos.resp" <<'EOF'
{"data":{"rateLimit":{"cost":1,"remaining":4998},
 "r0":{"nameWithOwner":"Acme/alpha"},
 "r1":null,
 "r2":{"nameWithOwner":"OtherOrg/gamma"}}}
EOF
run_sweep report "$B"
assert_eq "$(count repo_missing)" 1 "repo_missing == 1"
assert_eq "$(jq -r '.findings.repo_missing[0].listed' "$FIND")" "acme/beta" "repo_missing names the listed pair"

echo "=== report: unbaselined + orphan; refresh folds both ==="
owners_live; repos_clean
jq '.owners = {acme: .owners.acme, ghost: {id: 777, type: "User"}}' "$B" > "$B.tmp" && mv "$B.tmp" "$B"
run_sweep report "$B"
assert_eq "$RC" 0 "info-only drift exits 0"
assert_eq "$(count unbaselined)" 1 "unbaselined == 1 (otherorg)"
assert_eq "$(count baseline_orphans)" 1 "baseline_orphans == 1 (ghost)"
run_sweep refresh "$B"
assert_eq "$RC" 0 "clean refresh exits 0"
assert_eq "$(jq -r '.owners.acme.id' "$B")" 111 "refresh keeps the existing recorded id"
assert_eq "$(jq -r '.owners.otherorg.id' "$B")" 222 "refresh adds the unbaselined owner"
assert_eq "$(jq '.owners | has("ghost")' "$B")" "false" "refresh prunes the orphan"

echo "=== transport failure: a no-data chunk aborts loudly ==="
echo 'garbage' > "$TMP/owners.resp"
run_sweep report "$B"
assert_eq "$RC" 1 "no-data chunk → exit 1"
assert_contains "$OUT" "no data" "abort names the cause"

echo "=== read-only invariant ==="
assert_eq "$(mp_md5)" "$MP_BEFORE" "marketplace.json never modified"

echo
echo "=== $((total-failures))/$total passed ==="
[[ "$failures" -eq 0 ]]
