#!/usr/bin/env bash
# Tests for scripts/known-errors.py and step 20's use of it, with a fake CLI.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
mkdir -p "$T/bin"
# Refuses names that start with "claude-", in the CLI's own words and layout.
cat > "$T/bin/claude" <<'EOF'
#!/usr/bin/env python3
import json, sys
p = json.load(open(sys.argv[3]))["plugins"]
bad = [(i, e["name"]) for i, e in enumerate(p) if e["name"].startswith("claude-")]
print(f"Validating marketplace manifest: {sys.argv[3]}\n")
if not bad and any("late" in e for e in p):  # an error it reports only when there is no other
    print("✘ Found 1 error:\n\n  ❯ plugins[0].late: no\n\n✘ Validation failed")
    sys.exit(1)
if bad:
    print(f"✘ Found {len(bad)} error{'s' if len(bad) > 1 else ''}:\n")
    for i, n in bad:
        print(f'  ❯ plugins[{i}].name: Plugin name "{n}" is reserved')
    print("\n⚠ Found 1 warning:\n\n  ❯ description: none\n\n✘ Validation failed")
    sys.exit(1)
print("✔ Validation passed")
EOF
chmod +x "$T/bin/claude"
run() { # name want(0/1) base head [scope] [fail-on-warnings]
  local rc=0
  rm -rf "$T/v"; mkdir -p "$T/v"
  [[ -n "$3" ]] && printf '{"plugins":%s}' "$3" > "$T/v/marketplace.base.json"
  printf '{"plugins":%s}' "$4" > "$T/v/marketplace.json"
  PATH="$T/bin:$PATH" ACTION_PATH="$HERE" VALIDATE_TMP="$T/v" SCOPE_ERRORS_TO_CHANGED="${5:-true}" \
    FAIL_ON_WARNINGS="${6:-false}" bash "$HERE/scripts/20-validate-cli-marketplace.sh" > "$T/out" 2>&1 || rc=1
  if [[ "$rc" == "$2" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1"; cat "$T/out"; fi
}
OLD='{"name":"claude-a","source":"x"}'; OK='{"name":"ok","source":"y"}'; CH='{"name":"claude-a","source":"z"}'
run "clean"                 0 "[$OK]" "[$OK]"
run "unchanged bad entry"   0 "[$OLD]" "[$OK,$OLD]"
run "other entry removed"   0 "[$OK,$OLD]" "[$OLD]"
run "bad entry changed"     1 "[$OLD]" "[$CH]"
run "bad entry added"       1 "[$OK]" "[$OK,$OLD]"
run "one old, one new"      1 "[$OLD]" "[$OLD,{\"name\":\"claude-b\"}]"
run "bad entry doubled"     1 "[$OLD]" "[$OLD,$OLD]"
run "forged line in a name" 1 "[$OLD]" "[$OLD,{\"name\":\"claude-b\\n  ❯ plugins[0].name: x\"}]"
run "hidden by an old error" 1 "[$OLD]" "[$OLD,{\"name\":\"x\",\"late\":1}]"
run "no base"               1 "" "[$OLD]"
run "empty base"            1 "[]" "[$OLD]"
run "scope off"             1 "[$OLD]" "[$OLD]" false
run "warnings fail"         1 "[$OLD]" "[$OLD]" true true
echo "test-known-errors: $pass passed, $fail failed"
[[ "$fail" == 0 ]]
