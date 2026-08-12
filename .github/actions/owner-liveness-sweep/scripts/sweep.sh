#!/usr/bin/env bash
# Corpus-wide source-owner liveness sweep over the marketplace's external
# github.com entries. Report-only: it never edits the marketplace and never
# removes an entry — findings land in the step summary + a findings JSON for
# humans to act on.
#
# What it checks, per distinct owner and per distinct owner/repo pair:
#   · owner identity  — the committed baseline (.github/owner-baseline.json)
#     maps each owner login → the GitHub account id it resolved to when the
#     login was first seen. Account ids are stable for the life of an account,
#     so the SAME login resolving to a DIFFERENT id means the login was
#     released and re-registered by a different account — the one drift class
#     a plain existence probe can never see. Flagged as identity-changed
#     (the only finding class that fails the run).
#   · owner liveness  — a login that no longer resolves at all (deleted or
#     renamed away). Its entries are reachable only through repo-move
#     redirects, and the listed namespace no longer belongs to the publisher
#     the entries were accepted from.
#   · repo location   — a repository whose canonical nameWithOwner no longer
#     matches the listed owner (rename/transfer redirect), or that no longer
#     resolves at all (deleted or made private).
#
# Modes (MODE env / `mode` input):
#   report   — classify against the baseline; write findings + summary.
#              Exit 1 ONLY on identity-changed (when FAIL_ON_IDENTITY_CHANGE).
#   seed     — write a fresh baseline from live results (initial adoption).
#              Owners that don't resolve are reported, never baselined.
#   refresh  — additive baseline update: add unbaselined live owners, prune
#              owners whose entries left the corpus. NEVER rewrites an
#              existing owner's recorded id — an identity change must be
#              resolved by reviewing the affected entries (and only then
#              editing the baseline by hand), not by re-baselining over it.
#
# Resolution is batched GraphQL (aliased repositoryOwner / repository
# lookups, CHUNK per query), so a ~2k-owner corpus is a few dozen queries.
# Each query also fetches rateLimit{cost remaining} and logs it, keeping the
# real API cost observable in the run log.

set -euo pipefail

: "${MARKETPLACE_PATH:?}"
: "${BASELINE_PATH:?}"
MODE="${MODE:-report}"
case "$MODE" in report|seed|refresh) ;; *) echo "::error::mode must be report, seed, or refresh (got: $MODE)"; exit 1 ;; esac
FAIL_ON_IDENTITY_CHANGE="${FAIL_ON_IDENTITY_CHANGE:-true}"
CHUNK="${CHUNK:-50}"
[[ "$CHUNK" =~ ^[1-9][0-9]*$ ]] || { echo "::error::chunk-size must be a positive integer (got: $CHUNK)"; exit 1; }

[[ -f "$MARKETPLACE_PATH" ]] || { echo "::error::marketplace not found at $MARKETPLACE_PATH"; exit 1; }
if [[ "$MODE" != "seed" && ! -f "$BASELINE_PATH" ]]; then
  echo "::error::baseline not found at $BASELINE_PATH (run mode=seed first)"; exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
FINDINGS_PATH="${FINDINGS_PATH:-$work/findings.json}"

log() { printf '%s\n' "$*"; }

# ── 1. Extract external github.com sources → owners + repos ─────────────────
# entries.json: [{name, owner, repo, owner_lc, repo_lc}] for every external
# entry whose source URL parses as https://github.com/<owner>/<repo>[.git].
# Everything else (non-github hosts, local ./ sources, unparseable URLs) is
# counted and — for github.com URLs that don't parse — reported, never
# silently dropped.
jq -c '
  [.plugins[]
   | select(.source | type == "object")
   | {name, url: (.source.url // .source.repo // "")}
   | select(.url != "")]' -- "$MARKETPLACE_PATH" > "$work/external.json"

jq -c '
  [.[]
   | . as $e
   | (.url | sub("\\.git$"; "") | sub("/$"; "")) as $u
   | select($u | startswith("https://github.com/"))
   | ($u | sub("^https://github\\.com/"; "")) as $path
   | select($path | test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}$"))
   | {name: $e.name, owner: ($path | split("/")[0]), repo: ($path | split("/")[1])}
   | . + {owner_lc: (.owner | ascii_downcase), repo_lc: (.repo | ascii_downcase)}]' \
  "$work/external.json" > "$work/entries.json"

# github.com URLs that did NOT parse (bad owner charset / deep paths):
jq -c '
  [.[]
   | select((.url | sub("\\.git$"; "") | sub("/$"; "")) | startswith("https://github.com/"))
   | {name, url}]' "$work/external.json" > "$work/gh_urls.json"
jq -c --slurpfile parsed "$work/entries.json" '
  ([$parsed[0][].name]) as $ok | [.[] | select(([.name] | inside($ok)) | not)]' \
  "$work/gh_urls.json" > "$work/unparseable.json"

n_external="$(jq 'length' "$work/external.json")"
n_gh="$(jq 'length' "$work/gh_urls.json")"
n_entries="$(jq 'length' "$work/entries.json")"
n_unparseable="$(jq 'length' "$work/unparseable.json")"

# Distinct owners (keyed lowercase; first-seen spelling kept for the lookup)
# and distinct owner/repo pairs.
jq -c '[group_by(.owner_lc)[] | {key: .[0].owner_lc, login: .[0].owner,
        entries: [.[].name]}]' "$work/entries.json" > "$work/owners.json"
jq -c '[group_by(.owner_lc + "/" + .repo_lc)[] | {owner: .[0].owner, repo: .[0].repo,
        owner_lc: .[0].owner_lc, entries: [.[].name]}]' "$work/entries.json" > "$work/repos.json"
n_owners="$(jq 'length' "$work/owners.json")"
n_repos="$(jq 'length' "$work/repos.json")"

log "External entries: $n_external ($n_gh github.com; $n_entries parsed; $n_unparseable unparseable)"
log "Distinct owners: $n_owners · distinct repos: $n_repos"

# ── 2. Batched GraphQL resolution ───────────────────────────────────────────
# run_chunks <items.json> <kind> <out.json>
#   kind=owners: items [{key,login,entries}] → adds {live,id,type,canonical}
#   kind=repos:  items [{owner,repo,owner_lc,entries}] → adds {resolved,name_with_owner}
# A chunk whose response carries no .data is a hard failure (transport/auth) —
# a partial sweep must not masquerade as a clean one.
run_chunks() {
  local items="$1" kind="$2" out="$3"
  local total i=0
  total="$(jq 'length' "$items")"
  echo '[]' > "$out"
  while (( i < total )); do
    jq -c --argjson i "$i" --argjson n "$CHUNK" '.[$i:$i+$n]' "$items" > "$work/chunk.json"
    if [[ "$kind" == "owners" ]]; then
      jq -c '{query: ("query { rateLimit { cost remaining } "
        + ([to_entries[] | "o\(.key): repositoryOwner(login: \(.value.login | @json)) { __typename login ... on User { databaseId } ... on Organization { databaseId } }"] | join(" "))
        + " }")}' "$work/chunk.json" > "$work/payload.json"
    else
      jq -c '{query: ("query { rateLimit { cost remaining } "
        + ([to_entries[] | "r\(.key): repository(owner: \(.value.owner | @json), name: \(.value.repo | @json)) { nameWithOwner }"] | join(" "))
        + " }")}' "$work/chunk.json" > "$work/payload.json"
    fi
    # gh exits non-zero when any alias resolves null (NOT_FOUND errors ride
    # alongside partial data) — that partial data IS the answer we want, so
    # tolerate the exit code and require .data instead.
    resp="$(gh api graphql --input "$work/payload.json" 2>/dev/null)" || true
    if ! jq -e '.data' <<<"$resp" >/dev/null 2>&1; then
      echo "::error::GraphQL $kind chunk at offset $i returned no data — aborting (partial sweep would be misleading)"
      exit 1
    fi
    jq -r '.data.rateLimit | "  chunk '"$kind"'@'"$i"': cost \(.cost), remaining \(.remaining)"' <<<"$resp" || true
    if [[ "$kind" == "owners" ]]; then
      jq -c --slurpfile chunk "$work/chunk.json" '
        .data as $d
        | [range($chunk[0] | length) as $j
           | $chunk[0][$j] + (($d["o\($j)"] // null) as $r
             | {live: ($r != null), id: ($r.databaseId // null),
                type: ($r.__typename // null), canonical: ($r.login // null)})]' \
        <<<"$resp" > "$work/res.json"
    else
      jq -c --slurpfile chunk "$work/chunk.json" '
        .data as $d
        | [range($chunk[0] | length) as $j
           | $chunk[0][$j] + (($d["r\($j)"] // null) as $r
             | {resolved: ($r != null), name_with_owner: ($r.nameWithOwner // null)})]' \
        <<<"$resp" > "$work/res.json"
    fi
    jq -c -s '.[0] + .[1]' "$out" "$work/res.json" > "$out.tmp" && mv "$out.tmp" "$out"
    i=$(( i + CHUNK ))
  done
}

run_chunks "$work/owners.json" owners "$work/owners_resolved.json"
run_chunks "$work/repos.json"  repos  "$work/repos_resolved.json"

# ── 3. Classify ─────────────────────────────────────────────────────────────
if [[ -f "$BASELINE_PATH" ]]; then
  jq -c '.owners // {}' "$BASELINE_PATH" > "$work/baseline_owners.json"
else
  echo '{}' > "$work/baseline_owners.json"
fi

jq -n \
  --slurpfile owners "$work/owners_resolved.json" \
  --slurpfile repos "$work/repos_resolved.json" \
  --slurpfile base "$work/baseline_owners.json" \
  --slurpfile unparseable "$work/unparseable.json" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '($owners[0]) as $o | ($repos[0]) as $r | ($base[0]) as $b
   | {
      generated_at: $now,
      owners_checked: ($o | length),
      repos_checked: ($r | length),
      findings: {
        identity_changed: [ $o[] | select(.live and ($b[.key] != null) and ($b[.key].id != .id))
          | {owner: .login, recorded_id: $b[.key].id, live_id: .id, entries} ],
        owner_missing:    [ $o[] | select(.live | not) | .key as $k
          # Disposition split: a missing owner whose repos still RESOLVE at a
          # canonical successor location is typically a publisher rebrand or
          # transfer — verify the successor and refresh/re-pin the listing. A
          # missing owner with NO resolving repo left needs review of the
          # entries themselves. Derived from data already collected (the repo
          # resolution pass) — no extra lookups.
          | ([ $r[] | select(.owner_lc == $k and .resolved
                and ((.name_with_owner | split("/")[0] | ascii_downcase) != $k))
               | .name_with_owner ] | unique) as $succ
          | {owner: .login, entries,
             successors: $succ,
             disposition: (if ($succ | length) > 0 then "verify-successor" else "review" end)} ],
        repo_moved:       [ $r[] | select(.resolved and ((.name_with_owner | split("/")[0] | ascii_downcase) != .owner_lc))
          | {listed: (.owner + "/" + .repo), canonical: .name_with_owner, entries} ],
        repo_missing:     [ $r[] | select(.resolved | not) | {listed: (.owner + "/" + .repo), entries} ],
        unbaselined:      [ $o[] | select(.live and ($b[.key] == null)) | {owner: .login, id, entries} ],
        baseline_orphans: [ ($b | keys[]) as $k | select([$o[].key] | index($k) | not) | {owner: $k} ],
        unparseable:      $unparseable[0]
      }
    }' > "$FINDINGS_PATH"

counts="$(jq -c '.findings | map_values(length)' "$FINDINGS_PATH")"
log "Findings: $counts"

# ── 4. Step summary ─────────────────────────────────────────────────────────
summarize() {
  local f="$FINDINGS_PATH"
  echo "## Owner liveness sweep ($MODE)"
  echo
  jq -r '"Checked \(.owners_checked) distinct owners / \(.repos_checked) distinct repos at \(.generated_at)."' "$f"
  echo
  jq -r '.findings | to_entries[] | "- **\(.key)**: \(.value | length)"' "$f"
  local sec
  for sec in identity_changed owner_missing repo_moved repo_missing; do
    if [[ "$(jq --arg s "$sec" '.findings[$s] | length' "$f")" -gt 0 ]]; then
      echo
      echo "### $sec"
      case "$sec" in
        identity_changed) echo "| Owner | Recorded id | Live id | Entries |"; echo "|---|---|---|---|"
          jq -r '.findings.identity_changed[] | "| \(.owner) | \(.recorded_id) | \(.live_id) | \(.entries | join(", ")) |"' "$f" ;;
        owner_missing) echo "| Owner | Entries | Successor | Disposition |"; echo "|---|---|---|---|"
          jq -r '.findings.owner_missing[] | "| \(.owner) | \(.entries | join(", ")) | \(.successors | join(", ") | if . == "" then "—" else . end) | \(.disposition) |"' "$f" ;;
        repo_moved) echo "| Listed | Canonical | Entries |"; echo "|---|---|---|"
          jq -r '.findings.repo_moved[] | "| \(.listed) | \(.canonical) | \(.entries | join(", ")) |"' "$f" ;;
        repo_missing) echo "| Listed | Entries |"; echo "|---|---|"
          jq -r '.findings.repo_missing[] | "| \(.listed) | \(.entries | join(", ")) |"' "$f" ;;
      esac
    fi
  done
  if [[ "$(jq '.findings.unbaselined | length' "$f")" -gt 0 ]]; then
    echo
    jq -r '"<details><summary>Unbaselined owners (\(.findings.unbaselined | length)) — fold in via mode=refresh</summary>\n\n"
      + ([.findings.unbaselined[] | "- \(.owner) (id \(.id))"] | join("\n")) + "\n\n</details>"' "$f"
  fi
}
summarize >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

{
  echo "findings-path=$FINDINGS_PATH"
  echo "counts=$counts"
} >> "${GITHUB_OUTPUT:-/dev/null}"

# ── 5. Mode tails ───────────────────────────────────────────────────────────
write_baseline() {  # $1 = owners object {lc_login: {id, type}}
  jq -n --argjson owners "$1" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{schema: 1,
      note: "Maps each marketplace source-repo owner login (lowercased) to the GitHub account id it resolved to when first recorded. Account ids are stable, so a recorded login resolving to a DIFFERENT id means the login changed hands and every entry under it needs review before any further bumps. Maintained by the owner-liveness-sweep action (modes seed/refresh); never rewrite an existing id by hand without reviewing the affected entries.",
      updated_at: $now,
      owners: ($owners | to_entries | sort_by(.key) | from_entries)}' > "$BASELINE_PATH"
}

case "$MODE" in
  seed)
    live="$(jq -c '[.[] | select(.live)] | map({key, value: {id, type}}) | from_entries' "$work/owners_resolved.json")"
    write_baseline "$live"
    log "Baseline seeded: $(jq '.owners | length' "$BASELINE_PATH") owners → $BASELINE_PATH"
    n_dead="$(jq '.findings.owner_missing | length' "$FINDINGS_PATH")"
    [[ "$n_dead" -gt 0 ]] && log "::warning::$n_dead owner(s) did not resolve and were NOT baselined — see the findings summary; their entries need review."
    ;;
  refresh)
    n_idc="$(jq '.findings.identity_changed | length' "$FINDINGS_PATH")"
    if [[ "$n_idc" -gt 0 ]]; then
      echo "::error::refresh refused: $n_idc identity-changed owner(s) present. Review the affected entries first; a refresh must never re-baseline over an identity change."
      exit 1
    fi
    merged="$(jq -c -n \
      --slurpfile base "$work/baseline_owners.json" \
      --slurpfile owners "$work/owners_resolved.json" '
      ($owners[0]) as $o
      | ($base[0] | with_entries(select([.key] | inside([$o[].key]))))       # prune orphans
        + ([$o[] | select(.live and ($base[0][.key] == null))
            | {key, value: {id, type}}] | from_entries)                       # add unbaselined
      ')"
    write_baseline "$merged"
    log "Baseline refreshed: $(jq '.owners | length' "$BASELINE_PATH") owners (additions + orphan prunes only; existing ids untouched)"
    ;;
  report)
    n_idc="$(jq '.findings.identity_changed | length' "$FINDINGS_PATH")"
    if [[ "$n_idc" -gt 0 && "$FAIL_ON_IDENTITY_CHANGE" == "true" ]]; then
      echo "::error::$n_idc owner login(s) now resolve to a different account id than recorded — the affected entries need review before any further bumps (see summary)."
      exit 1
    fi
    ;;
esac
log "Sweep complete."
