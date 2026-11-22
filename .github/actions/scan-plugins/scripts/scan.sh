#!/usr/bin/env bash
# Claude policy scan of changed external marketplace entries.
# Non-blocking by default; set FAIL_ON_FINDINGS=true to hard-fail.

source "$VALIDATE_LIB"

# Auth: either a static API key, or the WIF env-var set (the action's mint
# step exports ANTHROPIC_FEDERATION_RULE_ID + _IDENTITY_TOKEN_FILE etc.; review.py
# reads those and exchanges the JWT itself).
if [[ -z "${ANTHROPIC_API_KEY:-}" && -z "${ANTHROPIC_FEDERATION_RULE_ID:-}" ]]; then
  die "no Anthropic auth: need ANTHROPIC_API_KEY or ANTHROPIC_FEDERATION_RULE_ID"
fi
: "${MARKETPLACE_PATH:?}"
: "${BASE_REF:?}"
: "${ALLOWED_HOSTS:?}"
: "${SCAN_TIMEOUT_SECS:?}"
: "${SCAN_MODEL:?}"
export SCAN_TIMEOUT_SECS SCAN_MODEL
[[ "$SCAN_TIMEOUT_SECS" =~ ^[1-9][0-9]*$ ]] || die "scan-timeout-secs must be a whole number above 0"

PROMPT_FILE="${POLICY_PROMPT:-$ACTION_PATH/policy/prompt.md}"
[[ -f "$PROMPT_FILE" ]] || die "policy prompt not found at $PROMPT_FILE"

workroot="$(mktemp -d)"
trap 'rm -rf "$workroot"' EXIT

# ---- helpers --------------------------------------------------------------

# Redact credential-shaped strings (Anthropic API keys, and JWTs: three
# base64url segments, the first two starting with "eyJ", which is base64 for
# {") from text before it reaches a log, annotation, summary or output.
scrub() {
  sed -E \
    -e 's/sk-ant-[A-Za-z0-9_-]{8,}/[REDACTED]/g' \
    -e 's/eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/[REDACTED]/g'
}

# Reduce the model's structured output to the verdict fields this action
# knows, coerced to their types, with the same redaction applied and string
# lengths capped — so a verdict has a bounded, predictable shape and size no
# matter what the model emitted. Anything that is not an object with a
# boolean `passes` yields no output.
normalize_verdict() {
  jq -c 'def clean: tostring
           | gsub("sk-ant-[A-Za-z0-9_-]{8,}"; "[REDACTED]")
           | gsub("eyJ[A-Za-z0-9_-]{8,}\\.eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"; "[REDACTED]")
           | .[0:4000];
         select(type == "object" and (.passes | type) == "boolean")
         | {passes,
            summary: ((.summary // "") | clean),
            violations: ((.violations // "") | clean),
            may_make_external_network_calls: (.may_make_external_network_calls == true),
            may_download_additional_software: (.may_download_additional_software == true)}'
}

# One line, no workflow-command syntax: model-produced text is printed inside
# ::warning/::error annotations and log lines, where an embedded newline would
# start a new line that the runner parses for "::" / "##[" commands.
oneline() { tr '\r\n' '  ' | sed -e 's/::/: :/g' -e 's/##\[/# #[/g'; }

# The WIF mint step masks the first identity token it writes, but its
# background refresh rewrites the file every few minutes and cannot issue
# workflow commands. Re-mask whatever is in the file now, from this
# (foreground) step, before each model invocation.
mask_identity_token() {
  local f="${ANTHROPIC_IDENTITY_TOKEN_FILE:-}"
  if [[ -n "$f" && -r "$f" && -s "$f" ]]; then
    printf '::add-mask::%s\n' "$(cat -- "$f")"
  fi
}

# Entries that could not be reviewed at all (clone failure, unusable result,
# timeout, ...). With fail-on-findings they fail the step: an entry nobody
# could look at must not pass a required policy check.
not_assessed='[]'
skip_entry() {  # <loc> <name> <reason>
  printf '::warning %s::scan-plugins: %s — %s; not assessed\n' "$1" "$2" "$3"
  not_assessed="$(jq -c --arg n "$2" --arg r "$3" '. + [{name:$n, reason:$r}]' <<<"$not_assessed")"
}

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
    skip_entry "$loc" "$name" "no url or sha"; group_end; continue
  fi
  if [[ "$url" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    url="https://github.com/$url"
  fi
  if has_unsafe_chars "$url" || [[ ! "$url" =~ ^https://[A-Za-z0-9./_-]+$ ]]; then
    skip_entry "$loc" "$name" "url unsafe"; group_end; continue
  fi
  host="${url#https://}"; host="${host%%/*}"
  ok=""; for h in $ALLOWED_HOSTS; do [[ "$host" == "$h" || "$host" == *".$h" ]] && { ok=1; break; }; done
  if [[ -z "$ok" ]]; then
    skip_entry "$loc" "$name" "host not in allowlist"; group_end; continue
  fi
  if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    skip_entry "$loc" "$name" "sha malformed"; group_end; continue
  fi
  if [[ -n "$subdir" ]] && { has_unsafe_chars "$subdir" || [[ "$subdir" == *".."* ]]; }; then
    skip_entry "$loc" "$name" "subdir unsafe"; group_end; continue
  fi

  dest="$workroot/ext-$idx"
  mkdir -p -- "$dest"
  # Nothing is checked out: review.py reads the files from git objects.
  if ! timeout 120 env GIT_LFS_SKIP_SMUDGE=1 GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 --no-checkout -- "$url" "$dest" 2>&1 \
     || ! timeout 120 env GIT_LFS_SKIP_SMUDGE=1 GIT_TERMINAL_PROMPT=0 git -C "$dest" fetch --quiet --depth 1 origin -- "$sha" 2>&1; then
    skip_entry "$loc" "$name" "clone/fetch failed"
    rm -rf -- "$dest"; group_end; continue
  fi

  mask_identity_token
  # One request, and the model has no tools: see review.py. </dev/null: the
  # loop's targets come in on stdin.
  raw="$(timeout -k 10 "$((SCAN_TIMEOUT_SECS + 60))" python3 -I "$ACTION_PATH/scripts/review.py" \
           "$dest" "$sha" "$subdir" "$PROMPT_FILE" \
           </dev/null 2>"$workroot/review-stderr.log")" && rc=0 || rc=$?
  # The token file may have been refreshed while the review ran; mask the
  # current value before anything derived from the run is printed.
  mask_identity_token

  # The verdict is model output shaped by the plugin under review: redact it
  # and cap its length before it goes anywhere. Only "passes" is gated.
  verdict=""
  if [[ "$rc" -eq 0 ]]; then
    verdict="$(normalize_verdict <<<"$raw" 2>/dev/null || true)"
  fi
  if [[ -z "$verdict" ]]; then
    case "$rc" in
      0)       why="review returned no usable verdict" ;;
      3)       why="$(scrub <"$workroot/review-stderr.log" | head -n 1 | cut -c1-400 | tr -d '\n' | oneline)" ;;
      124|137) why="review timed out" ;;
      *)       why="review stopped with status $rc" ;;
    esac
    log "  $why"
    skip_entry "$loc" "$name" "$why"
    rm -rf -- "$dest"; group_end; continue
  fi

  passes="$(jq -r '.passes' <<<"$verdict")"
  summary="$(jq -r '.summary' <<<"$verdict" | oneline)"
  violations="$(jq -r '.violations' <<<"$verdict" | oneline)"

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
  jq '.' <<<"$verdict" | sed -e 's/^/    /' -e 's/##\[/# #[/g'

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
ncount="$(jq 'length' <<<"$not_assessed")"
{
  echo "## Policy scan"
  echo
  echo "Scanned $(jq 'length' <<<"$scanned") plugin(s). Policy failures: $fcount. Not assessed: $ncount."
  echo
  if [[ "$(jq 'length' <<<"$scanned")" -gt 0 ]]; then
    echo "| Plugin | Passes | Unpinned auto-exec | Net calls | Installs sw | Summary |"
    echo "|---|---|---|---|---|---|"
    # summary/violations are model text shaped by the reviewed repo: strip
    # Markdown control characters before they reach the rendered summary.
    jq -r 'def cell: gsub("[|\n\r\\[\\]<>`]"; " ");
      .[] | "| \(.name) | \(if .passes then "✅" else "❌" end) | \(if .unpinned_autoexec_runtime then "⚠️ yes" else "no" end) | \(if .may_make_external_network_calls then "yes" else "no" end) | \(if .may_download_additional_software then "yes" else "no" end) | \(.summary | cell | .[0:120]) |"' <<<"$scanned"
  fi
  if [[ "$fcount" -gt 0 ]]; then
    echo
    echo "### Violations"
    jq -r 'def cell: gsub("[|\n\r\\[\\]<>`]"; " "); .[] | select(.passes==false) | "- **\(.name)** — \(.violations | cell | .[0:500])"' <<<"$scanned"
  fi
  if [[ "$ncount" -gt 0 ]]; then
    echo
    echo "### Not assessed"
    jq -r 'def cell: gsub("[|\n\r\\[\\]<>`]"; " "); .[] | "- **\(.name | cell)** — `\(.reason | cell)`"' <<<"$not_assessed"
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
# Fail closed: with fail-on-findings, an entry that could not be reviewed at
# all fails the step. Such entries are in neither `scanned` nor `failed`, so a
# consumer can tell "policy failure" (non-empty `failed`) from "no verdict"
# (step failed, `failed` empty) and, for example, not auto-revert the latter.
if [[ "$ncount" -gt 0 ]]; then
  names="$(jq -r '[.[].name] | join(", ")' <<<"$not_assessed")"
  if [[ "${FAIL_ON_FINDINGS:-false}" == "true" ]]; then
    printf '::error::scan-plugins: %s of %s entrie(s) could not be assessed (%s); failing rather than passing them unreviewed. Re-run if the cause was transient.\n' "$ncount" "$count" "$names"
    echo "result=fail" >> "${GITHUB_OUTPUT:-/dev/stdout}"
    exit 1
  fi
  printf '::warning::scan-plugins: %s of %s entrie(s) could not be assessed (%s).\n' "$ncount" "$count" "$names"
fi
echo "result=pass" >> "${GITHUB_OUTPUT:-/dev/stdout}"
