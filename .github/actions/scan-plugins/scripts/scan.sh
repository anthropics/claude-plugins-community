#!/usr/bin/env bash
# Claude policy scan of changed external marketplace entries.
# Non-blocking by default; set FAIL_ON_FINDINGS=true to hard-fail.

source "$VALIDATE_LIB"

# Auth: either a static API key, or the WIF env-var set (the action's mint
# step exports ANTHROPIC_FEDERATION_RULE_ID + _IDENTITY_TOKEN_FILE etc.; the
# claude CLI reads those and exchanges the JWT itself). Unset an empty
# ANTHROPIC_API_KEY so the CLI doesn't see a blank X-Api-Key header.
if [[ -z "${ANTHROPIC_API_KEY:-}" && -z "${ANTHROPIC_FEDERATION_RULE_ID:-}" ]]; then
  die "no Anthropic auth: need ANTHROPIC_API_KEY or ANTHROPIC_FEDERATION_RULE_ID"
fi
[[ -z "${ANTHROPIC_API_KEY:-}" ]] && unset ANTHROPIC_API_KEY
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

# Shared with static-pin-check.sh (lib/targets.sh) so the AI review and the
# static pin check resolve the identical target set.
source "$ACTION_PATH/lib/targets.sh"

group_start "Determine scan targets"

resolve_scan_targets "$MARKETPLACE_PATH" "$BASE_REF" "${SCAN_ALL_EXTERNAL:-false}" "$workroot/targets.json"

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
  # </dev/null: claude -p reads stdin if available, which would consume the
  # remaining lines of the targets pipe and silently truncate the loop.
  raw="$(cd "$target" && timeout "$SCAN_TIMEOUT_SECS" \
           claude -p "$prompt" \
             --bare \
             --allowed-tools "Read,Glob,Grep" \
             --output-format json \
             --json-schema "$schema" \
           </dev/null 2>&1 || true)"

  # --json-schema places the validated object at .structured_output;
  # .result is the text result. Only `passes` is gated.
  verdict="$(jq -c '.structured_output // empty' <<<"$raw" 2>/dev/null || true)"
  if [[ -z "$verdict" ]] || ! jq -e 'has("passes")' <<<"$verdict" >/dev/null 2>&1; then
    printf '::warning %s::scan-plugins: %s — could not parse verdict; raw output in step log\n' "$loc" "$name"
    log "$raw"
    rm -rf -- "$dest"; group_end; continue
  fi

  passes="$(jq -r '.passes' <<<"$verdict")"
  summary="$(jq -r '.summary' <<<"$verdict")"
  violations="$(jq -r '.violations' <<<"$verdict")"

  # Join the static pin check's action-emitted fields (never model-produced —
  # the model's verdict cannot set them). PIN_RESULTS_FILE is exported by the
  # static-pin-check step; absent (e.g. standalone scan.sh use) → false/[].
  pin_extra='{"unpinned_autoexec_runtime":false,"unpinned_autoexec_specs":[]}'
  if [[ -n "${PIN_RESULTS_FILE:-}" && -f "${PIN_RESULTS_FILE:-}" ]]; then
    pin_extra="$(jq -c --arg n "$name" \
      '[.[] | select(.name==$n)][0] // {}
       | {unpinned_autoexec_runtime: (.unpinned_autoexec_runtime // false),
          unpinned_autoexec_specs:   (.unpinned_autoexec_specs   // [])}' \
      -- "$PIN_RESULTS_FILE" 2>/dev/null || echo '{"unpinned_autoexec_runtime":false,"unpinned_autoexec_specs":[]}')"
  fi

  scanned="$(jq -c --arg n "$name" --argjson v "$verdict" --argjson p "$pin_extra" '. + [($v + $p + {name:$n})]' <<<"$scanned")"

  log "  verdict:"
  jq '.' <<<"$verdict" | sed 's/^/    /'

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
    echo "| Plugin | Passes | Unpinned auto-exec | Net calls | Installs sw | Summary |"
    echo "|---|---|---|---|---|---|"
    jq -r '.[] | "| \(.name) | \(if .passes then "✅" else "❌" end) | \(if .unpinned_autoexec_runtime then "⚠️ yes" else "no" end) | \(if .may_make_external_network_calls then "yes" else "no" end) | \(if .may_download_additional_software then "yes" else "no" end) | \(.summary | .[0:120]) |"' <<<"$scanned"
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
