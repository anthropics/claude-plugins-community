#!/usr/bin/env bash
# Claude policy scan of changed external marketplace entries.
# Non-blocking by default; set FAIL_ON_FINDINGS=true to hard-fail.

source "$VALIDATE_LIB"

: "${ANTHROPIC_API_KEY:?}"
: "${MARKETPLACE_PATH:?}"
: "${BASE_REF:?}"
: "${ALLOWED_HOSTS:?}"
: "${SCAN_TIMEOUT_SECS:?}"
[[ "$SCAN_TIMEOUT_SECS" =~ ^[0-9]+$ ]] || die "scan-timeout-secs must be an integer"

PROMPT_FILE="${POLICY_PROMPT:-$ACTION_PATH/policy/prompt.md}"
SCHEMA_FILE="$ACTION_PATH/policy/schema.json"
[[ -f "$PROMPT_FILE" ]] || die "policy prompt not found at $PROMPT_FILE"

workroot="$(mktemp -d)"
trap 'rm -rf "$workroot"' EXIT

# ---- determine targets ----------------------------------------------------

group_start "Determine scan targets"

if [[ "${SCAN_ALL_EXTERNAL:-false}" == "true" ]]; then
  jq -c '[.plugins[] | select(.source|type=="object") | {name, source}]' -- "$MARKETPLACE_PATH" > "$workroot/targets.json"
else
  if git cat-file -e "$BASE_REF:$MARKETPLACE_PATH" 2>/dev/null; then
    git show "$BASE_REF:$MARKETPLACE_PATH" > "$workroot/base.json"
  else
    echo '{"plugins":[]}' > "$workroot/base.json"
  fi
  jq -c -s \
    '(.[0].plugins | map({(.name): .}) | add // {}) as $b
     | [.[1].plugins[]
        | select(.source|type=="object")
        | select(($b[.name] // null) != .)
        | {name, source}]' \
    "$workroot/base.json" "$MARKETPLACE_PATH" > "$workroot/targets.json"
fi

count="$(jq 'length' -- "$workroot/targets.json")"
log "Scan targets: $count"
group_end

if [[ "$count" -eq 0 ]]; then
  log "No external entries to scan."
  echo "scanned=[]" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "failed=[]" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "result=pass" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 0
fi

# ---- scan each target -----------------------------------------------------

scanned='[]'
failed='[]'
idx=0

entry_line() {
  grep -n "\"name\": \"$1\"" -- "$MARKETPLACE_PATH" 2>/dev/null | head -1 | cut -d: -f1 || true
}

while IFS= read -r ext; do
  idx=$((idx+1))
  name="$(jq -r '.name' <<<"$ext")"
  url="$(jq -r '.source.url // .source.repo // empty' <<<"$ext")"
  sha="$(jq -r '.source.sha // empty' <<<"$ext")"
  subdir="$(jq -r '.source.path // ""' <<<"$ext")"
  line="$(entry_line "$name")"
  loc="file=$MARKETPLACE_PATH${line:+,line=$line}"

  group_start "Scan: $name"

  if [[ -z "$url" || -z "$sha" ]]; then
    printf '::warning %s::scan-plugins: %s has no url or sha; skipping\n' "$loc" "$name"
    group_end; continue
  fi
  if [[ "$url" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    url="https://github.com/$url"
  fi
  if has_unsafe_chars "$url" || [[ ! "$url" =~ ^https://[A-Za-z0-9./_-]+$ ]]; then
    printf '::warning %s::scan-plugins: %s url unsafe; skipping\n' "$loc" "$name"
    group_end; continue
  fi
  host="${url#https://}"; host="${host%%/*}"
  ok=""; for h in $ALLOWED_HOSTS; do [[ "$host" == "$h" || "$host" == *".$h" ]] && { ok=1; break; }; done
  if [[ -z "$ok" ]]; then
    printf '::warning %s::scan-plugins: %s host not in allowlist; skipping\n' "$loc" "$name"
    group_end; continue
  fi
  if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    printf '::warning %s::scan-plugins: %s sha malformed; skipping\n' "$loc" "$name"
    group_end; continue
  fi
  if [[ -n "$subdir" ]] && { has_unsafe_chars "$subdir" || [[ "$subdir" == *".."* ]]; }; then
    printf '::warning %s::scan-plugins: %s subdir unsafe; skipping\n' "$loc" "$name"
    group_end; continue
  fi

  dest="$workroot/ext-$idx"
  mkdir -p -- "$dest"
  if ! timeout 120 git clone --quiet --depth 1 -- "$url" "$dest" 2>&1 \
     || ! git -C "$dest" fetch --quiet --depth 1 origin -- "$sha" 2>&1 \
     || ! git -C "$dest" -c advice.detachedHead=false checkout --quiet "$sha" -- 2>&1; then
    printf '::warning %s::scan-plugins: %s clone/fetch/checkout failed; skipping\n' "$loc" "$name"
    rm -rf -- "$dest"; group_end; continue
  fi
  target="$dest${subdir:+/$subdir}"
  if [[ ! -d "$target" ]]; then
    printf '::warning %s::scan-plugins: %s subdir not found at sha; skipping\n' "$loc" "$name"
    rm -rf -- "$dest"; group_end; continue
  fi

  prompt="$(cat "$PROMPT_FILE")"$'\n\n'"The plugin files are in the current working directory. Read every relevant file (\`.claude-plugin/plugin.json\`, \`.mcp.json\`, \`skills/\`, \`agents/\`, \`commands/\`, \`hooks/\`, and any source) before deciding."

  schema="$(cat "$SCHEMA_FILE")"
  raw="$(cd "$target" && timeout "$SCAN_TIMEOUT_SECS" \
           claude -p "$prompt" \
             --bare \
             --allowed-tools "Read,Glob,Grep" \
             --output-format json \
             --json-schema "$schema" \
           2>&1 || true)"

  # Only `passes` is gated here; --json-schema makes the other required fields
  # present-or-retry at the model layer, so jq -r on them yields strings (or
  # the literal "null" on rare malformed output) rather than crashing.
  verdict="$(jq -c '.result // empty' <<<"$raw" 2>/dev/null || true)"
  if [[ -z "$verdict" ]] || ! jq -e 'has("passes")' <<<"$verdict" >/dev/null 2>&1; then
    printf '::warning %s::scan-plugins: %s — could not parse verdict; raw output in step log\n' "$loc" "$name"
    log "$raw"
    rm -rf -- "$dest"; group_end; continue
  fi

  passes="$(jq -r '.passes' <<<"$verdict")"
  summary="$(jq -r '.summary' <<<"$verdict")"
  violations="$(jq -r '.violations' <<<"$verdict")"

  scanned="$(jq -c --arg n "$name" --argjson v "$verdict" '. + [($v + {name:$n})]' <<<"$scanned")"

  if [[ "$passes" == "true" ]]; then
    log "  ✓ $name passes — $summary"
  else
    failed="$(jq -c --arg n "$name" '. + [$n]' <<<"$failed")"
    if [[ "${FAIL_ON_FINDINGS:-false}" == "true" ]]; then
      printf '::error %s::scan-plugins: %s FAILS policy — %s\n' "$loc" "$name" "$violations"
    else
      printf '::warning %s::scan-plugins: %s fails policy (non-blocking) — %s\n' "$loc" "$name" "$violations"
    fi
  fi

  rm -rf -- "$dest"
  group_end
done < <(jq -c '.[]' -- "$workroot/targets.json")

# ---- summary --------------------------------------------------------------

fcount="$(jq 'length' <<<"$failed")"
{
  echo "## Policy scan"
  echo
  echo "Scanned $(jq 'length' <<<"$scanned") plugin(s). Policy failures: $fcount."
  echo
  if [[ "$(jq 'length' <<<"$scanned")" -gt 0 ]]; then
    echo "| Plugin | Passes | Net calls | Installs sw | Summary |"
    echo "|---|---|---|---|---|"
    jq -r '.[] | "| \(.name) | \(if .passes then "✅" else "❌" end) | \(if .may_make_external_network_calls then "yes" else "no" end) | \(if .may_download_additional_software then "yes" else "no" end) | \(.summary | .[0:120]) |"' <<<"$scanned"
  fi
  if [[ "$fcount" -gt 0 ]]; then
    echo
    echo "### Violations"
    jq -r --argjson s "$scanned" '$s[] | select(.passes==false) | "- **\(.name)** — \(.violations)"' <<<'null'
  fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

{
  echo "scanned=$scanned"
  echo "failed=$failed"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

if [[ "$fcount" -gt 0 && "${FAIL_ON_FINDINGS:-false}" == "true" ]]; then
  echo "result=fail" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 1
fi
echo "result=pass" >> "${GITHUB_OUTPUT:-/dev/stdout}"
