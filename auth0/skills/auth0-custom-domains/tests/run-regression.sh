#!/usr/bin/env bash
# Regression harness for the auth0-custom-domains skill.
#
# Runs each regression prompt through `claude -p --plugin-dir <auth0 plugin>`
# in a fresh session, captures the response to tests/logs/<slug>.log, and
# prints a summary you can eyeball.
#
# The --plugin-dir flag is required: without it, claude -p sub-sessions do
# NOT load plugin skills unless the plugin is installed from a marketplace.
# With it, auto-discovery surfaces every skill in the directory (including
# sibling skills) so routing signals are real, not hallucinated from
# Claude's general Auth0 knowledge.
#
# This is a routing test, not an end-to-end test. Prompts typically stop at
# the skill's pre-flight tenant confirmation step because no tenant is wired
# in; what we're checking is that Claude picks the right capability and
# starts down its flow. For true E2E, run the prompts interactively against
# a real tenant and real DNS zone (see README.md in this directory).

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"

# Load the auth0 plugin from the local repo for the duration of each claude -p call.
# Without this, claude -p sub-sessions do not see plugin skills unless the plugin is
# installed in the user's marketplace. Auto-discovery surfaces every skill in the
# directory, so this enables the sibling skills (auth0-branding, auth0-cli, ...) too.
PLUGIN_DIR="$(cd "$ROOT/../.." && pwd)"

# Name => expected capability marker (case-insensitive regex matched against the full response).
#
# IMPORTANT: Markers must target SKILL-SPECIFIC jargon — API paths, exact field
# names, Management API shapes, and flow phrases that appear in this skill's
# reference files but are unlikely to appear in a generic Claude response
# about Auth0 custom domains. Avoid phrases like "active tenant", "tenants
# list", or "custom domain health" — those are general Auth0 vocabulary
# Claude emits even when this skill did not route. If a marker matches
# without the skill loaded, it's a false positive. Update these when
# SKILL.md terminology changes.
#
# Because `read` splits on every '|' but we only assign three vars (slug,
# prompt, marker), any extra '|'-separated segments after the third stay in
# `marker` as literal pipes — which are exactly the regex-OR separators that
# `grep -E` treats as alternatives. So listing several markers after the
# third field below is intentional, not accidental; each one is a valid hit.
declare -a PROMPTS=(
  "cap5-health|Check the health of my Auth0 custom domains.|verification\\.methods|auth0_managed_certs|dns record (match|mismatch)|tenants/settings|renewal-at-risk"
  "cap1-setup-cloudflare|Set up login.acme-corp.io as a custom domain on my Auth0 tenant. My DNS is at Cloudflare.|cloudflare mcp|proxied.*false|relying_party_identifier|custom_client_ip_header|POST /custom-domains"
  "cap2-troubleshoot|My custom domain login.acme.com has been stuck in pending_verification for over an hour.|diagnostic ladder|cname flattening|verification\\.methods|pending_verification|flattening"
  "cap3-manage-multi|I have three custom domains on this tenant. Make login-eu.example.com the default, and set the relying party identifier on login.example.com to example.com.|relying_party_identifier|default_custom_domain_id|PATCH /custom-domains|default custom domain"
  "cap3-metadata|Tag login.example.com with region=us-east and brand=acme so Actions can read it.|domain_metadata|GET.*merge.*PATCH|event\\.custom_domain"
  "cap4-remove-route53|Remove login-legacy.example.com from my Auth0 tenant. DNS is at Route 53.|change-resource-record-sets|default_custom_domain_id|DELETE /custom-domains|scan tier"
  "cap4-remove-default-ask|Remove login-legacy.example.com from my Auth0 tenant.|skip.*scan|quick scan.*deep scan|scan tier|where.*referenced|quick.*deep.*skip"
  "cap4-remove-skip|Remove login-legacy.example.com from my Auth0 tenant. I've already audited the tenant myself; skip the scan and proceed to delete.|already audited|without.*scan|skip.*scan|destructive delete|DELETE /custom-domains"
  "cap4-remove-quick|Remove login-legacy.example.com from my Auth0 tenant. Run a quick scan first to find any references, then proceed.|email-templates|emails/provider|quick scan|clients.*tenant.*email|external.*check yourself"
  "cap4-remove-deep|Remove login-legacy.example.com from my Auth0 tenant. Run a deep scan across everything reachable via the API, then proceed.|actions/actions|log-streams|resource-servers|deep scan|external.*check yourself"
  "ambiguous|Something's wrong with my Auth0 custom domain, can you look at it?|verification\\.methods|dig.*cname|auth0_managed_certs|read-only.*start|check domain health"
  "err-free-tier-403|I tried to create a custom domain on my Free-tier Auth0 tenant and got a 403 error. What do I do?|credit card on file|tenant settings.*billing|card is not charged|not.*plan upgrade|does not.*upgrade"
  "err-type-patch|I want to switch my custom domain login.acme-corp.io from Auth0-managed to self-managed certs. How do I PATCH it?|fixed at create|rejected.*patch|not patchable|delete.*recreate.*downtime"
  "err-self-managed-free|Create login.acme-corp.io with self-managed certs on my Free tenant.|self_managed_certs.*enterprise|two blockers|both.*requirements|enterprise.*credit card"
  "err-domain-taken|I tried to create login.acme-corp.io as a custom domain but got a 409 conflict error. The domain must be used somewhere else.|already.*tenant|auth0 domains list|409.*custom-domain|different domain"
)

# Slugs that are known to REVIEW reliably because `claude -p` cuts the session
# at the skill-mandated `auth0 tenants list` permission prompt with a reply
# that's too short to match any capability-specific marker. A REVIEW on one
# of these slugs is expected; a REVIEW on any other slug is a regression
# signal worth reading. Populate this list from the last known-good harness
# run. Empty means "every REVIEW is a potential regression."
declare -A KNOWN_FLAKY=(
  # e.g. [ambiguous]=1
)

pass=0
fail=0
known=0
declare -a failures=()
declare -a known_reviews=()

printf '%-30s %-14s %s\n' "PROMPT" "RESULT" "LOG"
printf '%s\n' "------------------------------ -------------- ----------------------------------------"

for entry in "${PROMPTS[@]}"; do
  IFS='|' read -r slug prompt marker <<< "$entry"
  log="$LOG_DIR/$slug.log"

  # Run in non-interactive mode, fresh session, no streaming.
  claude -p --plugin-dir "$PLUGIN_DIR" "$prompt" > "$log" 2>&1 || true

  if grep -qiE "$marker" "$log"; then
    printf '%-30s %-14s %s\n' "$slug" "PASS" "$log"
    pass=$((pass + 1))
  elif [ -n "${KNOWN_FLAKY[$slug]:-}" ]; then
    printf '%-30s %-14s %s\n' "$slug" "KNOWN_REVIEW" "$log"
    known_reviews+=("$slug")
    known=$((known + 1))
  else
    printf '%-30s %-14s %s\n' "$slug" "REVIEW" "$log"
    failures+=("$slug (expected: $marker)")
    fail=$((fail + 1))
  fi
done

echo
echo "Summary: $pass passed, $fail need review, $known known-flaky."
if [ $fail -gt 0 ]; then
  echo
  echo "Needs review (not in KNOWN_FLAKY):"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
  echo
  echo "Open the logs above; a REVIEW doesn't always mean the skill misrouted."
  echo "Claude may have chosen different phrasing. Read the log to decide. If a"
  echo "REVIEW is expected (e.g. claude -p cut the session short), add the slug"
  echo "to KNOWN_FLAKY at the top of this script."
fi
if [ $known -gt 0 ]; then
  echo
  echo "Known-flaky (REVIEW is expected):"
  for s in "${known_reviews[@]}"; do
    echo "  - $s"
  done
fi
