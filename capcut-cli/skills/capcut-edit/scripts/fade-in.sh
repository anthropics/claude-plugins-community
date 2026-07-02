#!/usr/bin/env bash
# fade-in.sh — thin wrapper around anim.sh with slug "fade-in".
#
# Usage: fade-in.sh <project> <segment-id> [<duration>]
#
# Default duration: 0.5s (CapCut default for Fade In).
#
# All logic lives in anim.sh + animations.json. Keep this wrapper so the
# PLAN.md Phase 0 deliverable name stays stable.

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <project> <segment-id> [<duration>]" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="$1"; seg="$2"; dur="${3:-}"

if [[ -n "$dur" ]]; then
  exec "$script_dir/anim.sh" "$project" "$seg" fade-in "$dur"
else
  exec "$script_dir/anim.sh" "$project" "$seg" fade-in
fi
