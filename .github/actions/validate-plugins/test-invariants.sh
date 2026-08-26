#!/usr/bin/env bash
# Static test suite for invariants I1-I12. No API key, no network — pure
# bash/jq against synthetic marketplace.json fixtures. Run locally or in CI
# on every PR touching validate-plugins/.
#
# Fixtures use heredocs (not quoted args) so the suite runs identically on
# macOS bash 3.2 and Linux bash 5.x — nested \"...\" inside $(...) triggers
# brace expansion under 3.2's parser.

set -euo pipefail
cd "$(dirname "$0")"
export ACTION_PATH="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
failures=0; total=0

mk() { local f="$TMP/$1.json"; cat > "$f"; printf '%s' "$f"; }

run_invariants() {
  export VALIDATE_TMP="$TMP/v" MARKETPLACE_PATH="$1" BASE_REF=HEAD WARN_INVARIANTS="" ENTRIES_DIR="${2:-}" SHA_EXEMPT="${SHA_EXEMPT_FIXTURE:-}"
  rm -rf "$VALIDATE_TMP"; mkdir -p "$VALIDATE_TMP"
  cp "$1" "$VALIDATE_TMP/marketplace.json"
  bash scripts/11-validate-invariants.sh 2>&1 || true
}

assert_fires() {
  total=$((total+1))
  if run_invariants "$3" "${4:-}" | grep -q "invariant $2:"; then
    echo "  PASS $1 — $2 fires"
  else echo "  FAIL $1 — expected $2 to fire"; failures=$((failures+1)); fi
}

assert_clean() {
  total=$((total+1))
  out="$(run_invariants "$2")"
  if grep -qE '::error|::warning' <<<"$out"; then
    echo "  FAIL $1 — expected clean, got:"; grep -E '::error|::warning' <<<"$out" | sed 's/^/    /'
    failures=$((failures+1))
  else echo "  PASS $1 — clean"; fi
}

echo "=== validate-plugins invariant tests ==="

f=$(mk good <<'EOF'
{"plugins":[{"name":"aaa","description":"A valid description here.","source":{"source":"url","url":"https://github.com/x/y","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]}
EOF
); assert_clean "baseline good entry" "$f"

f=$(mk i1 <<'EOF'
{"plugins":[{"name":"zzz","description":"ten chars ok","source":"./z"},{"name":"aaa","description":"ten chars ok","source":"./a"}]}
EOF
); assert_fires "I1 unsorted" I1 "$f"

f=$(mk i2 <<'EOF'
{"plugins":[{"name":"aaa","description":"ten chars ok","source":"./x"},{"name":"aaa","description":"ten chars ok","source":"./y"}]}
EOF
); assert_fires "I2 duplicate name" I2 "$f"

f=$(mk i3 <<'EOF'
{"plugins":[{"name":"abc","description":"short","source":"./x"}]}
EOF
); assert_fires "I3 desc too short" I3 "$f"

f=$(mk i4 <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","source":{"source":"url","url":"http://insecure.example/x","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]}
EOF
); assert_fires "I4 unsafe url" I4 "$f"

f=$(mk i5 <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y"}}]}
EOF
); assert_fires "I5 missing sha" I5 "$f"

# I5 sha-exempt: a listed name may omit sha entirely; a malformed sha still
# fails even when listed; the match is whole-word (no prefix bleed).
f=$(mk i5-exempt <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y"}}]}
EOF
)
SHA_EXEMPT_FIXTURE="abc"
assert_clean "I5 exempt name may omit sha" "$f"

f=$(mk i5-exempt-malformed <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y","sha":"deadbeef"}}]}
EOF
)
assert_fires "I5 exempt name, malformed sha still fails" I5 "$f"

f=$(mk i5-exempt-prefix <<'EOF'
{"plugins":[{"name":"abc-extra","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y"}}]}
EOF
)
assert_fires "I5 exemption is whole-word, not prefix" I5 "$f"
SHA_EXEMPT_FIXTURE=""

# A name with a space must not splice across two adjacent exempt entries.
f=$(mk i5-exempt-splice <<'EOF'
{"plugins":[{"name":"foo bar","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y"}}]}
EOF
)
SHA_EXEMPT_FIXTURE="foo bar"
assert_fires "I5 spaced name cannot splice exempt entries" I5 "$f"
SHA_EXEMPT_FIXTURE=""

# I6/I7: per-file mode invariants — need an entries-dir with a misnamed file
mkdir -p "$TMP/entries"
cat > "$TMP/entries/wrong.json" <<'EOF'
{"name":"right","description":"ten chars ok","source":"./x"}
EOF
f=$(mk i6 <<'EOF'
{"plugins":[{"name":"right","description":"ten chars ok","source":"./x"}]}
EOF
); assert_fires "I6 filename != name" I6 "$f" "$TMP/entries"

f=$(mk i8 <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","source":"./does-not-exist"}]}
EOF
); assert_fires "I8 vendored path missing" I8 "$f"

f=$(mk i9 <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y;rm","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]}
EOF
); assert_fires "I9 shell metachar" I9 "$f"

# I10: U+200B ZWSP embedded in description
f=$(mk i10); printf '{"plugins":[{"name":"abc","description":"hello​world ten chars","source":"./x"}]}' > "$f"
assert_fires "I10 hidden unicode" I10 "$f"

f=$(mk i11 <<'EOF'
{"plugins":[{"name":"Bad_Name","description":"ten chars ok","source":"./x"}]}
EOF
); assert_fires "I11 bad name format" I11 "$f"

f=$(mk i12-good <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","deprecated":true,"replacedBy":"abc-next","source":"./x"},{"name":"abc-next","description":"ten chars ok","source":"./y"}]}
EOF
); assert_clean "I12 valid deprecation metadata" "$f"

f=$(mk i12-bad-deprecated <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","deprecated":"yes","source":"./x"}]}
EOF
); assert_fires "I12 deprecated must be boolean" I12 "$f"

f=$(mk i12-replaced-without-deprecated <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","replacedBy":"abc-next","source":"./x"},{"name":"abc-next","description":"ten chars ok","source":"./y"}]}
EOF
); assert_fires "I12 replacedBy requires deprecated true" I12 "$f"

f=$(mk i12-self <<'EOF'
{"plugins":[{"name":"abc","description":"ten chars ok","deprecated":true,"replacedBy":"abc","source":"./x"}]}
EOF
); assert_fires "I12 replacedBy cannot point to self" I12 "$f"

# --- Mechanism A: diff-scoping (SCOPE_ERRORS_TO_CHANGED) ---------------------
# A per-entry violation on an entry NOT in changes.json's .entries downgrades
# ERROR->WARNING; a changed entry still ERRORs; whole-file invariants (no name)
# never downgrade. Uses a separate VALIDATE_TMP ($TMP/vs) + a written changes.json.
echo
echo "--- diff-scoping (scope-errors-to-changed) ---"

# run_scoped <changed-csv> <file> [scope=true] [writefile=yes] -> invariants stdout
#  scope:     value for SCOPE_ERRORS_TO_CHANGED ("true"/"false").
#  writefile: "no" omits changes.json entirely (exercises the absent-file fail-safe).
# WARN_INVARIANTS=NONE is a sentinel (not "") so the script's
# ${WARN_INVARIANTS:-I1 I3 I5 I8} default can't fire — that default would make
# I1/I5 warnings on its own and mask the scoping behavior under test.
# FAIL_ON_WARNINGS pinned false so an outer env can't turn a downgraded warning
# back into a failure mid-suite.
run_scoped() {
  local changed="$1" file="$2" scope="${3:-true}" writefile="${4:-yes}"
  export VALIDATE_TMP="$TMP/vs" MARKETPLACE_PATH="$file" BASE_REF=HEAD \
         WARN_INVARIANTS="NONE" ENTRIES_DIR="" SHA_EXEMPT="" FAIL_ON_WARNINGS="false" \
         SCOPE_ERRORS_TO_CHANGED="$scope"
  rm -rf "$VALIDATE_TMP"; mkdir -p "$VALIDATE_TMP"
  cp "$file" "$VALIDATE_TMP/marketplace.json"
  if [[ "$writefile" == "yes" ]]; then
    printf '%s' "$changed" | jq -R -s -c 'split(",")|map(select(length>0))|{entries:.,external:[],folders:[]}' \
      > "$VALIDATE_TMP/changes.json"
  fi
  bash scripts/11-validate-invariants.sh 2>&1 || true
}

# Annotation patterns are ANCHORED to the GitHub format flag() emits
# (`::error file=...::invariant <code>:`), so a marketplace tmp-path that happens
# to contain "invariant" or "::warning" can't produce a false match.
assert_error() {  # $1 desc $2 code $3 changed-csv $4 file [$5 scope] [$6 writefile]
  total=$((total+1))
  out="$(run_scoped "$3" "$4" "${5:-true}" "${6:-yes}")"
  if grep -qE "^::error file=.*::invariant $2:" <<<"$out"; then echo "  PASS $1 — $2 errors"
  else echo "  FAIL $1 — expected ::error for $2"; grep -E '::(error|warning)' <<<"$out"|sed 's/^/    /'; failures=$((failures+1)); fi
}

assert_warn_not_error() {  # $1 desc $2 code $3 changed-csv $4 file
  total=$((total+1))
  out="$(run_scoped "$3" "$4")"
  if grep -qE "^::warning file=.*::invariant $2:" <<<"$out" && ! grep -qE "^::error file=.*::invariant $2:" <<<"$out"; then
    echo "  PASS $1 — $2 downgraded to warning"
  else echo "  FAIL $1 — expected ::warning (not ::error) for $2"; grep -E '::(error|warning)' <<<"$out"|sed 's/^/    /'; failures=$((failures+1)); fi
}

# Two object-source entries (sorted); "bbb" omits sha (I5 violation).
f=$(mk scope <<'EOF'
{"plugins":[{"name":"aaa","description":"valid good entry","source":{"source":"url","url":"https://github.com/x/y","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},{"name":"bbb","description":"valid bad entry","source":{"source":"url","url":"https://github.com/x/z"}}]}
EOF
)
assert_warn_not_error "I5 on UNCHANGED entry (PR changed only aaa) downgrades" I5 "aaa" "$f"
assert_error          "I5 on CHANGED entry (PR changed bbb) still errors"      I5 "bbb" "$f"
# Feature OFF: same unchanged entry still ERRORs (regression guard for the default).
assert_error "I5 with scoping OFF still errors (unchanged entry)"          I5 "aaa" "$f" "false" "yes"
# Fail-safe: scoping ON but changes.json ABSENT -> behaves as OFF (errors).
assert_error "I5 scoping ON but no changes.json (fail-safe) errors"        I5 "aaa" "$f" "true"  "no"

# Whole-word matching: a changed entry must not cover a prefix-sharing sibling.
# "foo-extra" omits sha; PR changed only "foo" -> "foo-extra" must still downgrade.
f=$(mk scope_prefix <<'EOF'
{"plugins":[{"name":"foo","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/y","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},{"name":"foo-extra","description":"ten chars ok","source":{"source":"url","url":"https://github.com/x/z"}}]}
EOF
)
assert_warn_not_error "I5 whole-word: changed 'foo' does NOT cover 'foo-extra'" I5 "foo" "$f"

# Whole-file invariant (I1 sort, name-less) must NEVER downgrade — neither with an
# empty changed list nor with the offending entries explicitly in it.
f=$(mk scope_i1 <<'EOF'
{"plugins":[{"name":"zzz","description":"ten chars ok","source":"./z"},{"name":"aaa","description":"ten chars ok","source":"./a"}]}
EOF
)
assert_error "I1 (whole-file) errors with NO changed entries"            I1 ""        "$f"
assert_error "I1 (whole-file) errors with entries IN the changed list"   I1 "zzz,aaa" "$f"

echo
echo "=== $((total-failures))/$total passed ==="
[[ "$failures" -eq 0 ]]
