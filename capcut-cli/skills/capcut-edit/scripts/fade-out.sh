#!/usr/bin/env bash
# fade-out.sh — thin wrapper around anim.sh with slug "fade-out".
#
# Usage: fade-out.sh <project> <segment-id> [<duration>]
#
# Default duration: 0.5s (CapCut default for Fade Out).
# The outro is anchored at the end of the segment — anim.sh computes
# start = target_duration - duration so the fade finishes at the cut.
#
# All logic lives in anim.sh + animations.json.

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <project> <segment-id> [<duration>]" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$1"; seg="$2"; dur="${3:-}"

if [[ -n "$dur" ]]; then
  exec "$script_dir/anim.sh" "$project" "$seg" fade-out "$dur"
else
  exec "$script_dir/anim.sh" "$project" "$seg" fade-out
fi
