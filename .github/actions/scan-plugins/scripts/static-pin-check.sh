#!/usr/bin/env bash
# Deterministic runtime pin-state check of changed external marketplace
# entries — the auth-free sibling of scan.sh's AI policy review. For each
# target it clones the pinned SHA and classifies every declared .mcp.json
# MCP server's launcher spec (lib/pin-check.sh): a FLOATING npx/bunx/uvx/pipx
# spec auto-launches registry-resolved code at session start, which the
# entry's pinned source.sha does not fix.
#
# Detection is ALWAYS ON (::warning:: per floating server + the
# unpinned_autoexec_* fields). Whether a non-waived floating launcher FAILS
# the job is the caller's `fail-on-unpinned-autoexec` input
# (FAIL_ON_UNPINNED_AUTOEXEC) — detect-and-annotate only by default.
# Package-grained exceptions ride the file named by LAUNCH_SHAPE_WAIVERS.
#
# Runs with NO Anthropic auth, so consumers get pin enforcement even when the
# AI review is skipped.
#
# An entry with a manifest committed as a symlink, or stored through git LFS,
# is reported as not assessed.

source "$VALIDATE_LIB"
source "$ACTION_PATH/lib/pin-check.sh"
source "$ACTION_PATH/lib/targets.sh"

: "${MARKETPLACE_PATH:?}"
: "${BASE_REF:?}"
: "${ALLOWED_HOSTS:?}"
FAIL_ON_UNPINNED_AUTOEXEC="${FAIL_ON_UNPINNED_AUTOEXEC:-false}"
LAUNCH_SHAPE_WAIVERS="${LAUNCH_SHAPE_WAIVERS:-}"

# A configured-but-missing waivers file is a structural error, not a warn: the
# caller explicitly opted in, and silently running with zero waivers would
# either spuriously hard-fail waived entries (fail mode) or silently re-warn
# adjudicated exceptions (warn mode). Same loud-die posture as bump.sh's
# tracking-config.
if [[ -n "$LAUNCH_SHAPE_WAIVERS" && ! -f "$LAUNCH_SHAPE_WAIVERS" ]]; then
  die "launch-shape-waivers file not found at $LAUNCH_SHAPE_WAIVERS"
fi

[[ -f "$MARKETPLACE_PATH" ]] || die "marketplace not found at $MARKETPLACE_PATH"

workroot="$(mktemp -d)"
trap 'rm -rf "$workroot"' EXIT

group_start "Static pin check: determine targets"
resolve_scan_targets "$MARKETPLACE_PATH" "$BASE_REF" "${SCAN_ALL_EXTERNAL:-false}" "$workroot/targets.json"
count="$(jq 'length' -- "$workroot/targets.json")"
log "Pin-check targets: $count"
group_end

pin_results_file="${RUNNER_TEMP:-$workroot}/pin-scanned.json"

if [[ "$count" -eq 0 ]]; then
  log "No external entries to pin-check."
  echo '[]' > "$pin_results_file"
  [[ -n "${GITHUB_ENV:-}" ]] && echo "PIN_RESULTS_FILE=$pin_results_file" >> "$GITHUB_ENV"
  echo "pin-scanned=[]" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "pin-failed=[]" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "result=pass" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 0
fi

entry_line() {
  grep -n "\"name\": \"$1\"" -- "$MARKETPLACE_PATH" 2>/dev/null | head -1 | cut -d: -f1 || true
}

pin_scanned='[]'
pin_failed='[]'
idx=0

# record NAME ASSESSED RUNTIME SPECS_JSON — append one entry's result.
record() {
  pin_scanned="$(jq -c --arg n "$1" --argjson a "$2" --argjson r "$3" --argjson s "$4" \
    '. + [{name:$n, assessed:$a, unpinned_autoexec_runtime:$r, unpinned_autoexec_specs:$s}]' <<<"$pin_scanned")"
}

# manifest_problem CLONE_ROOT PLUGIN_DIR SUBDIR: print one constant reason
# (no text from the plugin repo) why the entry cannot be assessed, or nothing if
# manifests and .claude-plugin are regular files or folders, not LFS pointers.
manifest_problem() {
  local root plug rel rec p
  root="$(cd "$1" 2>/dev/null && pwd -P)" || root=""
  plug="$(cd "$2" 2>/dev/null && pwd -P)" || plug=""
  if [[ -z "$root" || -z "$plug" ]] || [[ "$plug" != "$root" && "$plug" != "$root"/* ]]; then
    printf 'source.path does not resolve to a folder inside the plugin repository'; return 0
  fi
  # source.path as git spells it: one slash between names, no "." names, no
  # leading slash, a trailing one. ".." was refused before the clone.
  rel="/$3/"
  while [[ "$rel" == *//* ]]; do rel="${rel//\/\//\/}"; done
  while [[ "$rel" == */./* ]]; do rel="${rel//\/.\//\/}"; done
  rel="${rel#/}"
  # A committed symlink is a plain file on disk here, so ask git what it checked
  # out: the index lists a symlink with mode 120000. Run from the clone root,
  # paths literal. The folder's path also lists what is under the folder.
  if ! git -C "$root" --literal-pathspecs ls-files -s -z -- \
         "${rel}.mcp.json" "${rel}plugin.json" "${rel}.claude-plugin" \
         > "$workroot/manifest-modes" 2>/dev/null; then
    printf 'git could not list the plugin files at the pinned sha (a fault in this check, not in the plugin; re-run the job)'; return 0
  fi
  while IFS= read -r -d '' rec; do
    [[ "$rec" == 120000\ * ]] || continue
    case "${rec#*$'\t'}" in
      "${rel}.claude-plugin/.mcp.json")   p=".claude-plugin/.mcp.json" ;;
      "${rel}.claude-plugin/plugin.json") p=".claude-plugin/plugin.json" ;;
      "${rel}.claude-plugin")             p="the .claude-plugin folder" ;;
      "${rel}.mcp.json")                  p=".mcp.json" ;;
      "${rel}plugin.json")                p="plugin.json" ;;
      *) continue ;;
    esac
    printf '%s is a symlink in the plugin repository, and this check does not follow symlinks' "$p"; return 0
  done < "$workroot/manifest-modes"
  # On disk these must be regular files or folders (symlinks are gone by now).
  for p in .claude-plugin .mcp.json plugin.json .claude-plugin/.mcp.json .claude-plugin/plugin.json; do
    if [[ -L "$plug/$p" ]] || [[ -e "$plug/$p" && ! -f "$plug/$p" && ! -d "$plug/$p" ]]; then
      printf '%s is a symlink or other special file, and this check reads only regular files and folders' "$p"; return 0
    fi
    # LFS objects are not fetched, so an LFS-stored manifest is a pointer file.
    [[ -f "$plug/$p" ]] || continue
    rec=""; IFS= read -r -n 48 rec < "$plug/$p" 2>/dev/null || true
    if [[ "$rec" == "version https://git-lfs.github.com/spec/v1"* ]]; then
      printf '%s is stored through git LFS, and this check does not download LFS files' "$p"; return 0
    fi
  done
  return 0
}

while IFS= read -r ext; do
  idx=$((idx+1))
  name="$(jq -r '.name' <<<"$ext")"
  url="$(jq -r '.source.url // .source.repo // empty' <<<"$ext")"
  sha="$(jq -r '.source.sha // empty' <<<"$ext")"
  subdir="$(jq -r '.source.path // ""' <<<"$ext")"
  line="$(entry_line "$name")"
  loc="file=$MARKETPLACE_PATH${line:+,line=$line}"

  group_start "Pin check: $name"

  # Target hygiene guards — KEEP IN SYNC with scan.sh's per-target guard block
  # (same order, same reject conditions). An unassessable target records
  # assessed=false and is skipped, never failed: an unclonable entry ships
  # nothing new (validate/scan surface clone/URL problems), and one skipped for
  # a symlinked or LFS-stored manifest is left to callers gating on `assessed`.
  skip_unassessed() {
    printf '::warning %s::static-pin-check: %s — %s; pin-state not assessed\n' "$loc" "$name" "$1"
    record "$name" false false '[]'
    rm -rf -- "$workroot/ext-$idx"
    group_end
  }

  if [[ -z "$url" || -z "$sha" ]]; then skip_unassessed "no url or sha"; continue; fi
  if [[ "$url" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    url="https://github.com/$url"
  fi
  if has_unsafe_chars "$url" || [[ ! "$url" =~ ^https://[A-Za-z0-9./_-]+$ ]]; then
    skip_unassessed "url unsafe"; continue
  fi
  host="${url#https://}"; host="${host%%/*}"
  ok=""; for h in $ALLOWED_HOSTS; do [[ "$host" == "$h" || "$host" == *".$h" ]] && { ok=1; break; }; done
  if [[ -z "$ok" ]]; then skip_unassessed "host not in allowlist"; continue; fi
  if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then skip_unassessed "sha malformed"; continue; fi
  if [[ -n "$subdir" ]] && { has_unsafe_chars "$subdir" || [[ "$subdir" == *".."* ]]; }; then
    skip_unassessed "subdir unsafe"; continue
  fi

  dest="$workroot/ext-$idx"
  mkdir -p -- "$dest"
  # KEEP IN SYNC with scan.sh's clone. core.symlinks=false: a symlink in the
  # plugin repo is checked out as a plain file, so nothing read below leads out
  # of the checkout. GIT_LFS_SKIP_SMUDGE: the checkout fetches no LFS objects.
  if ! timeout 120 env GIT_LFS_SKIP_SMUDGE=1 GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 --config core.symlinks=false -- "$url" "$dest" 2>&1 \
     || ! env GIT_LFS_SKIP_SMUDGE=1 GIT_TERMINAL_PROMPT=0 git -C "$dest" fetch --quiet --depth 1 origin -- "$sha" 2>&1 \
     || ! env GIT_LFS_SKIP_SMUDGE=1 git -C "$dest" -c advice.detachedHead=false checkout --quiet "$sha" -- 2>&1; then
    skip_unassessed "clone/fetch/checkout failed"; continue
  fi
  # Second guard: delete any symlink left on disk despite core.symlinks=false.
  find "$dest" -type l -delete 2>/dev/null || true
  target="$dest${subdir:+/$subdir}"
  if [[ ! -d "$target" ]]; then skip_unassessed "subdir not found at sha"; continue; fi
  problem="$(manifest_problem "$dest" "$target" "$subdir")"
  if [[ -n "$problem" ]]; then skip_unassessed "$problem"; continue; fi

  rows="$(pin_check_tree "$target")"
  floating_specs="$(pin_check_floating_specs "$rows")"

  if [[ -z "$floating_specs" ]]; then
    log "  ✓ $name: no floating auto-exec launcher specs"
    record "$name" true false '[]'
    rm -rf -- "$dest"; group_end; continue
  fi

  waived=false
  if [[ -n "$LAUNCH_SHAPE_WAIVERS" ]] \
     && pin_check_entry_waived "$name" "$floating_specs" "$LAUNCH_SHAPE_WAIVERS"; then
    waived=true
    log "  $name: floating spec(s) fully covered by the waivers file (entry '$name')"
  fi

  # Build the detail array from the refined rows (floating rows only —
  # pinned/vendored/local/vcsref never surface; `none` rows are logged).
  specs_json="$(printf '%s\n' "$rows" | jq -R -s -c --argjson w "$waived" '
    split("\n") | map(select(length > 0) | split("\t")
      | select(.[2] == "floating")
      | {server: .[0], launcher: .[1], class: .[2], spec: .[3], waived: $w})' 2>/dev/null || echo '[]')"
  none_servers="$(printf '%s\n' "$rows" | awk -F'\t' '$3=="none"{print $1}' | paste -sd', ' -)"
  [[ -n "$none_servers" ]] && log "  $name: launcher server(s) [$none_servers] carry no derivable package spec (not assessed)"

  if [[ "$waived" == "true" ]]; then
    record "$name" true false "$specs_json"
    rm -rf -- "$dest"; group_end; continue
  fi

  record "$name" true true "$specs_json"
  pin_failed="$(jq -c --arg n "$name" '. + [$n]' <<<"$pin_failed")"

  spec_list="$(printf '%s\n' "$floating_specs" | paste -sd', ' -)"
  msg="declares MCP server(s) that auto-launch an UNPINNED package-manager fetch at session start ($spec_list) — the entry's pinned source.sha does not fix the executed code. Pin an exact version (pkg@1.2.3 for npx/bunx; pkg==1.2.3 for uvx/pipx)."
  if [[ "$FAIL_ON_UNPINNED_AUTOEXEC" == "true" ]]; then
    printf '::error %s::static-pin-check: %s %s\n' "$loc" "$name" "$msg"
  else
    printf '::warning %s::static-pin-check: %s %s\n' "$loc" "$name" "$msg"
  fi

  rm -rf -- "$dest"
  group_end
done < <(jq -c '.[]' -- "$workroot/targets.json")

# ---- outputs + summary ------------------------------------------------------

printf '%s' "$pin_scanned" > "$pin_results_file"
[[ -n "${GITHUB_ENV:-}" ]] && echo "PIN_RESULTS_FILE=$pin_results_file" >> "$GITHUB_ENV"

fcount="$(jq 'length' <<<"$pin_failed")"
{
  echo "## Static pin check (auto-exec runtime pinning)"
  echo
  echo "Checked $(jq 'length' <<<"$pin_scanned") entr(ies). Non-waived floating auto-exec launcher(s): $fcount."
  echo
  if [[ "$fcount" -gt 0 ]]; then
    echo "| Plugin | Server | Launcher | Floating spec |"
    echo "|---|---|---|---|"
    jq -r '.[] | select(.unpinned_autoexec_runtime) | .name as $n
           | .unpinned_autoexec_specs[] | "| \($n) | \(.server) | \(.launcher) | `\(.spec)` |"' <<<"$pin_scanned"
    echo
    echo "A floating spec (dist-tag, range, or bare name) is resolved from the package registry when the MCP server launches at session start — the marketplace SHA pin does not fix that code. Pin an exact version."
  fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

{
  echo "pin-scanned=$pin_scanned"
  echo "pin-failed=$pin_failed"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

if [[ "$fcount" -gt 0 && "$FAIL_ON_UNPINNED_AUTOEXEC" == "true" ]]; then
  echo "result=fail" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 2
fi
echo "result=pass" >> "${GITHUB_OUTPUT:-/dev/stdout}"
