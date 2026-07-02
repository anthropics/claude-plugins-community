#!/usr/bin/env bash
# ken-burns.sh — animate uniform scale + position on a video/image segment.
#
# Usage:
#   ken-burns.sh <project> <segment-id> \
#     <start-scale> <end-scale> \
#     <tx-start> <tx-end> \
#     <ty-start> <ty-end> \
#     <duration>
#
#   <start/end-scale>  uniform scale values (1.0 = no zoom, 1.2 = 20% zoom-in)
#   <tx-start/tx-end>  horizontal position in half-canvas units (-1..1, 0 = center)
#   <ty-start/ty-end>  vertical position in half-canvas units (-1..1)
#   <duration>         time string (e.g. 3s, 500ms)
#
# Writes 6 keyframes total via `capcut keyframe --batch`: uniform_scale,
# position_x, position_y — each with a start keyframe at t=0 and an end
# keyframe at t=duration. Keyframes for motion properties render correctly
# in CapCut (unlike alpha — see pitfalls.md).

set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "Usage: $0 <project> <segment-id> <start-scale> <end-scale> <tx-start> <tx-end> <ty-start> <ty-end> <duration>" >&2
  exit 2
fi

project="$1"
segment_id="$2"
start_scale="$3"
end_scale="$4"
tx_start="$5"
tx_end="$6"
ty_start="$7"
ty_end="$8"
duration="$9"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cli="$script_dir/../../../dist/index.js"

if [[ ! -f "$cli" ]]; then
  echo "capcut CLI not found at $cli — run \`npm run build\` in capcut-cli/" >&2
  exit 1
fi

node "$cli" keyframe "$project" "$segment_id" --batch <<EOF
{"property":"uniform_scale","time":"0","value":"$start_scale"}
{"property":"uniform_scale","time":"$duration","value":"$end_scale"}
{"property":"position_x","time":"0","value":"$tx_start"}
{"property":"position_x","time":"$duration","value":"$tx_end"}
{"property":"position_y","time":"0","value":"$ty_start"}
{"property":"position_y","time":"$duration","value":"$ty_end"}
EOF
