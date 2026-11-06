#!/usr/bin/env bash
# Custom hardening invariants beyond the JSON Schema.
# Runs on the full marketplace, but (when SCOPE_ERRORS_TO_CHANGED=true) a
# per-entry violation on an entry this PR did NOT change is downgraded
# ERROR->WARNING, so a preexisting base-branch defect can't block an unrelated
# PR. Whole-marketplace invariants (I1 sort, I2 dups, I7) are never downgraded.
#
# I1  plugins[] alpha-sorted by name
# I2  no duplicate names
# I3  description 10-2000 chars, no leading/trailing whitespace
# I4  all source.url are https:// (re-checked here as defense-in-depth)
# I5  every external source has a 40-char sha (names in SHA_EXEMPT may omit
#     it entirely; a present-but-malformed sha still fails even for them;
#     names in COMMAND_EXEMPT whose source is {"source":"command"} have no
#     sha to pin and skip I5)
# I6  per-file mode: filename matches .name
# I7  per-file mode: PR does not edit assembled marketplace.json directly
# I8  vendored source path exists and contains .claude-plugin/plugin.json
# I9  string fields under .source contain no shell metacharacters (for a
#     COMMAND_EXEMPT command source, .command may contain single spaces
#     between words, and nothing else outside [A-Za-z0-9._/=:-])
# I10 name/description contain no hidden-Unicode (zero-width / bidi controls)
# I11 name matches ^[a-z0-9][a-z0-9-]{1,63}$

source "$ACTION_PATH/lib/common.sh"

: "${VALIDATE_TMP:?}"
: "${MARKETPLACE_PATH:?}"
MP="$VALIDATE_TMP/marketplace.json"
WARN_INVARIANTS=" ${WARN_INVARIANTS:-I1 I3 I5 I8} "
# Space-padded for whole-word matching, same trick as WARN_INVARIANTS —
# exempting "abc" must not exempt "abc-extra".
SHA_EXEMPT=" ${SHA_EXEMPT:-} "
# Plugin names allowed to use a {"source":"command"} source. Same
# space-padded whole-word convention as SHA_EXEMPT.
COMMAND_EXEMPT=" ${COMMAND_EXEMPT:-} "
# An exempt .command is a plain argv: words of [A-Za-z0-9._/=:-] separated by
# single spaces. No quotes, globs, substitutions, redirects or separators.
COMMAND_RE='^[A-Za-z0-9][A-Za-z0-9._/=:-]*( [A-Za-z0-9._/=:-]+)*$'
failures=0
warnings=0

# Diff-scoping (so a preexisting base-branch defect can't block an unrelated PR):
# 00-detect-changes.sh wrote the changed-entry list to changes.json, which runs
# before this step. When scoping is active, flag() downgrades a per-entry
# violation ERROR->WARNING if the offending entry is NOT in that list. Opt-in
# (default off): absent the file (unit tests; detect skipped) or when disabled,
# scoping is off and behavior is unchanged (every violation errors per
# WARN_INVARIANTS — fail-safe).
SCOPE_ERRORS_TO_CHANGED="${SCOPE_ERRORS_TO_CHANGED:-false}"
SCOPE_ACTIVE=0
CHANGED_ENTRIES=" "   # space-padded for whole-word matching, like SHA_EXEMPT
# Only activate when changes.json exists, is valid JSON, AND .entries is an
# array (jq -e). A missing/truncated/structurally-wrong file → scoping stays off
# (fail-safe: every violation errors) rather than silently downgrading everything.
if [[ "$SCOPE_ERRORS_TO_CHANGED" == "true" ]] \
   && jq -e '.entries | type == "array"' -- "$VALIDATE_TMP/changes.json" >/dev/null 2>&1; then
  SCOPE_ACTIVE=1
  CHANGED_ENTRIES=" $(jq -r '.entries[] // empty' -- "$VALIDATE_TMP/changes.json" 2>/dev/null | tr '\n' ' ')"
fi

entry_line() {
  local name="$1"
  [[ -n "$name" ]] || return 0
  grep -n "\"name\": \"$name\"" -- "$MARKETPLACE_PATH" 2>/dev/null | head -1 | cut -d: -f1 || true
}

flag() {
  local code="$1" msg="$2" name="${3:-}"
  local line; line="$(entry_line "$name")"
  local loc="file=$MARKETPLACE_PATH${line:+,line=$line}"
  local as_warn=0
  if [[ "$WARN_INVARIANTS" == *" $code "* ]]; then
    as_warn=1
  elif (( SCOPE_ACTIVE )) && [[ -n "$name" ]] \
       && [[ "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ ]] \
       && [[ "$CHANGED_ENTRIES" != *" $name "* ]]; then
    # Per-entry violation on an entry this PR did not change: surface it, but
    # don't let a preexisting base-branch defect block this unrelated PR.
    # The I11-shape guard (mirrors the SHA_EXEMPT lookup below) ensures $name is
    # a safe literal for the whole-word glob match — no spaces (which could
    # splice two adjacent changed names) and no glob metacharacters. A non-I11
    # name falls through to the error branch; it already carries its own I11
    # error, so we don't suppress a secondary one.
    # (name-less / whole-marketplace invariants like I1/I2/I7 also fall through
    # to the error branch and still hard-fail.)
    as_warn=1
    msg="$msg [unchanged entry — not introduced by this PR; downgraded to warning]"
  fi
  if (( as_warn )); then
    printf '::warning %s::invariant %s: %s\n' "$loc" "$code" "$msg"
    record_result "invariants" "warn" "$code" "$msg"; warnings=$((warnings+1))
  else
    printf '::error %s::invariant %s: %s\n' "$loc" "$code" "$msg"
    record_result "invariants" "fail" "$code" "$msg"; failures=$((failures+1))
  fi
}

group_start "Custom invariants I1-I11"

# I1 sort (case-insensitive, matching upstream assembler convention)
sorted="$(jq -r '[.plugins[].name | ascii_downcase] | . == (.|sort)' -- "$MP")"
[[ "$sorted" == "true" ]] || flag "I1" "plugins[] is not alpha-sorted by name (case-insensitive)"

# I2 dups
dups="$(jq -r '[.plugins[].name] | group_by(.) | map(select(length>1) | .[0]) | .[]' -- "$MP")"
[[ -z "$dups" ]] || flag "I2" "duplicate plugin names: $(tr '\n' ' ' <<<"$dups")"

# U+200B ZWSP, U+200C ZWNJ, U+200D ZWJ, U+200E LRM, U+200F RLM,
# U+202A-202E bidi embedding/override, U+2066-2069 bidi isolates, U+FEFF BOM
HIDDEN_UNI=$'​‌‍‎‏‪‫‬‭‮⁦⁧⁨⁩﻿'

# I3/I10/I11 — per-entry name/description checks
while IFS= read -r entry; do
  name="$(jq -r '.name' <<<"$entry")"
  desc="$(jq -r '.description' <<<"$entry")"
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ ]]; then
    flag "I11" "$name: name does not match ^[a-z0-9][a-z0-9-]{1,63}\$" "$name"
  fi
  if [[ "$name$desc" == *["$HIDDEN_UNI"]* ]]; then
    flag "I10" "$name: name/description contains hidden-Unicode (zero-width or bidi control)" "$name"
  fi
  len=${#desc}
  if (( len < 10 || len > 2000 )); then
    flag "I3" "$name: description length $len not in [10,2000]" "$name"
  fi
  if [[ "$desc" != "$(printf '%s' "$desc" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')" ]]; then
    flag "I3" "$name: description has leading/trailing whitespace" "$name"
  fi
done < <(jq -c '.plugins[]' -- "$MP")

# I4 / I5 / I9 — external sources (shape-agnostic: applies to any object source).
# We don't enumerate source kinds here; the canonical schema check is step 20.
# This layer enforces security policy on whichever fields are present.
while IFS= read -r entry; do
  name="$(jq -r '.name' <<<"$entry")"
  url="$(jq -r '.source.url // .source.repo // empty' <<<"$entry")"
  sha="$(jq -r '.source.sha // empty' <<<"$entry")"
  kind="$(jq -r '.source.source // empty' <<<"$entry")"
  # A command source resolves the plugin by running a local command (e.g. a
  # vendor CLI) on the user's machine, so there is no repo to pin. Allowed only
  # for names listed in command-exempt. The name must be I11-shaped before
  # consulting the list (same splice guard as SHA_EXEMPT below).
  cmd_exempt=0
  if [[ "$kind" == "command" && "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ \
        && "$COMMAND_EXEMPT" == *" $name "* ]]; then
    cmd_exempt=1
  fi

  if [[ -n "$url" ]]; then
    if [[ ! "$url" =~ ^https://[A-Za-z0-9./_-]+$ ]] && \
       [[ ! "$url" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
      flag "I4" "$name: source url/repo is not a safe https URL or owner/repo shorthand: $url" "$name"
    fi
  fi
  if (( cmd_exempt )) && [[ -z "$sha" ]]; then
    info "invariant I5: $name is a command source (allowed via command-exempt); no sha to pin"
    record_result "invariants" "skip" "I5" "$name: command source, exempt via command-exempt"
  elif [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    # The name must itself be I11-shaped before consulting the list: in
    # repos where I11 is a warning, a name containing a space could otherwise
    # splice across two adjacent exempt entries ("foo bar" vs "foo" + "bar").
    if [[ -z "$sha" && "$name" =~ ^[a-z0-9][a-z0-9-]{1,63}$ && "$SHA_EXEMPT" == *" $name "* ]]; then
      # Exemption waives only a MISSING sha. A sha that is present but
      # malformed is a typo in a pin, never an intentional unpinned source.
      info "invariant I5: $name has no source.sha (allowed via sha-exempt)"
      record_result "invariants" "skip" "I5" "$name: unpinned, exempt via sha-exempt"
    else
      msg="$name: source.sha is missing or not a 40-char hex SHA"
      [[ "$kind" == "command" ]] && msg="$msg (command sources must be listed in command-exempt)"
      flag "I5" "$msg" "$name"
    fi
  fi

  # I9: every string-valued field under .source must be free of shell metacharacters.
  # For an exempt command source, .command is checked against COMMAND_RE instead
  # (it is an argv, so it needs spaces); every other field keeps the strict check.
  skip_key=""
  if (( cmd_exempt )); then
    skip_key="command"
    cmd="$(jq -r '.source.command // empty' <<<"$entry")"
    if [[ ! "$cmd" =~ $COMMAND_RE ]] || (( ${#cmd} > 256 )); then
      flag "I9" "$name: source.command must be words of [A-Za-z0-9._/=:-] separated by single spaces (max 256 chars): $cmd" "$name"
    fi
  fi
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    if has_unsafe_chars "$v"; then
      flag "I9" "$name: source field contains shell metacharacters: $v" "$name"
    fi
  done < <(jq -r --arg skip "$skip_key" '.source | to_entries[] | select(.key != $skip) | select(.value|type=="string") | .value' <<<"$entry")
done < <(jq -c '.plugins[] | select(.source | type == "object")' -- "$MP")

# I6 / I7 — per-file mode only
if [[ -n "${ENTRIES_DIR:-}" ]]; then
  for f in "$ENTRIES_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f" .json)"
    inner="$(jq -r '.name' -- "$f")"
    [[ "$base" == "$inner" ]] || flag "I6" "$f: filename '$base' != .name '$inner'" "$inner"
  done
  if git diff --name-only "$BASE_REF"...HEAD 2>/dev/null | grep -qxF -- "$MARKETPLACE_PATH"; then
    flag "I7" "PR edits $MARKETPLACE_PATH directly; per-file repos must edit $ENTRIES_DIR/*.json only"
  fi
fi

# I8 — vendored paths exist
while IFS= read -r entry; do
  name="$(jq -r '.name' <<<"$entry")"
  p="$(jq -r '.source' <<<"$entry")"
  if has_unsafe_chars "$p" || [[ "$p" == *".."* ]]; then
    flag "I9" "$name: vendored source path contains unsafe characters: $p" "$name"
    continue
  fi
  p_clean="${p#./}"
  if [[ ! -f "$p_clean/.claude-plugin/plugin.json" ]]; then
    flag "I8" "$name: vendored source '$p' has no .claude-plugin/plugin.json" "$name"
  fi
done < <(jq -c '.plugins[] | select(.source | type == "string")' -- "$MP")

if (( failures > 0 )); then
  die "$failures invariant error(s), $warnings warning(s)"
fi

if (( warnings > 0 )) && [[ "${FAIL_ON_WARNINGS:-false}" == "true" ]]; then
  die "$warnings invariant warning(s) (fail-on-warnings is set)"
fi

record_result "invariants" "pass" "summary" "0 errors, $warnings warning(s)"
log "invariants: 0 errors, $warnings warning(s)"
group_end
