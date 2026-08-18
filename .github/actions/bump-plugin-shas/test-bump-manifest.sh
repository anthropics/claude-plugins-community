#!/usr/bin/env bash
# Synthesis-path test for bump.sh: a strict:false (skills-only) external with no
# plugin.json must be SYNTHESIZED + validated + bumped (not hard-skipped), exactly
# as validate-plugins/30-validate-cli-external.sh does — while a default-strict
# entry with no manifest stays fail-closed ("no plugin manifest"), and a
# default-strict entry WITH a manifest bumps unchanged (byte-identical default).
#
# Unlike test-bump.sh (which is network/gh/claude-free because every fixture
# short-circuits before `git ls-remote`), this test must drive bump.sh THROUGH the
# clone → resolve_external_manifest → validate → per-entry commit+PR path. It does
# so hermetically with PATH-shim `git`/`claude`/`gh`/`timeout` executables whose
# DEFAULT case fails closed (exit 1, never the real binary) — so a missing case is
# a loud test failure, never a live API call. It sources the REAL
# validate-plugins/lib/common.sh so the actual resolve_external_manifest is exercised.
#
# Runs in pr-mode: per-entry — the mode claude-plugins-community's nightly uses.
# Runs identically on macOS bash 3.2 and Linux bash 5.x (no bash-4 features, shims
# are scripts not exported functions, heredoc fixtures).

set -euo pipefail
cd "$(dirname "$0")"
ACTION_PATH="$PWD"
COMMON_SH="$ACTION_PATH/../validate-plugins/lib/common.sh"
[[ -f "$COMMON_SH" ]] || { echo "FATAL: real common.sh not found at $COMMON_SH" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
failures=0; total=0; skipped=0

# Stub HEAD the git shim reports for every ls-remote (40 hex, distinct from every
# fixture's old sha so new != old → each entry is "stale").
HEAD_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# ---- PATH shims (executable scripts, fail-closed default) -------------------
mkdir -p "$TMP/bin"

cat > "$TMP/bin/git" <<EOF
#!/usr/bin/env bash
# Hermetic git shim. ls-remote → fixed HEAD; clone → mkdir dest, then per the url's
# trailing path segment: a real plugin.json for .../charlie, a present-but-empty
# subdir for .../withskills, and nothing else (so .../alpha etc. get an EMPTY tree).
# fetch/checkout/init/remote/ls-tree (incl. via -C) → no-op 0. Anything else fails closed.
# Match on the EXACT trailing segment (*/charlie, not *charlie*) so a future fixture
# name that merely CONTAINS "charlie" can't accidentally inherit a real manifest and
# silently hollow the synth assertion.
case "\$1" in
  ls-remote) printf '%s\tHEAD\n' "$HEAD_SHA"; exit 0 ;;
  clone)
    # git clone --quiet --depth 1 -- <url> <dest> : dest is the last arg, url the one before.
    a1=""; a2=""
    for a in "\$@"; do a1="\$a2"; a2="\$a"; done
    url="\$a1"; dest="\$a2"
    mkdir -p "\$dest" || exit 1
    case "\$url" in
      */charlie)    mkdir -p "\$dest/.claude-plugin" && printf '{"name":"charlie"}' > "\$dest/.claude-plugin/plugin.json" || exit 1 ;;
      */withskills) mkdir -p "\$dest/skills" || exit 1 ;;  # subdir PRESENT but no manifest → strict:false synthesizes INTO it
      # */withsub deliberately gets NO subdir → exercises the subdir-existence guard.
    esac
    exit 0 ;;
  # -C is a deliberate catch-all no-op for the in-clone ops bump.sh runs via
  # \`git -C "\$dest" fetch|checkout\` AND the subtree-probe's init/remote/fetch/
  # ls-tree (reached now that some fixtures set source.path). The probe is fail-open:
  # ls-tree returns no output here → empty old/new tree oids → no suppression →
  # falls through to the normal clone+guard path, which is exactly what we test.
  -C|init|remote|fetch|checkout|ls-tree) exit 0 ;;
  *) echo "git shim: unexpected invocation: \$*" >&2; exit 1 ;;
esac
EOF

cat > "$TMP/bin/claude" <<'EOF'
#!/usr/bin/env bash
# Hermetic claude shim: `plugin validate <manifest>` always passes; nothing else.
if [[ "$1" == "plugin" && "$2" == "validate" ]]; then exit 0; fi
echo "claude shim: unexpected invocation: $*" >&2; exit 1
EOF

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Hermetic gh shim covering the per-entry commit+PR phase. Fails closed otherwise.
case "$1" in
  pr)
    case "$2" in
      list)
        # Non-empty URL ONLY for the branch named in OPEN_PR_BRANCH — exercises the
        # per-entry open-PR early-skip (bump.sh skips clone+validate when a slug
        # already has an open bump PR). Empty otherwise → the create path.
        _head=""; _prev=""
        for _a in "$@"; do [ "$_prev" = "--head" ] && _head="$_a"; _prev="$_a"; done
        if [ -n "${OPEN_PR_BRANCH:-}" ] && [ "$_head" = "$OPEN_PR_BRANCH" ]; then
          echo "https://github.com/acme/repo/pull/99"
        else echo ""; fi ;;
      create)
        # Tee the full argv to $PRCREATE_LOG (set by run_bump) so a test can
        # assert the --body-file PATH the script actually passed.
        if [ -n "${PRCREATE_LOG:-}" ]; then printf '%s\n' "$*" >> "$PRCREATE_LOG"; fi
        echo "https://github.com/acme/repo/pull/1" ;;
      edit)   : ;;
      *) echo "gh shim: unexpected pr subcommand: $*" >&2; exit 1 ;;
    esac
    exit 0 ;;
  api)
    case "$2" in
      graphql)
        # Tee the createCommitOnBranch payload to $GQL_LOG (set by run_bump) so a test
        # can assert the per-entry commit CONTENT; else preserve the stdin-sink default.
        if [ -n "${GQL_LOG:-}" ]; then cat >> "$GQL_LOG" || true; else cat >/dev/null 2>&1 || true; fi
        echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"; exit 0 ;;  # createCommitOnBranch oid
      -X)      exit 0 ;;                                        # POST/PATCH .../git/refs
      repos/*/git/ref/heads/*)
               echo "cccccccccccccccccccccccccccccccccccccccc"; exit 0 ;;  # base-branch .object.sha
      repos/*)
        # Source-owner verification lookup (plain repos/<owner>/<repo>): answer
        # with a canonical full_name MATCHING the listed one, so every fixture
        # entry passes the gate and this suite keeps testing the manifest paths.
        _or="${2#repos/}"; printf '{"full_name":"%s"}\n' "$_or"; exit 0 ;;
      *)       echo "cccccccccccccccccccccccccccccccccccccccc"; exit 0 ;;  # any other ref lookup
    esac ;;
  *) echo "gh shim: unexpected invocation: $*" >&2; exit 1 ;;
esac
EOF

cat > "$TMP/bin/timeout" <<'EOF'
#!/usr/bin/env bash
# Hermetic timeout shim: strip an optional `-k <n>` and the duration, exec the rest.
[[ "$1" == "-k" ]] && shift 2
shift
exec "$@"
EOF

chmod +x "$TMP/bin/git" "$TMP/bin/claude" "$TMP/bin/gh" "$TMP/bin/timeout"

# ---- run bump.sh against a fixture ------------------------------------------
mk() { local f="$TMP/$1.json"; cat > "$f"; printf '%s' "$f"; }

work=""
run_bump() {
  work="$TMP/work.json"; cp "$1" "$work"
  : > "$TMP/out.txt"; : > "$TMP/sum.md"; : > "$TMP/graphql.log"; : > "$TMP/prcreate.log"
  set +e
  OUT="$(
    PATH="$TMP/bin:$PATH" \
    VALIDATE_LIB="$COMMON_SH" VALIDATE_TMP="$TMP" \
    MARKETPLACE_PATH="$work" MAX_BUMPS=20 \
    ALLOWED_HOSTS="github.com gitlab.com bitbucket.org" \
    PR_MODE="per-entry" PR_BRANCH="bump/plugin-shas" BASE_BRANCH="main" \
    GH_TOKEN="dummy" GITHUB_REPOSITORY="acme/repo" \
    ONLY="${ONLY_FIXTURE:-}" OPEN_PR_BRANCH="${OPEN_PR_BRANCH:-}" \
    RUN_URL="https://github.com/acme/repo/actions/runs/1" \
    GQL_LOG="$TMP/graphql.log" PRCREATE_LOG="$TMP/prcreate.log" \
    GITHUB_OUTPUT="$TMP/out.txt" GITHUB_STEP_SUMMARY="$TMP/sum.md" \
    bash "$ACTION_PATH/scripts/bump.sh" 2>&1
  )"
  RC=$?
  set -e
  BUMPED_JSON="$(sed -n 's/^bumped=//p' "$TMP/out.txt")";   [[ -n "$BUMPED_JSON" ]]  || BUMPED_JSON='[]'
  SKIPPED_JSON="$(sed -n 's/^skipped=//p' "$TMP/out.txt")"; [[ -n "$SKIPPED_JSON" ]] || SKIPPED_JSON='[]'
  # pr-urls is the per-entry commit+PR phase's output (one {name,branch,pr_url} per
  # opened PR). Parsing it lets the test assert the PR phase actually RAN, not just
  # that an entry reached bumped[] (which is populated before that phase).
  PRURLS_JSON="$(sed -n 's/^pr-urls=//p' "$TMP/out.txt" | tail -1)"; [[ -n "$PRURLS_JSON" ]] || PRURLS_JSON='[]'
}

assert_bumped() {  # NAME LABEL
  total=$((total+1))
  if [[ "$(jq -r --arg n "$1" '[.[]|select(.name==$n)]|length' <<<"$BUMPED_JSON")" == "1" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — '$1' not in bumped[] (bumped=$BUMPED_JSON)"; failures=$((failures+1)); fi
}
assert_skip_reason() {  # NAME SUBSTR LABEL
  total=$((total+1))
  local got; got="$(jq -r --arg n "$1" '.[]|select(.name==$n)|.reason' <<<"$SKIPPED_JSON")"
  if [[ "$got" == *"$2"* ]]; then echo "  PASS $3"
  else echo "  FAIL $3 — '$1' reason='$got' expected to contain '$2'"; failures=$((failures+1)); fi
}
assert_not_bumped() {  # NAME LABEL
  total=$((total+1))
  if [[ "$(jq -r --arg n "$1" '[.[]|select(.name==$n)]|length' <<<"$BUMPED_JSON")" == "0" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — '$1' unexpectedly in bumped[]"; failures=$((failures+1)); fi
}
assert_out() {  # SUBSTR LABEL
  total=$((total+1))
  if grep -qF "$1" <<<"$OUT"; then echo "  PASS $2"
  else echo "  FAIL $2 — output missing '$1'"; failures=$((failures+1)); fi
}
assert_rc() {  # EXPECTED LABEL
  total=$((total+1))
  if [[ "$RC" == "$1" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — exit $RC, expected $1"; failures=$((failures+1)); fi
}
assert_pr_opened() {  # NAME BRANCH LABEL — entry NAME has a pr-urls record on BRANCH with a non-empty pr_url
  total=$((total+1))
  local br url; br="$(jq -r --arg n "$1" '.[]|select(.name==$n)|.branch' <<<"$PRURLS_JSON")"
  url="$(jq -r --arg n "$1" '.[]|select(.name==$n)|.pr_url' <<<"$PRURLS_JSON")"
  if [[ "$br" == "$2" && -n "$url" && "$url" != "null" ]]; then echo "  PASS $3"
  else echo "  FAIL $3 — '$1' pr-urls branch='$br' url='$url' (expected branch '$2', non-empty url)"; failures=$((failures+1)); fi
}
assert_not_skipped() {  # NAME LABEL
  total=$((total+1))
  if [[ "$(jq -r --arg n "$1" '[.[]|select(.name==$n)]|length' <<<"$SKIPPED_JSON")" == "0" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — '$1' unexpectedly in skipped[]"; failures=$((failures+1)); fi
}

# @base64d is jq 1.6+. CI (ubuntu) ships 1.6+; the guard only matters for a dev on an
# old macOS with system jq 1.5 — a clean visible SKIP beats a silent `jq: error`. Probe once.
HAVE_B64D=1; jq -n '"" | @base64d' >/dev/null 2>&1 || HAVE_B64D=0

# assert_commit_isolates BRANCH TARGET TGT_SHA SIB1 SIB1_SHA SIB2 SIB2_SHA LABEL
# Decode the createCommitOnBranch payload the gh graphql shim tee'd to $GQL_LOG for
# BRANCH and assert it bumps ONLY TARGET (to TGT_SHA) while both siblings keep their
# fixture (base) shas — i.e. per-entry commits are INDEPENDENT, built from
# base_marketplace_content + only this entry's bump, not stacked. NOTE: the synth run
# opens TWO commits (bump/alpha AND bump/charlie); select(.variables.branch==$br)
# isolates THIS branch's payload from the others in the log. (beta is skipped — no
# manifest — so it produces NO graphql entry; the log holds exactly one object per
# non-skipped bumped plugin.)
assert_commit_isolates() {
  # A SKIP must NOT inflate the pass tally (`$((total-failures))/$total passed`), so only
  # count this assertion toward total AFTER the capability guard — a jq<1.6 SKIP is then
  # neither pass nor fail (visible via the SKIP line, absent from the count).
  if [[ "$HAVE_B64D" != 1 ]]; then echo "  SKIP $8 — jq 1.6+ (@base64d) required to decode the commit payload"; skipped=$((skipped+1)); return; fi
  total=$((total+1))
  local content t s1 s2
  # `|| content=""` makes the empty-content guard reachable on BOTH failure shapes: a valid
  # log with no matching branch (jq exits 0, empty) AND a malformed log (jq errors) — without
  # it, set -e would abort the whole suite on a jq parse error before the guard runs. Either
  # way an absent/garbled payload for this branch is a LOUD FAIL here.
  content="$(jq -rs --arg br "$1" '.[]|select(.variables.branch==$br)|.variables.contents|@base64d' "$TMP/graphql.log" 2>/dev/null)" || content=""
  if [[ -z "$content" ]]; then echo "  FAIL $8 — no graphql payload for branch '$1'"; failures=$((failures+1)); return; fi
  t="$(jq -r --arg n "$2" '.plugins[]|select(.name==$n)|.source.sha' <<<"$content")"
  s1="$(jq -r --arg n "$4" '.plugins[]|select(.name==$n)|.source.sha' <<<"$content")"
  s2="$(jq -r --arg n "$6" '.plugins[]|select(.name==$n)|.source.sha' <<<"$content")"
  if [[ "$t" == "$3" && "$s1" == "$5" && "$s2" == "$7" ]]; then echo "  PASS $8"
  else echo "  FAIL $8 — $2=$t (want $3) $4=$s1 (want $5) $6=$s2 (want $7)"; failures=$((failures+1)); fi
}

# assert_no_commit BRANCH LABEL — NO createCommitOnBranch payload was sent for BRANCH.
# A plain-continued / skipped entry must NOT commit, so the shim must have tee'd zero
# payloads for its branch. Count-only (no @base64d decode → no capability guard needed);
# `jq -s` over an empty/no-match log yields length 0.
assert_no_commit() {
  total=$((total+1))
  local n
  n="$(jq -rs --arg br "$1" '[.[]|select(.variables.branch==$br)]|length' "$TMP/graphql.log" 2>/dev/null)" || n=""
  if [[ "$n" == "0" ]]; then echo "  PASS $2"
  else echo "  FAIL $2 — expected 0 payloads for '$1', got '$n'"; failures=$((failures+1)); fi
}

echo "=== bump-plugin-shas manifest-synthesis tests (per-entry) ==="

# A 3-entry fixture, all on github.com, no subdir (so the no-op subtree probe is
# skipped), each sha != the stub HEAD (so each is "stale"):
#   alpha   — strict:false, no plugin.json  → SYNTHESIZED + bumped
#   beta    — default strict, no plugin.json → SKIPPED "no plugin manifest" (fail-closed)
#   charlie — default strict, HAS plugin.json (clone shim) → bumped unchanged (regression guard)
# FIXTURE↔SHIM CONTRACT: the git clone shim writes a plugin.json ONLY for the
# .../charlie url (exact trailing segment), so alpha/beta deliberately get an EMPTY
# clone tree — that is what forces the synthesize (alpha, strict:false → mrc=2) vs
# fail-closed (beta, strict-default → mrc=1) paths. Renaming a fixture must preserve
# this: a name whose url's trailing segment is exactly `charlie` gets a real manifest.
f=$(mk synth <<'EOF'
{"plugins":[
  {"name":"alpha","strict":false,"source":{"url":"https://github.com/acme/alpha","sha":"1111111111111111111111111111111111111111"}},
  {"name":"beta","source":{"url":"https://github.com/acme/beta","sha":"2222222222222222222222222222222222222222"}},
  {"name":"charlie","source":{"url":"https://github.com/acme/charlie","sha":"3333333333333333333333333333333333333333"}}
]}
EOF
)
run_bump "$f"
assert_rc          0                                         "run exits 0"
assert_bumped      "alpha"                                   "strict:false + no manifest → synthesized + bumped"
assert_out         "synthesized a minimal one"               "synthesis is logged (mrc==2 parity with validate-plugins)"
assert_skip_reason "beta" "no plugin manifest"               "default-strict + no manifest → fail-closed skip"
assert_not_bumped  "beta"                                    "default-strict + no manifest → NOT bumped"
assert_bumped      "charlie"                                 "default-strict + real manifest → bumped unchanged (byte-identical default)"
# The per-entry commit+PR phase runs AFTER bumped[] is populated, so assert it
# actually executed (PR opened, pr-urls recorded) — otherwise the gh-shim'd
# commit/PR path is unverified and a regression there would pass silently.
assert_out         "Opened PR"                               "per-entry commit+PR phase ran (PR opened)"
assert_pr_opened   "alpha" "bump/alpha"                      "synthesized entry produced a per-entry PR on bump/alpha"
assert_pr_opened   "charlie" "bump/charlie"                  "second bumped entry produced its own per-entry PR on bump/charlie"
# Per-entry commit INDEPENDENCE: decode alpha's committed marketplace.json and prove it
# carries ONLY alpha's bump. charlie=3333 here is the independence LEVER — charlie bumps
# on its OWN branch (bump/charlie), but in alpha's commit it must stay at base 3333.
# Under the bump.sh mutation (per-entry commit built from $MARKETPLACE_PATH, which
# accumulates ALL bumps, instead of base_marketplace_content) charlie would be aaaa here
# → this assertion FAILs, proving it is not hollow.
assert_commit_isolates "bump/alpha" \
  "alpha"   "$HEAD_SHA" \
  "beta"    "2222222222222222222222222222222222222222" \
  "charlie" "3333333333333333333333333333333333333333" \
  "alpha's per-entry commit bumps ONLY alpha (beta/charlie at base shas)"
# Symmetric check on charlie's OWN commit — catches an ASYMMETRIC stacking bug (e.g. only
# the 2nd+ per-entry commit stacks) that the alpha-only assertion would miss. In charlie's
# commit: charlie=aaaa (bumped HEAD), alpha=1111 (base), beta=2222 (base).
assert_commit_isolates "bump/charlie" \
  "charlie" "$HEAD_SHA" \
  "alpha"   "1111111111111111111111111111111111111111" \
  "beta"    "2222222222222222222222222222222222222222" \
  "charlie's per-entry commit bumps ONLY charlie (alpha/beta at base shas)"

echo
echo "--- ONLY + synthesis intersection ---"
# only=alpha over the same 3-entry fixture: the strict:false target must STILL
# synthesize + bump (the only-guard at bump.sh sits BEFORE strict-resolution), and
# the non-targets are plain-continued (neither bumped nor recorded in skipped[]).
ONLY_FIXTURE="alpha"
run_bump "$f"
ONLY_FIXTURE=""
assert_rc          0                                         "only=alpha run exits 0"
assert_bumped      "alpha"                                   "only=alpha + strict:false → still synthesized + bumped"
assert_not_bumped  "charlie"                                 "only=alpha → charlie (non-target) not bumped"
assert_not_bumped  "beta"                                    "only=alpha → beta (non-target) not bumped"
assert_not_skipped "beta"                                    "only=alpha → beta plain-continued (not in skipped[])"
assert_not_skipped "charlie"                                 "only=alpha → charlie plain-continued (not in skipped[])"
# ONLY-mode COMMIT CONTENT: only=alpha drives the SAME per-entry commit path (a distinct
# bump.sh slice from the all-entries run) and tees a fresh bump/alpha payload (run_bump
# truncated $GQL_LOG, so it holds only this run's payloads). Decode it: the target's new
# sha must be correct and siblings at base — AND no non-target (charlie) may commit at all
# (the load-bearing only-mode contract: a single target → exactly one commit).
assert_commit_isolates "bump/alpha" \
  "alpha"   "$HEAD_SHA" \
  "beta"    "2222222222222222222222222222222222222222" \
  "charlie" "3333333333333333333333333333333333333333" \
  "only=alpha commit carries alpha's new sha; siblings at base"
assert_no_commit "bump/charlie" "only=alpha → non-target charlie did NOT commit (no payload)"
assert_no_commit "bump/beta"    "only=alpha → non-target beta did NOT commit (no payload)"

echo
echo "--- per-entry open-PR early-skip ---"
# A slug with an open bump PR is skipped before clone+validate (budget-saving,
# live -community nightly behavior). With an open PR on bump/alpha: alpha early-
# skips with that reason; charlie still bumps (its branch has no open PR).
OPEN_PR_BRANCH="bump/alpha"
run_bump "$f"
OPEN_PR_BRANCH=""
assert_skip_reason "alpha" "open bump PR already exists"     "open PR on bump/alpha → alpha early-skipped with that reason"
assert_not_bumped  "alpha"                                   "open-PR alpha not bumped"
assert_bumped      "charlie"                                 "open PR on alpha does not block charlie's bump"

echo
echo "--- subdir-existence guard (declared source.path gone at the new SHA) ---"
# A strict:false external with a source.path whose subdir does NOT exist in the
# clone must be a hard SKIP "subdir not found", NOT a synthesis: without the guard,
# resolve_external_manifest would mkdir -p the vanished path and synthesize a phantom
# {name} manifest → a false bump to a SHA where the plugin content is gone. Mirrors
# validate-plugins/30-validate-cli-external.sh. The clone shim creates NO subdir for
# a .../withsub url, so target="$dest/skills" is absent → the guard fires.
f=$(mk subdir_gone <<'EOF'
{"plugins":[
  {"name":"withsub","strict":false,"source":{"url":"https://github.com/acme/withsub","sha":"4444444444444444444444444444444444444444","path":"skills"}}
]}
EOF
)
run_bump "$f"
assert_rc          0                                         "subdir-gone run exits 0 (clean skip)"
assert_skip_reason "withsub" "subdir 'skills' not found"      "strict:false + vanished source.path → skip 'subdir not found' (NOT synthesized)"
assert_not_bumped  "withsub"                                 "vanished-subdir entry NOT bumped (no phantom synthesis)"
# The synth log must be ABSENT (the guard fires before resolve_external_manifest).
total=$((total+1))
if grep -qF "synthesized a minimal one" <<<"$OUT"; then
  echo "  FAIL no-synthesis-for-vanished-subdir — synthesis was logged despite the guard"; failures=$((failures+1))
else echo "  PASS no-synthesis-for-vanished-subdir (guard fired before resolve)"; fi

echo
echo "--- subdir-existence guard: PRESENT subdir does NOT over-fire ---"
# Counterpart: a strict:false external whose declared subdir IS present (but ships no
# manifest there) must still SYNTHESIZE + bump — the guard must not block legitimate
# subdir entries. The clone shim creates $dest/skills for a .../withskills url.
f=$(mk subdir_present <<'EOF'
{"plugins":[
  {"name":"withskills","strict":false,"source":{"url":"https://github.com/acme/withskills","sha":"5555555555555555555555555555555555555555","path":"skills"}}
]}
EOF
)
run_bump "$f"
assert_rc          0                                         "subdir-present run exits 0"
assert_bumped      "withskills"                              "strict:false + present subdir + no manifest → synthesized + bumped (guard does not over-fire)"
assert_not_skipped "withskills"                              "present-subdir entry NOT skipped"

echo
echo "--- hostile plugin name: PR-body path stays inside the workroot ---"
# The marketplace allows `/` in names (@scope/plugin), so treat the field as
# path-hostile: a name carrying `/` + `..` must not steer the per-entry
# PR-body write to a traversed path. body_file derives from the SANITIZED
# branch suffix ([A-Za-z0-9_.-], no `/`), never raw $name. Against the
# pre-fix code (body_file="$workroot/pr-body-$name.md") this section FAILS:
# the redirect target "$workroot/pr-body-evil/../../pwn.md" walks through a
# nonexistent pr-body-evil dir → the write errors, the run dies, no PR is
# recorded.
f=$(mk hostile_name <<'EOF'
{"plugins":[
  {"name":"evil/../../pwn","strict":false,"source":{"url":"https://github.com/acme/evilname","sha":"6666666666666666666666666666666666666666"}}
]}
EOF
)
run_bump "$f"
assert_rc        0                                     "hostile-name run exits 0"
assert_bumped    "evil/../../pwn"                      "hostile-name entry still bumps (sanitized, not rejected)"
assert_pr_opened "evil/../../pwn" "bump/evil-..-..-pwn" "PR opened on the sanitized branch"
# The body-file path the script passed to `gh pr create` must be a single
# slash-free basename under the workroot — no `..` path segment anywhere.
total=$((total+1))
_bf="$(sed -n 's/.*--body-file \(.*\)$/\1/p' "$TMP/prcreate.log" | tail -1)"
if [[ -n "$_bf" && "$_bf" != *"/../"* && "$(basename "$_bf")" == "pr-body-evil-..-..-pwn.md" ]]; then
  echo "  PASS body-file derives from the sanitized branch suffix ($_bf)"
else
  echo "  FAIL body-file path unsafe or missing — got '$_bf'"; failures=$((failures+1))
fi

echo
# Surface a non-zero SKIP count so a jq<1.6 run (where the isolation assertions SKIP) is
# NOT laundered into a clean-looking "N/N passed" — the check was narrower, say so.
_tally="=== $((total-failures))/$total passed"
[ "${skipped:-0}" -gt 0 ] && _tally="$_tally (${skipped} skipped)"
echo "$_tally ==="
[[ "$failures" -eq 0 ]]
