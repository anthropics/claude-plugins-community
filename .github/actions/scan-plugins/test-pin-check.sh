#!/usr/bin/env bash
# Golden-vector test suite for lib/pin-check.sh — the deterministic launcher
# pin-state classifier behind the static pin check (scan-plugins) and the
# bump-plugin-shas pin gate. Network-free, pure bash/jq against synthetic
# .mcp.json fixtures + tempdir trees. Run locally or in CI on every PR
# touching .github/actions/** (wired in validate-plugins.yml).
#
# The vectors mirror the classifier's spec of record (see the provenance
# header in lib/pin-check.sh) — a port regression that reclassifies any
# vector fails this suite.
#
# Fixtures use heredocs so the suite runs identically on macOS bash 3.2 and
# Linux bash 5.x.

set -euo pipefail
cd "$(dirname "$0")"
source lib/pin-check.sh
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
failures=0; total=0

pass() { total=$((total+1)); printf 'ok %d - %s\n' "$total" "$1"; }
fail() { total=$((total+1)); failures=$((failures+1)); printf 'NOT OK %d - %s\n    got: %s\n' "$total" "$1" "${2:-}"; }

# assert_class LABEL MANIFEST_JSON SERVER EXPECTED_CLASS [EXPECTED_SPEC]
# — pin_check_rows over MANIFEST_JSON yields exactly one row for SERVER with
# the expected class (and spec, when given).
assert_class() {
  local label="$1" json="$2" server="$3" want_class="$4" want_spec="${5-__any__}"
  local rows got_class got_spec
  rows="$(pin_check_rows "$json")"
  got_class="$(printf '%s\n' "$rows" | awk -F'\t' -v s="$server" '$1==s{print $3; exit}')"
  got_spec="$(printf '%s\n' "$rows" | awk -F'\t' -v s="$server" '$1==s{print $4; exit}')"
  if [[ "$got_class" != "$want_class" ]]; then
    fail "$label" "class='$got_class' spec='$got_spec' (want class='$want_class')"
  elif [[ "$want_spec" != "__any__" && "$got_spec" != "$want_spec" ]]; then
    fail "$label" "spec='$got_spec' (want '$want_spec')"
  else
    pass "$label"
  fi
}

mcp() { jq -nc --arg cmd "$1" --argjson args "$2" '{mcpServers:{srv:{command:$cmd,args:$args}}}'; }

# ---- npm launcher spec classes ---------------------------------------------

assert_class "npx exact pin"               "$(mcp npx '["-y","pkg@1.2.3"]')"                  srv pinned  "pkg@1.2.3"
assert_class "npx exact pin w/ prerelease" "$(mcp npx '["pkg@1.2.3-beta.1+build.5"]')"        srv pinned
assert_class "npx scoped exact pin"        "$(mcp npx '["@scope/pkg@1.2.3"]')"                srv pinned  "@scope/pkg@1.2.3"
assert_class "npx @latest dist-tag"        "$(mcp npx '["-y","pkg@latest"]')"                 srv floating "pkg@latest"
assert_class "npx scoped @latest"          "$(mcp npx '["@vendor/mcp@latest"]')"              srv floating
assert_class "npx caret range"             "$(mcp npx '["pkg@^1"]')"                          srv floating
assert_class "npx pkg@1 is a range"        "$(mcp npx '["pkg@1"]')"                           srv floating
assert_class "npx pkg@1.2 is a range"      "$(mcp npx '["pkg@1.2"]')"                         srv floating
assert_class "npx bare unversioned (raw)"  "$(mcp npx '["pkg"]')"                             srv bare    "pkg"
assert_class "npx ./local path"            "$(mcp npx '["./dist/index.js"]')"                 srv local
assert_class "npx plugin-root placeholder" "$(mcp npx '["${CLAUDE_PLUGIN_ROOT}/dist/x.js"]')" srv local
assert_class "pathless placeholder evades to floating" "$(mcp npx '["${UNSET:-evil@latest}"]')" srv floating
assert_class "npx git+https vcsref"        "$(mcp npx '["git+https://github.com/o/r.git"]')"  srv vcsref
assert_class "npx github: vcsref"          "$(mcp npx '["github:o/r"]')"                      srv vcsref
assert_class "npx owner/repo#ref vcsref"   "$(mcp npx '["o/r#abc123"]')"                      srv vcsref
assert_class "npx ref-less owner/repo floats" "$(mcp npx '["o/r"]')"                          srv floating
assert_class "bunx @latest"                "$(mcp bunx '["pkg@latest"]')"                     srv floating
assert_class "npx.cmd windows launcher"    "$(mcp npx.cmd '["pkg@latest"]')"                  srv floating
assert_class "abs-path npx basename"       "$(mcp /usr/local/bin/npx '["pkg@latest"]')"       srv floating

# ---- npm flag handling ------------------------------------------------------

assert_class "npx -p selects the spec (positional is the bin)" \
  "$(mcp npx '["-p","pkg@1.2.3","bin"]')" srv pinned "pkg@1.2.3"
assert_class "npx --package= inline form" \
  "$(mcp npx '["--package=pkg@latest","bin"]')" srv floating "pkg@latest"
assert_class "value-flag value not a spec" \
  "$(mcp npx '["--loglevel","error","pkg@1.2.3"]')" srv pinned "pkg@1.2.3"
assert_class "npx -c shell-string derives no spec" \
  "$(mcp npx '["-c","pkg@latest run"]')" srv none ""

# ---- pip launchers (uvx/pipx) ----------------------------------------------

assert_class "uvx exact == pin"            "$(mcp uvx '["pkg==1.2.3"]')"                      srv pinned
assert_class "uvx wildcard == is a range"  "$(mcp uvx '["pkg==1.*"]')"                        srv floating
assert_class "uvx >= range"                "$(mcp uvx '["pkg>=1.0"]')"                        srv floating
assert_class "uvx bare name floats"        "$(mcp uvx '["pkg"]')"                             srv floating
assert_class "uvx npm-style @ exact pin"   "$(mcp uvx '["ruff@0.3.0"]')"                      srv pinned
assert_class "uvx npm-style @latest"       "$(mcp uvx '["pkg@latest"]')"                      srv floating
assert_class "uvx --from selects the spec" "$(mcp uvx '["--from","pkg==1.2.3","tool"]')"      srv pinned "pkg==1.2.3"
assert_class "uvx value-flag skipped"      "$(mcp uvx '["--python","3.12","pkg==1.2.3"]')"    srv pinned
assert_class "pipx --spec selects"         "$(mcp pipx '["--spec","pkg==1.2.3","run","tool"]')" srv pinned "pkg==1.2.3"
assert_class "pipx run positional"         "$(mcp pipx '["run","pkg"]')"                      srv floating

# ---- non-launcher / robustness ---------------------------------------------

t="pin_check_rows: node entrypoint yields no rows"
rows="$(pin_check_rows "$(mcp node '["dist/index.js"]')")"
[[ -z "$rows" ]] && pass "$t" || fail "$t" "$rows"

t="pin_check_rows: remote url server yields no rows"
rows="$(pin_check_rows '{"mcpServers":{"r":{"url":"https://example.com/mcp","type":"http"}}}')"
[[ -z "$rows" ]] && pass "$t" || fail "$t" "$rows"

t="pin_check_rows: root-array manifest degrades to zero rows"
rows="$(pin_check_rows '[1,2,3]')"
[[ -z "$rows" ]] && pass "$t" || fail "$t" "$rows"

t="pin_check_rows: invalid JSON degrades to zero rows"
rows="$(pin_check_rows 'not json {')"
[[ -z "$rows" ]] && pass "$t" || fail "$t" "$rows"

t="pin_check_rows: bare-root (unwrapped) manifest is accepted"
rows="$(pin_check_rows '{"srv":{"command":"npx","args":["pkg@latest"]}}')"
[[ "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "floating" ]] && pass "$t" || fail "$t" "$rows"

t="hostile server name cannot forge or split a row (@tsv)"
hostile_json="$(jq -nc '{mcpServers:{("a\tb\nfake\tnpx\tpinned\tx"):{command:"npx",args:["pkg@latest"]}}}')"
rows="$(pin_check_rows "$hostile_json")"
n_rows="$(printf '%s\n' "$rows" | grep -c . || true)"
if [[ "$n_rows" == "1" ]] && printf '%s' "$rows" | grep -q 'floating'; then pass "$t"; else fail "$t" "rows=$rows"; fi

# ---- vendored refinement (pin_check_refine_bare / pin_check_tree) ----------

tree="$TMP/tree-vendored"; mkdir -p "$tree/node_modules/pkg"
echo '{}' > "$tree/node_modules/pkg/package.json"
cat > "$tree/.mcp.json" <<'EOF'
{"mcpServers":{"srv":{"command":"npx","args":["pkg"]}}}
EOF
t="bare name vendored at node_modules/<pkg> → vendored"
rows="$(pin_check_tree "$tree")"
[[ "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "vendored" ]] && pass "$t" || fail "$t" "$rows"

tree="$TMP/tree-dir-only"; mkdir -p "$tree/node_modules/pkg"
cat > "$tree/.mcp.json" <<'EOF'
{"mcpServers":{"srv":{"command":"npx","args":["pkg"]}}}
EOF
t="bare dir without package.json does NOT buy the exemption"
rows="$(pin_check_tree "$tree")"
[[ "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "floating" ]] && pass "$t" || fail "$t" "$rows"

tree="$TMP/tree-symlink"; mkdir -p "$tree/node_modules" "$TMP/outside/pkg"
echo '{}' > "$TMP/outside/pkg/package.json"
ln -s "$TMP/outside/pkg" "$tree/node_modules/pkg"
cat > "$tree/.mcp.json" <<'EOF'
{"mcpServers":{"srv":{"command":"npx","args":["pkg"]}}}
EOF
t="symlinked node_modules entry does NOT buy the exemption"
rows="$(pin_check_tree "$tree")"
[[ "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "floating" ]] && pass "$t" || fail "$t" "$rows"

# A bare-class spec containing `..` must never be path-tested, even when a
# matching node_modules dir exists (untrusted field used as a path).
tree="$TMP/tree-traversal"; mkdir -p "$tree/node_modules/foo..bar"
echo '{}' > "$tree/node_modules/foo..bar/package.json"
cat > "$tree/.mcp.json" <<'EOF'
{"mcpServers":{"srv":{"command":"npx","args":["foo..bar"]}}}
EOF
t="'..'-containing bare spec is never path-tested → floating"
rows="$(pin_check_tree "$tree")"
[[ "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "floating" ]] && pass "$t" || fail "$t" "$rows"

# ---- pin_check_tree source files -------------------------------------------

tree="$TMP/tree-cpdir"; mkdir -p "$tree/.claude-plugin"
cat > "$tree/.claude-plugin/.mcp.json" <<'EOF'
{"mcpServers":{"srv":{"command":"uvx","args":["pkg"]}}}
EOF
t=".claude-plugin/.mcp.json is read"
rows="$(pin_check_tree "$tree")"
[[ "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "floating" ]] && pass "$t" || fail "$t" "$rows"

tree="$TMP/tree-pluginjson"; mkdir -p "$tree/.claude-plugin"
cat > "$tree/.claude-plugin/plugin.json" <<'EOF'
{"name":"x","author":{"name":"someone"},"mcpServers":{"srv":{"command":"npx","args":["pkg@latest"]}}}
EOF
t="plugin.json mcpServers read; other objects not misread as servers"
rows="$(pin_check_tree "$tree")"
n_rows="$(printf '%s\n' "$rows" | grep -c . || true)"
if [[ "$n_rows" == "1" && "$(printf '%s\n' "$rows" | awk -F'\t' '$1=="srv"{print $3}')" == "floating" ]]; then
  pass "$t"
else
  fail "$t" "$rows"
fi

tree="$TMP/tree-none"; mkdir -p "$tree"
t="tree without any manifest yields no rows"
rows="$(pin_check_tree "$tree")"
[[ -z "$rows" ]] && pass "$t" || fail "$t" "$rows"

# ---- waivers ----------------------------------------------------------------

wv="$TMP/waivers.txt"
cat > "$wv" <<'EOF'
# comment line
azure @azure/  # scope waiver
exact-entry chrome-devtools-mcp  # exact-name waiver
two-prefix @scope/ other-pkg  # two grants
bare-slug  # NO prefixes — must never waive
EOF

t="scope prefix waives a scoped floating spec"
if pin_check_entry_waived azure "@azure/mcp@latest" "$wv"; then pass "$t"; else fail "$t"; fi

t="scope prefix rejects a non-matching package"
if pin_check_entry_waived azure "evil@latest" "$wv"; then fail "$t"; else pass "$t"; fi

t="exact prefix waives the exact package (version tail stripped)"
if pin_check_entry_waived exact-entry "chrome-devtools-mcp@latest" "$wv"; then pass "$t"; else fail "$t"; fi

t="exact prefix rejects a prefix-extended package name"
if pin_check_entry_waived exact-entry "chrome-devtools-mcp-evil@latest" "$wv"; then fail "$t"; else pass "$t"; fi

t="every floating spec must be covered (one uncovered → no waiver)"
specs="@scope/a@latest
third-party@latest"
if pin_check_entry_waived two-prefix "$specs" "$wv"; then fail "$t"; else pass "$t"; fi

t="all specs covered across two grants"
specs="@scope/a@latest
other-pkg"
if pin_check_entry_waived two-prefix "$specs" "$wv"; then pass "$t"; else fail "$t"; fi

t="prefix-less waiver entry never waives"
if pin_check_entry_waived bare-slug "anything@latest" "$wv"; then fail "$t"; else pass "$t"; fi

t="unlisted slug never waives"
if pin_check_entry_waived unlisted "pkg@latest" "$wv"; then fail "$t"; else pass "$t"; fi

t="missing waiver file never waives"
if pin_check_entry_waived azure "@azure/mcp@latest" "$TMP/nope.txt"; then fail "$t"; else pass "$t"; fi

t="zero specs never waive"
if pin_check_entry_waived azure "" "$wv"; then fail "$t"; else pass "$t"; fi

t="pip operator tail stripped before matching"
if pin_check_entry_waived exact-entry "chrome-devtools-mcp>=1.0" "$wv"; then pass "$t"; else fail "$t"; fi

t="pip extras suffix stripped before matching"
if pin_check_entry_waived exact-entry "chrome-devtools-mcp[extra]==1.*" "$wv"; then pass "$t"; else fail "$t"; fi

# ---- floating-spec extraction ----------------------------------------------

t="pin_check_floating_specs lists floating specs only"
rows="$(printf 'a\tnpx\tfloating\tpkg@latest\nb\tnpx\tpinned\tpkg@1.2.3\nc\tnpx\tnone\t\nd\tuvx\tfloating\tx>=1\n')"
got="$(pin_check_floating_specs "$rows" | paste -sd',' -)"
[[ "$got" == "pkg@latest,x>=1" ]] && pass "$t" || fail "$t" "$got"

# ---- summary ----------------------------------------------------------------

echo
echo "test-pin-check: $((total-failures))/$total passed"
[[ "$failures" -eq 0 ]] || { echo "FAILURES: $failures"; exit 1; }
