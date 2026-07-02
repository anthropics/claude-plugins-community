#!/usr/bin/env bash
# stamp-cta.sh — apply a saved CTA template into a project at a given time.
#
# Usage:
#   stamp-cta.sh <project> <template.json> <start> <duration> [<text>]
#
#   <project>       CapCut project directory or draft JSON
#   <template.json> saved template (e.g. ../assets/examples/subscribe-cta.json)
#   <start>         start time (e.g. 0:27, 2:30.5)
#   <duration>      duration (e.g. 3s, 5000ms)
#   <text>          optional: override the template's text body
#
# Thin wrapper around `capcut apply-template` so the CTA stamping recipe is
# a one-line script call rather than a remembered CLI invocation.

set -euo pipefail

if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo "Usage: $0 <project> <template.json> <start> <duration> [<text>]" >&2
  exit 2
fi

project="$1"
template="$2"
start="$3"
duration="$4"
text="${5:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cli="$script_dir/../../../dist/index.js"

if [[ ! -f "$cli" ]]; then
  echo "capcut CLI not found at $cli — run \`npm run build\` in capcut-cli/" >&2
  exit 1
fi

if [[ -n "$text" ]]; then
  node "$cli" apply-template "$project" "$template" "$start" "$duration" "$text"
else
  node "$cli" apply-template "$project" "$template" "$start" "$duration"
fi
