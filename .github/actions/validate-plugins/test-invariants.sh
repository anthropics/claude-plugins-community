#!/usr/bin/env bash
# Static test suite for invariants I1-I11. No API key, no network — pure
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
  export VALIDATE_TMP="$TMP/v" MARKETPLACE_PATH="$1" BASE_REF=HEAD WARN_INVARIANTS="" ENTRIES_DIR="${2:-}"
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

echo
echo "=== $((total-failures))/$total passed ==="
[[ "$failures" -eq 0 ]]
