#!/usr/bin/env bash
# Discover stale external SHAs, validate at new HEAD, open PR(s) with passing
# bumps. Two operating modes:
#
#   batch (default):    single PR (pr-branch, force-reset nightly) containing
#                       all passing bumps. Failures are reverted by the
#                       downstream revert-failed-bumps workflow.
#
#   per-entry:          one PR per bumped plugin on branch bump/<sanitized>.
#                       Failures stay open in their own PR for triage. Used
#                       by anthropics/claude-plugins-official to enable
#                       per-PR isolation and downstream `/triage-bump-prs
#                       --repo official` (see action.yml for details).
#
# See action.yml for input/output documentation.

source "$VALIDATE_LIB"

: "${MARKETPLACE_PATH:?}"
: "${MAX_BUMPS:?}"
[[ "$MAX_BUMPS" =~ ^[0-9]+$ ]] || die "max-bumps must be a non-negative integer (got: $MAX_BUMPS)"
: "${ALLOWED_HOSTS:?}"
: "${PR_BRANCH:?}"
: "${BASE_BRANCH:?}"
: "${GH_TOKEN:?}"

# Space-padded for whole-word matching (same convention as validate-plugins).
# Listed names are deliberately unpinned: without this skip, an empty
# old_sha never equals upstream HEAD, so the entry looks permanently stale
# and the nightly run would re-pin it — silently undoing the exemption.
SHA_EXEMPT=" ${SHA_EXEMPT:-} "

# Space-padded, same matching. FREEZE_SHAS names are PINNED entries held at
# their current source.sha — skipped from the bump so the pin can't advance
# until the name is removed (e.g. a security freeze pending a fix-forward).
# Distinct from SHA_EXEMPT: a frozen entry keeps its sha; an exempt one has none.
FREEZE_SHAS=" ${FREEZE_SHAS:-} "

# Optional per-caller tracking-policy file (a path in the CALLER's checkout).
# One key today: {"releases-only": [names…]} — entries whose bump target is the
# latest published RELEASE's commit instead of upstream HEAD. Absent/empty
# input → empty list → byte-identical behavior to a config-less run. A path
# that is set but missing/unparseable is a hard die (NOT a warn): the caller
# explicitly opted in, and silently falling back to HEAD-tracking would undo a
# partner's releases-only expectation — the same silent-no-op failure mode the
# freeze-shas reconcile warns about, but structural, so fail loudly.
TRACKING_CONFIG="${TRACKING_CONFIG:-}"
RELEASES_ONLY=" "
if [[ -n "$TRACKING_CONFIG" ]]; then
  [[ -f "$TRACKING_CONFIG" ]] || die "tracking-config not found at $TRACKING_CONFIG"
  # Strict schema: unknown keys, a non-array value, non-string members, and
  # whitespace-bearing names ALL die. `// []` alone would let a typo'd KEY
  # ({"releases_only": …}) parse as an empty list and silently disable the
  # whole policy — the exact silent-fallback the missing-file die exists to
  # prevent; and a name with a space would word-split into two independent
  # flags at match time.
  releases_only_list="$(jq -r '
      if type != "object" then error("root must be a JSON object")
      elif ((keys - ["releases-only"]) | length) > 0 then error("unknown key(s): " + ((keys - ["releases-only"]) | join(", ")))
      elif has("releases-only") and ((.["releases-only"] | type) != "array") then error("releases-only must be an array")
      elif has("releases-only") and ((.["releases-only"] | map(select(type != "string")) | length) > 0) then error("releases-only must contain only strings")
      elif has("releases-only") and ((.["releases-only"] | map(select(test("\\s"))) | length) > 0) then error("releases-only names must not contain whitespace")
      else ((.["releases-only"] // []) | join(" ")) end' -- "$TRACKING_CONFIG" 2>&1)" \
    || die "tracking-config is invalid ($TRACKING_CONFIG): $releases_only_list"
  RELEASES_ONLY=" $releases_only_list "
fi

# Single-plugin target (operator workflow_dispatch). Empty = bump all stale
# entries (default nightly behavior). Reject — never sanitize — a value with
# whitespace or shell metacharacters (same has_unsafe_chars guard bump.sh already
# applies to url/subdir); the exact whole-name match below is injection-safe with
# a quoted RHS, and a non-matching name simply bumps nothing. Unlike the
# freeze-shas charset guard, this does NOT reject scoped/dotted/uppercase names —
# branch_for() and the marketplace support `@scope/plugin`, `Foo.Bar`, etc., so a
# narrow [a-z0-9-] regex would `die` on a legitimate target.
ONLY="${ONLY:-}"
if [[ -n "$ONLY" ]] && has_unsafe_chars "$ONLY"; then
  die "only: '$ONLY' contains unsafe characters (whitespace/shell metacharacters)"
fi

PR_MODE="${PR_MODE:-batch}"
case "$PR_MODE" in
  batch|per-entry) ;;
  *) die "pr-mode must be 'batch' or 'per-entry' (got: $PR_MODE)" ;;
esac

[[ -f "$MARKETPLACE_PATH" ]] || die "marketplace not found at $MARKETPLACE_PATH"

workroot="$(mktemp -d)"
trap 'rm -rf "$workroot"' EXIT

# Capture base marketplace content BEFORE the discovery loop accumulates
# bumps into MARKETPLACE_PATH. Per-entry mode uses this to build each
# commit's file content from base (so per-entry commits are independent,
# not stacked).
base_marketplace_content="$(cat -- "$MARKETPLACE_PATH")"

bumped='[]'
skipped='[]'
checked=0
applied=0

skip() {
  local name="$1" reason="$2"
  warn "$name: skipped ($reason)"
  skipped="$(jq -c --arg n "$name" --arg r "$reason" '. + [{name:$n, reason:$r}]' <<<"$skipped")"
}

# Sanitize a plugin name into a git-safe branch suffix (per-entry mode).
# GitHub branch rules: allow [A-Za-z0-9._/-]; replace anything else with `-`,
# then strip leading dashes so `@scope/plugin` → `bump/scope-plugin` rather
# than `bump/-scope-plugin`. Trailing dots/dashes are also stripped to avoid
# `.lock`-suffix collisions and visual awkwardness.
branch_for() {
  local name="$1"
  local sanitized
  sanitized="$(printf '%s' "$name" | sed -E 's/[^A-Za-z0-9_.-]/-/g; s/^[-.]+//; s/[-.]+$//')"
  [[ -n "$sanitized" ]] || die "could not derive branch suffix for plugin name: $name"
  echo "bump/$sanitized"
}

# Reconcile freeze-shas against the marketplace before discovery. A listed name
# that can't actually hold a pin — a typo, a name with no pinned-source entry,
# or one the freeze guard's charset rejects (uppercase, dots, scope/slash) —
# silently no-ops while the nightly advances the pin anyway. For a security
# freeze that's the worst failure mode, so surface it loudly. Warning, not
# fatal: a stale freeze name must not block legitimate bumps of other entries.
# read -ra (not unquoted $FREEZE_SHAS) so a glob char in the list can't expand.
# Skipped entirely under a single-plugin `only` run: every non-target entry is
# plain-continued below, so a misconfigured freeze for some OTHER plugin is
# irrelevant to a targeted dispatch — emitting its warning would just be noise
# scoped to the wrong plugin. (The target's own freeze still applies in-loop.)
if [[ -z "$ONLY" && -n "${FREEZE_SHAS// /}" ]]; then
  freeze_external_names=" $(jq -r '.plugins[] | select(.source | type=="object") | .name' -- "$MARKETPLACE_PATH" | tr '\n' ' ')"
  read -ra _freeze_listed <<<"$FREEZE_SHAS"
  for fname in "${_freeze_listed[@]}"; do
    [[ -n "$fname" ]] || continue
    if [[ ! "$fname" =~ ^[a-z0-9][a-z0-9-]{1,63}$ ]]; then
      warn "freeze-shas: '$fname' is not a valid plugin name ([a-z0-9-], 2-64 chars) — it matches no entry and the freeze guard skips it; that pin is NOT protected."
    elif [[ "$freeze_external_names" != *" $fname "* ]]; then
      warn "freeze-shas: '$fname' matches no external (pinned-source) marketplace entry — typo, or the entry isn't pinned? That pin is NOT protected."
    fi
  done
fi

# Reconcile releases-only names the same way (and for the same reason) as
# freeze-shas above: a listed name that matches no pinned-source entry silently
# HEAD-tracks nothing — but unlike a freeze typo it can also be a NOT-YET-LIVE
# entry (config landed ahead of the marketplace add-PR), so the warning says so
# rather than presuming a typo. Warning, not fatal; suppressed under `only`
# (same noise-scoping rationale as the freeze reconcile).
if [[ -z "$ONLY" && -n "${RELEASES_ONLY// /}" ]]; then
  ro_external_names=" $(jq -r '.plugins[] | select(.source | type=="object") | .name' -- "$MARKETPLACE_PATH" | tr '\n' ' ')"
  read -ra _ro_listed <<<"$RELEASES_ONLY"
  for rname in "${_ro_listed[@]}"; do
    [[ -n "$rname" ]] || continue
    if [[ ! "$rname" =~ ^[a-z0-9][a-z0-9-]{1,63}$ ]]; then
      warn "tracking-config releases-only: '$rname' is not a valid plugin name ([a-z0-9-], 2-64 chars) — it matches no entry; that name is NOT releases-only tracked."
    elif [[ "$ro_external_names" != *" $rname "* ]]; then
      warn "tracking-config releases-only: '$rname' matches no external (pinned-source) marketplace entry — typo, or the entry isn't live yet? It is NOT releases-only tracked until it exists (harmless if the add is still pending)."
    fi
  done
fi

group_start "Discover stale SHAs and validate at new HEAD"

while IFS= read -r entry; do
  (( applied >= MAX_BUMPS )) && { log "Reached max-bumps=$MAX_BUMPS; stopping discovery."; break; }
  checked=$((checked+1))

  name="$(jq -r '.name' <<<"$entry")"

  # Single-plugin target: when ONLY is set, skip every entry whose name doesn't
  # match it exactly. Plain `continue` (NOT skip()) so a targeted run doesn't
  # record N-1 spurious skips. The matching name falls through to the normal
  # exempt/freeze/open-PR/validation path below, so it still reports its real
  # skip reason. Exact whole-name `==`, never a glob/regex (mirrors the
  # whole-word SHA_EXEMPT/FREEZE_SHAS convention).
  # CAVEAT: the sha-exempt/freeze gates below additionally require the name to
  # match ^[a-z0-9][a-z0-9-]{1,63}$, so a scoped/dotted/uppercase target that the
  # `only` guard intentionally ALLOWS (e.g. @scope/plugin) would bypass those
  # gates even if listed there — a pre-existing freeze/exempt-charset limitation,
  # not a regression (the open-PR + validation gates still apply to such a name).
  if [[ -n "$ONLY" && "$name" != "$ONLY" ]]; then continue; fi

  # Deliberately-unpinned entries: nothing to bump. Plain log, not skip() —
  # this is steady-state policy, not a per-run anomaly worth a ::warning.
  if [[ "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ && "$SHA_EXEMPT" == *" $name "* ]]; then
    log "$name: unpinned by policy (sha-exempt); not bumping"
    skipped="$(jq -c --arg n "$name" --arg r "unpinned by policy (sha-exempt)" '. + [{name:$n, reason:$r}]' <<<"$skipped")"
    continue
  fi

  # Frozen pins: keep the current source.sha, skip the bump. A deliberate hold
  # (e.g. security freeze pending an upstream fix-forward), not a per-run
  # anomaly — plain log, recorded in `skipped` so the freeze is visible.
  if [[ "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ && "$FREEZE_SHAS" == *" $name "* ]]; then
    log "$name: frozen at current pin (freeze-shas); not bumping"
    skipped="$(jq -c --arg n "$name" --arg r "frozen at current pin (freeze-shas)" '. + [{name:$n, reason:$r}]' <<<"$skipped")"
    continue
  fi

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
  # subdir must be relative and traversal-free: has_unsafe_chars blocks shell
  # metacharacters but not `..`/absolute paths, and target="$dest/$subdir"
  # below must not escape the throwaway clone. Mirrors scan.sh's subdir guard
  # and validate-plugins' assert_safe_path.
  [[ -z "$subdir" ]] || { { has_unsafe_chars "$subdir" || [[ "$subdir" == *".."* || "$subdir" == /* ]]; } && { skip "$name" "unsafe subdir"; continue; }; }

  # Resolve the bump target. Default: upstream HEAD (ls-remote). Entries in
  # tracking-config's releases-only list: the COMMIT of the latest published
  # GitHub release instead — the partner ships from release tags, not main.
  # No published release → hold the current pin (that IS releases-only
  # semantics), recorded in skipped[] so the hold stays visible in the summary.
  if [[ "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ && "$RELEASES_ONLY" == *" $name "* ]]; then
    # freeze-shas takes precedence: a frozen entry already `continue`d above
    # and never reaches this branch.
    if [[ "$host" != "github.com" ]]; then
      skip "$name" "releases-only tracking requires a github.com source (host: $host)"; continue
    fi
    owner_repo="${full_url#https://github.com/}"; owner_repo="${owner_repo%/}"; owner_repo="${owner_repo%.git}"
    if [[ ! "$owner_repo" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
      skip "$name" "releases-only: could not derive owner/repo from $full_url"; continue
    fi
    # gh api on an HTTP error prints the JSON error BODY to stdout (the --jq
    # filter is skipped), so "empty stdout" is NOT a no-releases signal.
    # Discriminate on exit status + the body's .status: 404 = genuinely no
    # published (non-draft, non-prerelease) release → the quiet policy hold
    # that IS releases-only semantics; anything else (403 rate limit, 5xx,
    # transport failure, empty body) = a LOUD skip with the real cause, never
    # misreported as "the developer hasn't cut a release".
    ro_rc=0
    ro_resp="$(gh api "repos/$owner_repo/releases/latest" 2>/dev/null)" || ro_rc=$?
    if [[ "$ro_rc" -ne 0 ]]; then
      ro_status="$(jq -r '.status // empty' <<<"$ro_resp" 2>/dev/null || true)"
      if [[ "$ro_status" == "404" ]]; then
        log "$name: mode=releases-only — no published releases at $owner_repo; holding current pin"
        skipped="$(jq -c --arg n "$name" --arg r "releases-only: no published releases (pin held)" '. + [{name:$n, reason:$r}]' <<<"$skipped")"
      else
        skip "$name" "releases-only: releases/latest lookup failed (HTTP ${ro_status:-unknown}) — pin held"
      fi
      continue
    fi
    latest_tag="$(jq -r '.tag_name // empty' <<<"$ro_resp" 2>/dev/null || true)"
    if [[ -z "$latest_tag" ]]; then
      skip "$name" "releases-only: releases/latest returned no tag_name"; continue
    fi
    # Positive charset allowlist (not has_unsafe_chars): the tag lands in an
    # API path, where e.g. `?`/`#` — which has_unsafe_chars permits — would
    # truncate the route. `/` is allowed (namespaced tags are valid refs) but
    # a `..` segment is not — it could rewrite the API route.
    if [[ ! "$latest_tag" =~ ^[A-Za-z0-9._/+-]+$ || "$latest_tag" == *..* ]]; then
      skip "$name" "releases-only: release tag '$latest_tag' has characters outside [A-Za-z0-9._/+-] or a '..' segment"; continue
    fi
    # commits/<tag> dereferences an annotated tag server-side → always the
    # COMMIT sha, never the tag-object sha (which clone/validate can't pin).
    rc_rc=0
    rc_resp="$(gh api "repos/$owner_repo/commits/$latest_tag" 2>/dev/null)" || rc_rc=$?
    new_sha=""
    if [[ "$rc_rc" -eq 0 ]]; then
      new_sha="$(jq -r '.sha // empty' <<<"$rc_resp" 2>/dev/null || true)"
    fi
    if [[ ! "$new_sha" =~ ^[0-9a-f]{40}$ ]]; then
      rc_status="$(jq -r '.status // empty' <<<"$rc_resp" 2>/dev/null || true)"
      skip "$name" "releases-only: could not resolve release tag '$latest_tag' to a commit (HTTP ${rc_status:-unknown})"; continue
    fi
    # Forward-only guard: releases/latest is CHRONOLOGICAL (created_at), not
    # semver — a back-patch release cut on an old line (or deleting the newest
    # release) can point "latest" at a commit that is NOT a descendant of the
    # current pin, and `claude plugin validate` would happily pass the older
    # tree. An auto-bumper must never move a pin backward/sideways: require
    # compare=ahead, hold loudly otherwise (a compare failure also holds —
    # the conservative direction).
    if [[ "$old_sha" =~ ^[0-9a-f]{40}$ && "$new_sha" != "$old_sha" ]]; then
      cmp_status="$(gh api "repos/$owner_repo/compare/$old_sha...$new_sha" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)"
      case "$cmp_status" in
        ahead) ;;
        identical) continue ;;
        *) skip "$name" "releases-only: latest release $latest_tag is not ahead of the current pin (compare=${cmp_status:-unknown}) — refusing a backward/divergent bump"; continue ;;
      esac
    fi
    log "$name: mode=releases-only — releases/latest=$latest_tag → ${new_sha:0:8}"
  else
    # || true masks SIGPIPE from head -1; the regex below catches partial reads.
    new_sha="$(git ls-remote -- "$full_url" HEAD 2>/dev/null | awk '{print $1}' | head -1 || true)"
    if [[ ! "$new_sha" =~ ^[0-9a-f]{40}$ ]]; then
      skip "$name" "ls-remote failed or returned no HEAD"; continue
    fi
  fi
  if [[ "$new_sha" == "$old_sha" ]]; then
    continue
  fi

  # ── Source-owner verification gate (github.com sources) ────────────────────
  # git ls-remote / clone silently follow GitHub's repo-move redirects, so a
  # SHA can resolve cleanly from a repository that is no longer where the
  # marketplace entry says it is. An auto-bumper must never advance a pin
  # through such a redirect: when the canonical owner differs from the listed
  # owner, the content at HEAD is no longer published under the namespace the
  # entry was accepted from, and the listed source URL needs a human review /
  # refresh before any further bumps. Resolve the LISTED owner/repo via the
  # API and require the canonical full_name to still match:
  #   · HTTP 404                     → source unavailable        → hold the pin
  #   · canonical owner ≠ listed     → owner changed (redirect)  → hold the pin
  #   · any other lookup failure     → cannot verify             → hold the pin
  # Fail-closed PER ENTRY (the run continues); every hold is a visible skip.
  # A repo renamed WITHIN the same owner is logged but not held — same
  # namespace, same publisher; the listing should still be refreshed.
  # Placed AFTER the staleness check so only entries actually about to be
  # bumped cost an API call (at-pin entries — the vast majority — never do).
  if [[ "$host" == "github.com" ]]; then
    sv_or="${full_url#https://github.com/}"; sv_or="${sv_or%/}"; sv_or="${sv_or%.git}"
    if [[ ! "$sv_or" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
      skip "$name" "source verification: could not derive owner/repo from $full_url — cannot verify source; pin held"; continue
    fi
    sv_rc=0
    sv_resp="$(gh api "repos/$sv_or" 2>/dev/null)" || sv_rc=$?
    if [[ "$sv_rc" -ne 0 ]]; then
      # gh api prints the JSON error body to stdout on an HTTP error (the same
      # convention the releases-only branch handles above): discriminate a
      # definitive 404 from a transient failure, hold the pin either way.
      sv_status="$(jq -r '.status // empty' <<<"$sv_resp" 2>/dev/null || true)"
      if [[ "$sv_status" == "404" ]]; then
        skip "$name" "source repo $sv_or not found (HTTP 404) — source unavailable; pin held"
      else
        skip "$name" "source repo $sv_or lookup failed (HTTP ${sv_status:-unknown}) — cannot verify source; pin held"
      fi
      continue
    fi
    sv_full="$(jq -r '.full_name // empty' <<<"$sv_resp" 2>/dev/null || true)"
    if [[ ! "$sv_full" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
      skip "$name" "source repo $sv_or lookup returned no usable full_name — cannot verify source; pin held"; continue
    fi
    sv_listed_owner_lc="$(tr '[:upper:]' '[:lower:]' <<<"${sv_or%%/*}")"
    sv_live_owner_lc="$(tr '[:upper:]' '[:lower:]' <<<"${sv_full%%/*}")"
    if [[ "$sv_live_owner_lc" != "$sv_listed_owner_lc" ]]; then
      skip "$name" "source now resolves to $sv_full (listed: $sv_or) — owner changed upstream; pin held pending a source-URL review"
      continue
    fi
    if [[ "$(tr '[:upper:]' '[:lower:]' <<<"${sv_full#*/}")" != "$(tr '[:upper:]' '[:lower:]' <<<"${sv_or#*/}")" ]]; then
      warn "$name: source repo renamed within the same owner ($sv_or → $sv_full) — bump proceeds; the listed source URL should be refreshed"
    fi
    # ── Identity leg (owner-baseline, when committed) ─────────────────────────
    # full_name alone cannot see a RE-REGISTERED owner: the login is freed and
    # re-taken, a repo is created at the listed path, and the lookup above
    # returns a matching full_name with no redirect. The account ID is the
    # discriminator — ids are stable for the life of an account, so the same
    # login resolving to a different id than the committed baseline records
    # means the login changed hands since the entry was recorded. Compare from
    # the SAME repos/ response (zero extra API cost):
    #   · recorded id present, live id differs   → hold the pin (loud skip)
    #   · recorded id present, live id missing   → hold (cannot verify identity)
    #   · owner not in the baseline              → warn-and-proceed — the entry
    #     was human-reviewed when it was added and holding would false-hold
    #     every new entry until the next baseline refresh merges; the warning
    #     keeps the not-yet-pinned state observable (fold in via the
    #     owner-liveness-sweep refresh mode).
    # No baseline file → the identity leg is inactive (location checks stand);
    # callers that haven't adopted a baseline keep today's behavior.
    if [[ -n "${OWNER_BASELINE:-}" && -f "$OWNER_BASELINE" ]]; then
      sv_recorded_id="$(jq -r --arg k "$sv_listed_owner_lc" '.owners[$k].id // empty' -- "$OWNER_BASELINE" 2>/dev/null || true)"
      if [[ "$sv_recorded_id" =~ ^[0-9]+$ ]]; then
        sv_live_id="$(jq -r 'if (.owner.id | type) == "number" then .owner.id else empty end' <<<"$sv_resp" 2>/dev/null || true)"
        if [[ -z "$sv_live_id" ]]; then
          skip "$name" "source owner '${sv_or%%/*}' identity could not be verified (no account id in the lookup; recorded $sv_recorded_id) — pin held"
          continue
        fi
        if [[ "$sv_live_id" != "$sv_recorded_id" ]]; then
          skip "$name" "source owner '${sv_or%%/*}' now resolves to a different account id (recorded $sv_recorded_id, live $sv_live_id) — the login no longer belongs to the account on record; pin held pending review"
          continue
        fi
      else
        warn "$name: source owner '${sv_or%%/*}' is not in the owner baseline ($OWNER_BASELINE) — identity pinning is not yet active for this entry; fold it in via the owner-liveness-sweep refresh"
      fi
    fi
  fi

  # No-op subtree suppression (git-subdir entries only): the repo HEAD moving
  # does NOT mean THIS plugin's subtree changed. If the tree object at $subdir
  # is byte-identical between old_sha and new_sha, the plugin content is
  # unchanged and bumping the pin is pure churn — a clone + validate + signed
  # commit + PR + the three dispatched required-check runs, all for nothing.
  # Probe the two trees cheaply (blobless, depth-1 → commit+tree objects only,
  # no blobs) and skip when they match. FAIL OPEN: any probe failure (init /
  # remote / fetch / ls-tree) falls through to the normal bump path, so a real
  # change is never suppressed because the probe was uncertain. A path added or
  # removed between the SHAs yields one empty tree oid → treated as a real bump.
  if [[ -n "$subdir" && "$old_sha" =~ ^[0-9a-f]{40}$ ]]; then
    probe="$workroot/probe-$checked"
    if git init -q "$probe" 2>/dev/null \
       && git -C "$probe" remote add origin "$full_url" 2>/dev/null \
       && timeout 120 git -C "$probe" fetch -q --filter=blob:none --depth 1 origin "$old_sha" "$new_sha" 2>/dev/null; then
      old_tree="$(git -C "$probe" ls-tree "$old_sha" -- "$subdir" 2>/dev/null | awk '$2=="tree"{print $3; exit}')"
      new_tree="$(git -C "$probe" ls-tree "$new_sha" -- "$subdir" 2>/dev/null | awk '$2=="tree"{print $3; exit}')"
      if [[ -n "$old_tree" && "$old_tree" == "$new_tree" ]]; then
        log "$name: subtree '$subdir' unchanged ${old_sha:0:8}→${new_sha:0:8}; suppressing no-op bump"
        skipped="$(jq -c --arg n "$name" --arg r "subtree '$subdir' unchanged ${old_sha:0:8}→${new_sha:0:8} (no-op bump suppressed)" '. + [{name:$n, reason:$r}]' <<<"$skipped")"
        rm -rf -- "$probe"
        continue
      fi
    fi
    rm -rf -- "$probe"
  fi

  # Per-entry early-skip: if there's already an open bump PR for this slug,
  # skip clone+validate to avoid wasting budget on plugins waiting on
  # developer/triage response. Batch mode doesn't need this (single PR).
  if [[ "$PR_MODE" == "per-entry" ]]; then
    entry_branch="$(branch_for "$name")"
    if existing_pr="$(gh pr list --head "$entry_branch" --base "$BASE_BRANCH" --state open --json url -q '.[0].url' 2>/dev/null)" \
       && [[ -n "$existing_pr" ]]; then
      skip "$name" "open bump PR already exists at $entry_branch ($existing_pr)"; continue
    fi
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
  # A declared subdir that's gone at the new SHA is a hard skip, NOT a synthesis
  # case (mirror 30-validate-cli-external.sh:101-105). Without this guard,
  # resolve_external_manifest below would mkdir -p the vanished path and
  # synthesize a phantom {name} manifest for a strict:false entry — a false bump
  # to a SHA where the plugin's content dir no longer exists. The no-op subtree
  # probe above does NOT catch this (a removed path yields an empty new tree oid
  # → treated as a real bump, by design), so the check belongs here.
  if [[ -n "$subdir" && ! -d "$target" ]]; then
    skip "$name" "subdir '$subdir' not found at $full_url@${new_sha:0:8}"; rm -rf -- "$dest"; continue
  fi
  # strict:false (skills-only) externals ship no plugin.json — the marketplace
  # synthesizes one from inline fields. Mirror validate-plugins
  # (30-validate-cli-external.sh): synthesize a minimal manifest for them rather
  # than hard-skipping, else a strict:false entry can NEVER be bumped and drifts
  # forever. The synthesized file lands in the throwaway clone ($dest, rm -rf'd
  # below) purely to feed `claude plugin validate` — only the SHA pin is ever
  # committed, never synthesized content. This INTENTIONALLY widens bumped[]/
  # pr-urls to include skills-only externals (a new class for downstream
  # per-entry scan-dispatch + /triage-bump-prs; benign — they read branch/name).
  # mrc: 0=existing manifest, 2=synthesized (strict:false), 1=none/synth-failed.
  strict="$(jq -r 'if .strict == false then "false" else "true" end' <<<"$entry")"
  mrc=0; manifest="$(resolve_external_manifest "$target" "$name" "$strict")" || mrc=$?
  if [[ "$mrc" -eq 1 ]]; then
    skip "$name" "no plugin manifest at $full_url@${new_sha:0:8}"; rm -rf -- "$dest"; continue
  fi
  [[ "$mrc" -eq 2 ]] && log "  (strict:false) no plugin manifest in source; synthesized a minimal one — $full_url@${new_sha:0:8}"
  if ! out="$(timeout 120 claude plugin validate "$manifest" 2>&1)"; then
    detail="$(grep -E '❯|Error:' <<<"$out" | head -1 | sed -E 's/^[[:space:]]+//')"
    skip "$name" "validation failed at $full_url@${new_sha:0:8}: ${detail:-$(head -1 <<<"$out")}"
    rm -rf -- "$dest"; continue
  fi
  rm -rf -- "$dest"

  # Accumulate into MARKETPLACE_PATH so the step summary and (in batch mode)
  # the createCommitOnBranch payload reflect all bumps. Per-entry mode uses
  # base_marketplace_content (captured above) for individual commits, so
  # this accumulation is informational there — not consumed by the commit.
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
  echo "## Bump Plugin SHAs (mode: $PR_MODE)"
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
  echo "pr-urls=[]" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 0
fi

# ============================================================================
# Commit + PR phase: signed via GraphQL createCommitOnBranch (see below).
# ============================================================================

# Commit via GitHub's GraphQL `createCommitOnBranch` mutation rather than a
# local `git commit` + push. Commits created server-side are signed by GitHub's
# web-flow GPG key and show as "Verified" — required when the base branch
# enforces `required_signatures` (e.g. via an org-level ruleset). A local
# commit in CI has no signing key and would be unmergeable.
#
# This also avoids importing any signing key material onto the runner: there
# is nothing to leak, rotate, or revoke. The token already in scope is the
# only credential involved, and `expectedHeadOid` gives compare-and-swap
# semantics so a concurrent push fails loudly instead of being clobbered.

base_sha="$(gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/${BASE_BRANCH}" --jq '.object.sha')"
[[ "$base_sha" =~ ^[0-9a-f]{40}$ ]] || die "could not resolve $BASE_BRANCH HEAD"

# create_or_reset_branch BRANCH BASE_SHA
# Point BRANCH at BASE_SHA: create if absent, force-reset if present. Force-
# reset is intentional — each run produces a fresh commit on top of base,
# replacing a stale unmerged bump rather than stacking on it (matches the
# previous `git checkout -B` + force-push semantics).
create_or_reset_branch() {
  local branch="$1" base="$2"
  if ! gh api -X POST "repos/${GITHUB_REPOSITORY}/git/refs" \
         -f ref="refs/heads/${branch}" -f sha="$base" >/dev/null 2>&1; then
    gh api -X PATCH "repos/${GITHUB_REPOSITORY}/git/refs/heads/${branch}" \
      -f sha="$base" -F force=true >/dev/null \
      || die "could not create or reset $branch"
  fi
}

# create_signed_commit BRANCH BASE_SHA MSG CONTENT_FILE
# Calls createCommitOnBranch with the marketplace.json content from
# CONTENT_FILE (path; --rawfile handles bytes via the per-arg size limit).
# Echoes the new commit OID on success.
create_signed_commit() {
  local branch="$1" base="$2" msg="$3" content_file="$4"
  jq -n \
    --rawfile content "$content_file" \
    --arg repo   "$GITHUB_REPOSITORY" \
    --arg branch "$branch" \
    --arg oid    "$base" \
    --arg msg    "$msg" \
    --arg path   "$MARKETPLACE_PATH" \
    '{
      query: "mutation($repo:String!,$branch:String!,$oid:GitObjectID!,$msg:String!,$path:String!,$contents:Base64String!){createCommitOnBranch(input:{branch:{repositoryNameWithOwner:$repo,branchName:$branch},message:{headline:$msg},fileChanges:{additions:[{path:$path,contents:$contents}]},expectedHeadOid:$oid}){commit{oid}}}",
      variables: {
        repo: $repo, branch: $branch, oid: $oid, msg: $msg,
        path: $path, contents: ($content | @base64)
      }
    }' \
  | gh api graphql --input - --jq '.data.createCommitOnBranch.commit.oid'
}

if [[ "$PR_MODE" == "per-entry" ]]; then
  # ──────────────────────────────────────────────────────────────────────────
  # Per-entry mode: one branch + one commit + one PR per bumped plugin.
  # Each commit applies ONLY that plugin's bump to base_marketplace_content,
  # so PRs are independent (no stacking). Failing PRs stay open for triage.
  # ──────────────────────────────────────────────────────────────────────────
  group_start "Open per-entry bump PRs"

  pr_urls='[]'
  printf '%s\n' "$bumped" | jq -c '.[]' | while IFS= read -r b; do
    name="$(jq -r '.name'    <<<"$b")"
    old_sha="$(jq -r '.old_sha' <<<"$b")"
    new_sha="$(jq -r '.new_sha' <<<"$b")"
    branch="$(branch_for "$name")"

    # Build per-entry marketplace content: base + only this entry's bump.
    # Independent of any other bumps applied this run.
    entry_file="$workroot/marketplace-${checked}-${RANDOM}.json"
    jq --arg n "$name" --arg s "$new_sha" \
      '(.plugins[] | select(.name==$n) | .source.sha) = $s' \
      <<<"$base_marketplace_content" > "$entry_file"

    create_or_reset_branch "$branch" "$base_sha"

    commit_msg="bump($name): ${old_sha:0:8} → ${new_sha:0:8}"
    new_oid="$(create_signed_commit "$branch" "$base_sha" "$commit_msg" "$entry_file")" \
      || die "createCommitOnBranch failed for $name"
    [[ "$new_oid" =~ ^[0-9a-f]{40}$ ]] || die "createCommitOnBranch did not return an OID for $name (got: $new_oid)"
    log "Created signed commit $new_oid on $branch ($name)"

    # Derive the filename from the sanitized branch suffix, never raw $name —
    # the marketplace allows `/` in names (@scope/plugin), and a raw
    # interpolation would steer this write outside $workroot.
    body_file="$workroot/pr-body-${branch#bump/}.md"
    {
      echo "Automated SHA bump for **\`$name\`**. The new SHA was validated via \`claude plugin validate\` in [this workflow run]($RUN_URL) before this PR was opened."
      echo
      echo "| Old SHA | New SHA |"
      echo "|---|---|"
      echo "| \`${old_sha:0:12}\` | \`${new_sha:0:12}\` |"
      echo
      echo "Review the scan job below before merging — bump PRs are not auto-merged by default."
    } > "$body_file"

    if existing="$(gh pr list --head "$branch" --base "$BASE_BRANCH" --state open --json url -q '.[0].url' 2>/dev/null)" \
       && [[ -n "$existing" ]]; then
      gh pr edit "$existing" --body-file "$body_file" >/dev/null
      pr_url="$existing"
      log "Updated existing PR: $pr_url"
    else
      pr_url="$(gh pr create --base "$BASE_BRANCH" --head "$branch" \
        --title "$commit_msg" --body-file "$body_file")"
      log "Opened PR: $pr_url"
    fi

    # Per-entry rolling output (jq's first-write rebuilds; using a tempfile
    # avoids losing entries to subshell scope when piped through `while`).
    jq -c --arg n "$name" --arg o "$old_sha" --arg s "$new_sha" \
      --arg br "$branch" --arg u "$pr_url" \
      '. + [{name:$n, old_sha:$o, new_sha:$s, branch:$br, pr_url:$u}]' \
      <<<"$pr_urls" > "$workroot/pr_urls.tmp" && pr_urls="$(cat "$workroot/pr_urls.tmp")"
  done

  # The `while` loop ran in a subshell (piped from jq), so pr_urls
  # accumulated there is lost. Reconstruct from the temp file the loop
  # wrote on its final iteration.
  if [[ -s "$workroot/pr_urls.tmp" ]]; then
    pr_urls="$(cat "$workroot/pr_urls.tmp")"
  fi

  echo "pr-url=" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "pr-urls=$pr_urls" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  log "Opened/updated $(jq 'length' <<<"$pr_urls") per-entry bump PR(s)"
  group_end

else
  # ──────────────────────────────────────────────────────────────────────────
  # Batch mode: single commit on PR_BRANCH, single PR with all bumps.
  # Preserves the pre-per-entry behavior exactly.
  # ──────────────────────────────────────────────────────────────────────────
  group_start "Open batch bump PR"

  create_or_reset_branch "$PR_BRANCH" "$base_sha"

  commit_msg="Bump $applied plugin SHA pin(s) to upstream HEAD"
  new_oid="$(create_signed_commit "$PR_BRANCH" "$base_sha" "$commit_msg" "$MARKETPLACE_PATH")" \
    || die "createCommitOnBranch failed"
  [[ "$new_oid" =~ ^[0-9a-f]{40}$ ]] || die "createCommitOnBranch did not return a commit OID (got: $new_oid)"
  log "Created signed commit $new_oid on $PR_BRANCH"

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
  echo "pr-urls=[]" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  log "PR: $pr_url"
  group_end
fi
