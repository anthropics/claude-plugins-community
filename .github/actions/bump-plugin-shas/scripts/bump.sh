#!/usr/bin/env bash
# Discover stale external SHAs, validate at new HEAD, open one PR with all
# passing bumps. See action.yml for the design rationale.

source "$VALIDATE_LIB"

: "${MARKETPLACE_PATH:?}"
: "${MAX_BUMPS:?}"
[[ "$MAX_BUMPS" =~ ^[0-9]+$ ]] || die "max-bumps must be a non-negative integer (got: $MAX_BUMPS)"
: "${ALLOWED_HOSTS:?}"
: "${PR_BRANCH:?}"
: "${BASE_BRANCH:?}"
: "${GH_TOKEN:?}"

[[ -f "$MARKETPLACE_PATH" ]] || die "marketplace not found at $MARKETPLACE_PATH"

workroot="$(mktemp -d)"
trap 'rm -rf "$workroot"' EXIT

bumped='[]'
skipped='[]'
checked=0
applied=0

skip() {
  local name="$1" reason="$2"
  warn "$name: skipped ($reason)"
  skipped="$(jq -c --arg n "$name" --arg r "$reason" '. + [{name:$n, reason:$r}]' <<<"$skipped")"
}

group_start "Discover stale SHAs and validate at new HEAD"

while IFS= read -r entry; do
  (( applied >= MAX_BUMPS )) && { log "Reached max-bumps=$MAX_BUMPS; stopping discovery."; break; }
  checked=$((checked+1))

  name="$(jq -r '.name' <<<"$entry")"
  url="$(jq -r '.source.url // .source.repo // empty' <<<"$entry")"
  old_sha="$(jq -r '.source.sha // empty' <<<"$entry")"
  subdir="$(jq -r '.source.path // ""' <<<"$entry")"

  [[ -n "$url" ]] || { skip "$name" "no url/repo on source"; continue; }

  if [[ "$url" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    full_url="https://github.com/$url"
  else
    full_url="$url"
  fi
  if has_unsafe_chars "$full_url" || [[ ! "$full_url" =~ ^https://[A-Za-z0-9./_-]+$ ]]; then
    skip "$name" "unsafe url"; continue
  fi
  host="${full_url#https://}"; host="${host%%/*}"
  ok=""
  for h in $ALLOWED_HOSTS; do
    [[ "$host" == "$h" || "$host" == *".$h" ]] && { ok=1; break; }
  done
  [[ -n "$ok" ]] || { skip "$name" "host '$host' not in allowlist"; continue; }
  [[ -z "$subdir" ]] || { has_unsafe_chars "$subdir" && { skip "$name" "unsafe subdir"; continue; }; }

  # || true masks SIGPIPE from head -1; the regex below catches partial reads.
  new_sha="$(git ls-remote -- "$full_url" HEAD 2>/dev/null | awk '{print $1}' | head -1 || true)"
  if [[ ! "$new_sha" =~ ^[0-9a-f]{40}$ ]]; then
    skip "$name" "ls-remote failed or returned no HEAD"; continue
  fi
  if [[ "$new_sha" == "$old_sha" ]]; then
    continue
  fi

  log "---- $name: $old_sha -> $new_sha ----"

  dest="$workroot/ext-$checked"
  mkdir -p -- "$dest"
  if ! timeout 120 git clone --quiet --depth 1 -- "$full_url" "$dest" 2>&1; then
    skip "$name" "clone failed"; rm -rf -- "$dest"; continue
  fi
  if ! git -C "$dest" fetch --quiet --depth 1 origin -- "$new_sha" 2>&1; then
    skip "$name" "fetch of new sha failed"; rm -rf -- "$dest"; continue
  fi
  if ! git -C "$dest" -c advice.detachedHead=false checkout --quiet "$new_sha" -- 2>&1; then
    skip "$name" "checkout of new sha failed"; rm -rf -- "$dest"; continue
  fi

  target="$dest${subdir:+/$subdir}"
  manifest="$target/.claude-plugin/plugin.json"
  if [[ ! -f "$manifest" ]]; then
    skip "$name" "no .claude-plugin/plugin.json at new sha"; rm -rf -- "$dest"; continue
  fi
  if ! out="$(timeout 120 claude plugin validate "$manifest" 2>&1)"; then
    skip "$name" "validation failed at new sha: $(head -1 <<<"$out")"
    rm -rf -- "$dest"; continue
  fi
  rm -rf -- "$dest"

  jq --arg n "$name" --arg s "$new_sha" \
    '(.plugins[] | select(.name==$n) | .source.sha) = $s' \
    -- "$MARKETPLACE_PATH" > "$MARKETPLACE_PATH.tmp"
  mv -- "$MARKETPLACE_PATH.tmp" "$MARKETPLACE_PATH"

  bumped="$(jq -c --arg n "$name" --arg o "$old_sha" --arg s "$new_sha" \
    '. + [{name:$n, old_sha:$o, new_sha:$s}]' <<<"$bumped")"
  applied=$((applied+1))
  log "  ✓ $name validated and bumped"
done < <(jq -c '.plugins[] | select(.source | type=="object")' -- "$MARKETPLACE_PATH")

group_end

{
  echo "bumped=$bumped"
  echo "skipped=$skipped"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

{
  echo "## Bump Plugin SHAs"
  echo
  echo "Checked $checked external entries. Bumped $applied, skipped $(jq 'length' <<<"$skipped")."
  echo
  if (( applied > 0 )); then
    echo "| Plugin | Old SHA | New SHA |"
    echo "|---|---|---|"
    jq -r '.[] | "| \(.name) | `\(.old_sha[0:12] // "(none)")` | `\(.new_sha[0:12])` |"' <<<"$bumped"
  fi
  if [[ "$(jq 'length' <<<"$skipped")" -gt 0 ]]; then
    echo
    echo "<details><summary>Skipped</summary>"
    echo
    jq -r '.[] | "- **\(.name)** — \(.reason)"' <<<"$skipped"
    echo
    echo "</details>"
  fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if (( applied == 0 )); then
  log "Nothing to bump."
  echo "pr-url=" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 0
fi

group_start "Open PR"

git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout -B "$PR_BRANCH"
git add -- "$MARKETPLACE_PATH"
git commit -m "Bump $applied plugin SHA pin(s) to upstream HEAD"
git push --force-with-lease origin "$PR_BRANCH"

body="$workroot/pr-body.md"
{
  echo "Automated SHA bump. Each entry below was cloned at the new SHA and passed \`claude plugin validate\` in [this workflow run]($RUN_URL) before being included."
  echo
  echo "| Plugin | Old SHA | New SHA |"
  echo "|---|---|---|"
  jq -r '.[] | "| \(.name) | `\(.old_sha[0:12] // "(none)")` | `\(.new_sha[0:12])` |"' <<<"$bumped"
  if [[ "$(jq 'length' <<<"$skipped")" -gt 0 ]]; then
    echo
    echo "Skipped (not bumped — see run for details): $(jq -r 'map(.name) | join(", ")' <<<"$skipped")"
  fi
} > "$body"

if existing="$(gh pr list --head "$PR_BRANCH" --base "$BASE_BRANCH" --state open --json url -q '.[0].url' 2>/dev/null)" && [[ -n "$existing" ]]; then
  gh pr edit "$existing" --body-file "$body"
  pr_url="$existing"
else
  pr_url="$(gh pr create --base "$BASE_BRANCH" --head "$PR_BRANCH" \
    --title "Bump $applied plugin SHA pin(s)" --body-file "$body")"
fi

echo "pr-url=$pr_url" >> "${GITHUB_OUTPUT:-/dev/stdout}"
log "PR: $pr_url"
group_end
