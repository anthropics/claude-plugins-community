#!/usr/bin/env bash
# long-to-short.sh — cut a range from a long-form project and stamp a title + CTA.
#
# Usage:
#   long-to-short.sh <project> <start> <end> <out-path> <title-text> <cta-text>
#
#   <project>    long-form CapCut project directory or draft JSON
#   <start>      start time (e.g. 2:30, 150s)
#   <end>        end time
#   <out-path>   output draft JSON path (new file; source is not modified)
#   <title-text> text stamped at the top for the first 3 seconds
#   <cta-text>   text stamped at the bottom for the last 3 seconds
#
# Pipeline:
#   1. capcut cut   — extract the range to <out-path>
#   2. capcut add-text — title, centred-upper, first 3s
#   3. capcut add-text — CTA, centred-lower, last 3s

set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <project> <start> <end> <out-path> <title-text> <cta-text>" >&2
  exit 2
fi

project="$1"
start="$2"
end="$3"
out="$4"
title="$5"
cta="$6"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cli="$script_dir/../../../dist/index.js"

if [[ ! -f "$cli" ]]; then
  echo "capcut CLI not found at $cli — run \`npm run build\` in capcut-cli/" >&2
  exit 1
fi

# 1. Cut the range
node "$cli" cut "$project" "$start" "$end" --out "$out" >/dev/null

# Compute total duration in seconds for positioning the CTA at the tail.
# parseTimeInput accepts the same formats on both ends, so we trust capcut
# to have placed the cut accurately and work in seconds here via the cli.
total_us=$(node -e "
const fs=require('fs');
const d=JSON.parse(fs.readFileSync('$out','utf8'));
console.log(d.duration);
")

# 2. Title — first 3 seconds, upper-centre
node "$cli" add-text "$out" 0 3s "$title" --font-size 18 --y -0.6 >/dev/null

# 3. CTA — last 3 seconds, lower-centre
cta_start_ms=$(( (total_us - 3000000) / 1000 ))
if (( cta_start_ms < 0 )); then cta_start_ms=0; fi
node "$cli" add-text "$out" "${cta_start_ms}ms" 3s "$cta" --font-size 18 --y 0.6 >/dev/null

echo "{\"ok\":true,\"out\":\"$out\",\"duration_us\":$total_us,\"title\":\"$title\",\"cta\":\"$cta\"}"
